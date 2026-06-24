# frozen_string_literal: true

require 'nokogiri'

module Xliff
  # Models a file header.
  #
  # Headers have an element and a set of key/value pairs encoded as XML attributes.
  class Header
    # A valid (optionally namespace-prefixed) XML element name.
    VALID_ELEMENT_NAME = /\A[[:alpha:]_][[:alnum:]_.-]*(?::[[:alpha:]_][[:alnum:]_.-]*)?\z/.freeze
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
    # @param [String] element The XML element to use.
    # @param [String: String] attributes Any attributes that should be set on the header.
    def initialize(element:, attributes: {})
      raise "Invalid Header element name – #{element.inspect}" unless element.to_s.match?(VALID_ELEMENT_NAME)

      @element = element.to_s
      @attributes = attributes.transform_values(&:to_s)
    end

    # Encode this {Xliff::Header} object as an Nokogiri XML Element Representation of this header's expected element
    #
    # @return [Nokogiri::XML.fragment]
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
    # Raises for invalid input.
    #
    # @param [Nokogiri::XML::Element] xml An XLIFF header fragment.
    # @return [Header]
    def self.from_xml(xml)
      raise 'Header XML is nil' if xml.nil?
      raise "Invalid Header XML – must be a nokogiri object, got `#{xml.class}`" unless xml.is_a? Nokogiri::XML::Element

      Header.new(
        element: xml.name,
        attributes: xml.attribute_nodes.to_h { |a| [[a.namespace&.prefix, a.name].compact.join(':'), a.value] }
      )
    end
  end
end
