# frozen_string_literal: true

RSpec.describe Xliff::Header do
  describe '#initialize' do
    it 'properly stores the element' do
      expect(described_class.new(element: 'foo').element).to eq 'foo'
    end

    it 'requires an element' do
      expect { described_class.new(attributes: { foo: 'bar' }) }.to raise_error(ArgumentError, /element/)
    end

    it 'rejects an element name that is not a valid XML name' do
      expect { described_class.new(element: 'bad name') }.to raise_error(/Invalid Header element name/)
    end

    it 'rejects an attribute name that is not a valid XML name' do
      expect { described_class.new(element: 'tool', attributes: { 'build num' => 'x' }) }
        .to raise_error(/Invalid Header attribute name/)
    end

    it 'coerces a non-string element so it serializes cleanly instead of raising' do
      expect(described_class.new(element: :tool).to_s).to eq '<tool/>'
    end

    it 'properly stores the attributes' do
      expect(described_class.new(element: 'foo', attributes: { key: 'value' }).attributes['key']).to eq 'value'
    end

    it 'coerces scalars attributes to strings' do
      expect(described_class.new(element: 'foo', attributes: { key: 1 }).attributes['key']).to eq '1'
    end

    it 'coerces non-scalars to strings' do
      expect(described_class.new(element: 'foo', attributes: { key: {} }).attributes['key']).to eq '{}'
    end

    it 'coerces attribute keys to strings (matching parsed headers)' do
      expect(described_class.new(element: 'foo', attributes: { sym: 'v' }).attributes).to eq('sym' => 'v')
    end
  end

  describe '.to_xml' do
    it 'produces valid XML' do
      expect(new_header.to_xml).to be_a Nokogiri::XML::Element
    end

    it 'has the correct root element name' do
      expect(new_header(element: 'my-header').to_xml.name).to eq 'my-header'
    end

    it 'has the correct attributes' do
      expect(new_header(attributes: { test: 1234 }).to_xml['test']).to eq '1234'
    end
  end

  describe '#from_xml' do
    let(:valid_header) { described_class.from_xml(sample_file_xml('fragment-header.xml')) }

    it 'raises for nil xml' do
      expect { described_class.from_xml(nil) }.to raise_exception 'Header XML is nil'
    end

    it 'raises for the wrong kind of object' do
      msg = 'Invalid Header XML – must be a nokogiri object, got `String`'
      expect { described_class.from_xml('<xml />') }.to raise_exception msg
    end

    it 'parses the element name correctly' do
      expect(valid_header.element).to eq 'tool'
    end

    it 'parses the `attributes` correctly' do
      expect(valid_header.attributes['tool-id']).to eq 'com.apple.dt.xcode'
    end

    it 'preserves a namespaced attribute on parse' do
      header = described_class.from_xml(parse_xml('<note xml:lang="en" foo="bar"/>'))
      expect(header.attributes).to eq('xml:lang' => 'en', 'foo' => 'bar')
    end

    it 're-emits a namespaced attribute on write (round-trip)' do
      header = described_class.from_xml(parse_xml('<note xml:lang="en" foo="bar"/>'))
      expect(header.to_s).to eq '<note xml:lang="en" foo="bar"/>'
    end

    it 'accepts a valid-but-exotic XML name (e.g. an NFD-decomposed accent) without re-validating it' do
      name = "caf#{[0x0065, 0x0301].pack('U*')}" # "cafe" + combining acute (NFD) — a valid XML name
      expect(described_class.from_xml(parse_xml("<#{name} v='1'/>")).element).to eq(name)
    end

    it 'accepts a Unicode element name (a valid XML name) on parse' do
      expect(described_class.from_xml(parse_xml('<café tool-id="x"/>')).element).to eq 'café'
    end
  end

  describe '.to_s' do
    it 'can decode/encode with identical output' do
      xml = sample_file_contents('fragment-header.xml')
      header = described_class.from_xml(sample_file_xml('fragment-header.xml'))
      expect(header.to_s).to eq xml
    end
  end
end
