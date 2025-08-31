FROM instructure/ruby:3.3-jammy

USER root
RUN apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . .

RUN chown -R docker:docker /app
RUN chown -R docker:docker /usr/local

WORKDIR /app/arcana
USER docker

RUN bundle install

CMD ["tail", "-f", "/dev/null"]