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

Output targets **XLIFF 1.2**. Documents built from scratch validate against both the strict and transitional schemas. The declared `xsi:schemaLocation` defaults to the transitional schema – which is what real-world content such as Xcode's `<tool build-num>` conforms to – and is preserved verbatim from the source document when round-tripping, so reading and re-writing a file leaves it byte-for-byte unchanged.

A few things worth knowing:

- **Untranslated strings** parse with a `nil` `target` (and `note`); both elements are omitted on write.
- **`Xliff::Header` models an element name and its attributes only** – a header's text content and any nested child elements are not preserved on round-trip.
- **`source`, `target`, and `note` are plain text.** Inline XLIFF markup (`<g>`, `<ph>`, …) inside them is flattened to its text, and only the first `<note>` on a `<trans-unit>` is retained.
- **Attribute values aren't validated against the schema's enumerations** – an out-of-range `datatype`, `xml:space`, or language code is serialized as given.

## Development

After checking out the repo, run `bundle install` to install dependencies. Then, run `bundle exec rake spec` to run the tests. You can also run `bundle exec console` for an interactive prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/automattic/xliff. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/automattic/xliff/blob/trunk/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Xliff project's codebase and issue tracker is expected to follow the [code of conduct](https://github.com/automattic/xliff/blob/trunk/CODE_OF_CONDUCT.md).
