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

    it 'falls back to the default when constructed with a whitespace-only schema_location' do
      expect(described_class.new(schema_location: '   ').schema_location).to include('xliff-core-1.2-transitional.xsd')
    end

    it 'falls back to the default when assigned a nil schema_location' do
      bundle = described_class.new
      bundle.schema_location = nil
      expect(bundle.schema_location).to include('xliff-core-1.2-transitional.xsd')
    end

    it 'strips surrounding whitespace from a padded schema_location' do
      expect(described_class.new(schema_location: '  urn:custom  ').schema_location).to eq 'urn:custom'
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

    # Regression: a parsed header attribute under a prefix the library can't declare (anything but `xml:`)
    # used to round-trip to an undeclared-prefix, non-well-formed document. It's dropped on parse now, so the
    # output re-parses cleanly. See #18.
    context 'when a header attribute uses a namespace prefix the library cannot declare' do
      let(:source) do
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <xliff xmlns="urn:oasis:names:tc:xliff:document:1.2" version="1.2" xmlns:custom="urn:x">
            <file original="x" source-language="en" datatype="plaintext">
              <header><tool tool-id="t" custom:flag="on"/></header>
              <body/>
            </file>
          </xliff>
        XML
      end

      it 'round-trips to well-formed XML' do
        output = described_class.from_string(source).to_s
        expect(Nokogiri::XML(output, &:strict).errors).to be_empty
      end
    end

    # Content survival, not byte-identity: a `<group>` in a namespaced document is re-emitted with a
    # redundant `xmlns` and after the file's entries (full fidelity is tracked in #16/#17). These assert the
    # group survives as a single wrapper carrying its id and its nested source/target text — not merely that
    # a `trans-unit` with the right id exists somewhere in the output.
    context 'when round-tripping a namespaced <group>' do
      let(:reparsed) { Nokogiri::XML(described_class.from_string(sample_file_contents('xcode-with-group.xliff')).to_s) }
      let(:body_children) { reparsed.xpath("//*[local-name()='body']/*") }
      let(:nested) { body_children.last.xpath("./*[local-name()='trans-unit']").first }

      it 'keeps the <group> as a single wrapper after the entry' do
        expect(body_children.map(&:name)).to eq(%w[trans-unit group])
      end

      it "preserves the group's id" do
        expect(body_children.last['id']).to eq 'g1'
      end

      it "preserves the nested unit's id" do
        expect(nested['id']).to eq 'nested'
      end

      it "preserves the nested unit's source text" do
        expect(nested.xpath("./*[local-name()='source']").text).to eq 'Nested'
      end

      it "preserves the nested unit's target text" do
        expect(nested.xpath("./*[local-name()='target']").text).to eq 'Imbriqué'
      end
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

    # Regression: a file built with a non-String `original` (e.g. an integer) used to make `file_named`
    # raise `TypeError` from `::File.basename`, because the value was stored uncoerced and every lookup
    # fell through to the basename comparison.
    it 'does not raise when a file was built with a non-String original' do
      bundle = described_class.new
      bundle.add_file(new_file(original: 1234))

      expect(bundle.file_named('nope')).to be_nil
    end

    it 'finds a file built with a non-String original by its coerced name' do
      bundle = described_class.new
      bundle.add_file(new_file(original: 1234))

      expect(bundle.file_named('1234').original).to eq '1234'
    end
  end

  # Guards the central conformance guarantee: serialized output validates against the official OASIS XLIFF 1.2
  # XSDs (vendored under spec/schemas). Without this, the README's "validates against the strict/transitional
  # schema" claim is only checked by eye and can regress silently.
  describe 'XLIFF 1.2 schema conformance', :conformance do
    context 'with a document built from scratch' do
      subject(:output) do
        bundle = described_class.new
        file = Xliff::File.new(original: 'info.plist', source_language: 'en', target_language: 'fr')
        file.add_entry(Xliff::Entry.new(id: 1234, source: 'hello', target: 'bonjour'))
        bundle.add_file(file)
        bundle.to_s
      end

      it { is_expected.to conform_to_xliff_schema(:strict) }
      it { is_expected.to conform_to_xliff_schema(:transitional) }
    end

    context 'with a from-scratch file that has a header' do
      # Guards the build-by-hand `File#add_header` → `add_headers_to_file` emission path: every other
      # from-scratch example builds a header-less file, so this is otherwise only exercised by the
      # parse-then-re-emit round-trip samples. `build-num` is omitted because it is transitional-only.
      subject(:output) do
        bundle = described_class.new
        file = Xliff::File.new(original: 'info.plist', source_language: 'en', target_language: 'fr')
        header = Xliff::Header.new(element: 'tool', attributes: { 'tool-id' => 'example', 'tool-name' => 'Xcode' })
        file.add_header(header)
        file.add_entry(Xliff::Entry.new(id: 1234, source: 'hello', target: 'bonjour'))
        bundle.add_file(file)
        bundle.to_s
      end

      it { is_expected.to conform_to_xliff_schema(:strict) }
      it { is_expected.to conform_to_xliff_schema(:transitional) }

      it 'emits the header before the body' do
        expect(Nokogiri::XML(output).xpath("//*[local-name()='file']/*").map(&:name)).to eq(%w[header body])
      end
    end

    context 'with a source-only (untranslated) document' do
      # No target-language and no <target> — the Xcode-untranslated shape this PR adds must stay schema-valid.
      subject(:output) do
        bundle = described_class.new
        file = Xliff::File.new(original: 'x.strings', source_language: 'en')
        file.add_entry(Xliff::Entry.new(id: 'CFBundleName', source: 'WooCommerce'))
        bundle.add_file(file)
        bundle.to_s
      end

      it { is_expected.to conform_to_xliff_schema(:strict) }
      it { is_expected.to conform_to_xliff_schema(:transitional) }
    end

    context 'with a file that has no entries' do
      # Guards the "always emit an (empty) <body>" fix: a body-less <file> is schema-invalid.
      subject(:output) do
        bundle = described_class.new
        bundle.add_file(Xliff::File.new(original: 'empty.strings', source_language: 'en'))
        bundle.to_s
      end

      it { is_expected.to conform_to_xliff_schema(:strict) }
    end

    context 'when round-tripping an Xcode export' do
      # Xcode's <tool build-num="…"> is rejected by strict but allowed by transitional — which is why the
      # library declares transitional. Re-serializing the parsed document must stay conformant.
      %w[xcode-untranslated.xliff xcode-with-group.xliff infoplist-strings.xliff].each do |sample|
        it "re-serializes #{sample} as valid transitional XLIFF" do
          round_tripped = described_class.from_string(sample_file_contents(sample)).to_s
          expect(round_tripped).to conform_to_xliff_schema(:transitional)
        end
      end
    end

    # Characterization: the library round-trips a source's xsi:schemaLocation verbatim, so an Xcode export
    # that declares strict while carrying the transitional-only `build-num` re-emits the same over-claim.
    # This pins that intended trade-off — re-deriving the declaration would break the byte-identical
    # round-trip — and closes the gap left by validating round-trips only against :transitional above.
    context 'when a source over-declares its schema' do
      subject(:output) { described_class.from_string(sample_file_contents('infoplist-strings.xliff')).to_s }

      it "preserves the source's strict schema declaration" do
        expect(output).to include('xliff-core-1.2-strict.xsd')
      end

      it 'does not actually satisfy the strict schema it declares (build-num is transitional-only)' do
        expect(output).not_to conform_to_xliff_schema(:strict)
      end

      it 'satisfies the transitional schema it actually conforms to' do
        expect(output).to conform_to_xliff_schema(:transitional)
      end
    end

    context 'with the conformance matcher itself' do
      # A <file> with no <body> is invalid XLIFF; this guards the matcher against vacuously passing.
      let(:bodyless) do
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <xliff xmlns="urn:oasis:names:tc:xliff:document:1.2" version="1.2">
            <file original="x" source-language="en" datatype="plaintext"/>
          </xliff>
        XML
      end

      it 'rejects known-invalid XLIFF' do
        expect(bodyless).not_to conform_to_xliff_schema(:strict)
      end
    end
  end
end
