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

    it 'defaults the target to nil for strings that are not yet translated' do
      expect(described_class.new(id: 'x', source: 'Hello').target).to be_nil
    end

    it 'coerces the id to a String' do
      expect(described_class.new(id: 1234, source: 'source').id).to eq('1234')
    end

    it 'rejects a nil id' do
      expect { described_class.new(id: nil, source: 'source') }.to raise_error(ArgumentError, /must not be blank/)
    end

    it 'rejects an empty id' do
      expect { described_class.new(id: '', source: 'source') }.to raise_error(ArgumentError, /must not be blank/)
    end

    it 'rejects a whitespace-only id' do
      expect { described_class.new(id: "  \t\n", source: 'source') }.to raise_error(ArgumentError, /must not be blank/)
    end
  end

  describe '.id=' do
    it 'allows overwriting the id' do
      entry = new_entry
      entry.id = '5678'
      expect(entry.id).to eq '5678'
    end

    it 'coerces an assigned id to a String' do
      entry = new_entry
      entry.id = 5678
      expect(entry.id).to eq('5678')
    end

    it 'rejects an empty assigned id' do
      expect { new_entry.id = '' }.to raise_error(ArgumentError, /must not be blank/)
    end

    it 'rejects a whitespace-only assigned id' do
      expect { new_entry.id = '   ' }.to raise_error(ArgumentError, /must not be blank/)
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

  describe '.xml_space=' do
    it 'allows overwriting the xml:space value' do
      entry = new_entry
      entry.xml_space = 'preserve'
      expect(entry.xml_space).to eq 'preserve'
    end

    it 'normalises a blank assigned value to "default"' do
      entry = new_entry
      entry.xml_space = ''
      expect(entry.xml_space).to eq 'default'
    end

    it 'normalises a whitespace-only assigned value to "default"' do
      entry = new_entry
      entry.xml_space = "  \t"
      expect(entry.xml_space).to eq 'default'
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

      it 'omits the `target` element when the target is nil' do
        expect(described_class.new(id: 'x', source: 'Hello', note: 'ctx').to_xml.at('target')).to be_nil
      end

      it 'keeps the `target` element when the target is an empty string' do
        expect(described_class.new(id: 'x', source: 'Hello', target: '').to_xml.at('target')).not_to be_nil
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

    it 'raises when the mandatory `<source>` element is missing' do
      msg = 'Invalid Entry XML – `<trans-unit>` is missing a `<source>` element'
      expect { described_class.from_xml(parse_xml('<trans-unit id="x"><target>T</target></trans-unit>')) }
        .to raise_exception msg
    end

    it 'raises when the mandatory `id` attribute is missing' do
      msg = 'Invalid Entry XML – `<trans-unit>` has a missing or blank `id` attribute'
      expect { described_class.from_xml(parse_xml('<trans-unit><source>S</source></trans-unit>')) }
        .to raise_exception msg
    end

    it 'raises when the `id` attribute is present but empty' do
      msg = 'Invalid Entry XML – `<trans-unit>` has a missing or blank `id` attribute'
      expect { described_class.from_xml(parse_xml('<trans-unit id=""><source>S</source></trans-unit>')) }
        .to raise_exception msg
    end

    it 'raises when the `id` attribute is present but only whitespace' do
      msg = 'Invalid Entry XML – `<trans-unit>` has a missing or blank `id` attribute'
      expect { described_class.from_xml(parse_xml('<trans-unit id="   "><source>S</source></trans-unit>')) }
        .to raise_exception msg
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

    # Xcode omits `<target>` entirely for strings in a locale that hasn't been translated yet.
    context 'when the entry is untranslated (no `<target>` element)' do
      let(:untranslated) { described_class.from_xml(sample_file_xml('fragment-trans-unit-untranslated.xml')) }

      it 'parses the `source` correctly' do
        expect(untranslated.source).to eq 'WooCommerce'
      end

      it 'parses a nil `target`' do
        expect(untranslated.target).to be_nil
      end

      it 'parses the `note` correctly' do
        expect(untranslated.note).to eq 'Bundle name'
      end
    end

    # `<alt-trans>` holds alternative translations; its nested `<source>`/`<target>`/`<note>` must not be
    # mistaken for the trans-unit's own direct children.
    context 'when the trans-unit contains an `<alt-trans>`' do
      it 'ignores an `<alt-trans>` target/note on an untranslated unit' do
        xml = parse_xml('<trans-unit id="x"><source>Hello</source>' \
                        '<alt-trans><target>Alt</target><note>AltNote</note></alt-trans></trans-unit>')
        expect(described_class.from_xml(xml)).to have_attributes(target: nil, note: nil)
      end

      it 'parses the trans-unit\'s own target, not the `<alt-trans>` target' do
        xml = parse_xml('<trans-unit id="x"><source>Hello</source><target>Real</target>' \
                        '<alt-trans><target>Alt</target></alt-trans></trans-unit>')
        expect(described_class.from_xml(xml).target).to eq 'Real'
      end
    end

    it 'parses a nil `note` when the `<note>` element is absent' do
      xml = parse_xml('<trans-unit id="x"><source>Hello</source><target>Bonjour</target></trans-unit>')
      expect(described_class.from_xml(xml).note).to be_nil
    end

    it 'defaults a missing `xml:space` to "default"' do
      xml = parse_xml('<trans-unit id="x"><source>Hello</source></trans-unit>')
      expect(described_class.from_xml(xml).xml_space).to eq('default')
    end

    it 'defaults an empty `xml:space` to "default"' do
      xml = parse_xml('<trans-unit id="x" xml:space=""><source>Hello</source></trans-unit>')
      expect(described_class.from_xml(xml).xml_space).to eq('default')
    end
  end

  describe '.to_s' do
    it 'matches the input exactly' do
      contents = sample_file_contents('fragment-trans-unit.xml').strip
      xml = Nokogiri::XML(contents).document.root
      expect(described_class.from_xml(xml).to_s).to eq contents
    end

    it 'round-trips an untranslated entry without inventing a `<target>`' do
      contents = sample_file_contents('fragment-trans-unit-untranslated.xml').strip
      xml = Nokogiri::XML(contents).document.root
      expect(described_class.from_xml(xml).to_s).to eq contents
    end
  end
end
