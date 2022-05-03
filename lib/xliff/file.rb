# frozen_string_literal: true

module Xliff
  # Models a single file for translation
  class File
    attr_reader :headers, :entries
    attr_accessor :original, :source_language, :target_language, :datatype

    def initialize(original:, source_language:, target_language:, datatype: 'plaintext')
      @original = original
      @source_language = source_language
      @target_language = target_language
      @datatype = datatype

      @headers = []
      @entries = []
    end

    # Add arbitrary header data to the file.
    #
    # @param Xliff::Header A translation file header
    def add_header(header)
      raise unless header.is_a? Xliff::Header

      @headers << header
    end

    # Add a translation entry to the file.
    #
    # @param Xliff::Entry A translation unit
    def add_entry(entry)
      raise unless entry.is_a? Xliff::Entry

      @entries << entry
    end

    # Encode this `File` object to an Nokogiri XML Element Representation of a `<file>` element.
    #
    # Also encodes any headers and translation strings as children of the `File` element.
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

    # Encode this `Entry` object to an XML string
    def to_s
      to_xml.to_xml
    end

    # Decode the given XML into an {Xliff::File} object, if possible.
    #
    # Raises for invalid input, and parses all child translation entries.
    # @param Nokogiri::XML A translation unit
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

    def self.validate_source_xml(xml)
      raise if xml.nil?
      raise 'Invalid File XML – the root node must be `<file>`' if xml.name != 'file'
    end

    private

    def add_headers_to_file(fragment, node)
      return if @headers.empty?

      header = Nokogiri::XML::Node.new('header', fragment.document)
      @headers.each do |h|
        header.add_child(h.to_xml)
      end
      node.add_child(header)
    end

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
