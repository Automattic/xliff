# frozen_string_literal: true

# Namespace for classes and modules that handle building and parsing XLIFF files.
# @api public
module Xliff
  # Return `value` unless it is blank – empty or whitespace-only – in which case return `nil`.
  #
  # Centralises the "a blank value falls back to the default" rule shared by the optional, defaultable
  # attributes – `xml:space`, `datatype`, `target-language`, and `xsi:schemaLocation` – so a caller reads
  # as `Xliff.presence(value) || default`. Whitespace-only counts as blank (matching {Xliff::Entry#id=}), so
  # it can't slip through as an invalid `xml:space="   "` / `target-language="   "` / `xsi:schemaLocation="   "`.
  #
  # @api private
  # @param [String, nil] value The value to coerce.
  # @return [String, nil] `value` when present, or `nil` when it is blank.
  # @example Fall back to a default for a blank value
  #   Xliff.presence('   ') || 'default' #=> "default"
  def self.presence(value)
    value.to_s.strip.empty? ? nil : value
  end
end

require_relative 'xliff/bundle'
require_relative 'xliff/entry'
require_relative 'xliff/file'
require_relative 'xliff/header'
require_relative 'xliff/xml_extensions'
