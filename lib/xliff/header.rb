# frozen_string_literal: true

require 'nokogiri'

module Xliff
  # Models a file header.
  #
  # Headers have an element and a set of key/value pairs encoded as XML attributes.
  class Header
    attr_reader :element, :attributes

    def initialize(element: nil, attributes: {})
      @element = element
      @attributes = attributes.transform_values(&:to_s)
    end

    def to_xml
      fragment = Nokogiri::XML.fragment('')
      node = fragment.document.create_element(@element)

      @attributes.each do |key, value|
        node[key] = value
      end

      node
    end

    def to_s
      to_xml.to_xml
    end

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
