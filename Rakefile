# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

abort 'Please run rake using `bundle exec`' unless %w[BUNDLE_BIN_PATH BUNDLE_GEMFILE].any? { |k| ENV.key?(k) }

RSpec::Core::RakeTask.new(:spec)

require 'rubocop/rake_task'

RuboCop::RakeTask.new

task default: %i[rubocop:auto_correct spec]

## Documentation Coverage
require 'yardstick/rake/measurement'
require 'yardstick/rake/verify'

Yardstick::Rake::Measurement.new(:yardstick_measure) do |measurement|
  measurement.output = 'coverage/yard-coverage.txt'
end

Yardstick::Rake::Verify.new do |verify|
  # Treat the threshold as a floor: fail only when documentation coverage drops below it, not when it rises
  # above it (which would otherwise turn every documentation improvement into a CI failure).
  verify.threshold = 92.0
  verify.require_exact_threshold = false
end
