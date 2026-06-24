# frozen_string_literal: true

RSpec.describe Xliff::File do
  describe '#initialize' do
    it 'properly stores the original' do
      expect(new_file(original: 'test').original).to eq 'test'
    end

    it 'properly stores the source_language' do
      expect(new_file(source_language: 'en').source_language).to eq 'en'
    end

    it 'properly stores the target_language' do
      expect(new_file(target_language: 'fr').target_language).to eq 'fr'
    end

    it 'uses `plaintext` as the default datatype' do
      expect(new_file.datatype).to eq 'plaintext'
    end

    it 'properly stores the datatype' do
      expect(new_file(datatype: 'php').datatype).to eq 'php'
    end

    it 'rejects a nil original' do
      expect { new_file(original: nil) }.to raise_error(ArgumentError, /original/)
    end

    it 'rejects an empty original' do
      expect { new_file(original: '') }.to raise_error(ArgumentError, /original/)
    end

    it 'rejects a nil source_language' do
      expect { new_file(source_language: nil) }.to raise_error(ArgumentError, /source-language/)
    end

    it 'rejects an empty source_language' do
      expect { new_file(source_language: '') }.to raise_error(ArgumentError, /source-language/)
    end

    it 'treats an empty target_language as absent' do
      expect(new_file(target_language: '').target_language).to be_nil
    end

    it 'treats an empty datatype as the default' do
      expect(new_file(datatype: '').datatype).to eq 'plaintext'
    end

    it 'has no files by default' do
      expect(new_file.entries).to be_empty
    end

    it 'has no headers by default' do
      expect(new_file.headers).to be_empty
    end
  end

  describe '.entry_with_id' do
    it 'finds an entry with the given id' do
      file = new_file
      file.add_entry(new_entry(id: '1234'))

      expect(file.entry_with_id('1234').id).to eq '1234'
    end

    it 'finds an entry built with an integer id when looked up by that integer' do
      file = new_file
      file.add_entry(new_entry(id: 1234))

      expect(file.entry_with_id(1234).id).to eq '1234'
    end

    it 'returns nil if not found' do
      file = new_file
      expect(file.entry_with_id('1234')).to be_nil
    end
  end

  describe '#from_xml' do
    let(:valid_file) { described_class.from_xml(sample_file_xml('fragment-valid-file.xml')) }

    it 'raises for nil xml' do
      expect { described_class.from_xml(nil) }.to raise_exception 'File XML is nil'
    end

    it 'raises for the wrong kind of object' do
      msg = 'Invalid File XML – must be a nokogiri object, got `String`'
      expect { described_class.from_xml('<xml />') }.to raise_exception msg
    end

    it 'raises for invalid xml' do
      exp = 'Invalid File XML – the root node must be `<file>`'
      expect { described_class.from_xml(Nokogiri::XML('<xml />').document.root) }.to raise_exception exp
    end

    it 'raises when the required `original` attribute is missing' do
      exp = 'Invalid File XML – `<file>` is missing the required `original` attribute'
      expect { described_class.from_xml(parse_xml('<file source-language="en"><body/></file>')) }.to raise_exception exp
    end

    it 'raises when the required `source-language` attribute is missing' do
      exp = 'Invalid File XML – `<file>` is missing the required `source-language` attribute'
      expect { described_class.from_xml(parse_xml('<file original="x"><body/></file>')) }.to raise_exception exp
    end

    it 'parses the `original` correctly' do
      expect(valid_file.original).to eq 'Resources/en.lproj/InfoPlist.strings'
    end

    it 'parses the `source-language` correctly' do
      expect(valid_file.source_language).to eq 'en'
    end

    it 'parses the `target-language` correctly' do
      expect(valid_file.target_language).to eq 'fr'
    end

    it 'parses the `datatype` correctly' do
      expect(valid_file.datatype).to eq 'plaintext'
    end

    it 'defaults a missing `datatype` to plaintext' do
      xml = parse_xml('<file original="x" source-language="en" target-language="fr"><body/></file>')
      expect(described_class.from_xml(xml).datatype).to eq('plaintext')
    end

    it 'parses a nil `target-language` when the attribute is absent (it is optional)' do
      xml = parse_xml('<file original="x" source-language="en" datatype="plaintext"><body/></file>')
      expect(described_class.from_xml(xml).target_language).to be_nil
    end

    it 'does not re-emit `target-language` when the source omitted it' do
      xml = parse_xml('<file original="x" source-language="en" datatype="plaintext"><body/></file>')
      expect(described_class.from_xml(xml).to_xml['target-language']).to be_nil
    end

    it 'correctly parses file with missing header tag' do
      expect(described_class.from_xml(sample_file_xml('fragment-empty-file.xml')).headers).to be_empty
    end

    it 'correctly parses file with missing body tag' do
      expect(described_class.from_xml(sample_file_xml('fragment-empty-file.xml')).entries).to be_empty
    end

    it 'parses only the top-level trans-units of <body>' do
      file = described_class.from_xml(sample_file_xml('fragment-file-with-group.xml'))
      expect(file.entries.map(&:id)).to eq(['top'])
    end

    it 'preserves a <group> and its nested <trans-unit> on round-trip' do
      file = described_class.from_xml(sample_file_xml('fragment-file-with-group.xml'))
      reparsed = Nokogiri::XML(file.to_s)

      # The nested `inside` unit can only survive if the enclosing `<group>` was preserved verbatim.
      expect(reparsed.xpath("//*[local-name()='trans-unit']").map { |t| t['id'] }).to eq(%w[top inside])
    end
  end

  describe '.to_xml' do
    it 'produces valid XML' do
      expect(new_file.to_xml).to be_a Nokogiri::XML::Element
    end

    it 'has the root node <file>' do
      expect(new_file.to_xml.name).to eq 'file'
    end

    describe '<file>' do
      it 'has the correct `original` attribute' do
        expect(new_file(original: 'test').to_xml['original']).to eq 'test'
      end

      it 'has the correct `source-language` attribute' do
        expect(new_file(source_language: 'en').to_xml['source-language']).to eq 'en'
      end

      it 'has the correct `target-language` attribute' do
        expect(new_file(target_language: 'fr').to_xml['target-language']).to eq 'fr'
      end

      it 'omits the `target-language` attribute when target_language is nil' do
        expect(described_class.new(original: 'a', source_language: 'en').to_xml['target-language']).to be_nil
      end

      it 'has the correct `datatype` attribute' do
        expect(new_file(datatype: 'php').to_xml['datatype']).to eq 'php'
      end

      it 'does not contain the header element by default' do
        expect(new_file.to_xml.at('header')).to be_nil
      end

      it 'contains an (empty) `body` element by default, as the schema requires' do
        expect(new_file.to_xml.at('body')).not_to be_nil
      end

      it 'contains the `body` element if entries are present' do
        expect(new_file(entries: [new_entry]).to_xml.at('body')).not_to be_nil
      end
    end
  end
end
