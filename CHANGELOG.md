## [Unreleased]

### Fixed

- Parse Xcode exports for locales that aren't translated yet. `Xliff::Entry.from_xml` previously crashed
  (`NoMethodError`) on `<trans-unit>` elements with no `<target>` — the shape Xcode emits for untranslated
  strings — and on entries with no `<note>`. `target` is now an optional argument, absent `<target>`/`<note>`
  elements parse to `nil`, and neither element is emitted on write when `nil`, so source-only files round-trip
  unchanged.
- `Xliff::Bundle#file_named` no longer raises `NameError` when matching a file by basename (e.g. looking up
  `InfoPlist.strings` against an Xcode `original` path of `Resources/en.lproj/InfoPlist.strings`).

## [0.1.0] - 2022-04-23

- Initial release
