# Contributing

## Before you start

Read [docs/DECISIONS.md](docs/DECISIONS.md). Most of what looks like an obvious
improvement to this codebase was considered and rejected for a reason that is
written down there — the measured-not-modelled estimates, the resident worker
isolate, and the rule that a source file is never overwritten in particular.

## The toolchain

Flutter **3.44.8** (Dart 3.12.2). CI pins it, so a different version is a
different set of results.

```bash
flutter pub get
flutter gen-l10n
```

To work against a sibling checkout of the widget kit, add a
`pubspec_overrides.yaml` — it is gitignored, and CI resolves the pinned tag:

```yaml
dependency_overrides:
  slate_ui:
    path: ../ui-kit
```

## Before opening a pull request

```bash
dart format --set-exit-if-changed .
flutter analyze --fatal-infos
bash tools/check_hardcoded_strings.sh
flutter test
```

These four are exactly what the CI analyze job runs. A green local run means
that job is green.

Also:

- **New behaviour in `model/`, `ops/`, `io/` or `controller/` needs a test.**
  Those layers import no widgets precisely so they can be tested headlessly;
  use that.
- **User-visible strings go in `lib/l10n/app_en.arb`,** never into a widget.
  Run `flutter gen-l10n` and commit the generated files — CI checks they are not
  stale. Enum values are phrased in `lib/ui/labels.dart` and nowhere else.
- **User-visible changes need a `CHANGELOG.md` entry** under `## [Unreleased]`.
- **Do not bump the version** in an ordinary change; releases do that.
- **Do not edit generated files by hand** — the localizations, or the icons that
  `tools/make_icons.dart` writes. Change the source and re-run the generator.

## Comments

Explain *why*, never *what*. The code already says what it does; what it cannot
say is which alternative was tried, what broke, and what the number was chosen
against. Those are the comments worth writing and the ones worth keeping
accurate.

## Reporting a bug

The most useful report names the images. Compression behaviour is a property of
the picture, and "the budget was not met" means something different for a
photograph than for a screenshot. Include the source dimensions, the source
size, the four target settings, and what came out.
