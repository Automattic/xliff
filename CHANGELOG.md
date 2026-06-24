## [Unreleased]

### Fixed

- `Xliff::Bundle#to_xml`/`#to_s` now emit the `<xliff>` root element even when the bundle has no files. An
  empty bundle previously serialized to just an XML declaration with no root element, which is not even
  well-formed XLIFF.
- `target-language` is now optional on `Xliff::File` and omitted from output when absent. It is an optional
  attribute in XLIFF 1.2, but round-tripping a `<file>` that omitted it previously emitted
  `target-language=""`, which is invalid (`xsd:language` rejects the empty string) — turning schema-valid
  input into schema-invalid output.
- `Xliff::File` now always emits a `<body>` element, even when it has no entries. `<body>` is required by the
  XLIFF schema (an empty one is legal), but a file with no entries previously omitted it entirely, producing
  schema-invalid output. The optional `<header>` is still omitted when empty.

- Parse Xcode exports for locales that aren't translated yet. `Xliff::Entry.from_xml` previously crashed
  (`NoMethodError`) on `<trans-unit>` elements with no `<target>` — the shape Xcode emits for untranslated
  strings — and on entries with no `<note>`. `target` is now an optional argument, absent `<target>`/`<note>`
  elements parse to `nil`, and neither element is emitted on write when `nil`, so source-only files round-trip
  unchanged.
- `Xliff::Bundle#file_named` no longer raises `NameError` when matching a file by basename (e.g. looking up
  `InfoPlist.strings` against an Xcode `original` path of `Resources/en.lproj/InfoPlist.strings`).
- `Xliff::Bundle#file_named` no longer raises `TypeError` when the bundle contains a file with a `nil`
  `original` (e.g. a `<file>` parsed without the `original` attribute); such a file is simply skipped.
- Parsing a `<file>` whose `<body>` contains a schema-valid `<group>` or `<bin-unit>` element no longer
  crashes the whole parse. Non-`<trans-unit>` children are now skipped (mirroring how `<xliff>` children are
  filtered), preserving the `<trans-unit>` siblings the library understands.
- `Xliff::Bundle.from_string`/`from_path` now raise the documented `Invalid XLIFF file` error for empty,
  whitespace-only, or otherwise root-less input instead of leaking an internal `NoMethodError`.
- A `<file>` parsed without a `datatype` attribute now falls back to the documented `plaintext` default
  instead of becoming `nil` and serializing to an invalid `datatype=""`.
- A `<trans-unit>` parsed without an `xml:space` attribute now falls back to the documented `default` value
  instead of serializing to an invalid `xml:space=""`.
- `Xliff::Entry.from_xml` now raises a clear error for a `<trans-unit>` missing its mandatory `<source>`
  element, rather than silently parsing it to `nil` and fabricating an empty `<source/>`. The optional
  `<target>`/`<note>` (which Xcode omits for untranslated strings) remain tolerated.
- `Xliff::Entry.from_xml` now raises a clear error for a `<trans-unit>` missing its mandatory `id` attribute,
  rather than silently fabricating an empty `id=""` that every id-less entry (and `entry_with_id("")`) would
  then collide on.
- `Xliff::Header.from_xml` now preserves namespaced attributes. A header attribute such as `xml:lang="en"`
  was previously read as `lang=""` (prefix dropped, value erased) because it was looked up by local name;
  attributes are now read from the parsed nodes, keeping both prefix and value.
- `Xliff::Entry` now coerces its `id` to a `String` — on both construction and assignment (`entry.id =`) —
  matching the documented type and the README's example of an integer `id`, so `File#entry_with_id` finds an
  entry consistently before and after a serialize/parse round trip.
- `Xliff::Header.new` now requires its `element:` argument (matching `Xliff::Entry`'s `id:` and
  `Xliff::File`'s `original:`). Building a header without one previously constructed fine and then crashed
  with an opaque Nokogiri `TypeError` at serialization; it now fails fast with a clear `ArgumentError`.
- `Xliff::Header.new` now rejects an `element:` that is not a valid XML element name (e.g. one containing a
  space), which previously serialized to unparseable XML with no error. Valid (including hyphenated and
  namespace-prefixed) names are unaffected, as is the parse path.

## [0.1.0] - 2022-04-23

- Initial release
