FROM instructure/ruby:3.3-jammy

USER root
RUN apt-get update && apt-get install -y git fzf && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . .

RUN chown -R docker:docker /app

USER docker

# Install gems to a path owned by docker user
RUN bundle config set --local path '/app/vendor/bundle'
RUN bundle install

CMD ["tail", "-f", "/dev/null"]