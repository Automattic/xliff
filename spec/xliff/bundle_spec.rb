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

    it 'defaults the schema_location to the XLIFF 1.2 transitional schema' do
      expect(described_class.new.schema_location).to include('xliff-core-1.2-transitional.xsd')
    end
  end

  describe '.schema_location' do
    it 'preserves the schemaLocation declared by the source document on round-trip' do
      bundle = described_class.from_string(sample_file_contents('infoplist-strings.xliff'))
      expect(bundle.to_s).to include('xliff-core-1.2-strict.xsd')
    end

    it 'declares the transitional schema for a bundle built from scratch' do
      bundle = described_class.new
      bundle.add_file(new_file)
      expect(bundle.to_s).to include('xliff-core-1.2-transitional.xsd')
    end

    it 'preserves a schemaLocation declared under a non-`xsi` namespace prefix' do
      bundle = described_class.from_string(sample_file_contents('non-xsi-schema-prefix.xliff'))
      expect(bundle.schema_location).to include('xliff-core-1.2-strict.xsd')
    end

    it 'falls back to the default when constructed with an empty schema_location' do
      expect(described_class.new(schema_location: '').schema_location).to include('xliff-core-1.2-transitional.xsd')
    end

    it 'falls back to the default when assigned a nil schema_location' do
      bundle = described_class.new
      bundle.schema_location = nil
      expect(bundle.schema_location).to include('xliff-core-1.2-transitional.xsd')
    end

    it 'never emits an empty `xsi:schemaLocation`' do
      bundle = described_class.new(schema_location: '')
      bundle.add_file(new_file)
      expect(bundle.to_s).not_to include('schemaLocation=""')
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

    it 'raises a clear error for empty or root-less input' do
      ['', '   ', '<?xml version="1.0"?>', '<!-- comment -->'].each do |input|
        expect { described_class.from_string(input) }
          .to raise_error('Invalid XLIFF file – the root node must be `<xliff>`')
      end
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

    it 'raises rather than emit a file-less `<xliff>` (the schema requires at least one `<file>`)' do
      expect { described_class.new.to_xml }.to raise_error(/at least one/)
    end

    # Content survival, not byte-identity: a `<group>` in a namespaced document is re-emitted with a
    # redundant `xmlns` and after the file's entries, so this asserts the nested unit survives rather than
    # a byte-for-byte round trip (full fidelity is tracked in #16/#17).
    it 'preserves a namespaced <group> and its nested <trans-unit> through a round-trip' do
      bundle = described_class.from_string(sample_file_contents('xcode-with-group.xliff'))
      reparsed = Nokogiri::XML(bundle.to_s)

      expect(reparsed.xpath("//*[local-name()='trans-unit']").map { |t| t['id'] }).to eq(%w[top nested])
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

    it 'returns nil if not found' do
      bundle = described_class.new
      expect(bundle.file_named('example.com/foo/bar/baz')).to be_nil
    end
  end
end
