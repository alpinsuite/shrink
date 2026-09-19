# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[semantic versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-09-19

First version. Everything below is new.

### Added

- **Batch resizing** over any number of files. Add images, add a folder, or drop
  either onto the window; folders are walked and non-images ignored.
- **Four target constraints**, each independently switchable: output format,
  longest edge in pixels, quality, and a file-size ceiling.
- **Cross-parameter recommendations.** Moving one control shows what the others
  would have to be to satisfy the whole set, with a word to apply it — the
  quality that fits a size budget, the dimensions needed when quality alone
  cannot, and the size a given quality produces.
- **Measured estimates.** A worker isolate holds the selected image decoded and
  really encodes it at the current settings; every encode feeds a per-image
  model that answers the inverse questions instantly. Numbers are marked as
  approximate until a real measurement lands.
- **Before-and-after preview** at the true output size and byte count, with an
  enlarged view that can show either half across the full width.
- **File-size budgets that are verified**, not predicted: quality comes down
  first, then dimensions, and a file that cannot reach the budget is written as
  small as possible and reported as over rather than shipped oversized.
- **Output control**: beside the originals with a name suffix, or into a chosen
  folder, with rename / replace / skip on a name collision. A source file is
  never overwritten, whatever the policy.
- Formats written: JPEG, PNG, TIFF, BMP, TGA, GIF, or same as source. Formats
  read additionally include WebP, PSD, ICO and the Netpbm family.
- Custom title bar, light and dark palettes, and an application menu, all drawn
  with the `slate_ui` kit.
- Localisation plumbing (English) with a build-time check against hardcoded
  strings.
- A generated application icon for the Windows executable, the Linux hicolor
  theme and the desktop entry.
- **A Debian package.** `packaging/build_deb.sh` builds `shrink_<version>_amd64.deb`
  with its dependencies computed from the binary, a launcher entry, icons, a
  man page and AppStream metadata. Releases are built against glibc 2.35, so
  they run on Ubuntu 22.04+ and Debian 12+, and are published through the
  suite's APT repository at `apt.buache.systems`.
