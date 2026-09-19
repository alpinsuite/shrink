# CLAUDE.md

Working notes for agents making changes here. Human-facing documentation lives
in [README.md](README.md) and [docs/](docs/); this file is the short version of
what you need before touching the code.

## What this is

A Flutter batch image resizer for Windows **and** Linux desktop. Unlike its
siblings in this suite, Windows is a real target, not a convenience — it is
built, run and screenshotted there.

The thing that makes it worth building rather than shelling out to ImageMagick
is the **recommendation engine**: four constraints, and moving one tells you
what the others would have to be, from measurements taken on the user's own
image. Everything else is the machinery that makes those measurements cheap
enough to take.

## Environment

Flutter is not preinstalled in a fresh container:

```bash
curl -sSL -o /tmp/flutter.tar.xz \
  https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.44.8-stable.tar.xz
tar xf /tmp/flutter.tar.xz -C /opt
git config --global --add safe.directory /opt/flutter
export PATH="/opt/flutter/bin:$PATH"

apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev
```

Pin **3.44.8** — it is what CI uses.

## Commands

```bash
flutter pub get
flutter gen-l10n                       # after any change to lib/l10n/app_en.arb
dart format --set-exit-if-changed .
flutter analyze --fatal-infos
bash tools/check_hardcoded_strings.sh
flutter test
dart run tools/make_icons.dart         # after any change to the mark

flutter build windows --release        # build/windows/x64/runner/Release/shrink.exe
flutter build linux --release          # build/linux/x64/release/bundle/shrink
bash packaging/build_deb.sh            # build/dist/shrink_<version>_amd64.deb (Debian/Ubuntu host)
tools/set_version.sh                   # print the version; pass one to set it
```

Run the first five before claiming a change is done. They are what the CI
analyze job runs, so a green local run means that job is green.

## Seeing a change on Windows

There is no Xvfb here and no `import`. The equivalent is PrintWindow through
PowerShell, and it is the only way to check anything about how the window
actually looks:

```powershell
# See scratch scripts in this session's notes, or rewrite:
#   SetProcessDPIAware  — PowerShell is DPI-unaware, and without it every
#                         coordinate is virtualised and the capture lands offset
#   PrintWindow with PW_RENDERFULLCONTENT — captures without stealing focus
#   fall back to SetForegroundWindow + CopyFromScreen when it returns blank
```

Two facts learned the hard way while driving it:

- **A minimised window reports a rect of (-32000, -32000).** Every coordinate
  computed from it lands off-screen and the clicks silently go nowhere. Restore
  with `ShowWindow(hwnd, SW_RESTORE)` first.
- **The first click on an unfocused window is swallowed activating it.** Click
  twice, with a pause, or accept that half your clicks do nothing.

Preferences live at `%APPDATA%\<CompanyName>\<ProductName>\shared_preferences.json`,
and those two names come from `windows/runner/Runner.rc` — **changing the
version-info strings moves the settings file**, which reads exactly like the app
failing to load its own settings.

## Rules that matter

1. **`EncodeOps.encodeImage` is the only pipeline.** The batch reaches it
   through `EncodeOps.run` (which decodes from a path); the preview reaches it
   directly with a resident image. A second implementation would eventually
   disagree with the file on disk, and then every number in the interface is
   worthless.

2. **A budget is verified, never predicted.** `SizeModel` decides what to
   *show*; the batch encodes for real and checks. A file that could not reach
   the budget is written as small as it could be and reported as over —
   `budgetMet` must always agree with the bytes on disk.

3. **The requested quality is a ceiling, not a goal.** A generous budget does
   not entitle the search to encode above what the user asked for.

4. **A source file is never overwritten.** `OutputNaming.resolve` renames around
   every path in the current batch regardless of the collision policy. There is
   a test; keep it passing.

5. **Never upscale.** "Maximum edge" has to mean a maximum.

6. **Anything looping over pixels goes off the UI thread** — `Isolate.run` for
   the batch, the long-lived `PreviewWorker` for estimates. No exceptions.

7. **Every user-visible string lives in `lib/l10n/app_en.arb`.** Run
   `flutter gen-l10n` and commit the generated files.
   `tools/check_hardcoded_strings.sh` fails on a literal in a `Text`. Enum
   values are phrased in `lib/ui/labels.dart` and nowhere else.

8. **`model/` and `ops/` import no widgets.** That is what keeps the estimator
   and the resize maths testable headlessly.

9. **The widget kit is a separate package.** Everything is drawn with
   `slate_ui`, pinned to a tag. Reach for a Material widget only where the kit
   genuinely has no equivalent; when it plausibly should have one, add it in
   [alpinsuite/ui-kit](https://github.com/alpinsuite/ui-kit), release it, and
   bump the `ref`.

10. **Icons are generated.** `tools/make_icons.dart` writes the `.ico`, the
    bundled asset and the hicolor PNGs from one drawing. Editing an output by
    hand puts the platforms out of step at the next run.

## Layout

```
lib/core/        theme, settings, byte formatting, fire-and-forget
lib/model/       plain values: ResizeTarget, OutputFormat, BatchItem, PixelSize
lib/ops/         the pixel pipeline and the estimator — no widgets
lib/io/          probing, naming, dialogs
lib/controller/  QueueController, TargetController, EstimateController,
                 BatchController
lib/ui/          widgets; AppActions is the single home for every command
tools/           make_icons.dart, check_hardcoded_strings.sh
packaging/       desktop entry, icons, metainfo, man page, build_deb.sh
```

Dependency direction is one-way: `ui` → `controller` → `model`/`ops`/`io`/`core`.

`AppActions` is where every user command is implemented once, so the menu, the
toolbar and the shortcuts cannot drift. Add commands there, not in the widgets.

## Gotchas discovered the hard way

- **A `ReceivePort` is a single-subscription stream.** Reading the worker
  handshake with `asBroadcastStream().first` and then calling `listen()` again
  throws — the worker looks alive and every measurement hangs forever. One
  listener handles both. This bug shipped once; see `PreviewWorker._onMessage`.
- `package:image` **can** encode WebP now, but losslessly only — `WebPEncoder`
  takes no quality argument. That is why WebP is readable and not a target.
- The kit's `SlateDataGrid` pads its header cells and not its body cells, so a
  caller has to pad cells itself or every value sits left of its column.
- `img` is an import prefix, so `img..fillRect(...)` is a compile error, not a
  cascade.
- `dart format` reformats aggressively. Anchor-based patch scripts written
  against pre-format source stop matching — read the file first.
- `CallbackShortcuts` in the shell sits *below* `WidgetsApp`, where Flutter
  installs the default text-editing shortcuts, so a binding here wins the key
  over a focused text field. Delete is guarded for that reason.

## Before finishing

- All five checks pass.
- New behaviour in `ops/`, `model/`, `io/` or `controller/` has tests.
- User-visible changes have a `CHANGELOG.md` entry under `## [Unreleased]`.
- Comments explain *why*, never *what*.
