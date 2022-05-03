# frozen_string_literal: true

require 'nokogiri'

module Xliff
  # Models a single translation string
  class Entry
    attr_accessor :id, :source, :target, :note, :xml_space

    def initialize(id:, source:, target:, note: nil, xml_space: 'default')
      @id = id
      @source = source
      @target = target
      @note = note
      @xml_space = xml_space
    end

    # Encode this `Entry` object to an Nokogiri XML Element Representation of a `<trans-unit>` element.
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
    def to_s
      to_xml.to_s.strip
    end

    # Decode the given XML into an `Entry` object, if possible.
    #
    # Raises for invalid input
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
    def self.validate_source_xml(xml)
      raise 'Entry XML is nil' if xml.nil?
      raise "Invalid Entry XML – must be a nokogiri object, got `#{xml.class}`" unless xml.is_a? Nokogiri::XML::Element
      raise 'Invalid Entry XML – the root node must be `<trans-unit>`' if xml.name != 'trans-unit'
    end
  end
end
