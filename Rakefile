# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

abort 'Please run rake using `bundle exec`' unless %w[BUNDLE_BIN_PATH BUNDLE_GEMFILE].any? { |k| ENV.key?(k) }

RSpec::Core::RakeTask.new(:spec)

# Run only the XLIFF 1.2 schema-conformance examples – validation of serialized output against the vendored
# official OASIS XSDs (see spec/schemas). They also run as part of `spec`; this task runs them in isolation.
RSpec::Core::RakeTask.new(:conformance) do |task|
  task.rspec_opts = '--tag conformance'
end

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

# yardstick measures coverage; this catches structural doc mistakes it doesn't (e.g. an unknown @param name).
namespace :yard do
  desc 'Fail if YARD emits any documentation warnings'
  task :check do
    sh "yard doc 'lib/**/*.rb' --no-output --no-save --fail-on-warning"
  end
end

## Type Checking
namespace :rbs do
  desc 'Validate the RBS type signatures in sig/'
  task :validate do
    sh 'rbs -I sig validate'
  end
end

namespace :steep do
  desc 'Type-check lib/ against the RBS signatures with Steep'
  task :check do
    sh 'steep check'
  end
end
