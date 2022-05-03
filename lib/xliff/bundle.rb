# frozen_string_literal: true

require 'nokogiri'

module Xliff
  # Models a collection of files for translation
  class Bundle
    attr_reader :files
    attr_accessor :path

    def initialize(path: nil)
      @path = path
      @files = []
    end

    def add_file(file)
      @files << file
    end

    def file_named(name)
      @files.select do |file|
        File.basename(file.original) == name
      end
    end

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

    def to_s
      to_xml.to_s.strip
    end

    def self.from_path(path)
      xml = Nokogiri::XML(::File.open(path))
      bundle = from_xml(xml)
      bundle.path = path

      bundle
    end

    def self.from_string(string)
      xml = Nokogiri::XML(string)
      from_xml(xml)
    end

    def self.from_xml(xml)
      raise if xml.nil?

      xliff_root = xml.document.root
      raise 'Invalid XLIFF file – the root node must be `<xliff>`' if xliff_root.name != 'xliff'

      bundle = Bundle.new

      xliff_root.element_children
                .select { |node| node.name == 'file' }
                .each { |node| bundle.add_file File.from_xml(node) }

      bundle
    end

    private

    def attach_xliff_metadata(node)
      node['xmlns'] = 'urn:oasis:names:tc:xliff:document:1.2'
      node['xmlns:xsi'] = 'http://www.w3.org/2001/XMLSchema-instance'
      node['version'] = '1.2'
      node['xsi:schemaLocation'] = 'urn:oasis:names:tc:xliff:document:1.2 http://docs.oasis-open.org/xliff/v1.2/os/xliff-core-1.2-strict.xsd'
    end
  end
end
