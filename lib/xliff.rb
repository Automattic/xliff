# frozen_string_literal: true

# Namespace for classes and modules that handle building and parsing XLIFF files.
# @api public
module Xliff
  # Whether `value` is blank – `nil`, empty, or whitespace-only once coerced to a `String`.
  #
  # The single definition of "blank" shared across the library so the rule is applied uniformly: a required
  # attribute (`<file>`'s `original`/`source-language`, an {Entry}'s `id`) is rejected when blank, and an
  # optional, defaultable one (`xml:space`, `datatype`, `target-language`, `xsi:schemaLocation`) falls back to
  # its default. Whitespace-only counts as blank, so a value like `"   "` can't slip through as a schema-invalid
  # `source-language="   "` / `target-language="   "`.
  #
  # @api private
  # @param [String, nil] value The value to test.
  # @return [Boolean] `true` when `value` is `nil`, empty, or whitespace-only.
  # @example Detect a whitespace-only value
  #   Xliff.blank?('   ') #=> true
  def self.blank?(value)
    value.to_s.strip.empty?
  end

  # Return `value` unless it is blank, in which case return `nil`.
  #
  # The counterpart to {.blank?} for the optional, defaultable attributes, so a caller reads as
  # `Xliff.presence(value) || default`. See {.blank?} for the definition of blank.
  #
  # @api private
  # @param [String, nil] value The value to coerce.
  # @return [String, nil] `value` when present, or `nil` when it is blank.
  # @example Fall back to a default for a blank value
  #   Xliff.presence('   ') || 'default' #=> "default"
  def self.presence(value)
    blank?(value) ? nil : value
  end
end

require_relative 'xliff/bundle'
require_relative 'xliff/entry'
require_relative 'xliff/file'
require_relative 'xliff/header'
require_relative 'xliff/xml_extensions'
