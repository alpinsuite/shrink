// End-to-end: real files on a real disk, through the real controllers, with the
// real encoders — and then the *files* are checked, not the reported numbers.
//
// The unit tests assert that the pipeline computes the right things. This
// asserts that pressing Start puts images on the disk that meet what was asked
// for, which is the only claim a user of this application actually cares about.
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shrink/controller/batch_controller.dart';
import 'package:shrink/controller/queue_controller.dart';
import 'package:shrink/controller/target_controller.dart';
import 'package:shrink/core/settings_controller.dart';
import 'package:shrink/model/batch_item.dart';
import 'package:shrink/model/output_format.dart';
import 'package:shrink/model/output_options.dart';
import 'package:shrink/model/resize_target.dart';

void main() {
  // The controllers reach shared_preferences and `compute`, both of which need
  // the binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory workspace;

  /// Photograph-like content: gradients, noise and hard edges, so the encoders
  /// have real work to do. Flat colour compresses to almost nothing and would
  /// make every budget trivially reachable.
  img.Image photo(int width, int height, int seed) {
    final image = img.Image(width: width, height: height, numChannels: 3);
    final random = math.Random(seed);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final wave = (math.sin(x / 40.0 + seed) * math.cos(y / 30.0) * 60)
            .round();
        image.setPixelRgb(
          x,
          y,
          (120 + wave + random.nextInt(60)).clamp(0, 255),
          (90 + (x * 255 ~/ width) ~/ 2 + random.nextInt(60)).clamp(0, 255),
          (160 - wave + random.nextInt(60)).clamp(0, 255),
        );
      }
    }
    return image;
  }

  File write(String name, List<int> bytes) {
    final file = File(p.join(workspace.path, name))..writeAsBytesSync(bytes);
    return file;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    workspace = Directory.systemTemp.createTempSync('shrink_batch_test');
  });

  tearDown(() => workspace.deleteSync(recursive: true));

  /// Builds the three controllers the window wires together, and runs the
  /// queue to completion.
  Future<(QueueController, BatchController)> run({
    required List<String> paths,
    required void Function(TargetController) configure,
  }) async {
    final settings = await SettingsController.load();
    final queue = QueueController();
    final target = TargetController(settings: settings);
    final batch = BatchController(queue: queue, target: target);

    await queue.addPaths(paths);
    // Probing is deliberately fire-and-forget so the window stays responsive;
    // here there is nothing else to do until it lands.
    while (queue.items.any((i) => i.status == BatchItemStatus.probing)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    configure(target);
    await batch.start();
    return (queue, batch);
  }

  test(
    'meets a file-size budget on the disk, not just on the screen',
    () async {
      final big = write(
        'big.jpg',
        img.encodeJpg(photo(2000, 1500, 1), quality: 95),
      );
      expect(big.lengthSync(), greaterThan(500 * 1000));

      const budget = 200 * 1000;
      final (queue, batch) = await run(
        paths: <String>[big.path],
        configure: (target) => target
          ..format = OutputFormat.jpeg
          ..quality = 90
          ..maxBytes = budget,
      );

      expect(batch.summary.written, 1);
      expect(batch.summary.failed, 0);

      final item = queue.items.single;
      expect(item.status, BatchItemStatus.done);
      expect(item.budgetMet, isTrue);

      // The claim under test: the file itself.
      final output = File(item.outputPath!);
      expect(output.existsSync(), isTrue);
      expect(
        output.lengthSync(),
        lessThanOrEqualTo(budget),
        reason: 'the batch reported success for a file that is over budget',
      );
      expect(item.outputBytes, output.lengthSync());
      // And it is still a readable image, not a truncated one.
      expect(img.decodeImage(output.readAsBytesSync()), isNotNull);
    },
  );

  test('caps the longest edge without upscaling anything', () async {
    final landscape = write(
      'landscape.jpg',
      img.encodeJpg(photo(1600, 900, 2), quality: 90),
    );
    final portrait = write(
      'portrait.jpg',
      img.encodeJpg(photo(900, 1600, 3), quality: 90),
    );
    final small = write(
      'small.jpg',
      img.encodeJpg(photo(320, 240, 4), quality: 90),
    );

    final (queue, batch) = await run(
      paths: <String>[landscape.path, portrait.path, small.path],
      configure: (target) => target
        ..format = OutputFormat.jpeg
        ..maxEdge = 800,
    );
    expect(batch.summary.written, 3);

    for (final item in queue.items) {
      final decoded = img.decodeImage(
        File(item.outputPath!).readAsBytesSync(),
      )!;
      final longest = math.max(decoded.width, decoded.height);
      if (item.name.startsWith('small')) {
        // Already inside the cap: "maximum edge" has to mean a maximum.
        expect(decoded.width, 320);
        expect(decoded.height, 240);
      } else {
        expect(longest, 800);
      }
    }
  });

  test('never writes a file larger than the one it came from', () async {
    // The defaults, on a JPEG that was saved small: encoding it again at 85
    // would come out bigger. What lands on the disk has to be the original.
    final small = write(
      'small.jpg',
      img.encodeJpg(photo(900, 600, 4), quality: 35),
    );
    final before = small.readAsBytesSync();

    final (queue, batch) = await run(
      paths: <String>[small.path],
      configure: (target) => target
        ..maxEdge = null
        ..quality = 85,
    );

    final item = queue.items.single;
    expect(item.status, BatchItemStatus.done);
    expect(item.keptOriginal, isTrue);
    expect(batch.summary.written, 1);

    final output = File(item.outputPath!);
    expect(output.path, isNot(small.path));
    expect(output.readAsBytesSync(), before, reason: 'byte for byte');
    expect(item.outputBytes, before.length);
    expect(small.readAsBytesSync(), before, reason: 'and the source untouched');
  });

  test('a first launch starts with the longest edge switched on', () async {
    final settings = await SettingsController.load();
    expect(settings.target.maxEdge, ResizeTarget.firstLaunchMaxEdge);
  });

  test('an edge that was switched off stays off', () async {
    final settings = await SettingsController.load();
    await settings.setTarget(settings.target.withMaxEdge(null));

    final reloaded = await SettingsController.load();
    expect(reloaded.target.maxEdge, isNull);
  });

  test('never writes over a source file', () async {
    // The most destructive thing this application could do: an empty suffix,
    // the same format, and the originals as somebody's only copy.
    final source = write(
      'photo.jpg',
      img.encodeJpg(photo(400, 300, 5), quality: 90),
    );
    final before = source.readAsBytesSync();

    final (queue, batch) = await run(
      paths: <String>[source.path],
      configure: (target) => target
        ..format = OutputFormat.jpeg
        ..quality = 40
        ..output = const OutputOptions(
          suffix: '',
          collision: CollisionPolicy.overwrite,
        ),
    );

    expect(batch.summary.written, 1);
    expect(
      source.readAsBytesSync(),
      before,
      reason: 'the original was modified',
    );
    expect(queue.items.single.outputPath, isNot(source.path));
    expect(File(queue.items.single.outputPath!).existsSync(), isTrue);
  });

  test('converts format and takes the new extension', () async {
    final source = write('shot.png', img.encodePng(photo(500, 400, 6)));

    final (queue, _) = await run(
      paths: <String>[source.path],
      configure: (target) => target
        ..format = OutputFormat.jpeg
        ..quality = 80,
    );

    final output = queue.items.single.outputPath!;
    expect(p.extension(output), '.jpg');
    expect(
      img.findDecoderForData(File(output).readAsBytesSync()),
      isA<img.JpegDecoder>(),
    );
  });

  test(
    'reports a file it cannot write rather than writing something else',
    () async {
      // WebP is readable and, under "same as source", has no encoder. Writing it
      // as a PNG instead would be a format change nobody asked for.
      final source = write('shot.webp', img.encodeWebP(photo(200, 150, 7)));

      final (queue, batch) = await run(
        paths: <String>[source.path],
        configure: (target) => target.format = OutputFormat.sameAsSource,
      );

      expect(batch.summary.failed, 1);
      final item = queue.items.single;
      expect(item.status, BatchItemStatus.failed);
      expect(item.failure, BatchItemFailure.noEncoder);
      expect(
        Directory(workspace.path).listSync().length,
        1,
        reason: 'a file was written for a source that could not be encoded',
      );
    },
  );

  test('keeps going after a file it cannot read', () async {
    write('broken.png', 'not a png at all'.codeUnits);
    final good = write(
      'good.jpg',
      img.encodeJpg(photo(300, 200, 8), quality: 90),
    );

    final (queue, batch) = await run(
      paths: <String>[good.path, p.join(workspace.path, 'broken.png')],
      configure: (target) => target
        ..format = OutputFormat.jpeg
        ..quality = 70,
    );

    // The unreadable one is filtered out by the probe, so it never reaches the
    // batch — it stays in the queue saying why.
    expect(batch.summary.written, 1);
    final broken = queue.items.firstWhere((i) => i.name == 'broken.png');
    expect(broken.status, BatchItemStatus.unreadable);
  });

  test('reaches a budget for a lossless format by shrinking', () async {
    // PNG has no quality knob, so dimensions are the only lever. This is the
    // behaviour the target panel promises when it says a size limit will be
    // met by reducing dimensions alone.
    final source = write('dense.png', img.encodePng(photo(1200, 900, 9)));
    expect(source.lengthSync(), greaterThan(100 * 1000));

    const budget = 20 * 1000;
    final (queue, batch) = await run(
      paths: <String>[source.path],
      configure: (target) => target
        ..format = OutputFormat.png
        ..maxBytes = budget,
    );

    final item = queue.items.single;
    expect(item.status, BatchItemStatus.done);
    expect(item.budgetMet, isTrue);
    expect(batch.summary.missedBudget, 0);

    final output = File(item.outputPath!);
    expect(output.lengthSync(), lessThanOrEqualTo(budget));
    final decoded = img.decodeImage(output.readAsBytesSync())!;
    expect(
      math.max(decoded.width, decoded.height),
      lessThan(1200),
      reason: 'the only lever a lossless format has was not used',
    );
  });

  test('never claims a budget it did not meet', () async {
    // The invariant, independent of content: `budgetMet` and the size of the
    // file on disk must agree. Whether a given budget is reachable depends on
    // the picture — what must never happen is the batch reporting success for
    // a file that is over.
    //
    // Deliberately harsh and on dense content, so the search is pushed to the
    // end of every lever it has.
    final source = write(
      'noise.jpg',
      img.encodeJpg(photo(1400, 1000, 10), quality: 95),
    );

    final (queue, batch) = await run(
      paths: <String>[source.path],
      configure: (target) => target
        ..format = OutputFormat.jpeg
        // Below the minimum the interface offers, so this also pins the clamp:
        // the target is a value object that refuses to hold a budget no control
        // could have produced.
        ..maxBytes = 1,
    );

    // The clamp itself belongs to the value object, and this is what the
    // batch above was actually run against.
    expect(
      const ResizeTarget().withMaxBytes(1).maxBytes,
      ResizeTarget.minBudget,
      reason: 'a below-minimum budget was not clamped',
    );

    final item = queue.items.single;
    expect(item.status, BatchItemStatus.done);

    final output = File(item.outputPath!);
    expect(output.existsSync(), isTrue);
    expect(item.outputBytes, output.lengthSync());
    expect(
      item.budgetMet,
      output.lengthSync() <= ResizeTarget.minBudget,
      reason: 'the reported outcome disagrees with the file on disk',
    );
    expect(batch.summary.missedBudget, item.budgetMet ? 0 : 1);
    // Whatever happened, it is a real image and it is smaller than it was.
    expect(img.decodeImage(output.readAsBytesSync()), isNotNull);
    expect(output.lengthSync(), lessThan(source.lengthSync()));
  });
}
