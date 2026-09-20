import 'dart:io';

import 'package:flutter/material.dart';
import 'package:slate_ui/slate_ui.dart';

import '../controller/estimate_controller.dart';
import '../core/byte_format.dart';
import '../core/theme.dart';
import '../l10n/generated/app_localizations.dart';
import '../model/batch_item.dart';

/// Which halves of the comparison are on screen.
enum PreviewMode {
  /// Side by side. What the panel always shows, and the overlay's default.
  both,

  /// One image across the full width, for looking at compression closely.
  original,
  result,
}

/// The before-and-after itself, at whatever size it is given.
///
/// One widget for the panel and the enlarged overlay, so the caption under the
/// small picture and the caption under the big one cannot come to disagree
/// about what was measured.
class PreviewComparison extends StatelessWidget {
  const PreviewComparison({
    required this.item,
    required this.estimates,
    this.mode = PreviewMode.both,
    this.onTapPane,
    super.key,
  });

  final BatchItem item;
  final EstimateController estimates;
  final PreviewMode mode;

  /// Tapping a picture. The panel uses it to open the enlarged view, which is
  /// the affordance people reach for before they find the button.
  final VoidCallback? onTapPane;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final estimate = estimates.estimate;
    final source = item.size;

    final original = _Pane(
      title: l10n.previewOriginal,
      onTap: onTapPane,
      // Straight from disk: the engine decodes it natively, which is both
      // faster than anything this application could do and the honest thing to
      // show as "before".
      image: Image.file(
        // Keyed, or Flutter reuses the element and shows the previous file's
        // pixels when the selection changes.
        key: ValueKey<String>(item.path),
        File(item.path),
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stack) => const SizedBox.shrink(),
      ),
      caption: source == null
          ? ''
          : '${l10n.dimensions(source.width, source.height)}  '
                '${ByteFormat.format(item.sourceBytes)}',
    );

    final data = estimates.previewData;
    final result = _Pane(
      title: l10n.previewResult,
      onTap: onTapPane,
      image: data == null
          ? null
          : Image.memory(
              data,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              // Keyed on length so a re-encode at new settings really replaces
              // the picture rather than being deduplicated against the last.
              key: ValueKey<int>(data.length),
              errorBuilder: (context, error, stack) => const SizedBox.shrink(),
            ),
      caption: _resultCaption(l10n, estimate),
      warn: !estimate.budgetMet,
      // Only the result side is ever being computed. The original is a file on
      // disk and appears immediately.
      busy: estimates.isMeasuring,
      busyLabel: l10n.previewMeasuring,
    );

    return switch (mode) {
      PreviewMode.original => original,
      PreviewMode.result => result,
      PreviewMode.both => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(child: original),
          const SizedBox(width: 10),
          Expanded(child: result),
        ],
      ),
    };
  }

  /// `1600 x 1200  ~ 480 KB  quality 74`.
  ///
  /// The `~` is dropped the moment the number comes from a real encode, which
  /// is the whole distinction this panel exists to make.
  static String _resultCaption(AppLocalizations l10n, TargetEstimate estimate) {
    final size = estimate.outputSize;
    final bytes = estimate.outputBytes;
    if (size == null || bytes == null) return '';

    final formatted = ByteFormat.format(bytes);
    final quality = estimate.quality;
    return <String>[
      l10n.dimensions(size.width, size.height),
      estimate.measured ? formatted : l10n.approximately(formatted),
      if (estimate.keptOriginal)
        l10n.previewKeptOriginal
      else if (quality != null && estimate.measured && estimate.qualityApplies)
        l10n.previewQualityUsed(quality),
    ].join('  ');
  }
}

/// One side of the comparison: a title, a picture on a checkerboard, a caption.
class _Pane extends StatelessWidget {
  const _Pane({
    required this.title,
    required this.image,
    required this.caption,
    this.warn = false,
    this.onTap,
    this.busy = false,
    this.busyLabel = '',
  });

  final String title;
  final Widget? image;
  final String caption;

  /// A real encode is in flight for this pane.
  ///
  /// A 12 MP source takes a moment to decode the first time, and a lossless
  /// format at full size takes longer still — long enough that without saying
  /// so the panel looks broken rather than busy.
  final bool busy;
  final String busyLabel;

  /// Draws the caption in the danger colour — used when the size budget could
  /// not be met, which is the one thing here worth interrupting for.
  final bool warn;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.slate;
    final (light, dark) = AppTheme.checkerboard(theme.palette);

    final picture = image;
    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.palette.separator),
      ),
      child: CustomPaint(
        painter: _CheckerPainter(light: light, dark: dark),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (picture != null)
              Padding(
                padding: const EdgeInsets.all(1),
                // Faded while a new encode is running, so what is on screen
                // reads as the previous answer rather than the current one.
                child: busy ? Opacity(opacity: 0.35, child: picture) : picture,
              ),
            if (busy && picture == null)
              Center(child: Text(busyLabel, style: theme.dimTextStyle)),
            if (busy)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: _IndeterminateBar(color: theme.palette.accent),
              ),
          ],
        ),
      ),
    );

    if (onTap != null) {
      surface = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          // Translucent, so the tap lands on the whole pane and not only where
          // the picture happens to be — a portrait image in a wide pane leaves
          // most of the box empty.
          behavior: HitTestBehavior.translucent,
          child: surface,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(title, style: theme.sectionStyle),
        const SizedBox(height: 4),
        Expanded(child: surface),
        const SizedBox(height: 4),
        Text(
          caption,
          overflow: TextOverflow.ellipsis,
          style: warn
              ? theme.dimTextStyle.copyWith(color: theme.palette.danger)
              : theme.dimTextStyle,
        ),
      ],
    );
  }
}

/// A segment sliding along the top edge of a pane that is working.
///
/// Not a `LinearProgressIndicator` and not a spinner: there is no progress to
/// report — the encode takes as long as it takes — and Material's indicator
/// carries a rounded track and a colour scheme that reads as a different piece
/// of software next to hairline rules.
class _IndeterminateBar extends StatefulWidget {
  const _IndeterminateBar({required this.color});

  final Color color;

  @override
  State<_IndeterminateBar> createState() => _IndeterminateBarState();
}

class _IndeterminateBarState extends State<_IndeterminateBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 2,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => CustomPaint(
          painter: _BarPainter(
            progress: _controller.value,
            color: widget.color,
          ),
        ),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  const _BarPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  /// How much of the width the moving segment covers.
  static const double _segment = 0.28;

  @override
  void paint(Canvas canvas, Size size) {
    // Travels a full segment past each end, so it enters and leaves rather
    // than appearing and vanishing at the edges.
    final span = size.width * (1 + _segment * 2);
    final left = progress * span - size.width * _segment;
    canvas.drawRect(
      Rect.fromLTWH(left, 0, size.width * _segment, size.height),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_BarPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

/// The transparency checkerboard.
///
/// Two greys rather than one, because "nothing is here" has to read as
/// different from "this part of the picture is grey" — which a flat colour
/// cannot do.
class _CheckerPainter extends CustomPainter {
  const _CheckerPainter({required this.light, required this.dark});

  final Color light;
  final Color dark;

  static const double _square = 8;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = light);
    final paint = Paint()..color = dark;
    for (var y = 0.0; y < size.height; y += _square) {
      for (
        var x = ((y / _square).floor().isEven ? _square : 0.0);
        x < size.width;
        x += _square * 2
      ) {
        canvas.drawRect(
          Rect.fromLTWH(
            x,
            y,
            _square.clamp(0, size.width - x),
            _square.clamp(0, size.height - y),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_CheckerPainter oldDelegate) =>
      oldDelegate.light != light || oldDelegate.dark != dark;
}
