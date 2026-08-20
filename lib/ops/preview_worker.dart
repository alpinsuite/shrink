/// A long-lived isolate that holds one decoded image and re-encodes it on
/// demand.
///
/// The estimate beside each control has to be a *measurement* rather than a
/// guess, which means really encoding the image every time a slider settles.
/// Doing that through `Isolate.run` would decode the source again on every
/// keystroke, and a 12 MP JPEG decode in pure Dart is a second or two — so the
/// numbers would always be several seconds behind the controls that produced
/// them.
///
/// This keeps the decoded image resident instead. The first measurement pays
/// for the decode; every one after it is a resize and an encode.
///
/// Only one image is held at a time — the selected one. Caching more would mean
/// holding several uncompressed bitmaps, which for camera-sized photographs is
/// hundreds of megabytes for images nobody is looking at.
library;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../core/fire_and_forget.dart';
import '../model/output_format.dart';
import '../model/pixel_size.dart';
import '../model/resize_target.dart';
import 'encode_ops.dart';
import 'size_model.dart';

/// The source, once it has been decoded.
@immutable
class PreviewSource {
  const PreviewSource({required this.size, required this.sourceBytes});

  final PixelSize size;
  final int sourceBytes;
}

/// One real encode at the current settings.
@immutable
class PreviewMeasurement {
  const PreviewMeasurement({
    required this.size,
    required this.bytes,
    required this.quality,
    required this.budgetMet,
    required this.samples,
    this.data,
  });

  final PixelSize size;
  final int bytes;

  /// The quality actually used, which is lower than requested when a byte
  /// budget had to be met.
  final int quality;

  /// False when the budget could not be met by any combination of quality and
  /// dimensions. The panel says so rather than showing a number that quietly
  /// exceeds what was asked for.
  final bool budgetMet;

  /// Everything measured on the way, for the estimator to learn from.
  final List<SizeSample> samples;

  /// The encoded output, for the preview to draw. Withheld when it is large
  /// enough that shipping it across the boundary would cost more than the
  /// picture is worth.
  final Uint8List? data;
}

/// Above this, the encoded output is not sent back for display.
///
/// The engine decodes it natively and quickly at any size, but copying the
/// bytes out of the worker is a real allocation, and nobody is inspecting
/// compression artefacts on a file this big through a panel this small.
const int _maxPreviewBytes = 12 * 1024 * 1024;

/// The estimator's client-side handle on the worker.
class PreviewWorker {
  PreviewWorker._(this._isolate, this._responses) {
    _subscription = _responses.listen(_onMessage);
  }

  final Isolate _isolate;
  final ReceivePort _responses;
  late final StreamSubscription<dynamic> _subscription;

  /// Completes with the worker's own port once it has sent one, or with null
  /// if this handle was disposed before that ever happened. Null rather than an
  /// error: nothing is in a position to handle a failure here, and an
  /// unobserved error on a completer nobody is awaiting is a crash.
  final Completer<SendPort?> _ready = Completer<SendPort?>();

  final Map<int, Completer<Object?>> _pending = <int, Completer<Object?>>{};
  int _nextId = 0;
  bool _disposed = false;

  static Future<PreviewWorker> spawn() async {
    final responses = ReceivePort();
    final isolate = await Isolate.spawn(_entry, responses.sendPort);
    final worker = PreviewWorker._(isolate, responses);
    // A `ReceivePort` is a single-subscription stream, so the handshake cannot
    // be read with its own listener and the replies with another — the second
    // `listen` throws, the worker looks alive, and every measurement hangs
    // forever. One listener handles both.
    await worker._ready.future;
    return worker;
  }

  /// Decodes [path] and keeps it. Null when it is not a readable image.
  Future<PreviewSource?> load(String path) async {
    final result = await _call(_LoadRequest(path));
    return result as PreviewSource?;
  }

  /// Encodes the held image at [target]. Null when nothing is loaded.
  ///
  /// [format] must already be resolved — the worker has no opinion about what
  /// "same as source" means.
  Future<PreviewMeasurement?> measure({
    required ResizeTarget target,
    required OutputFormat format,
    required bool wantImage,
  }) async {
    final result = await _call(
      _MeasureRequest(target: target, format: format, wantImage: wantImage),
    );
    return result as PreviewMeasurement?;
  }

  Future<Object?> _call(Object request) async {
    if (_disposed) return null;
    final send = await _ready.future;
    if (send == null || _disposed) return null;
    final id = _nextId++;
    final completer = Completer<Object?>();
    _pending[id] = completer;
    send.send(_Envelope(id, request));
    return completer.future;
  }

  void _onMessage(dynamic message) {
    // The worker's first message is the port to talk back on.
    if (message is SendPort) {
      if (!_ready.isCompleted) _ready.complete(message);
      return;
    }
    if (message is! _Envelope) return;
    final completer = _pending.remove(message.id);
    if (completer == null || completer.isCompleted) return;
    final payload = message.payload;
    completer.complete(payload is _Failure ? null : payload);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    // Anything still in flight will never be answered; completing it keeps a
    // caller from awaiting a future that can no longer be resolved. The
    // handshake counts: disposing before the worker ever replied would
    // otherwise leave `_call` waiting on it for the life of the process.
    for (final completer in _pending.values) {
      if (!completer.isCompleted) completer.complete(null);
    }
    _pending.clear();
    if (!_ready.isCompleted) _ready.complete(null);
    fireAndForget(_subscription.cancel());
    _responses.close();
    _isolate.kill(priority: Isolate.immediate);
  }
}

// ---------------------------------------------------------------------------
// Wire types. Plain values: they cross an isolate boundary.
// ---------------------------------------------------------------------------

@immutable
class _Envelope {
  const _Envelope(this.id, this.payload);

  final int id;
  final Object? payload;
}

@immutable
class _LoadRequest {
  const _LoadRequest(this.path);

  final String path;
}

@immutable
class _MeasureRequest {
  const _MeasureRequest({
    required this.target,
    required this.format,
    required this.wantImage,
  });

  final ResizeTarget target;
  final OutputFormat format;
  final bool wantImage;
}

@immutable
class _Failure {
  const _Failure();
}

// ---------------------------------------------------------------------------
// The worker.
// ---------------------------------------------------------------------------

void _entry(SendPort send) {
  final requests = ReceivePort();
  send.send(requests.sendPort);

  img.Image? held;

  requests.listen((dynamic message) {
    if (message is! _Envelope) return;
    final request = message.payload;

    try {
      if (request is _LoadRequest) {
        final data = File(request.path).readAsBytesSync();
        final decoded = EncodeOps.decode(data, request.path);
        if (decoded == null) {
          send.send(_Envelope(message.id, const _Failure()));
          return;
        }
        held = decoded;
        send.send(
          _Envelope(
            message.id,
            PreviewSource(
              size: PixelSize(decoded.width, decoded.height),
              sourceBytes: data.length,
            ),
          ),
        );
        return;
      }

      if (request is _MeasureRequest) {
        final source = held;
        if (source == null) {
          send.send(_Envelope(message.id, const _Failure()));
          return;
        }
        send.send(_Envelope(message.id, _measure(source, request)));
        return;
      }
    } catch (_) {
      // A malformed file or an encoder that refuses this particular image must
      // not take the worker down with it — the next request may well be for a
      // different image entirely.
      send.send(_Envelope(message.id, const _Failure()));
    }
  });
}

/// Runs the batch's own pipeline against the resident image.
///
/// [EncodeOps.encodeImage] is the single implementation of resize-encode-meet-
/// the-budget; this adds nothing to it but the decision about whether to ship
/// the pixels back for display.
PreviewMeasurement _measure(img.Image source, _MeasureRequest request) {
  final result = EncodeOps.encodeImage(
    source: source,
    format: request.format,
    quality: request.target.quality,
    maxEdge: request.target.maxEdge,
    maxBytes: request.target.maxBytes,
  );

  return PreviewMeasurement(
    size: result.size,
    bytes: result.bytes,
    quality: result.quality,
    budgetMet: result.budgetMet,
    samples: result.samples,
    data: request.wantImage && result.bytes <= _maxPreviewBytes
        ? result.data
        : null,
  );
}
