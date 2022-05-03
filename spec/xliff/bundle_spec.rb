# frozen_string_literal: true

RSpec.describe Xliff::Bundle do
  describe '#initialize' do
    it 'properly stores the file path' do
      expect(described_class.new(path: '/dev/null').path).to eq '/dev/null'
    end

    it 'properly stores no file path' do
      expect(described_class.new.path).to be_nil
    end

    it 'contains no files' do
      expect(described_class.new.files).to be_empty
    end
  end

  describe '#from_path' do
    it 'reads XML from the given path' do
      expect(described_class.from_path(sample_file_path('infoplist-strings.xliff'))).to be_a described_class
    end
  end

  describe '#from_string' do
    it 'reads XML from the given string' do
      xml = sample_file_contents('infoplist-strings.xliff')
      described_class.from_string(xml)
    end

    it 'returns a bundle object' do
      expect(described_class.from_string(sample_file_contents('infoplist-strings.xliff'))).to be_a described_class
    end
  end

  describe '.path=' do
    it 'stores the path correctly' do
      bundle = described_class.new
      bundle.path = '/dev/null'
      expect(bundle.path).to eq '/dev/null'
    end
  end

  describe '.to_s' do
    it 'can decode/encode with identical output' do
      xml = sample_file_contents('infoplist-strings.xliff')
      bundle = described_class.from_string(xml)
      puts xml.inspect
      puts bundle.to_s.inspect

      expect(bundle.to_s).to eq xml
    end
  end
end
