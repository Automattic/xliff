# frozen_string_literal: true

require 'nokogiri'

module Xliff
  # Models a collection of files for translation
  class Bundle
    attr_reader :files
    attr_accessor :path

    # Create a blank {Bundle} object, suitable for building an XLIFF file by hand.
    #
    # @param [String] path An optional path to where the file should be stored on disk.
    def initialize(path: nil)
      @path = path
      @files = []
    end

    # Add an additional {File} object to the bundle.
    #
    # @param [File] file The file to be stored in the bundle.
    def add_file(file)
      @files << file
    end

    # Find a given file by name.
    #
    # @param [String] name The name of the file to locate. If found it is returned.
    def file_named(name)
      @files.select do |file|
        File.basename(file.original) == name
      end
    end

    # Encode this {Bundle} object as an XLIFF document.
    def to_xml
      document = Nokogiri::XML::Document.new
      document.encoding = 'UTF-8'

      xliff_node = document.create_element('xliff')
      attach_xliff_metadata(xliff_node)

      return document if @files.empty?

      @files.each do |file|
        xliff_node.add_child(file.to_xml)
      end

      document.add_child(xliff_node)

      document
    end

    # Encode this {Bundle} object as an XLIFF document string.
    def to_s
      to_xml.to_s.strip
    end

    # Parse the XLIFF file at the given `path` as an XLIFF {Bundle} object.
    #
    # Raises for invalid input
    #
    # @param [String] path The path to an `xliff` file.
    def self.from_path(path)
      xml = Nokogiri::XML(::File.open(path))
      bundle = from_xml(xml)
      bundle.path = path

      bundle
    end

    # Parse the XLIFF file stored in the given `string` as an XLIFF {Bundle} object.
    #
    # Raises for invalid input
    #
    # @param [String] string A string containing XLIFF data.
    def self.from_string(string)
      xml = Nokogiri::XML(string)
      from_xml(xml)
    end

    # Parse the Nokogiri XML representation of an XLIFF file to a {Bundle} object.
    #
    # Raises for invalid input
    #
    # @param [Nokogiri::XML::Element] xml A Nokogiri XML document containing XLIFF data.
    def self.from_xml(xml)
      raise if xml.nil?

      raise 'Invalid XLIFF file – the root node must be `<xliff>`' if xml.document.root.name != 'xliff'

      bundle = Bundle.new

      xml.document.root.element_children
         .select { |node| node.name == 'file' }
         .each { |node| bundle.add_file File.from_xml(node) }

      bundle
    end

    private

    # Attach the required XLIFF metadata to the given `node`.
    #
    # Currently only supports XLIFF 1.2.
    def attach_xliff_metadata(node)
      node['xmlns'] = 'urn:oasis:names:tc:xliff:document:1.2'
      node['xmlns:xsi'] = 'http://www.w3.org/2001/XMLSchema-instance'
      node['version'] = '1.2'
      node['xsi:schemaLocation'] = 'urn:oasis:names:tc:xliff:document:1.2 http://docs.oasis-open.org/xliff/v1.2/os/xliff-core-1.2-strict.xsd'
    end
  end
end
