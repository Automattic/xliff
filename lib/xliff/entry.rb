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
    attr_accessor :source

    # The translated text
    # @return [String, nil]
    attr_accessor :target

    # Documentation for translators understand the context of a string
    # @return [String, nil]
    attr_accessor :note

    # The XML whitespace processing behaviour
    # @return [String]
    attr_reader :xml_space

    # Create a blank Entry object
    #
    # Most often used to build an XLIFF file by hand.
    #
    # @param [String] id A unique identifier for this string.
    # @param [String] source The original text.
    # @param [String, nil] target The translated text. Omitted by Xcode for strings that haven't been translated
    #   yet, so it defaults to `nil` and no `<target>` element is emitted when absent.
    # @param [String, nil] note Documentation for translators understand the context of a string.
    # @param [String] xml_space The XML whitespace processing behaviour.
    def initialize(id:, source:, target: nil, note: nil, xml_space: 'default')
      self.id = id
      @source = source
      @target = target
      @note = note
      self.xml_space = xml_space
    end

    # Set the unique identifier, coercing the value to a `String`
    #
    # XML attributes are always strings, so coercing here keeps `id` consistent whether it was built by hand
    # (e.g. with an integer) or parsed back from a document. An empty `id` is rejected: it is meaningless and
    # every empty-id entry would collide under {File#entry_with_id}.
    #
    # @param [#to_s] value The new identifier.
    # @raise [ArgumentError] If the coerced value is empty.
    # @return [void]
    def id=(value)
      coerced = value.to_s
      raise ArgumentError, 'Entry `id` must not be empty' if coerced.empty?

      @id = coerced
    end

    # Set the XML whitespace processing behaviour, normalising a blank value to `default`
    #
    # `xml:space` is a schema enumeration that rejects the empty string, so a blank value is coerced to
    # `default` here (mirroring {#initialize}) to keep {#to_xml} from emitting an invalid `xml:space=""`.
    #
    # @param [String, nil] value The new whitespace behaviour.
    # @return [void]
    def xml_space=(value)
      @xml_space = value.to_s.empty? ? 'default' : value
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
      trans_unit_node.add_leaf_node(element: 'target', content: @target) unless @target.nil?
      trans_unit_node.add_leaf_node(element: 'note', content: @note) unless @note.nil?

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
    # @return [Entry]
    def self.from_xml(xml)
      validate_source_xml(xml)

      Entry.new(
        id: xml['id'],
        source: direct_child(xml, 'source')&.content,
        target: direct_child(xml, 'target')&.content,
        note: direct_child(xml, 'note')&.content,
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
      raise 'Invalid Entry XML – `<trans-unit>` has a missing or empty `id` attribute' if xml['id'].to_s.empty?
      raise 'Invalid Entry XML – `<trans-unit>` is missing a `<source>` element' if direct_child(xml, 'source').nil?
    end

    # The first direct child element with the given (local) name, or nil
    #
    # Matches by local name (namespace-agnostic, like the rest of the parser) and only considers direct
    # children, so a nested `<alt-trans>`/`<group>` subtree can't be mistaken for the trans-unit's own
    # `<source>`/`<target>`/`<note>`.
    #
    # @api private
    # @param [Nokogiri::XML::Element] xml The `<trans-unit>` element.
    # @param [String] name The local element name to find.
    # @return [Nokogiri::XML::Element, nil]
    private_class_method def self.direct_child(xml, name)
      xml.element_children.find { |node| node.name == name }
    end
  end
end
