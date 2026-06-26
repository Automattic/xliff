# frozen_string_literal: true

require 'nokogiri'

# Extensions of the Nokogiri gem for use with this project.
module Nokogiri
  # Customizations to the Nokogiri XML namespace.
  module XML
    # Helpers for operating on XML Elements
    class Element
      # Adds a simple Text Node as a child element
      #
      # @param [String] element The XML tag name to use.
      # @param [String] content The text contents of the XML tag.
      # @example Generate `<text>Hello World</text>` as a child node
      #   xml.add_leaf_node(element: 'text', content: 'Hello World')
      # @api private
      # @return [Void]
      def add_leaf_node(element:, content:)
        node = document.create_element(element)
        node.content = content
        add_child(node)
      end

      # The first direct child element with the given (local) name, or `nil`
      #
      # Matches by local name and considers only direct children — unlike `at`/`css`, which descend the whole
      # subtree — so a nested element (e.g. an `<alt-trans>`'s `<target>`, or a `<body>` inside a header
      # skeleton) can't be mistaken for a direct child of this element.
      #
      # @param [String] name The local element name to find.
      # @example Read a `<trans-unit>`'s own `<source>`
      #   trans_unit.child_element('source')
      # @api private
      # @return [Nokogiri::XML::Element, nil]
      def child_element(name)
        element_children.find { |node| node.name == name }
      end

      # All direct child elements with the given (local) name
      #
      # The `select`-all counterpart to {#child_element}: matches by local name and considers only direct
      # children, never descendants.
      #
      # @param [String] name The local element name to find.
      # @example Collect the `<file>` children of an `<xliff>` root
      #   root.child_elements('file')
      # @api private
      # @return [Array<Nokogiri::XML::Element>]
      def child_elements(name)
        element_children.select { |node| node.name == name }
      end

      # A deep copy of this element re-homed into a fresh, standalone document
      #
      # Unlike `dup` – which keeps the copy associated with this element's source document – this re-homes the
      # copy into a throwaway document, so holding on to the copy (e.g. in {Xliff::File#unparsed_body_nodes})
      # doesn't keep the entire source document reachable for the copy's lifetime.
      #
      # @example Detach a parsed node from its source document
      #   node.detached_copy
      # @api private
      # @return [Nokogiri::XML::Element]
      def detached_copy
        dup(1, Document.new)
      end
    end
  end
end
