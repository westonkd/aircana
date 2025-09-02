FROM instructure/ruby:3.3-jammy

USER root
RUN apt-get update && apt-get install -y git fzf && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . .

RUN chown -R docker:docker /app
RUN chown -R docker:docker /usr/local

USER docker

RUN bundle install

CMD ["tail", "-f", "/dev/null"]