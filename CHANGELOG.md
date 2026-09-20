# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[semantic versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.1] - 2026-09-20

### Fixed

- **Shrink never writes a file larger than the one it came from.** Decoding a
  JPEG and saving it again at quality 85 routinely produces more bytes than the
  original had, and 0.1.0 wrote that and reported it, in red, as "58% larger".
  When nothing was resized, the format has not changed and encoding again gains
  nothing, the copy is now the original file, byte for byte, and the row says
  **Kept as is**. That is also lossless, where the re-encode was a generation of
  damage for no benefit. A resize, a change of format and a file-size ceiling
  the original does not meet are all still honoured. The preview goes through
  the same rule, so it shows what the batch will write.

### Changed

- **A first launch starts with the longest edge switched on, at 1600 pixels.**
  With every constraint off, pressing Start made nothing smaller, which is the
  one thing the application is opened for. It applies once: after the first
  change, what was saved is what is used, including an edge turned off on
  purpose.

### Added

- CI starts the Linux build on a real X server, hands it a folder of images,
  clicks Start, and checks the files that land on the disk.

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
