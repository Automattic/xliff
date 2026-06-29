# Xliff

This gem is for parsing and building `xliff` files.

## Usage

The gem is meant to handle two tasks – reading `xliff` files and creating new ones.

### Reading `xliff` files

```ruby
bundle = Xliff::Bundle.from_path('path/to/my/file.xliff')
bundle.files.each do |file|
    puts "File: #{file.original}:"
    file.entries.each do |entry|
        puts "#{entry.source}:#{entry.target}"
    end
end
```

Strings that haven't been translated yet – the shape Xcode exports for a new locale – carry no `<target>`, so `entry.target` may be `nil`. A `<note>` is optional too, so `entry.note` may be `nil`.

### Creating `xliff` files

```ruby
bundle = Xliff::Bundle.new(path: 'path/to/my/file.xliff')
file = Xliff::File.new(original: 'info.plist', source_language: 'en', target_language: 'fr')
entry = Xliff::Entry.new(id: 1234, source: 'hello', target: 'bonjour')
file.add_entry(entry)
bundle.add_file(file)

xml = bundle.to_s
```

In the above example, `xml` reads:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<xliff xmlns="urn:oasis:names:tc:xliff:document:1.2" version="1.2" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:oasis:names:tc:xliff:document:1.2 http://docs.oasis-open.org/xliff/v1.2/os/xliff-core-1.2-transitional.xsd">
  <file original="info.plist" source-language="en" target-language="fr" datatype="plaintext">
    <body>
      <trans-unit id="1234" xml:space="default">
        <source>hello</source>
        <target>bonjour</target>
      </trans-unit>
    </body>
  </file>
</xliff>
```

`target` is optional – omit it to build a source-only entry for a string that hasn't been translated yet, and no `<target>` element is written.

## Conformance and limitations

Output targets **XLIFF 1.2**. Documents built from scratch validate against both the strict and transitional schemas, and round-tripped Xcode exports against the transitional schema – all verified by the test suite against the official OASIS XSDs (`bundle exec rake conformance`). The declared `xsi:schemaLocation` defaults to the transitional schema – which is what real-world content such as Xcode's `<tool build-num>` conforms to – and is preserved from the source document when round-tripping. For a document that uses only the structure and attributes the library models – as Xcode's exports do – reading and re-writing it is byte-for-byte unchanged. The `<xliff>` root's full attribute set is preserved (see below), re-emitted in a canonical attribute order; `<file>` and `<trans-unit>`, by contrast, model a fixed attribute set, so a document carrying *other* attributes on those elements round-trips its content but not those attributes. Attributes are re-emitted in a canonical order, so a root – or any element – whose attributes appear in a different order is reformatted to that canonical order on write. This is stable: the reformatted output round-trips byte-for-byte, so the library can normalise a whole tree once and then reads and writes it unchanged.

A few things worth knowing:

- **Untranslated strings** parse with a `nil` `target` (and `note`); both elements are omitted on write.
- **`Xliff::Header` models an element name and its attributes; a parsed header's child content is preserved verbatim.** A header child's inner nodes – text and nested elements, e.g. an `<skl>` skeleton's `<internal-file>` – are deep-copied on parse (exposed as `Xliff::Header#child_nodes`) and re-emitted on write, surviving a round-trip even though the library doesn't model them. As with `<group>` below, the content survives but isn't byte-for-byte: a moved node in a namespaced document may gain a redundant `xmlns`. A header built by hand carries only its element name and attributes. The class doesn't bind XML namespaces; `xml:` is the one prefix it can emit (it's always bound). On parse, a non-`xml:` prefix on an element name is dropped (the element re-homes into the default namespace), and a non-`xml:` prefix on an attribute name is dropped too – keeping it would emit an undeclared prefix (non-well-formed XML). Building a header by hand rejects a non-`xml:` prefix outright instead. See [#18](https://github.com/Automattic/xliff/issues/18).
- **Only modeled attributes are preserved.** `<file>` keeps `original`/`source-language`/`target-language`/`datatype` and `<trans-unit>` keeps `id`/`xml:space`; any other attribute – e.g. `approved`, `state`, `product-name`, or `xml:lang` on `<source>`/`<target>` – is dropped on read and not re-emitted. Tracked in [#28](https://github.com/Automattic/xliff/issues/28).
- **`source`, `target`, and `note` are plain text.** Inline XLIFF markup (`<g>`, `<ph>`, …) inside them is flattened to its text, and only the first `<note>` on a `<trans-unit>` is retained.
- **`<group>` and `<bin-unit>` are preserved, not parsed.** Their content survives a round-trip (and is available as `Xliff::File#unparsed_body_nodes`), but the library doesn't model them or expose their nested `<trans-unit>`s as entries — and they're re-emitted after the file's entries rather than byte-for-byte in place. First-class support is tracked in [#17](https://github.com/Automattic/xliff/issues/17).
- **Attribute values aren't validated against the schema's enumerations** – an out-of-range `datatype`, `xml:space`, or language code is serialized as given.
- **A preserved `xsi:schemaLocation` is reported, not verified.** The declaration is round-tripped verbatim from the source, so a document that over-declares – like Xcode's exports, which name the *strict* schema yet carry the transitional-only `<tool build-num>` – re-emits output that declares a schema it doesn't fully satisfy. (Re-deriving the declaration instead would break the byte-identical round-trip.) Documents built from scratch default to the transitional schema precisely to avoid this.
- **The `<xliff>` root's full attribute set is preserved, in a canonical order.** Its namespace declarations and attributes – a non-`xsi` schema-instance prefix, an omitted (optional) `xsi:schemaLocation`, a vendor extension – are captured on parse and replayed on write, rather than normalized to a fixed `xmlns`/`xmlns:xsi`/`version`/`xsi:schemaLocation` set. The exception is a root that *omits* part of the baseline a valid document needs: `version` (required on `<xliff>` by the schema) and a default `xmlns` for the XLIFF namespace are re-asserted when absent, so a root that would otherwise serialize as invalid is healed rather than reproduced as-is. (The schema requires only that the elements be *in* the namespace; the default `xmlns` is this library's constraint, since it emits unprefixed `<xliff>`/`<file>`. A present-but-non-standard *value*, like a non-XLIFF default namespace, is left as captured – that's the namespace caveat below.) They're re-emitted in the canonical attribute order Nokogiri produces, which is byte-identical for an Xcode export (and any already-canonical root); a root in a different order is reformatted to the canonical one on write. That reformat is stable – the output round-trips byte-for-byte – so a pipeline can normalise every file once and then see no diff churn.
- **Namespace handling targets the standard XLIFF namespace.** A source document not in the XLIFF 1.2 namespace still round-trips its content, but a preserved `<group>`/`<bin-unit>` or header child may shift its `xmlns` on write – and such a round-trip can take a second pass to stabilize. The standalone `Xliff::Header#to_s`/`Xliff::File#to_s` likewise emit a namespace-coherent fragment only within the full `<xliff>` document. Deliberately out of scope here, since Xcode's exports are all in the standard namespace – tracked in [#32](https://github.com/Automattic/xliff/issues/32).

## Development

After checking out the repo, run `bundle install` to install dependencies. Then, run `bundle exec rake spec` to run the tests; `bundle exec rake conformance` runs just the schema-conformance examples, validating serialized output against the vendored OASIS XLIFF 1.2 XSDs in `spec/schemas`. You can also run `bundle exec console` for an interactive prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/automattic/xliff. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/automattic/xliff/blob/trunk/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Xliff project's codebase and issue tracker is expected to follow the [code of conduct](https://github.com/automattic/xliff/blob/trunk/CODE_OF_CONDUCT.md).
