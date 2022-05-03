# frozen_string_literal: true

require 'nokogiri'

module Xliff
  # Models a single translation string
  class Entry
    # A unique identifier for this translation string
    #
    # This will often match the source language string, but can also be used for cases where the
    # source translation is not a suitable unique identifier.
    #
    # @return [String]
    attr_reader :id

    # The original text
    # @return [String]
    attr_reader :source

    # The translated text
    # @return [String]
    attr_reader :target

    # Documentation for translators understand the context of a string
    # @return [String]
    attr_reader :note

    # The XML whitespace processing behaviour
    # @return [String]
    attr_reader :xml_space

    # Create a blank Entry object
    #
    # Most often used to build an XLIFF file by hand.
    #
    # @param [String] id A unique identifier for this string.
    # @param [String] source The original text.
    # @param [String] target The translated text.
    # @param [String] note Documentation for translators understand the context of a string.
    # @param [String] xml_space The XML whitespace processing behaviour.
    def initialize(id:, source:, target:, note: nil, xml_space: 'default')
      @id = id
      @source = source
      @target = target
      @note = note
      @xml_space = xml_space
    end

    # Encode this `Entry` object to an Nokogiri XML Element Representation of a `<trans-unit>` element
    #
    # @return [Nokogiri::XML::Element]
    def to_xml
      fragment = Nokogiri::XML.fragment('<trans-unit />')
      trans_unit_node = fragment.at('trans-unit')
      trans_unit_node['id'] = @id
      trans_unit_node['xml:space'] = @xml_space

      trans_unit_node.add_leaf_node(element: 'source', content: @source)
      trans_unit_node.add_leaf_node(element: 'target', content: @target)

      return trans_unit_node if @note.nil?

      trans_unit_node.add_leaf_node(element: 'note', content: @note)

      trans_unit_node
    end

    # Encode this `Entry` object to an XML string
    #
    # @return [String]
    def to_s
      to_xml.to_s.strip
    end

    # Decode the given XML into an `Entry` object, if possible
    #
    # Raises for invalid input
    #
    # @return [Entry, nil]
    def self.from_xml(xml)
      validate_source_xml(xml)

      Entry.new(
        id: xml['id'],
        source: xml.at('source').content,
        target: xml.at('target').content,
        note: xml.at('note').content || nil,
        xml_space: xml['xml:space']
      )
    end

    # Validate the given XML to ensure that it's a valid `<trans-unit>` element
    #
    # @return [void]
    def self.validate_source_xml(xml)
      raise 'Entry XML is nil' if xml.nil?
      raise "Invalid Entry XML – must be a nokogiri object, got `#{xml.class}`" unless xml.is_a? Nokogiri::XML::Element
      raise 'Invalid Entry XML – the root node must be `<trans-unit>`' if xml.name != 'trans-unit'
    end
  end
end
