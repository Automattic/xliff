# frozen_string_literal: true

RSpec.describe Xliff::Bundle do
  # A document Nokogiri can only parse by recovering from a fatal error: its final tag is truncated, so the
  # default (recovery-mode) parser yields a silently corrupted tree rather than raising. It carries a valid
  # `<xliff>` root, so it reaches the malformed-document check rather than the root-node check.
  let(:truncated_xliff) do
    '<xliff xmlns="urn:oasis:names:tc:xliff:document:1.2" version="1.2">' \
      '<file original="x" source-language="en"><body>' \
      '<trans-unit id="a"><source>hi</source></trans-unit></body></file'
  end

  # A document whose `<source>` holds an unescaped `&` — a fatal XML error. Recovery-mode parsing silently
  # drops the broken text (`A & B` becomes `A  B`) instead of raising.
  let(:bad_entity_xliff) do
    '<xliff xmlns="urn:oasis:names:tc:xliff:document:1.2" version="1.2">' \
      '<file original="x" source-language="en"><body>' \
      '<trans-unit id="a"><source>A & B</source></trans-unit></body></file></xliff>'
  end

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
    # A root that declares the schema-instance namespace but no `schemaLocation` — assigning one exercises the
    # setter's "append under the already-declared prefix" path, distinct from synthesizing a fresh `xmlns:xsi`.
    let(:xsi_without_schema_location) do
      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <xliff xmlns="urn:oasis:names:tc:xliff:document:1.2" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="1.2">
          <file original="x" source-language="en" datatype="plaintext"><body/></file>
        </xliff>
      XML
    end

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

    it 'reports nil for a parsed document that declares no schemaLocation' do
      bundle = described_class.from_string(sample_file_contents('root-no-schema-location.xliff'))
      expect(bundle.schema_location).to be_nil
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

    it 'appends `schemaLocation` under an already-declared schema-instance prefix' do
      bundle = described_class.from_string(xsi_without_schema_location)
      bundle.schema_location = 'urn:x http://example.com/x.xsd'
      expect(bundle.to_s).to include('xsi:schemaLocation="urn:x http://example.com/x.xsd"')
    end

    it 'synthesizes the schema-instance namespace when assigned to a root that declared none' do
      bundle = described_class.from_string(sample_file_contents('root-no-schema-location.xliff'))
      bundle.schema_location = 'urn:x http://example.com/x.xsd'
      expect(bundle.to_s).to include('xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"')
        .and include('xsi:schemaLocation="urn:x http://example.com/x.xsd"')
    end
  end

  describe '#from_path' do
    it 'reads XML from the given path' do
      expect(described_class.from_path(sample_file_path('infoplist-strings.xliff'))).to be_a described_class
    end

    it 'raises rather than silently recover a malformed file' do
      Tempfile.create(['malformed', '.xliff']) do |file|
        file.write(truncated_xliff)
        file.flush
        expect { described_class.from_path(file.path) }.to raise_error(/Invalid XLIFF file/)
      end
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

    it 'raises a clear error for a well-formed document whose root is not `<xliff>`' do
      expect { described_class.from_string('<not-xliff/>') }
        .to raise_error('Invalid XLIFF file – the root node must be `<xliff>`')
    end

    it 'ignores a non-`<file>` element child of the `<xliff>` root' do
      xml = '<xliff xmlns="urn:oasis:names:tc:xliff:document:1.2" version="1.2">' \
            '<other-thing/>' \
            '<file original="x" source-language="en"><body/></file></xliff>'
      expect(described_class.from_string(xml).files.map(&:original)).to eq(['x'])
    end

    # Regression: a fatal well-formedness error used to yield a partial, silently corrupted bundle instead of
    # raising — contradicting the documented "raises for invalid input" contract.
    it 'raises rather than silently recover a truncated document' do
      expect { described_class.from_string(truncated_xliff) }.to raise_error(/Invalid XLIFF file/)
    end

    it 'raises rather than silently drop content broken by an unescaped `&`' do
      expect { described_class.from_string(bad_entity_xliff) }.to raise_error(/Invalid XLIFF file/)
    end

    # An undeclared namespace prefix is a non-fatal (level ERROR, not FATAL) problem Nokogiri recovers from.
    # Unlike the truncated/bad-entity fixtures (both FATAL), it exercises the `error?` half of the
    # malformed-document check, and carries a valid `<xliff>` root so it reaches that check.
    it 'raises rather than silently recover an error-level (non-fatal) namespace problem' do
      undeclared_prefix = '<xliff xmlns="urn:oasis:names:tc:xliff:document:1.2" version="1.2"><foo:bar/></xliff>'
      expect { described_class.from_string(undeclared_prefix) }.to raise_error(/Invalid XLIFF file/)
    end
  end

  describe '#from_xml' do
    it 'raises a descriptive error for nil xml, matching the other parsers' do
      expect { described_class.from_xml(nil) }.to raise_exception 'Bundle XML is nil'
    end

    it 'raises for a document that only parsed by recovering from a fatal error' do
      expect { described_class.from_xml(Nokogiri::XML(truncated_xliff)) }.to raise_error(/Invalid XLIFF file/)
    end

    it 'preserves the full root attribute set, including a vendor namespace and attribute' do
      output = described_class.from_xml(Nokogiri::XML(sample_file_contents('root-vendor-attributes.xliff'))).to_s
      expect(output).to include('xmlns:tool="urn:example:tool"').and include('tool:product="WooCommerce"')
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

    # #16: the full `<xliff>` root attribute set — namespace declarations, the optional schemaLocation, and
    # any vendor extension — is captured and replayed, rather than normalized to a fixed
    # `xmlns`/`xmlns:xsi`/`version`/`xsi:schemaLocation` set. The set is re-emitted in libxml2's canonical
    # attribute order: byte-identical for an Xcode-shaped (or already-canonical) root, and for any other root
    # semantically identical and byte-stable after the first write (the autoformatter property asserted below).
    context 'when preserving the `<xliff>` root attribute set' do
      # Regression: a source omitting the optional `xsi:schemaLocation` used to gain both `xmlns:xsi` and a
      # defaulted `xsi:schemaLocation` on write. It is now left exactly as declared — and, carrying nothing
      # that reorders, round-trips byte-for-byte.
      it 'round-trips a root that omits the optional `xsi:schemaLocation` byte-for-byte' do
        xml = sample_file_contents('root-no-schema-location.xliff')
        expect(described_class.from_string(xml).to_s).to eq xml
      end

      it 'does not synthesize a schema-instance namespace for a root that declares none' do
        output = described_class.from_string(sample_file_contents('root-no-schema-location.xliff')).to_s
        expect(output).not_to include('xsi')
      end

      # The schema-instance namespace keeps its declared (non-`xsi`) prefix on both the declaration and the
      # `schemaLocation`, rather than being re-emitted under `xsi:`.
      it 'keeps a non-`xsi` schema-instance prefix on the namespace and its schemaLocation' do
        output = described_class.from_string(sample_file_contents('non-xsi-schema-prefix.xliff')).to_s
        expect(output).to include('xmlns:si=').and include('si:schemaLocation=')
      end

      it 'preserves a vendor namespace declaration and attribute the library does not model' do
        output = described_class.from_string(sample_file_contents('root-vendor-attributes.xliff')).to_s
        expect(output).to include('xmlns:tool="urn:example:tool"').and include('tool:product="WooCommerce"')
      end

      # An attribute value carrying XML metacharacters is escaped by Nokogiri on write; a canonically-escaped
      # source round-trips byte-for-byte.
      it 'preserves an attribute value carrying XML metacharacters byte-for-byte' do
        xml = sample_file_contents('root-escaped-attribute.xliff')
        expect(described_class.from_string(xml).to_s).to eq xml
      end

      # The autoformatter property: a root whose attribute order isn't canonical (a non-`xsi` prefix, a vendor
      # attribute) is normalised on first write, then re-writes byte-for-byte — so a pipeline can normalise
      # every file once and see no further diff churn.
      it 'is byte-stable on re-round-trip for a reordered root' do
        %w[non-xsi-schema-prefix.xliff root-vendor-attributes.xliff].each do |sample|
          normalized = described_class.from_string(sample_file_contents(sample)).to_s
          expect(described_class.from_string(normalized).to_s).to eq normalized
        end
      end
    end

    # The full attribute set is preserved, but not at the cost of validity: a parsed root that omits a
    # declaration XLIFF 1.2 requires is healed rather than faithfully reproduced as invalid. (A non-XLIFF
    # default namespace, by contrast, is left as captured — that is the separate concern tracked in #32.)
    context 'when a parsed root omits a required declaration' do
      let(:no_version_root) do
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <xliff xmlns="urn:oasis:names:tc:xliff:document:1.2">
            <file original="x" source-language="en" datatype="plaintext"><body/></file>
          </xliff>
        XML
      end

      let(:no_namespace_root) do
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <xliff version="1.2">
            <file original="x" source-language="en" datatype="plaintext"><body/></file>
          </xliff>
        XML
      end

      # `version` is `use="required"` on `<xliff>`, so a source omitting it re-emits with `version="1.2"`.
      it 're-asserts a missing `version` so the output is valid XLIFF' do
        expect(described_class.from_string(no_version_root).to_s)
          .to include('version="1.2"').and conform_to_xliff_schema(:strict)
      end

      # Strict conformance proves the re-assertion: its validation root must be `{urn:…}xliff`, so an output
      # left in no namespace would fail with "no matching global declaration".
      it 're-asserts the document namespace for a root that declares none' do
        expect(described_class.from_string(no_namespace_root).to_s).to conform_to_xliff_schema(:strict)
      end
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
    # redundant `xmlns` and after the file's entries (placement is tracked in #17, the namespace in #32). These
    # assert the group survives as a single wrapper carrying its id and its nested source/target text — not
    # merely that a `trans-unit` with the right id exists somewhere in the output.
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

    # Regression: a padded `original` used to be stored verbatim, so its basename never matched the clean
    # lookup name. The original is now stripped on construction, so the basename match holds.
    it 'finds a file built with a padded original by its basename' do
      bundle = described_class.new
      bundle.add_file(new_file(original: '  Resources/en.lproj/InfoPlist.strings  '))

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

    # Regression: the lookup argument was compared uncoerced, so an integer name missed a file whose
    # `original` was the coerced equivalent — asymmetric with the integer-built `File#entry_with_id` query.
    it 'finds a file by a non-String lookup argument matching its coerced original' do
      bundle = described_class.new
      bundle.add_file(new_file(original: 1234))

      expect(bundle.file_named(1234).original).to eq '1234'
    end

    it 'finds a file by a name looked up with incidental surrounding whitespace' do
      bundle = described_class.new
      bundle.add_file(new_file(original: 'InfoPlist.strings'))

      expect(bundle.file_named('  InfoPlist.strings  ').original).to eq 'InfoPlist.strings'
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
      # library declares transitional. Re-serializing the parsed document must stay conformant. The
      # root-* samples additionally guard that a preserved arbitrary root (#16) — one omitting schemaLocation
      # or carrying a vendor namespace/attribute — re-serializes as valid XLIFF.
      %w[xcode-untranslated.xliff xcode-with-group.xliff infoplist-strings.xliff
         root-no-schema-location.xliff root-vendor-attributes.xliff].each do |sample|
        it "re-serializes #{sample} as valid transitional XLIFF" do
          round_tripped = described_class.from_string(sample_file_contents(sample)).to_s
          expect(round_tripped).to conform_to_xliff_schema(:transitional)
        end
      end

      # A schemaLocation-less root carries nothing transitional-only, so it must also satisfy strict.
      it 're-serializes root-no-schema-location.xliff as valid strict XLIFF' do
        round_tripped = described_class.from_string(sample_file_contents('root-no-schema-location.xliff')).to_s
        expect(round_tripped).to conform_to_xliff_schema(:strict)
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
