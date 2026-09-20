import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:slate_ui/slate_ui.dart';

import '../controller/batch_controller.dart';
import '../controller/estimate_controller.dart';
import '../controller/queue_controller.dart';
import '../controller/target_controller.dart';
import '../core/byte_format.dart';
import '../core/fire_and_forget.dart';
import '../l10n/generated/app_localizations.dart';
import '../model/batch_item.dart';
import '../model/pixel_size.dart';
import '../ops/resize_ops.dart';
import 'app_actions.dart';
import 'labels.dart';

/// The files, and what each one is going to become.
///
/// The two right-hand columns are the point: a row shows the source beside the
/// output *before* anything is written, so the decision to press Start is made
/// with the answer already visible rather than after the fact.
class QueuePanel extends StatelessWidget {
  const QueuePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = context.slate;
    final queue = context.watch<QueueController>();
    final target = context.watch<TargetController>().target;
    // Watched so a landed measurement refreshes the whole column, not only the
    // selected row: one file's model is usually a good guide to its neighbours'
    // order of magnitude, and a column that updates only where the cursor is
    // looks broken.
    context.watch<EstimateController>();

    if (queue.isEmpty) return const _EmptyQueue();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _QueueToolbar(),
        const SlateSeparator(),
        Expanded(
          // Inset from the window edge, so the table reads as a table rather
          // than as text poured into the corner of the frame.
          child: Padding(
            padding: const EdgeInsets.only(left: 6, right: 6),
            // The File column takes whatever the four fixed ones leave, so the
            // table reaches the edge of its panel instead of stopping short of
            // it. The grid copies its columns into its own state when it is
            // first built — that is how a column a user has dragged stays
            // dragged — so this sets the width the table opens at and does not
            // follow the window afterwards. A column that really stretches is a
            // change for the kit, not for this file.
            child: LayoutBuilder(
              builder: (context, constraints) => SlateDataGrid(
                columns: <SlateGridColumn>[
                  SlateGridColumn(
                    id: 'file',
                    title: l10n.columnFile,
                    width: math.max(260, constraints.maxWidth - _fixedColumns),
                  ),
                  SlateGridColumn(
                    id: 'source',
                    title: l10n.columnSource,
                    width: 150,
                  ),
                  SlateGridColumn(
                    id: 'output',
                    title: l10n.columnOutput,
                    width: 150,
                  ),
                  SlateGridColumn(
                    id: 'change',
                    title: l10n.columnChange,
                    width: 100,
                    alignment: Alignment.centerRight,
                  ),
                  SlateGridColumn(
                    id: 'status',
                    title: l10n.columnStatus,
                    width: 120,
                  ),
                ],
                rowCount: queue.length,
                isRowSelected: (row) => row == queue.selectedIndex,
                onRowTap: (row) => queue.selectedIndex = row,
                rowSemanticLabel: (row) => queue.items[row].name,
                // The grid pads its *headers* but not its cells, so without this
                // every value sits a few pixels left of the column it belongs to
                // and the first one is flush against the window edge. Matching the
                // header's own padding is what lines the two up.
                cellBuilder: (context, row, column) => Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: theme.metrics.pad / 2,
                  ),
                  child: _Cell(
                    item: queue.items[row],
                    columnId: column.id,
                    maxEdge: target.maxEdge,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Source, Output, Change and Status, as declared above.
  static const double _fixedColumns = 150 + 150 + 100 + 120;
}

/// Add, remove, clear.
class _QueueToolbar extends StatelessWidget {
  const _QueueToolbar();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = context.slate;
    final actions = AppActions(context);
    final queue = context.watch<QueueController>();
    final running = context.watch<BatchController>().isRunning;

    return Container(
      height: theme.metrics.barHeight,
      color: theme.palette.panel,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: <Widget>[
          SlateButton(
            icon: SlateIcons.file,
            label: l10n.actionAddFiles,
            onPressed: running ? null : () => fireAndForget(actions.addFiles()),
          ),
          const SizedBox(width: 6),
          SlateButton(
            icon: SlateIcons.folder,
            label: l10n.actionAddFolder,
            onPressed: running
                ? null
                : () => fireAndForget(actions.addFolder()),
          ),
          const Spacer(),
          Text(l10n.queueCount(queue.length), style: theme.dimTextStyle),
          const SizedBox(width: 8),
          SlateIconButton(
            icon: SlateIcons.close,
            tooltip: l10n.actionRemoveSelected,
            size: 24,
            onPressed: queue.selectedIndex < 0 || running
                ? null
                : actions.removeSelected,
          ),
          SlateIconButton(
            icon: SlateIcons.trash,
            tooltip: l10n.actionClearQueue,
            size: 24,
            onPressed: queue.isEmpty || running ? null : actions.clearQueue,
          ),
        ],
      ),
    );
  }
}

/// One cell. Kept in one place so the columns cannot disagree about how a size
/// or a status is written.
class _Cell extends StatelessWidget {
  const _Cell({
    required this.item,
    required this.columnId,
    required this.maxEdge,
  });

  final BatchItem item;
  final String columnId;

  /// The dimension cap, for projecting the output size of rows that have not
  /// been written yet.
  final int? maxEdge;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = context.slate;

    return switch (columnId) {
      'file' => Text(
        item.name,
        overflow: TextOverflow.ellipsis,
        style: item.status == BatchItemStatus.unreadable
            ? theme.textStyle.copyWith(color: theme.palette.inkDim)
            : theme.textStyle,
      ),
      'source' => Text(
        _describe(l10n, item.size, item.sourceBytes),
        style: theme.dimTextStyle,
      ),
      'output' => Text(_output(l10n, item), style: theme.dimTextStyle),
      'change' => _Change(item: item),
      _ => _Status(item: item),
    };
  }

  /// `4000 x 3000 · 5.2 MB`, or empty while the probe is still running.
  static String _describe(AppLocalizations l10n, PixelSize? size, int bytes) {
    if (size == null) return '';
    final dimensions = l10n.dimensions(size.width, size.height);
    return bytes > 0 ? '$dimensions  ${ByteFormat.format(bytes)}' : dimensions;
  }

  /// What the file became, or — before the batch has run — the dimensions it
  /// will have. The size is deliberately not projected here: a per-file
  /// estimate needs a per-file measurement, and the panel that has one is the
  /// preview.
  String _output(AppLocalizations l10n, BatchItem item) {
    if (item.outputSize != null) {
      return _describe(l10n, item.outputSize, item.outputBytes ?? 0);
    }
    final source = item.size;
    if (source == null) return '';
    final projected = ResizeOps.targetSize(source, maxEdge);
    return l10n.dimensions(projected.width, projected.height);
  }
}

/// How much smaller the file got, once it has been written.
class _Change extends StatelessWidget {
  const _Change({required this.item});

  final BatchItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = context.slate;
    final saved = item.savedFraction;
    if (saved == null) return const SizedBox.shrink();

    final percent = (saved.abs() * 100).round();
    return Text(
      saved >= 0 ? l10n.percentSmaller(percent) : l10n.percentLarger(percent),
      style: theme.dimTextStyle.copyWith(
        // A conversion that made the file bigger is not a failure, but it is
        // the one number in this column worth stopping on.
        color: saved >= 0 ? theme.palette.inkDim : theme.palette.danger,
      ),
    );
  }
}

/// The row's state, with a colour only where one is earned.
class _Status extends StatelessWidget {
  const _Status({required this.item});

  final BatchItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = context.slate;

    final overBudget = item.status == BatchItemStatus.done && !item.budgetMet;
    final keptOriginal =
        item.status == BatchItemStatus.done && item.keptOriginal;
    final label = overBudget
        ? l10n.statusOverBudget
        : keptOriginal
        ? l10n.statusKeptOriginal
        : item.status.labelFor(l10n);

    final color = switch (item.status) {
      BatchItemStatus.failed ||
      BatchItemStatus.unreadable => theme.palette.danger,
      BatchItemStatus.done =>
        overBudget ? theme.palette.danger : theme.palette.accent,
      _ => theme.palette.inkDim,
    };

    final tooltip =
        item.failure?.labelFor(l10n) ??
        (keptOriginal ? l10n.statusKeptOriginalHint : null);
    final text = Text(
      label,
      overflow: TextOverflow.ellipsis,
      style: theme.dimTextStyle.copyWith(color: color),
    );
    return tooltip == null ? text : Tooltip(message: tooltip, child: text);
  }
}

/// What the window says before anything has been added.
class _EmptyQueue extends StatelessWidget {
  const _EmptyQueue();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = context.slate;
    final actions = AppActions(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SlateIcon(
            SlateIcons.tiles,
            size: 28,
            color: theme.palette.inkDim.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 12),
          Text(l10n.emptyQueueTitle, style: theme.titleStyle),
          const SizedBox(height: 4),
          Text(l10n.emptyQueueHint, style: theme.dimTextStyle),
          const SizedBox(height: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SlateButton(
                kind: SlateButtonKind.primary,
                icon: SlateIcons.file,
                label: l10n.actionAddFiles,
                onPressed: () => fireAndForget(actions.addFiles()),
              ),
              const SizedBox(width: 8),
              SlateButton(
                icon: SlateIcons.folder,
                label: l10n.actionAddFolder,
                onPressed: () => fireAndForget(actions.addFolder()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
