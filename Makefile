test:
	docker run -v $(shell pwd):/app -w /app public.ecr.aws/docker/library/ruby:2.7.4-bullseye /bin/bash -c "bundle install && bundle exec rspec"

update-dependencies:
	docker run -v $(shell pwd):/app -w /app public.ecr.aws/docker/library/ruby:2.7.4-bullseye /bin/bash -c "bundle update"

bundle-check:
		docker run -v $(shell pwd):/app -w /app public.ecr.aws/docker/library/ruby:2.7.4-bullseye /bin/bash -c "bundle install && bundle check"
