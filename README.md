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

Strings that haven't been translated yet – the shape Xcode exports for a new locale – carry no `<target>`, so `entry.target` (and `entry.note`) may be `nil`.

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

Output targets **XLIFF 1.2**. Documents built from scratch validate against both the strict and transitional schemas, and round-tripped Xcode exports against the transitional schema – all verified by the test suite against the official OASIS XSDs (`bundle exec rake conformance`). The declared `xsi:schemaLocation` defaults to the transitional schema – which is what real-world content such as Xcode's `<tool build-num>` conforms to – and is preserved from the source document when round-tripping. For a document that uses only the structure and attributes the library models – as Xcode's exports do – reading and re-writing it is byte-for-byte unchanged. The library models a fixed attribute set per element and re-emits those attributes in a canonical order (see the limitations below); a document carrying other attributes – or the modeled ones in a different order – round-trips its content but not byte-for-byte.

A few things worth knowing:

- **Untranslated strings** parse with a `nil` `target` (and `note`); both elements are omitted on write.
- **`Xliff::Header` models an element name and its attributes only** – a header's text content and any nested child elements are not preserved on round-trip. It also doesn't bind XML namespaces; `xml:` is the one prefix it can emit (it's always bound). On parse, a non-`xml:` prefix on an element name is dropped (the element re-homes into the default namespace), and a non-`xml:` prefix on an attribute name is dropped too – the library has no way to declare it, so keeping it would emit an undeclared prefix (non-well-formed XML). Building a header by hand rejects a non-`xml:` prefix outright instead. See [#18](https://github.com/Automattic/xliff/issues/18).
- **Only modeled attributes are preserved.** `<file>` keeps `original`/`source-language`/`target-language`/`datatype` and `<trans-unit>` keeps `id`/`xml:space`; any other attribute – e.g. `approved`, `state`, `product-name`, or `xml:lang` on `<source>`/`<target>` – is dropped on read and not re-emitted. Tracked in [#28](https://github.com/Automattic/xliff/issues/28).
- **`source`, `target`, and `note` are plain text.** Inline XLIFF markup (`<g>`, `<ph>`, …) inside them is flattened to its text, and only the first `<note>` on a `<trans-unit>` is retained.
- **`<group>` and `<bin-unit>` are preserved, not parsed.** Their content survives a round-trip (and is available as `Xliff::File#unparsed_body_nodes`), but the library doesn't model them or expose their nested `<trans-unit>`s as entries — and they're re-emitted after the file's entries rather than byte-for-byte in place. First-class support is tracked in [#17](https://github.com/Automattic/xliff/issues/17).
- **Attribute values aren't validated against the schema's enumerations** – an out-of-range `datatype`, `xml:space`, or language code is serialized as given.
- **A preserved `xsi:schemaLocation` is reported, not verified.** The declaration is round-tripped verbatim from the source, so a document that over-declares – like Xcode's exports, which name the *strict* schema yet carry the transitional-only `<tool build-num>` – re-emits output that declares a schema it doesn't fully satisfy. (Re-deriving the declaration instead would break the byte-identical round-trip.) Documents built from scratch default to the transitional schema precisely to avoid this.
- **Byte-identical round-trip assumes a standard root.** The `<xliff>` element is always re-emitted with `xmlns`, `xmlns:xsi`, `version`, and `xsi:schemaLocation`; a source that omits any of these, or declares the schema-instance namespace under a non-`xsi` prefix, is normalized to that form. Preserving an arbitrary root verbatim is tracked in [#16](https://github.com/Automattic/xliff/issues/16).

## Development

After checking out the repo, run `bundle install` to install dependencies. Then, run `bundle exec rake spec` to run the tests; `bundle exec rake conformance` runs just the schema-conformance examples, validating serialized output against the vendored OASIS XLIFF 1.2 XSDs in `spec/schemas`. You can also run `bundle exec console` for an interactive prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/automattic/xliff. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/automattic/xliff/blob/trunk/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Xliff project's codebase and issue tracker is expected to follow the [code of conduct](https://github.com/automattic/xliff/blob/trunk/CODE_OF_CONDUCT.md).
