# frozen_string_literal: true

require 'nokogiri'

module Xliff
  # Models a collection of files for translation
  class Bundle
    # An array of translated files in this bundle
    # @return [Array<File>]
    # @api public
    # @example Retrieve the bundle's files
    #   "bundle.files" #=> [{File}]
    attr_reader :files

    # The path on disk that this bundle was read from
    # @!attribute [rw] path
    # @return [String]
    # @api public
    # @example Retrieve the bundle path
    #   "bundle.path" #=> /tmp/foo.xliff
    attr_accessor :path

    # The `xsi:schemaLocation` declared on the `<xliff>` root
    #
    # Preserved from the source document when parsing (an absent or empty declaration falls back to the
    # default), and defaulting to the XLIFF 1.2 transitional schema for bundles built from scratch.
    # @!attribute [rw] schema_location
    # @return [String]
    # @api public
    # @example Retrieve the schema location
    #   "bundle.schema_location" #=> "urn:oasis:names:tc:xliff:document:1.2 http://docs.oasis-open.org/..."
    attr_reader :schema_location

    # The default `xsi:schemaLocation` for bundles built from scratch: XLIFF 1.2 transitional, not strict,
    # because the library round-trips real-world content (e.g. Xcode's `<tool build-num>`) that only the
    # transitional schema accepts. A parsed bundle keeps whatever its source document declared instead.
    DEFAULT_SCHEMA_LOCATION = 'urn:oasis:names:tc:xliff:document:1.2 http://docs.oasis-open.org/xliff/v1.2/os/xliff-core-1.2-transitional.xsd'
    private_constant :DEFAULT_SCHEMA_LOCATION

    # The XML Schema instance namespace. Used to locate the `schemaLocation` declaration by namespace rather
    # than by a hard-coded `xsi:` prefix, so a document that binds it to a different prefix is still preserved.
    XSI_NAMESPACE = 'http://www.w3.org/2001/XMLSchema-instance'
    private_constant :XSI_NAMESPACE

    # Create a blank {Bundle} object, suitable for building an XLIFF file by hand
    #
    # @param [String] path An optional path to where the file should be stored on disk.
    # @param [String] schema_location The `xsi:schemaLocation` to declare. Defaults to XLIFF 1.2 transitional.
    # @example Create an empty XLIFF bundle
    #   bundle.new
    # @example Create an empty XLIFF bundle with a pre-specified path
    #   bundle.new(path: /path/to/my/output/file.xliff)
    def initialize(path: nil, schema_location: DEFAULT_SCHEMA_LOCATION)
      @path = path
      self.schema_location = schema_location
      @files = []
    end

    # Set the declared `xsi:schemaLocation`, defaulting a blank value
    #
    # An empty or `nil` value is normalised to the XLIFF 1.2 transitional default, because
    # `xsi:schemaLocation=""` is invalid output.
    #
    # @param [String, nil] value The schema location to declare.
    # @return [void]
    # @example Reset to the default
    #   "bundle.schema_location = nil" #=> declares the XLIFF 1.2 transitional schema
    def schema_location=(value)
      @schema_location = value.to_s.empty? ? DEFAULT_SCHEMA_LOCATION : value
    end

    # Add an additional {File} object to the bundle
    #
    # @param [File] file The file to be stored in the bundle.
    # @example Add a new file to the bundle
    #   file = File.new(...)
    #   bundle.add_file(file)
    # @return [void]
    def add_file(file)
      @files << file
    end

    # Find a given file by name
    #
    # If two files exist with the same name, only the first will be returned.
    #
    # @param [String] name The name of the file to locate. If found it is returned.
    # @example Look up an existing file
    #   # Bundle contains two files: [foo.txt, bar.txt]
    #   bundle.file_named('foo.txt') => {File}
    # @example Look up a non-existent file
    #   # Bundle contains two files: [foo.txt, bar.txt]
    #   bundle.file_named('baz.txt') => nil
    # @return [File, nil] The file, if found.
    def file_named(name)
      @files.find do |file|
        file.original == name || ::File.basename(file.original) == name
      end
    end

    # Encode this {Bundle} object as an XLIFF document
    #
    # @raise [RuntimeError] If the bundle has no files; XLIFF requires at least one `<file>`, so a file-less
    #   bundle has no valid serialization. (Reading a file-less `<xliff>` is still tolerated.)
    # @return [Nokogiri::XML::Document]
    def to_xml
      raise 'Cannot serialize a Bundle with no files – XLIFF requires at least one `<file>`' if @files.empty?

      document = Nokogiri::XML::Document.new
      document.encoding = 'UTF-8'

      xliff_node = document.create_element('xliff')
      attach_xliff_metadata(xliff_node)

      @files.each do |file|
        xliff_node.add_child(file.to_xml)
      end

      document.add_child(xliff_node)

      document
    end

    # Encode this {Bundle} object as an XLIFF document string
    #
    # @return [String]
    def to_s
      to_xml.to_s.strip
    end

    # Parse the XLIFF file at the given `path` as an XLIFF {Bundle} object
    #
    # Raises for invalid input
    #
    # @param [String] path The path to an `xliff` file.
    # @return [Bundle]
    def self.from_path(path)
      xml = Nokogiri::XML(::File.open(path))
      bundle = from_xml(xml)
      bundle.path = path

      bundle
    end

    # Parse the XLIFF file stored in the given `string` as an XLIFF {Bundle} object
    #
    # Raises for invalid input
    #
    # @param [String] string A string containing XLIFF data.
    # @return [Xliff::Bundle]
    def self.from_string(string)
      xml = Nokogiri::XML(string)
      from_xml(xml)
    end

    # Parse the Nokogiri XML representation of an XLIFF file to a {Bundle} object
    #
    # Raises for invalid input
    #
    # @param [Nokogiri::XML::Element] xml A Nokogiri XML document containing XLIFF data.
    # @return [Bundle]
    def self.from_xml(xml)
      raise if xml.nil?

      root = xml.document.root
      raise 'Invalid XLIFF file – the root node must be `<xliff>`' if root.nil? || root.name != 'xliff'

      declared_schema = root.attribute_with_ns('schemaLocation', XSI_NAMESPACE)&.value
      bundle = Bundle.new(schema_location: declared_schema)
      import_files(root, bundle)

      bundle
    end

    # Parse each `<file>` child of the `<xliff>` root into the bundle, skipping any other elements.
    #
    # @api private
    # @param [Nokogiri::XML::Element] root The `<xliff>` root node.
    # @param [Bundle] bundle The {Bundle} being built.
    # @return [void]
    private_class_method def self.import_files(root, bundle)
      root.child_elements('file').each { |node| bundle.add_file File.from_xml(node) }
    end

    private

    # Attach the required XLIFF metadata to the given `node`
    #
    # Currently only supports XLIFF 1.2.
    # @api private
    # @return [void]
    def attach_xliff_metadata(node)
      node['xmlns'] = 'urn:oasis:names:tc:xliff:document:1.2'
      node['xmlns:xsi'] = XSI_NAMESPACE
      node['version'] = '1.2'
      node['xsi:schemaLocation'] = @schema_location
    end
  end
end
