test:
	docker run -v $(shell pwd):/app -w /app public.ecr.aws/docker/library/ruby:2.7.4-bullseye /bin/bash -c "bundle install && bundle exec rspec"

lint:
	docker run -v $(shell pwd):/app -w /app public.ecr.aws/docker/library/ruby:2.7.4-bullseye /bin/bash -c "bundle install && bundle exec rubocop"

update-dependencies:
	docker run -v $(shell pwd):/app -w /app public.ecr.aws/docker/library/ruby:2.7.4-bullseye /bin/bash -c "bundle update"

bundle-check:
	docker run -v $(shell pwd):/app -w /app public.ecr.aws/docker/library/ruby:2.7.4-bullseye /bin/bash -c "bundle install && bundle check"

build:
	docker run -v $(shell pwd):/app -w /app public.ecr.aws/docker/library/ruby:2.7.4-bullseye /bin/bash -c "gem build xliff.gemspec"

