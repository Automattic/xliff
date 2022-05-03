# frozen_string_literal: true

require 'nokogiri'

module Xliff
  # Models a file header.
  #
  # Headers have an element and a set of key/value pairs encoded as XML attributes.
  class Header
    attr_reader :element, :attributes

    # Create a blank Header object.
    #
    # Most often used to build an XLIFF file by hand.
    #
    # @param [String] element The XML element to use.
    # @param [String: String] attributes Any attributes that should be set on the header.
    def initialize(element: nil, attributes: {})
      @element = element
      @attributes = attributes.transform_values(&:to_s)
    end

    # Encode this {Xliff::Header} object as an Nokogiri XML Element Representation of this header's expected element.
    def to_xml
      fragment = Nokogiri::XML.fragment('')
      node = fragment.document.create_element(@element)

      @attributes.each do |key, value|
        node[key] = value
      end

      node
    end

    # Encode this {Xliff::Header} object to an XML string
    def to_s
      to_xml.to_xml
    end

    # Decode the given XML into an {Xliff::Header} object, if possible.
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
        attributes: xml.keys.to_h { |k| [k, xml[k]] }
      )
    end
  end
end
