// Shrink — a batch image resizer for the Linux and Windows desktop.
// Copyright (C) 2026 rbuache
//
// This program is free software: you can redistribute it and/or modify it
// under the terms of the GNU General Public License as published by the Free
// Software Foundation, either version 3 of the License, or (at your option)
// any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
// FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
// more details.
//
// You should have received a copy of the GNU General Public License along
// with this program. If not, see <https://www.gnu.org/licenses/>.
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'controller/batch_controller.dart';
import 'controller/estimate_controller.dart';
import 'controller/queue_controller.dart';
import 'controller/target_controller.dart';
import 'core/fire_and_forget.dart';
import 'core/settings_controller.dart';

/// Entry point. [args] carries file and folder paths when the application is
/// launched from a file manager or with `shrink photos/`.
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  final settings = await SettingsController.load();
  final queue = QueueController();
  final target = TargetController(settings: settings);
  final estimates = EstimateController(queue: queue, target: target);
  final batch = BatchController(queue: queue, target: target);

  // Anything named on the command line joins the queue. Folders are walked and
  // non-images filtered out by the queue itself, so this only has to drop the
  // switches.
  final requested = args.where((arg) => !arg.startsWith('-')).toList();
  if (requested.isNotEmpty) {
    fireAndForget(queue.addPaths(requested).then((_) {}));
  }

  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      size: Size(1180, 760),
      // Below this the target panel starts clipping its sliders, and a resizer
      // whose controls do not fit is not a smaller resizer.
      minimumSize: Size(880, 560),
      center: true,
      title: 'Shrink',
      // The title bar is drawn by the application instead, so the menus, the
      // title and the window buttons share one themed row.
      // See lib/ui/window_bar.dart.
      titleBarStyle: TitleBarStyle.hidden,
    ),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsController>.value(value: settings),
        ChangeNotifierProvider<QueueController>.value(value: queue),
        ChangeNotifierProvider<TargetController>.value(value: target),
        ChangeNotifierProvider<EstimateController>.value(value: estimates),
        ChangeNotifierProvider<BatchController>.value(value: batch),
      ],
      child: const ShrinkApp(),
    ),
  );
}
