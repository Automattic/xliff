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

    it 'rejects an element name carrying a namespace prefix it cannot bind' do
      expect { described_class.new(element: 'custom:thing') }.to raise_error(/Invalid Header element name/)
    end

    it 'rejects an attribute name carrying a namespace prefix it cannot bind' do
      expect { described_class.new(element: 'tool', attributes: { 'custom:attr' => 'x' }) }
        .to raise_error(/Invalid Header attribute name/)
    end

    # `xml:` is the one prefix bound in every context (the XML spec reserves it), so a hand-built `xml:lang`
    # serializes to well-formed XML — unlike any other prefix, which the library has no way to declare.
    it 'accepts (and round-trips) an `xml:`-prefixed attribute name' do
      expect(described_class.new(element: 'note', attributes: { 'xml:lang' => 'en' }).to_s)
        .to eq '<note xml:lang="en"/>'
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

    it 'has no child nodes when built by hand' do
      expect(described_class.new(element: 'tool').child_nodes).to be_empty
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

    context 'when a header attribute carries a prefix the library cannot declare' do
      # Only `xml:` is bound on write, so any other prefix is dropped on parse rather than re-emitted as an
      # undeclared prefix (non-well-formed XML) — matching the build-by-hand rejection. See #18.
      let(:tool) do
        parse_xml('<root xmlns:custom="urn:x"><tool tool-id="t" custom:flag="on" xml:lang="en"/></root>')
          .element_children.first
      end

      it 'drops the undeclarable attribute but keeps the rest' do
        expect(described_class.from_xml(tool).attributes).to eq('tool-id' => 't', 'xml:lang' => 'en')
      end

      it 're-emits well-formed XML' do
        expect(Nokogiri::XML(described_class.from_xml(tool).to_s, &:strict).errors).to be_empty
      end
    end

    it 'accepts a valid-but-exotic XML name (e.g. an NFD-decomposed accent) without re-validating it' do
      name = "caf#{[0x0065, 0x0301].pack('U*')}" # "cafe" + combining acute (NFD) — a valid XML name
      expect(described_class.from_xml(parse_xml("<#{name} v='1'/>")).element).to eq(name)
    end

    it 'accepts a Unicode element name (a valid XML name) on parse' do
      expect(described_class.from_xml(parse_xml('<café tool-id="x"/>')).element).to eq 'café'
    end

    context 'when the header element has child content the library does not model' do
      # e.g. an <skl> skeleton wrapping an <internal-file>: preserved verbatim (deep-copied) rather than
      # modeled, mirroring how <group>/<bin-unit> are kept in the body. See #17/#18.
      let(:skl) do
        parse_xml('<root xmlns="urn:oasis:names:tc:xliff:document:1.2">' \
                  '<skl xml:space="preserve"><internal-file>SKELETON</internal-file></skl></root>')
          .element_children.first
      end

      it 'exposes the preserved child nodes' do
        expect(described_class.from_xml(skl).child_nodes.map(&:name)).to eq(['internal-file'])
      end

      it 'detaches them from the source document so it can be freed' do
        expect(described_class.from_xml(skl).child_nodes.first.document).not_to be(skl.document)
      end

      it 're-emits the nested content on write' do
        expect(described_class.from_xml(skl).to_s).to include('<internal-file', 'SKELETON')
      end

      it 're-emits well-formed XML' do
        expect(Nokogiri::XML(described_class.from_xml(skl).to_s, &:strict).errors).to be_empty
      end

      it "preserves a header child's direct text content" do
        note = parse_xml('<root><note>just text</note></root>').element_children.first
        expect(described_class.from_xml(note).to_s).to eq '<note>just text</note>'
      end
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
