## [Unreleased]

### Added

- Parse Xcode exports for locales that aren't translated yet. `Xliff::Entry`'s `target` (and `note`) are now
  optional: a `<trans-unit>` with no `<target>`/`<note>` — the shape Xcode emits for untranslated strings —
  parses to `nil`, and neither element is emitted on write, so source-only files round-trip unchanged.
  (Previously `Xliff::Entry.from_xml` crashed with `NoMethodError` on this shape.)
- `Xliff::Bundle#schema_location` exposes (and lets you set) the declared `xsi:schemaLocation`. A parsed
  bundle preserves the source document's value on round-trip — located by the XML Schema instance namespace
  rather than a hard-coded `xsi:` prefix, so a document that binds it to a different prefix isn't silently
  downgraded — and bundles built from scratch default to the XLIFF 1.2 **transitional** schema (which is what
  real-world content such as Xcode's `<tool build-num>` conforms to), so the declared schema no longer
  over-claims strict conformance. (A full byte-identical round-trip for documents with non-standard root
  attributes is tracked in [#16](https://github.com/Automattic/xliff/issues/16).)
- `Xliff::File#unparsed_body_nodes` preserves `<body>` children the library doesn't model (`<group>`,
  `<bin-unit>`): they're deep-copied out of the source document on parse (so it isn't retained in memory) and
  re-emitted on write instead of being dropped, so their nested `<trans-unit>`s survive a round-trip.
  (Previously such an element crashed the whole parse.) Content is preserved rather than reproduced
  byte-for-byte: nodes are re-emitted after the file's entries, and a moved node in a namespaced document may
  gain a redundant namespace declaration. First-class support is tracked in
  [#17](https://github.com/Automattic/xliff/issues/17).
- `Xliff::Header#child_nodes` preserves a parsed header element's child content — text and nested elements,
  such as an `<skl>` skeleton's `<internal-file>` — that the library doesn't model. The nodes are deep-copied
  out of the source document on parse (so it isn't retained) and re-emitted on write, instead of being
  dropped. (Previously `Xliff::Header` modeled only an element name and its attributes, so a `<header>`
  carrying a skeleton round-tripped to an empty element, silently losing it.) As with `<group>`, the content
  survives but isn't reproduced byte-for-byte: a moved node in a namespaced document may gain a redundant
  namespace declaration. A header built by hand carries no child content.
- Ship RBS type signatures (`sig/`) for the public API, so projects that type-check with Steep or RBS can
  resolve `Xliff`'s types. `sig/manifest.yaml` declares the `nokogiri` dependency, so a consumer's
  `rbs collection install` resolves Nokogiri's own signatures from `ruby/gem_rbs_collection` rather than this
  gem bundling (and potentially colliding with) a stub of them.

### Fixed

- `Xliff::Bundle.from_string`/`.from_path`/`.from_xml` now raise for a malformed document instead of
  silently recovering a corrupted bundle. Nokogiri parses in recovery mode by default, so a fatal
  well-formedness error — a truncated tag, or content broken by an unescaped `&` — used to yield a partial,
  silently corrupted `Bundle` (e.g. `A & B` parsed to `A  B`), contradicting the documented "raises for
  invalid input" contract. Such documents are now rejected; a warning-level problem is still tolerated, so a
  clean document is never refused.
- `Xliff::Bundle#to_xml`/`#to_s` now raise rather than emit a file-less `<xliff>`, which is not valid XLIFF
  (the schema requires at least one `<file>`). Previously an empty bundle serialized to just an XML
  declaration with no root element. Reading a file-less `<xliff>` is still tolerated — it parses to an empty
  bundle — it simply can't be serialized back out (liberal on read, strict on write).
- `target-language` is now optional on `Xliff::File` and omitted from output when absent (or blank). It is an
  optional attribute in XLIFF 1.2, but round-tripping a `<file>` that omitted it previously emitted
  `target-language=""`, which is invalid (`xsd:language` rejects the empty string) — turning schema-valid
  input into schema-invalid output.
- `Xliff::Bundle#schema_location` no longer emits an invalid `xsi:schemaLocation=""`. An empty, whitespace-only,
  or `nil` value — set explicitly, assigned via `schema_location=`, or parsed from a blank source declaration —
  now falls back to the transitional default, matching how blank `datatype`/`xml:space`/`target-language` are
  handled (a single `Xliff.presence` helper backs all four).
- `Xliff::File` now always emits a `<body>` element, even when it has no entries. `<body>` is required by the
  XLIFF schema (an empty one is legal), but a file with no entries previously omitted it entirely, producing
  schema-invalid output. The optional `<header>` is still omitted when empty.
- `Xliff::Bundle#file_named` no longer raises `NameError` when matching a file by basename (e.g. looking up
  `InfoPlist.strings` against an Xcode `original` path of `Resources/en.lproj/InfoPlist.strings`).
- `Xliff::File` now requires a non-blank `original` and `source-language` – rejecting an empty or
  whitespace-only value – both on construction and when parsing (`File.from_xml`), instead of serializing a
  missing required attribute to an invalid `original=""` / `source-language="   "`. (Previously a `nil`
  `original` was tolerated and skipped by `Bundle#file_named`; it is now prevented at the source.)
- `Xliff::Bundle.from_string`/`from_path` now raise the documented `Invalid XLIFF file` error for empty,
  whitespace-only, or otherwise root-less input instead of leaking an internal `NoMethodError`.
- A `<file>` parsed without (or with a blank) `datatype` attribute now falls back to the documented
  `plaintext` default instead of becoming `nil`/`""` and serializing to an invalid `datatype=""`.
- A `<trans-unit>` parsed without (or with a blank) `xml:space` attribute now falls back to the documented
  `default` value instead of serializing to an invalid `xml:space=""`.
- `Xliff::Entry.from_xml` now raises a clear error for a `<trans-unit>` missing its mandatory `<source>`
  element, rather than crashing with an internal `NoMethodError`. The optional
  `<target>`/`<note>` (which Xcode omits for untranslated strings) remain tolerated.
- `Xliff::Entry` now rejects a blank `id` — missing, empty, or whitespace-only — both when parsing (`from_xml`
  raises for a `<trans-unit>` with no `id`, `id=""`, or `id="  "`) and when building by hand (`Entry.new`/
  `entry.id=` raise) — rather than silently fabricating a meaningless `id` that every id-less entry (and
  `entry_with_id("")`) would then collide on.
- `Xliff::Header.from_xml` now preserves an `xml:`-prefixed attribute. A header attribute such as
  `xml:lang="en"` was previously read as `lang=""` (prefix dropped, value erased) because it was looked up by
  local name; it's now read from the parsed nodes, keeping both prefix and value. An attribute under any other
  namespace prefix is dropped, because the library can't declare it on write and keeping it would emit
  non-well-formed XML (an undeclared prefix) — matching the build-by-hand path, which rejects such a name.
- `Xliff::Entry` now coerces its `id` to a `String` — on both construction and assignment (`entry.id =`) — and
  `File#entry_with_id` coerces its lookup argument to match, so an entry built with an integer `id` (as in the
  README example) is found by `entry_with_id(1234)` or `entry_with_id("1234")`, consistently before and after a
  serialize/parse round trip.
- `Xliff::Entry` now coerces its `source` to a `String` — on both construction and assignment (`entry.source =`)
  — matching `id`, so `entry.source` reads back a `String` whatever it was built with, rather than only being
  stringified at write time. Unlike `id`, surrounding whitespace is preserved, since source text can be
  significant under `xml:space="preserve"`.
- `Xliff::File` now coerces its `original` and `source-language` to a `String` on construction, matching
  `Xliff::Entry#id`. A `File` built with a non-`String` `original` (e.g. an integer) previously crashed
  `Bundle#file_named` with a `TypeError` from `::File.basename` — the value was stored uncoerced, so every
  lookup fell through to the basename comparison and raised.
- `Xliff::Entry` now strips surrounding whitespace from its `id` — on construction, on assignment, and in the
  `File#entry_with_id` lookup — so what is stored agrees with the blank check (which already strips before
  testing). An `id` of `" x "` was previously stored padded yet missed by `entry_with_id("x")`; it now
  normalizes to `"x"` consistently.
- `Xliff::Header.new` now requires its `element:` argument (matching `Xliff::Entry`'s `id:` and
  `Xliff::File`'s `original:`). Building a header without one previously constructed fine and then crashed
  with an opaque Nokogiri `TypeError` at serialization; it now fails fast with a clear `ArgumentError`.
- `Xliff::Header.new` now rejects an `element:` (and, likewise, an attribute name) that is not a valid XML
  name when building by hand — e.g. one containing a space, which previously serialized to unparseable/malformed
  XML with no error. Common hyphenated and Unicode names are accepted, as is the `xml:` prefix (the one prefix
  bound in every context); any other namespace prefix is rejected, because the library has no way to declare it
  and would otherwise emit an undeclared-prefix document (e.g. a hand-built `custom:thing`). Names from a parsed
  document are trusted as-is rather than re-validated (Nokogiri already validated them), so a valid-but-exotic
  parsed name — e.g. an NFD-decomposed accent — no longer crashes the parse. A non-`String` element (e.g. a
  `Symbol`) is coerced to a `String` so it serializes cleanly instead of crashing at write time.
- `Xliff::Header` now coerces attribute **keys** to `String` (it already coerced values), so a header built
  with `Symbol` keys matches one parsed from XML — both are `Hash<String, String>` — and a colliding
  string/symbol key pair can no longer silently drop a value on write.
- `Xliff::File.from_xml` now reads the file's own direct-child `<header>`/`<body>` rather than the first
  descendant of either name. A `<body>` (or `<header>`) nested inside the header skeleton — `<header><skl>
  <internal-file><body>…</body></internal-file></skl>` — no longer shadows the file's real `<body>`, which
  previously caused every real `<trans-unit>` to be silently dropped. (Same recursive-lookup fix already
  applied to `<source>`/`<target>`/`<note>`.)

## [0.1.0] - 2022-04-23

- Initial release
