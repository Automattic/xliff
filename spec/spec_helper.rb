# frozen_string_literal: true

require 'xliff'
require 'nokogiri'
require 'simplecov'
require 'simplecov-json'

SimpleCov.start
SimpleCov.formatter = SimpleCov::Formatter::JSONFormatter unless ENV['CI'].nil?

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

## Test Helpers

def parse_xml(xml)
  Nokogiri::XML(xml).document.root
end

def sample_file_path(name)
  File.join(__dir__, 'samples', name)
end

def sample_file_contents(name)
  File.read(sample_file_path(name)).strip
end

def sample_file_xml(name)
  parse_xml(sample_file_contents(name))
end

def new_entry(id: 'id', source: 'source', target: 'target', note: nil)
  Xliff::Entry.new(
    id: id,
    source: source,
    target: target,
    note: note
  )
end

def new_header(element: 'header', attributes: { foo: 'bar' })
  Xliff::Header.new(
    element: element,
    attributes: attributes
  )
end

def new_file(
  original: 'original',
  source_language: 'en',
  target_language: 'fr',
  datatype: 'plaintext',
  entries: []
)
  file = Xliff::File.new(
    original: original,
    source_language: source_language,
    target_language: target_language,
    datatype: datatype
  )

  entries.each { |e| file.add_entry(e) }

  file
end
