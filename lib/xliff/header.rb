# frozen_string_literal: true

require 'nokogiri'

module Xliff
  # Models a file header.
  #
  # A header has an element name and a set of key/value pairs encoded as XML attributes. A header parsed from
  # a document also preserves its child content ({#child_nodes}) verbatim, even though the library doesn't
  # model it.
  class Header
    # A valid XML name the library can actually serialize: an unprefixed name, or one carrying the `xml:`
    # prefix — the only prefix bound in every context, including a standalone {Header#to_s}. Used to reject
    # names supplied on the build-by-hand path that can't be emitted as well-formed XML: one containing a
    # space, or one carrying a namespace prefix the library has no way to bind (e.g. `custom:thing`, which
    # would serialize to a document with an undeclared `custom:` prefix). Names from a parsed document are
    # trusted rather than re-checked — see {.from_xml} — because Nokogiri has already validated them and this
    # pattern intentionally doesn't enumerate every exotic XML 1.0 name character.
    VALID_ELEMENT_NAME = /\A(?:xml:)?[[:alpha:]_][[:alnum:]_.-]*\z/
    private_constant :VALID_ELEMENT_NAME

    # This header's element
    # @return [String]
    attr_reader :element

    # This header's element
    # @return [Hash<String, String>]
    attr_reader :attributes

    # The element's preserved child nodes — its inner content (text and nested elements) kept verbatim
    #
    # Populated only when parsed via {.from_xml}: a header child the library doesn't model (e.g. an `<skl>`
    # skeleton's `<internal-file>`) is deep-copied out of the source document so its content survives a
    # round-trip without retaining that document, and re-emitted by {#to_xml} after the attributes. Empty for
    # a header built by hand. Like a preserved `<group>`, the content survives but isn't reproduced
    # byte-for-byte — a moved node in a namespaced document may gain a redundant namespace declaration.
    # @return [Array<Nokogiri::XML::Node>]
    # @api public
    # @example Inspect a parsed header's preserved content
    #   "header.child_nodes.map(&:name)" #=> ["internal-file"]
    attr_reader :child_nodes

    # Create a blank Header object
    #
    # Most often used to build an XLIFF file by hand.
    #
    # @param [#to_s] element The XML element to use.
    # @param [String: String] attributes Any attributes that should be set on the header.
    # @param [Boolean] validate Whether to reject names that aren't valid XML names. Defaults to `true`;
    #   {.from_xml} passes `false` to accept a parsed document's already-validated names as-is.
    def initialize(element:, attributes: {}, validate: true)
      if validate
        raise "Invalid Header element name – #{element.inspect}" unless element.to_s.match?(VALID_ELEMENT_NAME)

        attributes.each_key do |key|
          raise "Invalid Header attribute name – #{key.inspect}" unless key.to_s.match?(VALID_ELEMENT_NAME)
        end
      end

      @element = element.to_s
      @attributes = attributes.to_h { |key, value| [key.to_s, value.to_s] }
      @child_nodes = []
    end

    # Encode this {Xliff::Header} object as an Nokogiri XML Element Representation of this header's expected element
    #
    # @return [Nokogiri::XML::Element]
    def to_xml
      fragment = Nokogiri::XML.fragment('')
      node = fragment.document.create_element(@element)

      @attributes.each do |key, value|
        node[key] = value
      end

      @child_nodes.each { |child| node.add_child(child.dup) }

      node
    end

    # Encode this {Header} object to an XML string
    #
    # @return [String]
    def to_s
      to_xml.to_xml
    end

    # Decode the given XML into an {Xliff::Header} object, if possible
    #
    # Raises for invalid input. The element name comes straight from a parsed document, so {#initialize} is
    # called with `validate: false` and uses it as-is — Nokogiri has already validated it, and re-checking
    # would wrongly reject a valid-but-exotic XML name (e.g. an NFD-decomposed accent), crashing the parse.
    # Attributes are pre-filtered by {.attributes_from} to those the library can emit; the element's child
    # content is preserved verbatim in {#child_nodes}.
    #
    # @param [Nokogiri::XML::Element] xml An XLIFF header fragment.
    # @return [Header]
    def self.from_xml(xml)
      raise 'Header XML is nil' if xml.nil?
      raise "Invalid Header XML – must be a nokogiri object, got `#{xml.class}`" unless xml.is_a? Nokogiri::XML::Element

      header = new(element: xml.name, attributes: attributes_from(xml), validate: false)
      header.child_nodes.concat(xml.detached_copy.children.to_a)
      header
    end

    # Read a header element's emittable attributes into a `{ "name" => value }` hash
    #
    # Keeps unprefixed attributes and the one prefix the library can declare on write — `xml:`, which is
    # bound in every context. An attribute under any other namespace prefix is dropped: the library has no
    # way to emit its `xmlns` declaration, so preserving it would serialize to an undeclared-prefix,
    # non-well-formed document. This mirrors the build-by-hand path, which rejects a non-`xml:` prefix
    # outright. Preserving arbitrary namespaces is tracked in #18.
    #
    # @api private
    # @param [Nokogiri::XML::Element] xml The parsed header element.
    # @return [Hash{String => String}]
    private_class_method def self.attributes_from(xml)
      xml.attribute_nodes.each_with_object({}) do |attr, attributes|
        prefix = attr.namespace&.prefix
        next if prefix && prefix != 'xml'

        attributes[[prefix, attr.name].compact.join(':')] = attr.value
      end
    end
  end
end
