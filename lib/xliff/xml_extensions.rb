# frozen_string_literal: true

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
      # @example Look up an existing file
      #   # To Generate <text>Hello World</text>:
      #   xml.add_leaf_node(element: 'text', content: 'Hello World')
      # @api private
      # @return [Void]
      def add_leaf_node(element:, content:)
        node = document.create_element(element)
        node.content = content
        add_child(node)
      end
    end
  end
end
