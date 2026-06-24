# frozen_string_literal: true

RSpec.describe Xliff::Bundle do
  describe '#initialize' do
    it 'properly stores the file path' do
      expect(described_class.new(path: File::NULL).path).to eq File::NULL
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
      expect(described_class.from_string(xml)).not_to be_nil
    end

    it 'returns a bundle object' do
      expect(described_class.from_string(sample_file_contents('infoplist-strings.xliff'))).to be_a described_class
    end
  end

  describe '.path=' do
    it 'stores the path correctly' do
      bundle = described_class.new
      bundle.path = File::NULL
      expect(bundle.path).to eq File::NULL
    end
  end

  describe '.to_s' do
    it 'can decode/encode with identical output' do
      xml = sample_file_contents('infoplist-strings.xliff')
      bundle = described_class.from_string(xml)

      expect(bundle.to_s).to eq xml
    end

    it 'round-trips an Xcode export containing untranslated strings' do
      xml = sample_file_contents('xcode-untranslated.xliff')
      bundle = described_class.from_string(xml)

      expect(bundle.to_s).to eq xml
    end
  end

  describe '.file_named' do
    it 'can find a file by its basename' do
      bundle = described_class.new
      bundle.add_file(new_file(original: 'my-file.txt'))

      expect(bundle.file_named('my-file.txt').original).to eq 'my-file.txt'
    end

    it 'can find a file that uses a URL for its name' do
      bundle = described_class.new
      bundle.add_file(new_file(original: 'example.com/foo/bar/baz'))

      expect(bundle.file_named('example.com/foo/bar/baz').original).to eq 'example.com/foo/bar/baz'
    end

    it 'can find a file by its basename when the original is an Xcode-style path' do
      bundle = described_class.new
      bundle.add_file(new_file(original: 'Resources/en.lproj/InfoPlist.strings'))

      expect(bundle.file_named('InfoPlist.strings').original).to eq 'Resources/en.lproj/InfoPlist.strings'
    end

    it 'returns nil without raising when a full-path file does not match' do
      bundle = described_class.new
      bundle.add_file(new_file(original: 'Resources/en.lproj/InfoPlist.strings'))

      expect(bundle.file_named('Missing.strings')).to be_nil
    end

    it 'returns nil without raising when a file has a nil original' do
      bundle = described_class.new
      bundle.add_file(new_file(original: nil))

      expect(bundle.file_named('anything.strings')).to be_nil
    end

    it 'returns nil if not found' do
      bundle = described_class.new
      expect(bundle.file_named('example.com/foo/bar/baz')).to be_nil
    end
  end
end
