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
    id:,
    source:,
    target:,
    note:
  )
end

def new_header(element: 'header', attributes: { foo: 'bar' })
  Xliff::Header.new(
    element:,
    attributes:
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
    original:,
    source_language:,
    target_language:,
    datatype:
  )

  entries.each { |e| file.add_entry(e) }

  file
end

## Shared Examples

# A required attribute that must not be blank: nil, empty, or whitespace-only all raise an `ArgumentError`
# matching `message`. The including group defines `set(value)` to construct (or assign) the attribute with
# `value`; only the raising behaviour is exercised, so the return value is irrelevant.
RSpec.shared_examples 'a blank-rejecting attribute' do |message|
  it 'rejects a nil value' do
    expect { set(nil) }.to raise_error(ArgumentError, message)
  end

  it 'rejects an empty value' do
    expect { set('') }.to raise_error(ArgumentError, message)
  end

  it 'rejects a whitespace-only value' do
    expect { set("  \t\n") }.to raise_error(ArgumentError, message)
  end
end

# An optional attribute that falls back to `default` when blank and is stripped of surrounding whitespace
# otherwise. The including group defines `result(value)` to set the attribute to `value` and return what was
# stored; `sample` is any valid, non-blank value for that attribute.
RSpec.shared_examples 'a blank-defaulting attribute' do |default, sample|
  it 'treats an empty value as the default' do
    expect(result('')).to eq default
  end

  it 'treats a whitespace-only value as the default' do
    expect(result('   ')).to eq default
  end

  it 'strips surrounding whitespace from a present value' do
    expect(result("  #{sample}  ")).to eq sample
  end
end
