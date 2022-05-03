# frozen_string_literal: true

RSpec.describe Xliff::Header do
  describe '#initialize' do
    it 'properly stores the element' do
      expect(described_class.new(element: 'foo').element).to eq 'foo'
    end

    it 'properly stores the attributes' do
      expect(described_class.new(element: 'foo', attributes: {key: 'value'}).attributes[:key]).to eq 'value'
    end

    it 'coerces scalars attributes to strings' do
      expect(described_class.new(element: 'foo', attributes: {key: 1}).attributes[:key]).to eq '1'
    end

    it 'coerces non-scalars to strings' do
      expect(described_class.new(element: 'foo', attributes: {key: {}}).attributes[:key]).to eq '{}'
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
      expect(new_header(attributes: {test: 1234}).to_xml['test']).to eq '1234'
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
      expect(valid_header.attributes['tool-name']).to eq 'Xcode'
      expect(valid_header.attributes['tool-version']).to eq '13.2.1'
      expect(valid_header.attributes['build-num']).to eq '13C100'
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
