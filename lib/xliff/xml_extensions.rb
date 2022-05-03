# frozen_string_literal: true

module Nokogiri
  module XML
    # Helpers to simplify working with Nokogiri
    class Element
      def add_leaf_node(element:, content:)
        node = document.create_element(element)
        node.content = content
        add_child(node)
      end
    end
  end
end
