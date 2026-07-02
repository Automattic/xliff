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

    # Create a blank {Bundle} object, suitable for building an XLIFF file by hand
    #
    # @param [String] path An optional path to where the file should be stored on disk.
    # @param [String] schema_location The `xsi:schemaLocation` to declare. Defaults to XLIFF 1.2 transitional.
    # @example Create an empty XLIFF bundle
    #   bundle.new
    # @example Create an empty XLIFF bundle with a pre-specified path
    #   bundle.new(path: /path/to/my/output/file.xliff)
    def initialize(path: nil, schema_location: nil)
      @path = path
      @files = []
      @root_attributes = RootAttributes.default(schema_location)
    end

    # The `xsi:schemaLocation` declared on the `<xliff>` root
    #
    # Preserved from the source document when parsing, located by the prefix bound to the XML Schema instance
    # namespace (so a non-`xsi` prefix is read correctly), and defaulting to the XLIFF 1.2 transitional schema
    # for bundles built from scratch. `nil` when a parsed document declared none (it is optional in XLIFF 1.2).
    #
    # @return [String, nil]
    # @api public
    # @example Retrieve the schema location
    #   "bundle.schema_location" #=> "urn:oasis:names:tc:xliff:document:1.2 http://docs.oasis-open.org/..."
    def schema_location
      @root_attributes.schema_location
    end

    # Set the declared `xsi:schemaLocation`, defaulting a blank value
    #
    # An empty, whitespace-only, or `nil` value is normalised to the XLIFF 1.2 transitional default, because
    # `xsi:schemaLocation=""` is invalid output. See {Xliff.presence}.
    #
    # @param [String, nil] value The schema location to declare.
    # @return [void]
    # @example Reset to the default
    #   "bundle.schema_location = nil" #=> declares the XLIFF 1.2 transitional schema
    def schema_location=(value)
      @root_attributes.schema_location = value
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
    # @param [#to_s] name The name of the file to locate. Coerced to a stripped `String` to match how {File}
    #   stores its `original` (see {File#initialize}), mirroring {File#entry_with_id}, so a non-`String` name
    #   and incidental surrounding whitespace don't cause a miss. If found it is returned.
    # @example Look up an existing file
    #   # Bundle contains two files: [foo.txt, bar.txt]
    #   bundle.file_named('foo.txt') => {File}
    # @example Look up a non-existent file
    #   # Bundle contains two files: [foo.txt, bar.txt]
    #   bundle.file_named('baz.txt') => nil
    # @return [File, nil] The file, if found.
    def file_named(name)
      name = name.to_s.strip
      @files.find do |file|
        file.original == name || ::File.basename(file.original) == name
      end
    end

    # Encode this {Bundle} object as an XLIFF document
    #
    # The `<xliff>` root carries the preserved attribute set (its namespace declarations and attributes); a
    # parsed bundle keeps whatever its source declared, a from-scratch bundle the XLIFF 1.2 defaults. The set
    # is re-emitted in libxml2's canonical attribute order — semantically identical to the source and
    # byte-identical for an Xcode export, though a differently-ordered root is normalised on write (see
    # {RootAttributes}).
    #
    # @raise [RuntimeError] If the bundle has no files; XLIFF requires at least one `<file>`, so a file-less
    #   bundle has no valid serialization. (Reading a file-less `<xliff>` is still tolerated.)
    # @return [Nokogiri::XML::Document]
    def to_xml
      raise 'Cannot serialize a Bundle with no files – XLIFF requires at least one `<file>`' if @files.empty?

      document = Nokogiri::XML::Document.new
      document.encoding = 'UTF-8'

      xliff_node = document.create_element('xliff')
      @root_attributes.attach_to(xliff_node)

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
      xml = ::File.open(path) { |file| Nokogiri::XML(file) }
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
    # Raises for invalid input, including a document Nokogiri only produced by recovering from a fatal
    # well-formedness error (such a document is silently corrupted, so it is rejected rather than parsed).
    #
    # The `<xliff>` root's full attribute set — namespace declarations and attributes — is captured and
    # replayed on write, re-emitted in libxml2's canonical attribute order (see {RootAttributes}).
    #
    # @param [Nokogiri::XML::Element] xml A Nokogiri XML document containing XLIFF data.
    # @raise [RuntimeError] If `xml` is nil, has a non-`<xliff>` root, or carries a fatal parse error.
    # @return [Bundle]
    def self.from_xml(xml)
      raise 'Bundle XML is nil' if xml.nil?

      document = xml.document
      root = document.root
      raise 'Invalid XLIFF file – the root node must be `<xliff>`' if root.nil? || root.name != 'xliff'

      reject_malformed_document(document)

      bundle = new
      bundle.send(:root_attributes=, RootAttributes.capture(root))
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

    # Reject a document Nokogiri only produced by recovering from a malformed source
    #
    # Nokogiri parses in recovery mode by default: a fatal well-formedness error – a truncated tag, an
    # unescaped `&` – doesn't raise but yields a partial, silently corrupted tree, recording the problem in
    # `errors`. The `from_*` parsers promise to raise for invalid input, so surface the first such problem
    # instead of building a {Bundle} from the wreckage. Only `error`/`fatal` levels (a not-well-formed
    # document) are rejected; a warning is tolerated, so a clean document is never refused.
    #
    # @api private
    # @param [Nokogiri::XML::Document] document The parsed document to inspect.
    # @raise [RuntimeError] If the document carries an error- or fatal-level parse problem.
    # @return [void]
    private_class_method def self.reject_malformed_document(document)
      malformed = document.errors.find { |error| error.error? || error.fatal? }
      raise "Invalid XLIFF file – #{malformed.message.strip}" if malformed
    end

    private

    # Install a captured root attribute set, replacing the defaults
    #
    # Replaces the default attributes {#initialize} set up with those captured from a parsed document. Used by
    # {.from_xml}.
    #
    # @api private
    # @param [RootAttributes] root_attributes The captured attribute set.
    # @return [void]
    attr_writer :root_attributes
  end
end
