# frozen_string_literal: true

require 'nokogiri'

module Xliff
  # Models a single file for translation
  class File
    #  The file's headers
    # @return [Array<Header>]
    attr_reader :headers

    # The file's translation entries
    # @return [Array<Entry>]
    attr_reader :entries

    # `<body>` children the library does not model (e.g. `<group>`, `<bin-unit>`)
    #
    # Deep-copied out of the source document on parse (so the source document isn't retained) and re-emitted
    # on write, so their nested content survives a round-trip even though it is not parsed into {#entries}.
    # Content is preserved rather than reproduced byte-for-byte: the nodes are re-emitted after the file's
    # entries, and in a namespaced document a moved node may gain a redundant namespace declaration (full
    # fidelity is tracked in #16/#17).
    # @return [Array<Nokogiri::XML::Node>]
    # @example Inspect the preserved (unmodeled) body children
    #   "file.unparsed_body_nodes.map(&:name)" #=> ["group"]
    attr_reader :unparsed_body_nodes

    # The file's name in the original project (used for reference when translating)
    # @return [String]
    attr_reader :original

    # The locale code for the source language
    #
    # @return [String]
    attr_reader :source_language

    # The locale code for the translated language
    #
    # This usually matches the `source_language` for files to be translated – it will differ if the file has
    # been translated.
    #
    # @return [String, nil]
    attr_reader :target_language

    # The type of data represented
    #
    # There are a variety of programming languages that can be represented by the XLIFF spec. Defaults to `plaintext`.
    # @return [String]
    attr_reader :datatype

    # Create a blank File object
    #
    # Most often used to build an XLIFF file by hand.
    #
    # @param [String] original The original file name. Required by XLIFF 1.2; must not be empty.
    # @param [String] source_language The locale code for the source language. Required; must not be empty.
    # @param [String, nil] target_language The locale code for the translated language. Optional in XLIFF 1.2,
    #   so an absent (or blank) value becomes `nil` and no `target-language` attribute is emitted.
    # @param [String] datatype The type of data represented. An absent (or blank) value defaults to `plaintext`.
    # @raise [ArgumentError] If `original` or `source_language` is empty.
    def initialize(original:, source_language:, target_language: nil, datatype: 'plaintext')
      raise ArgumentError, 'File `original` must not be empty' if original.to_s.empty?
      raise ArgumentError, 'File `source-language` must not be empty' if source_language.to_s.empty?

      @original = original
      @source_language = source_language
      @target_language = Xliff.presence(target_language)
      @datatype = Xliff.presence(datatype) || 'plaintext'

      @headers = []
      @entries = []
      @unparsed_body_nodes = []
    end

    # Add arbitrary header data to the file
    #
    # @param [Xliff::Header] header A translation file header.
    # @return [void]
    def add_header(header)
      raise unless header.is_a? Xliff::Header

      @headers << header
    end

    # Add a translation entry to the file
    #
    # @param [Xliff::Entry] entry A translation unit.
    # @return [void]
    def add_entry(entry)
      raise unless entry.is_a? Xliff::Entry

      @entries << entry
    end

    # Find the first entry with a given `id`, if present
    #
    # @param [#to_s] id The `id` to search for. Coerced to a `String` to match how {Entry} stores its `id`.
    # @return [Xliff::Entry, nil]
    def entry_with_id(id)
      id = id.to_s
      @entries.find do |entry|
        entry.id == id
      end
    end

    # Encode this {File} object as an XLIFF document fragment representing the {File}
    #
    # Also encodes any headers and translation strings as children of the `File` element.
    #
    # @return [Nokogiri::XML::Element]
    def to_xml
      fragment = Nokogiri::XML.fragment('')
      file_node = fragment.document.create_element('file')
      file_node['original'] = @original
      file_node['source-language'] = @source_language
      file_node['target-language'] = @target_language unless @target_language.nil?
      file_node['datatype'] = @datatype

      add_headers_to_file(fragment, file_node)
      add_entries_to_file(fragment, file_node)

      file_node
    end

    # Encode this {File} object to an XML string
    #
    # @return [String]
    def to_s
      to_xml.to_xml
    end

    # Decode the given XML into an {Xliff::File} object, if possible
    #
    # Raises for invalid input, and parses all child translation entries.
    #
    # @param [Nokogiri::XML::Element] xml An XLIFF `<file>` fragment.
    # @return [File]
    def self.from_xml(xml)
      validate_source_xml(xml)

      file = File.new(
        original: xml['original'],
        source_language: xml['source-language'],
        target_language: xml['target-language'],
        datatype: xml['datatype']
      )

      import_file_header(xml, file)
      import_file_body(xml, file)

      file
    end

    # Run a series of validations against the input XML
    #
    # Automatically run prior to attempting to parse using `from_xml`.
    #
    # @raise [RuntimeError] If the input XML is nil, not a Nokogiri element, or not a valid `<file>`.
    # @return [void]
    def self.validate_source_xml(xml)
      raise 'File XML is nil' if xml.nil?
      raise "Invalid File XML – must be a nokogiri object, got `#{xml.class}`" unless xml.is_a? Nokogiri::XML::Element
      raise 'Invalid File XML – the root node must be `<file>`' if xml.name != 'file'

      %w[original source-language].each do |attr|
        raise "Invalid File XML – `<file>` is missing the required `#{attr}` attribute" if xml[attr].to_s.empty?
      end
    end

    # Import File Header Tags from given XML
    #
    # Parses the `<header>` XML tag and imports any headers into the file.
    #
    # @api private
    # @param [Nokogiri::XML::Element] xml An XLIFF `<file>` fragment.
    # @param [File] file The {File} object being created.
    # @return [void]
    private_class_method def self.import_file_header(xml, file)
      header = xml.child_element('header')
      return if header.nil?

      header.element_children.each { |node| file.add_header Header.from_xml(node) }
    end

    # Import File <trans-unit> Tags from given XML
    #
    # Parses the `<body>` XML tag and imports any translation entries into the file.
    #
    # @api private
    # @param [Nokogiri::XML::Element] xml An XLIFF `<file>` fragment.
    # @param [File] file The {File} object being created.
    # @return [void]
    private_class_method def self.import_file_body(xml, file)
      body = xml.child_element('body')
      return if body.nil?

      trans_units, others = body.element_children.partition { |node| node.name == 'trans-unit' }
      trans_units.each { |node| file.add_entry(Entry.from_xml(node)) }
      file.unparsed_body_nodes.concat(others.map(&:detached_copy))
    end

    private

    # Encode the file headers into their XML representation
    #
    # @api private
    # @return [void]
    def add_headers_to_file(fragment, node)
      return if @headers.empty?

      header = Nokogiri::XML::Node.new('header', fragment.document)
      @headers.each do |h|
        header.add_child(h.to_xml)
      end
      node.add_child(header)
    end

    # Encode the file's translation entries into their XML representation
    #
    # `<body>` is required by the XLIFF schema even when a file has no entries, so an empty `<body>` is always
    # emitted (unlike the optional `<header>`). Any unmodeled `<body>` children captured on parse
    # ({#unparsed_body_nodes}) are re-emitted after the entries so they survive a round-trip.
    #
    # @api private
    # @return [void]
    def add_entries_to_file(fragment, node)
      body = Nokogiri::XML::Node.new('body', fragment.document)
      @entries.each do |entry|
        body.add_child(entry.to_xml)
      end
      @unparsed_body_nodes.each do |preserved|
        body.add_child(preserved.dup)
      end
      node.add_child(body)
    end
  end
end
