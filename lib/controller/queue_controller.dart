import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../core/fire_and_forget.dart';
import '../io/image_probe.dart';
import '../model/batch_item.dart';
import '../model/output_format.dart';

/// The list of files waiting to be resized.
///
/// Owns the queue and nothing else: it does not know what the target is, and it
/// does not run the batch. Adding a file is instant and the dimensions arrive
/// afterwards, because a folder of six hundred photographs should appear in the
/// window immediately and fill in, not appear once it has all been read.
class QueueController extends ChangeNotifier {
  final List<BatchItem> _items = <BatchItem>[];

  /// How deep a dropped folder is walked.
  ///
  /// Deep enough for the way people actually organise photographs — by year,
  /// then by event — and shallow enough that dropping a home directory does not
  /// become an unbounded filesystem crawl.
  static const int maxFolderDepth = 6;

  int _selectedIndex = -1;

  /// Bumped whenever the queue's *contents* change, so anything caching per
  /// file can tell a reorder from a genuine change.
  int _revision = 0;
  int get revision => _revision;

  List<BatchItem> get items => List<BatchItem>.unmodifiable(_items);

  int get length => _items.length;

  bool get isEmpty => _items.isEmpty;

  int get selectedIndex => _selectedIndex;

  BatchItem? get selected =>
      _selectedIndex >= 0 && _selectedIndex < _items.length
      ? _items[_selectedIndex]
      : null;

  set selectedIndex(int value) {
    final clamped = value < 0 || value >= _items.length ? -1 : value;
    if (clamped == _selectedIndex) return;
    _selectedIndex = clamped;
    notifyListeners();
  }

  /// Everything the batch would attempt.
  Iterable<BatchItem> get processable => _items.where((i) => i.isProcessable);

  /// Every source path, for the overwrite guard in `OutputNaming`.
  Set<String> get sourcePaths =>
      _items.map((item) => p.normalize(p.absolute(item.path))).toSet();

  int get totalSourceBytes =>
      _items.fold(0, (sum, item) => sum + item.sourceBytes);

  /// Adds files and folders. Folders are walked; anything unreadable by
  /// extension is ignored rather than added and then failed.
  ///
  /// Returns how many were actually added, so the caller can say "12 added, 3
  /// already in the list" instead of appearing to have done nothing.
  Future<int> addPaths(Iterable<String> paths) async {
    final expanded = await compute(_expand, paths.toList());
    final existing = sourcePaths;

    final added = <BatchItem>[];
    for (final path in expanded) {
      final normalised = p.normalize(p.absolute(path));
      if (!existing.add(normalised)) continue;
      added.add(BatchItem(path: normalised));
    }
    if (added.isEmpty) return 0;

    _items.addAll(added);
    _revision++;
    if (_selectedIndex < 0) _selectedIndex = _items.length - added.length;
    notifyListeners();

    // Probing is fire-and-forget: each result updates its own row when it
    // lands, and the queue is usable in the meantime.
    for (final item in added) {
      fireAndForget(_probe(item.path));
    }
    return added.length;
  }

  Future<void> _probe(String path) async {
    final result = await ImageProbe.probe(path);
    final index = indexOf(path);
    if (index < 0) return;

    _items[index] = result == null
        ? _items[index].copyWith(
            status: BatchItemStatus.unreadable,
            failure: BatchItemFailure.unreadable,
          )
        : _items[index].copyWith(
            status: BatchItemStatus.ready,
            size: result.size,
            sourceBytes: result.bytes,
          );
    _revision++;
    notifyListeners();
  }

  int indexOf(String path) =>
      _items.indexWhere((item) => p.equals(item.path, path));

  void replace(int index, BatchItem item) {
    if (index < 0 || index >= _items.length) return;
    _items[index] = item;
    notifyListeners();
  }

  void removeAt(int index) {
    if (index < 0 || index >= _items.length) return;
    _items.removeAt(index);
    if (_selectedIndex >= _items.length) _selectedIndex = _items.length - 1;
    _revision++;
    notifyListeners();
  }

  void clear() {
    if (_items.isEmpty) return;
    _items.clear();
    _selectedIndex = -1;
    _revision++;
    notifyListeners();
  }

  /// Clears every file's outcome, keeping what was probed.
  ///
  /// Called when the target changes: last run's output size is no longer an
  /// answer to any question the user is asking.
  void resetOutcomes() {
    var changed = false;
    for (var i = 0; i < _items.length; i++) {
      if (_items[i].outputBytes == null &&
          _items[i].status != BatchItemStatus.skipped &&
          _items[i].status != BatchItemStatus.failed) {
        continue;
      }
      _items[i] = _items[i].reset();
      changed = true;
    }
    if (changed) notifyListeners();
  }

  /// Walks folders and filters by extension, off the platform thread.
  static List<String> _expand(List<String> paths) {
    final found = <String>[];

    void walk(Directory directory, int depth) {
      if (depth > maxFolderDepth) return;
      final List<FileSystemEntity> entries;
      try {
        entries = directory.listSync(followLinks: false);
      } on FileSystemException {
        // An unreadable folder is skipped rather than failing the whole drop.
        return;
      }
      for (final entry in entries) {
        if (entry is Directory) {
          walk(entry, depth + 1);
        } else if (entry is File && OutputFormat.isReadable(entry.path)) {
          found.add(entry.path);
        }
      }
    }

    for (final path in paths) {
      if (Directory(path).existsSync()) {
        walk(Directory(path), 0);
      } else if (File(path).existsSync() && OutputFormat.isReadable(path)) {
        found.add(path);
      }
    }

    found.sort();
    return found;
  }
}
