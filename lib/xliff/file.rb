# frozen_string_literal: true

module Xliff
  # Models a single file for translation
  class File
    #  The file's headers
    # @return [Array<Header>]
    attr_reader :headers

    # The file's translation entries
    # @return [Array<Header>]
    attr_reader :entries

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
    # @return [String]
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
    # @param [String] original The original file name.
    # @param [String] source_language The locale code for the source language.
    # @param [String] target_language The locale code for the translated language.
    # @param [String] datatype The type of data represented.
    def initialize(original:, source_language:, target_language:, datatype: 'plaintext')
      @original = original
      @source_language = source_language
      @target_language = target_language
      @datatype = datatype

      @headers = []
      @entries = []
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

    # Encode this `File` object to an Nokogiri XML Element Representation of a `<file>` element
    #
    # Also encodes any headers and translation strings as children of the `File` element.
    #
    # @return [Nokogiri::XML.fragment]
    def to_xml
      fragment = Nokogiri::XML.fragment('')
      file_node = fragment.document.create_element('file')
      file_node['original'] = @original
      file_node['source-language'] = @source_language
      file_node['target-language'] = @target_language
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
    # @param [Nokogiri::XML::Element, #read] xml An XLIFF `<file>` fragment.
    # @return [File]
    def self.from_xml(xml)
      validate_source_xml(xml)

      file = File.new(
        original: xml['original'],
        source_language: xml['source-language'],
        target_language: xml['target-language'],
        datatype: xml['datatype'] || nil
      )

      xml.at('header').element_children.each { |node| file.add_header Header.from_xml(node) }
      xml.at('body').element_children.each { |node| file.add_entry Entry.from_xml(node) }

      file
    end

    # Run a series of validations against the input XML
    #
    # Automatically run prior to attempting to parse using `from_xml`.
    #
    # @raise [ExceptionClass] Raises exceptions if the input XML does not match expectations.
    # @return [void]
    def self.validate_source_xml(xml)
      raise if xml.nil?
      raise 'Invalid File XML – the root node must be `<file>`' if xml.name != 'file'
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
    # @api private
    # @return [void]
    def add_entries_to_file(fragment, node)
      return if @entries.empty?

      body = Nokogiri::XML::Node.new('body', fragment.document)
      @entries.each do |entry|
        body.add_child(entry.to_xml)
      end
      node.add_child(body)
    end
  end
end
