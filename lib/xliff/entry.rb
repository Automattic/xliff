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
    # @return [String, nil]
    attr_reader :target

    # Documentation for translators understand the context of a string
    # @return [String, nil]
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
    # @param [String, nil] target The translated text. Omitted by Xcode for strings that haven't been translated
    #   yet, so it defaults to `nil` and no `<target>` element is emitted when absent.
    # @param [String, nil] note Documentation for translators understand the context of a string.
    # @param [String] xml_space The XML whitespace processing behaviour.
    def initialize(id:, source:, target: nil, note: nil, xml_space: 'default')
      self.id = id
      self.source = source
      self.target = target
      self.note = note
      self.xml_space = xml_space
    end

    # Set the unique identifier, coercing the value to a stripped `String`
    #
    # XML attributes are always strings, so coercing here keeps `id` consistent whether it was built by hand
    # (e.g. with an integer) or parsed back from a document. Surrounding whitespace is stripped so storage
    # agrees with the blank check (which strips before testing) and with the {File#entry_with_id} lookup
    # (which strips too) — otherwise an `id` of `" x "` would be stored padded yet be unfindable by `"x"`.
    # A blank `id` (empty or whitespace-only) is rejected: it is meaningless as a unique identifier, and an
    # empty one would collide for every id-less entry under {File#entry_with_id}.
    #
    # @param [#to_s] value The new identifier.
    # @raise [ArgumentError] If the coerced value is blank (empty or whitespace-only).
    # @return [void]
    def id=(value)
      raise ArgumentError, 'Entry `id` must not be blank' if Xliff.blank?(value)

      @id = value.to_s.strip
    end

    # Set the source text, coercing it to a `String` and rejecting a `nil` value
    #
    # `source` is the original string a `<trans-unit>` must carry, so a `nil` is rejected here and on
    # assignment — the way {#id=} rejects a blank id and {File} rejects a blank `original` — rather than
    # silently emitting an empty `<source/>`. An empty string is tolerated, mirroring {.from_xml}, which
    # accepts an empty `<source>` element (liberal on read). The value is coerced to a `String` (XML content
    # always is), matching {#id=} and {File#initialize}, so {#source} reads back a `String` whatever it was
    # built with — rather than only stringifying at {#to_xml} time. Unlike {#id}, surrounding whitespace is
    # kept: source text can be significant under `xml:space="preserve"`.
    #
    # @param [#to_s] value The new source text.
    # @raise [ArgumentError] If `value` is `nil`.
    # @return [void]
    def source=(value)
      raise ArgumentError, 'Entry `source` must not be nil' if value.nil?

      @source = value.to_s
    end

    # Set the translated text, coercing a present value to a `String` while keeping an absent one `nil`
    #
    # `target` is optional — Xcode omits `<target>` for strings that aren't translated yet — so unlike
    # {#source=} a `nil` is kept as `nil` (and no `<target>` is emitted). A present value is coerced to a
    # `String`, matching {#id=}/{#source=}, so {#target} reads back a `String` whatever it was built with
    # rather than only stringifying at {#to_xml} time. An empty string is preserved (emitted as an empty
    # `<target/>`), keeping the translated-to-empty case distinct from untranslated.
    #
    # @param [#to_s, nil] value The new translated text.
    # @return [void]
    def target=(value)
      @target = value&.to_s
    end

    # Set the translator note, coercing a present value to a `String` while keeping an absent one `nil`
    #
    # Optional like {#target=}: a `nil` is kept as `nil` (no `<note>` emitted), and a present value is coerced
    # to a `String` to match {#id=}/{#source=} rather than stringifying only at {#to_xml} time.
    #
    # @param [#to_s, nil] value The new translator note.
    # @return [void]
    def note=(value)
      @note = value&.to_s
    end

    # Set the XML whitespace processing behaviour, normalising a blank value to `default`
    #
    # `xml:space` is a schema enumeration that rejects the empty string, so a blank value – empty or
    # whitespace-only – is coerced to `default` here (mirroring {#initialize}) to keep {#to_xml} from
    # emitting an invalid `xml:space=""`. See {Xliff.presence}.
    #
    # @param [String, nil] value The new whitespace behaviour.
    # @return [void]
    def xml_space=(value)
      @xml_space = Xliff.presence(value) || 'default'
    end

    # Encode this `Entry` object to an Nokogiri XML Element Representation of a `<trans-unit>` element
    #
    # @return [Nokogiri::XML::Element]
    def to_xml
      fragment = Nokogiri::XML.fragment('')
      trans_unit_node = fragment.document.create_element('trans-unit')
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
      source = validate_source_xml(xml)

      Entry.new(
        id: xml['id'],
        source: source.content,
        target: xml.child_element('target')&.content,
        note: xml.child_element('note')&.content,
        xml_space: xml['xml:space']
      )
    end

    # Validate the given XML to ensure that it's a valid `<trans-unit>` element
    #
    # Returns the located `<source>` so {.from_xml} can read it without scanning the children a second time.
    #
    # @return [Nokogiri::XML::Element] The validated `<source>` element.
    def self.validate_source_xml(xml)
      raise 'Entry XML is nil' if xml.nil?
      raise "Invalid Entry XML – must be a nokogiri object, got `#{xml.class}`" unless xml.is_a? Nokogiri::XML::Element
      raise 'Invalid Entry XML – the root node must be `<trans-unit>`' if xml.name != 'trans-unit'
      raise 'Invalid Entry XML – `<trans-unit>` has a missing or blank `id` attribute' if Xliff.blank?(xml['id'])

      source = xml.child_element('source')
      raise 'Invalid Entry XML – `<trans-unit>` is missing a `<source>` element' if source.nil?

      source
    end
  end
end
