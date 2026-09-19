# Shrink

A batch image resizer for the Windows and Linux desktop.

Resizing a folder of photographs is almost never expressed as "scale to 43%".
It arrives as a *constraint* — under 2 MB, no wider than 1600 pixels, as JPEG —
and the tools that exist make you guess which knob gets you there.

Shrink takes the constraint directly. Four targets, each switchable on its own:

| | |
|---|---|
| **Format** | Same as source, JPEG, PNG, TIFF, BMP, TGA, GIF |
| **Longest edge** | A pixel cap. Never upscales — a maximum is a maximum |
| **Quality** | 1–100, for the formats that have one |
| **File size** | A byte ceiling, typed the way people say it: `800 KB`, `1.5 MB` |

Move one and the others tell you what they would have to be, with a word to
apply it. Set a 500 KB budget and the quality field says which quality reaches
it; drop the quality and the size field says what that produces; ask for
something quality alone cannot deliver and the dimension cap says how far the
image has to come down.

Those numbers are **measured, not guessed**. A worker holds the selected image
decoded and really encodes it at the current settings — which is also what the
preview draws — so the estimate you are shown was produced by the same pipeline
that will write the file.

## What it does

- **Batch over any number of files.** Add images, add a folder, or drop either
  onto the window. Folders are walked; anything that is not an image is ignored.
- **Before and after, side by side**, at the real output size and the real byte
  count. Enlarge it when a quality decision needs a closer look.
- **Meets a file-size budget for real.** Quality comes down first, and only when
  quality is spent do dimensions give. Every file is encoded and *verified*
  against the budget; one that cannot get there is written as small as it can be
  and reported as over, never quietly shipped oversized.
- **Never overwrites an original.** Not with any suffix, not under any collision
  policy. That rule outranks every setting in the window.
- **Reads more than it writes.** WebP, PSD, ICO and the Netpbm family decode
  fine. They are not offered as targets, because a format that cannot be written
  faithfully should not appear in a list of things to write.

## Building

Flutter **3.44.8** (Dart 3.12.2) — the version CI pins.

```bash
flutter pub get
flutter gen-l10n
flutter build windows --release   # build/windows/x64/runner/Release/shrink.exe
flutter build linux --release     # build/linux/x64/release/bundle/shrink
```

The interface comes from [alpinsuite/ui-kit](https://github.com/alpinsuite/ui-kit)
(`slate_ui`), pinned to a tag. To develop against a sibling checkout, add a
`pubspec_overrides.yaml` — it is gitignored:

```yaml
dependency_overrides:
  slate_ui:
    path: ../ui-kit
```

## Checks

```bash
dart format --set-exit-if-changed .
flutter analyze --fatal-infos
bash tools/check_hardcoded_strings.sh
flutter test
bash tools/sbom.sh --check
```

`test/batch_integration_test.dart` runs the real controllers over real files and
then checks the files on the disk, rather than the numbers the batch reported
about them.

## Supply chain

Every release carries a CycloneDX Software Bill of Materials, generated from
`pubspec.lock` rather than `pubspec.yaml` — the manifest records the version
ranges that were asked for, the lockfile records the versions actually built.

```bash
bash tools/sbom.sh          # write build/sbom.cdx.json
bash tools/sbom.sh --check  # the release gate
```

`--check` fails when the SBOM is missing, when it is older than the lockfile,
or when a package in the lockfile is absent from it. CI generates it in the
same job that produces the binary, so it describes that build and not a
developer's machine.

## Icons

`tools/make_icons.dart` draws the mark and writes every platform file from it —
the Windows `.ico`, the bundled asset, and the hicolor sizes a Linux `.desktop`
entry is looked up in. Run it after any change to the drawing; do not edit the
outputs.

## Licence

GPL-3.0-or-later. See [LICENSE](LICENSE).

You may use, study, modify and redistribute it. If you distribute it, modified
or not, you have to pass on the source and the same freedoms. Running it, and
changing it for your own use, carries no obligation at all.
