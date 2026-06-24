## [Unreleased]

### Fixed

- `Xliff::Bundle#to_xml`/`#to_s` now raise rather than emit a file-less `<xliff>`, which is not valid XLIFF
  (the schema requires at least one `<file>`). Previously an empty bundle serialized to just an XML
  declaration with no root element. Reading a file-less `<xliff>` is still tolerated — it parses to an empty
  bundle — it simply can't be serialized back out (liberal on read, strict on write).
- `target-language` is now optional on `Xliff::File` and omitted from output when absent (or empty). It is an
  optional attribute in XLIFF 1.2, but round-tripping a `<file>` that omitted it previously emitted
  `target-language=""`, which is invalid (`xsd:language` rejects the empty string) — turning schema-valid
  input into schema-invalid output.
- `Xliff::File` now always emits a `<body>` element, even when it has no entries. `<body>` is required by the
  XLIFF schema (an empty one is legal), but a file with no entries previously omitted it entirely, producing
  schema-invalid output. The optional `<header>` is still omitted when empty.
- `Xliff::Bundle` no longer overwrites a parsed document's declared `xsi:schemaLocation`. It now preserves the
  source document's value on round-trip — located by the XML Schema instance namespace rather than a hard-coded
  `xsi:` prefix, so a document that binds it to a different prefix is no longer silently downgraded to the
  default — and exposes it via a new `schema_location` accessor. Bundles built from scratch default to the
  XLIFF 1.2 **transitional** schema rather than strict, since the library round-trips real-world content (e.g.
  Xcode's `<tool build-num>`) that only the transitional schema accepts — so the declared schema no longer
  over-claims strict conformance. (A full byte-identical round-trip for documents with non-standard root
  attributes is tracked in [#16](https://github.com/Automattic/xliff/issues/16).)

- Parse Xcode exports for locales that aren't translated yet. `Xliff::Entry.from_xml` previously crashed
  (`NoMethodError`) on `<trans-unit>` elements with no `<target>` — the shape Xcode emits for untranslated
  strings — and on entries with no `<note>`. `target` is now an optional argument, absent `<target>`/`<note>`
  elements parse to `nil`, and neither element is emitted on write when `nil`, so source-only files round-trip
  unchanged.
- `Xliff::Bundle#file_named` no longer raises `NameError` when matching a file by basename (e.g. looking up
  `InfoPlist.strings` against an Xcode `original` path of `Resources/en.lproj/InfoPlist.strings`).
- `Xliff::File` now requires a non-empty `original` and `source-language`, rejecting them both on construction
  and when parsing (`File.from_xml`) instead of serializing a missing required attribute to an invalid
  `original=""` / `source-language=""`. (Previously a `nil` `original` was tolerated and skipped by
  `Bundle#file_named`; it is now prevented at the source.)
- Parsing a `<file>` whose `<body>` contains a schema-valid `<group>` or `<bin-unit>` element no longer
  crashes the whole parse. These elements aren't modeled as entries, but they're now preserved verbatim and
  re-emitted on write (exposed via `Xliff::File#unparsed_body_nodes`) instead of being dropped, so their
  nested `<trans-unit>`s survive a round-trip. First-class support is tracked in
  [#17](https://github.com/Automattic/xliff/issues/17).
- `Xliff::Bundle.from_string`/`from_path` now raise the documented `Invalid XLIFF file` error for empty,
  whitespace-only, or otherwise root-less input instead of leaking an internal `NoMethodError`.
- A `<file>` parsed without (or with an empty) `datatype` attribute now falls back to the documented
  `plaintext` default instead of becoming `nil`/`""` and serializing to an invalid `datatype=""`.
- A `<trans-unit>` parsed without (or with an empty) `xml:space` attribute now falls back to the documented
  `default` value instead of serializing to an invalid `xml:space=""`.
- `Xliff::Entry.from_xml` now raises a clear error for a `<trans-unit>` missing its mandatory `<source>`
  element, rather than silently parsing it to `nil` and fabricating an empty `<source/>`. The optional
  `<target>`/`<note>` (which Xcode omits for untranslated strings) remain tolerated.
- `Xliff::Entry` now rejects a missing or empty `id` — both when parsing (`from_xml` raises for a `<trans-unit>`
  with no `id` or `id=""`) and when building by hand (`Entry.new`/`entry.id=` raise) — rather than silently
  fabricating an empty `id=""` that every id-less entry (and `entry_with_id("")`) would then collide on.
- `Xliff::Header.from_xml` now preserves namespaced attributes. A header attribute such as `xml:lang="en"`
  was previously read as `lang=""` (prefix dropped, value erased) because it was looked up by local name;
  attributes are now read from the parsed nodes, keeping both prefix and value.
- `Xliff::Entry` now coerces its `id` to a `String` — on both construction and assignment (`entry.id =`) — and
  `File#entry_with_id` coerces its lookup argument to match, so an entry built with an integer `id` (as in the
  README example) is found by `entry_with_id(1234)` or `entry_with_id("1234")`, consistently before and after a
  serialize/parse round trip.
- `Xliff::Header.new` now requires its `element:` argument (matching `Xliff::Entry`'s `id:` and
  `Xliff::File`'s `original:`). Building a header without one previously constructed fine and then crashed
  with an opaque Nokogiri `TypeError` at serialization; it now fails fast with a clear `ArgumentError`.
- `Xliff::Header.new` now rejects an `element:` that is not a valid XML element name (e.g. one containing a
  space), which previously serialized to unparseable XML with no error. Valid (including hyphenated,
  namespace-prefixed, and Unicode) names are unaffected, as is the parse path. A non-`String` element (e.g. a
  `Symbol`) is coerced to a `String` so it serializes cleanly instead of crashing at write time.

## [0.1.0] - 2022-04-23

- Initial release
