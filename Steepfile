# frozen_string_literal: true

target :lib do
  signature 'sig'
  check 'lib'

  # The gem builds attribute hashes with `each_with_object({})`; the empty literal
  # can't be annotated without touching the implementation, so ignore the nag.
  configure_code_diagnostics do |hash|
    hash[Steep::Diagnostic::Ruby::UnannotatedEmptyCollection] = nil
  end
end
