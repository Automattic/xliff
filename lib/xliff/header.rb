# frozen_string_literal: true

require 'nokogiri'

module Xliff
  # Models a file header.
  #
  # Headers have an element and a set of key/value pairs encoded as XML attributes.
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
    # Raises for invalid input. The element and attribute names come straight from a parsed document, so
    # {#initialize} is called with `validate: false` and uses them as-is — Nokogiri has already validated
    # them, and re-checking would wrongly reject valid-but-exotic XML names (e.g. an NFD-decomposed accent),
    # crashing the parse.
    #
    # @param [Nokogiri::XML::Element] xml An XLIFF header fragment.
    # @return [Header]
    def self.from_xml(xml)
      raise 'Header XML is nil' if xml.nil?
      raise "Invalid Header XML – must be a nokogiri object, got `#{xml.class}`" unless xml.is_a? Nokogiri::XML::Element

      new(element: xml.name, attributes: attributes_from(xml), validate: false)
    end

    # Read a header element's attributes into a `{ "prefix:name" => value }` hash, keeping namespace prefixes
    #
    # @api private
    # @param [Nokogiri::XML::Element] xml The parsed header element.
    # @return [Hash{String => String}]
    private_class_method def self.attributes_from(xml)
      xml.attribute_nodes.to_h { |a| [[a.namespace&.prefix, a.name].compact.join(':'), a.value] }
    end
  end
end
