# frozen_string_literal: true

require 'nokogiri'

module Xliff
  # The attribute set declared on an XLIFF document's `<xliff>` root element — its namespace declarations
  # (`xmlns`, `xmlns:xsi`, …) and ordinary attributes (`version`, `xsi:schemaLocation`, vendor extensions) —
  # captured as `[name, value]` pairs so the whole set round-trips, not just the subset the library models.
  # Namespace declarations are held under their literal `xmlns`/`xmlns:prefix` names, in the same list as
  # ordinary attributes.
  #
  # The set is re-emitted through Nokogiri's node API ({#attach_to}), so the output's attributes appear in
  # libxml2's canonical order rather than the source's. That is semantically identical to the source and
  # stable on re-round-trip; for an Xcode export — the library's target input — it is byte-identical too. A
  # root in a different shape (a non-`xsi` schema-instance prefix, a vendor attribute) is normalised to the
  # canonical order on first write and byte-stable thereafter, so the library doubles as an autoformatter for
  # a version-controlled localization pipeline.
  class RootAttributes
    # The XLIFF 1.2 namespace, bound to the default (`xmlns`) prefix on a from-scratch root.
    XLIFF_12_NAMESPACE = 'urn:oasis:names:tc:xliff:document:1.2'
    private_constant :XLIFF_12_NAMESPACE

    # The XLIFF version this library reads and writes. Required on every `<xliff>` root, so it is re-asserted
    # for a parsed root that omits it (see {.capture}).
    XLIFF_VERSION = '1.2'
    private_constant :XLIFF_VERSION

    # The default `xsi:schemaLocation` for bundles built from scratch: XLIFF 1.2 transitional, not strict,
    # because the library round-trips real-world content (e.g. Xcode's `<tool build-num>`) that only the
    # transitional schema accepts. A parsed bundle keeps whatever its source document declared instead.
    DEFAULT_SCHEMA_LOCATION = 'urn:oasis:names:tc:xliff:document:1.2 http://docs.oasis-open.org/xliff/v1.2/os/xliff-core-1.2-transitional.xsd'
    private_constant :DEFAULT_SCHEMA_LOCATION

    # The XML Schema instance namespace. Used to locate the `schemaLocation` declaration by namespace rather
    # than by a hard-coded `xsi:` prefix, so a document that binds it to a different prefix is still preserved.
    XSI_NAMESPACE = 'http://www.w3.org/2001/XMLSchema-instance'
    private_constant :XSI_NAMESPACE

    # The XLIFF 1.2 default root attributes for a bundle built from scratch
    #
    # A blank `schema_location` falls back to the transitional default (`xsi:schemaLocation=""` is invalid
    # output; see {Xliff.presence}). Emitted as the four standard declarations Xcode's exports carry.
    #
    # @param [String, nil] schema_location The `xsi:schemaLocation` value to declare.
    # @return [RootAttributes]
    # @example Build the defaults for a from-scratch bundle
    #   RootAttributes.default #=> the four standard XLIFF 1.2 declarations
    def self.default(schema_location = nil)
      new([
            ['xmlns', XLIFF_12_NAMESPACE],
            ['xmlns:xsi', XSI_NAMESPACE],
            ['version', XLIFF_VERSION],
            ['xsi:schemaLocation', Xliff.presence(schema_location) || DEFAULT_SCHEMA_LOCATION]
          ])
    end

    # Capture a parsed `<xliff>` root's attributes as `[name, value]` pairs
    #
    # Namespace declarations (as `xmlns`/`xmlns:prefix` names) come first, then ordinary attributes — the
    # order in which they are re-emitted. Values are taken from the parsed tree, already entity-decoded.
    #
    # `version` (which the schema marks `use="required"` on `<xliff>`) and a default `xmlns` for the XLIFF
    # namespace are re-asserted when the source omits them, so a root that would otherwise serialize as invalid
    # is healed rather than reproduced as-is (see {.reassert_required}). The schema requires the elements be
    # *in* the XLIFF namespace, not bound under any particular prefix; the *default* `xmlns` is this library's
    # constraint, since {Bundle#to_xml} emits unprefixed `<xliff>`/`<file>` elements that can only sit in the
    # namespace that way. A present-but-different value is left untouched (a non-XLIFF default namespace is the
    # separate concern tracked in #32).
    #
    # @param [Nokogiri::XML::Element] root The `<xliff>` root node.
    # @return [RootAttributes]
    # @example Capture a parsed root
    #   RootAttributes.capture(document.root)
    def self.capture(root)
      namespaces = root.namespace_definitions.map { |ns| [namespace_name(ns), ns.href] }
      attributes = root.attribute_nodes.map { |attr| [qualified_name(attr), attr.value] }

      new(reassert_required(namespaces + attributes))
    end

    # The declaration name of a namespace: `xmlns` for the default, `xmlns:prefix` otherwise
    #
    # @api private
    # @param [Nokogiri::XML::Namespace] namespace The parsed namespace definition.
    # @return [String]
    private_class_method def self.namespace_name(namespace)
      namespace.prefix ? "xmlns:#{namespace.prefix}" : 'xmlns'
    end

    # The serialized name of a parsed attribute node: `prefix:local`, or just `local` when unprefixed
    #
    # @api private
    # @param [Nokogiri::XML::Attr] attr The parsed attribute node.
    # @return [String]
    private_class_method def self.qualified_name(attr)
      attr.namespace&.prefix ? "#{attr.namespace.prefix}:#{attr.name}" : attr.name
    end

    # Re-assert the baseline a parsed `<xliff>` root needs to serialize as valid XLIFF, for any part it omits
    #
    # `version` is `use="required"` on `<xliff>` in the schema; the elements must also be in the XLIFF
    # namespace, which this library can only achieve through a default `xmlns` (it emits unprefixed
    # `<xliff>`/`<file>`). Both are added only when absent, so a parsed root missing either is healed instead
    # of faithfully reproduced as invalid. A value that is present — even a non-XLIFF default namespace (#32) —
    # is left exactly as captured.
    #
    # @api private
    # @param [Array<Array(String, String)>] pairs The captured `[name, value]` pairs.
    # @return [Array<Array(String, String)>]
    private_class_method def self.reassert_required(pairs)
      pairs = [['xmlns', XLIFF_12_NAMESPACE], *pairs] unless pairs.assoc('xmlns')
      pairs += [['version', XLIFF_VERSION]] unless pairs.assoc('version')
      pairs
    end

    # Wrap an ordered list of `[name, value]` attribute pairs
    #
    # @param [Array<Array(String, String)>] pairs The `[name, value]` attribute pairs.
    # @example Wrap an explicit set
    #   RootAttributes.new([['xmlns', 'urn:oasis:names:tc:xliff:document:1.2'], ['version', '1.2']])
    def initialize(pairs)
      @pairs = pairs
    end

    # The declared `xsi:schemaLocation` value, or `nil` when none is declared
    #
    # Located by the prefix bound to the XML Schema instance namespace, so a non-`xsi` prefix is honoured.
    #
    # @return [String, nil]
    # @example Read the declared schema location
    #   root_attributes.schema_location #=> "urn:oasis:names:tc:xliff:document:1.2 http://…/xliff-core-1.2-strict.xsd"
    def schema_location
      name = schema_location_attribute_name
      name && @pairs.assoc(name)&.last
    end

    # Set the declared `xsi:schemaLocation`, defaulting a blank value
    #
    # Updates the attribute in place so it keeps its position and prefix. A blank value is normalised to the
    # XLIFF 1.2 transitional default (`xsi:schemaLocation=""` is invalid output; see {Xliff.presence}). If no
    # schema-instance namespace is declared yet, one is added under the `xsi:` prefix.
    #
    # @param [String, nil] value The schema location to declare.
    # @return [void]
    # @example Reset to the default
    #   root_attributes.schema_location = nil
    def schema_location=(value)
      normalized = Xliff.presence(value) || DEFAULT_SCHEMA_LOCATION
      name = schema_location_attribute_name

      if name && (pair = @pairs.assoc(name))
        pair[1] = normalized
      elsif name
        @pairs << [name, normalized]
      else
        @pairs << ['xmlns:xsi', XSI_NAMESPACE] << ['xsi:schemaLocation', normalized]
      end
    end

    # Set each captured attribute on `node`
    #
    # Used to build the `<xliff>` element for {Bundle#to_xml}. Namespace declarations carried as literal
    # `xmlns`/`xmlns:prefix` names serialize as-is, so the element re-parses with the intended namespaces.
    #
    # @param [Nokogiri::XML::Element] node The `<xliff>` element being built.
    # @return [void]
    # @example Attach the set to a fresh root element
    #   root_attributes.attach_to(document.create_element('xliff'))
    def attach_to(node)
      @pairs.each { |name, value| node[name] = value }
    end

    private

    # The name under which `schemaLocation` is (or would be) declared, e.g. `xsi:schemaLocation`
    #
    # Derived from whichever prefix binds the XML Schema instance namespace. `nil` when it isn't declared.
    #
    # @api private
    # @return [String, nil]
    def schema_location_attribute_name
      declaration = @pairs.find { |name, value| name.start_with?('xmlns:') && value == XSI_NAMESPACE }
      declaration && "#{declaration.first.delete_prefix('xmlns:')}:schemaLocation"
    end
  end
end
