# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

abort 'Please run rake using `bundle exec`' unless %w[BUNDLE_BIN_PATH BUNDLE_GEMFILE].any? { |k| ENV.key?(k) }

RSpec::Core::RakeTask.new(:spec)

require 'rubocop/rake_task'

RuboCop::RakeTask.new

task default: %i[rubocop:auto_correct spec]
