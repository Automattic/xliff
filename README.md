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

### Creating `xliff` files
```ruby

bundle = Xliff::Bundle.new(path: 'path/to/my/file.xliff')
file = Xliff::File.new(original: 'info.plist', source_language: 'en', target_language: 'fr')
entry = Xliff::Entry.new(id: 1234, source: 'hello', target: 'bounjour')
file.add_entry(entry)
bundle.add_file(file)

xml = bundle.to_s
```

In the above example, `xml` reads:

```xml
<xliff>
  <file original="info.plist" source-language="en" target-language="fr" datatype="plaintext">
    <body>
      <trans-unit id="1234" xml:space="default">
        <source>hello</source>
        <target>bounjour</target>
      </trans-unit>
    </body>
  </file>
</xliff>
```

## Development

After checking out the repo, run `bundle install` to install dependencies. Then, run `bundle exec rake spec` to run the tests. You can also run `bundle exec console` for an interactive prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/automattic/xliff. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/automattic/xliff/blob/trunk/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Xliff project's codebase and issue tracker is expected to follow the [code of conduct](https://github.com/automattic/xliff/blob/trunk/CODE_OF_CONDUCT.md).
