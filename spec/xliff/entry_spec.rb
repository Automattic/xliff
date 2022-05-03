# frozen_string_literal: true

RSpec.describe Xliff::Entry do
  describe '#initialize' do
    it 'properly stores the id' do
      expect(new_entry(id: '1234').id).to eq '1234'
    end

    it 'properly stores the source' do
      expect(new_entry(source: 'test').source).to eq 'test'
    end

    it 'properly stores the target' do
      expect(new_entry(target: 'test').target).to eq 'test'
    end

    it 'properly stores the note' do
      expect(new_entry(note: 'note').note).to eq 'note'
    end
  end

  describe '.id=' do
    it 'allows overwriting the id' do
      entry = new_entry
      entry.id = '5678'
      expect(entry.id).to eq '5678'
    end
  end

  describe '.source=' do
    it 'allows overwriting the source' do
      entry = new_entry
      entry.source = 'new-source'
      expect(entry.source).to eq 'new-source'
    end
  end

  describe '.target=' do
    it 'allows overwriting the target' do
      entry = new_entry
      entry.target = 'new-target'
      expect(entry.target).to eq 'new-target'
    end
  end

  describe '.note=' do
    it 'allows overwriting the note' do
      entry = new_entry
      entry.note = 'new-note'
      expect(entry.note).to eq 'new-note'
    end
  end

  describe '.to_xml' do
    it 'produces valid XML' do
      expect(new_entry.to_xml).to be_a Nokogiri::XML::Element
    end

    it 'has the root node <trans-unit>' do
      expect(new_entry.to_xml.name).to eq 'trans-unit'
    end

    describe '<trans-unit>' do
      it 'has the correct `id` attribute' do
        expect(new_entry(id: '1234').to_xml['id']).to eq '1234'
      end

      it 'has the `source` element' do
        expect(new_entry.to_xml.at('source')).not_to be_nil
      end

      it 'has the correct `source` value' do
        expect(new_entry(source: 'test').to_xml.at('source').content).to eq 'test'
      end

      it 'has the `target` element' do
        expect(new_entry.to_xml.at('target')).not_to be_nil
      end

      it 'has the correct `target` value' do
        expect(new_entry(target: 'test').to_xml.at('target').content).to eq 'test'
      end

      it 'does not have the `note` element by default' do
        expect(new_entry.to_xml.at('note')).to be_nil
      end

      it 'has the correct `note` value if provided' do
        expect(new_entry(note: 'test').to_xml.at('note').content).to eq 'test'
      end
    end
  end

  describe '#from_xml' do
    let(:valid_entry) { described_class.from_xml(sample_file_xml('fragment-trans-unit.xml')) }

    it 'raises for nil xml' do
      expect { described_class.from_xml(nil) }.to raise_exception 'Entry XML is nil'
    end

    it 'raises for the wrong kind of object' do
      msg = 'Invalid Entry XML – must be a nokogiri object, got `String`'
      expect { described_class.from_xml('<xml />') }.to raise_exception msg
    end

    it 'raises for invalid xml' do
      exp = 'Invalid Entry XML – the root node must be `<trans-unit>`'
      expect { described_class.from_xml(Nokogiri::XML('<xml />').document.root) }.to raise_exception exp
    end

    it 'parses the `id` correctly' do
      expect(valid_entry.id).to eq 'CFBundleDisplayName'
    end

    it 'parses the `source` correctly' do
      expect(valid_entry.source).to eq 'Woo'
    end

    it 'parses the `target` correctly' do
      expect(valid_entry.target).to eq 'Woof'
    end

    it 'parses the `note` correctly' do
      expect(valid_entry.note).to eq 'Bundle display name'
    end

    it 'parses the `xml:space` declaration correctly' do
      expect(valid_entry.xml_space).to eq 'preserve'
    end
  end

  describe '.to_s' do
    it 'matches the input exactly' do
      contents = sample_file_contents('fragment-trans-unit.xml').strip
      xml = Nokogiri::XML(contents).document.root
      expect(described_class.from_xml(xml).to_s).to eq contents
    end
  end
end
