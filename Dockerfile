FROM elixir:1.12-alpine

ENV MIX_ENV=prod

COPY .git .git
COPY lib lib
COPY config config

COPY mix.exs .
COPY mix.lock .

RUN apk add openssl git openssh

RUN mix local.rebar --force \
    && mix local.hex --force \
    && mix deps.get

ENTRYPOINT [ "sh", "-c", "elixir --name gateway@${POD_IP} --cookie gm --no-halt -S mix" ]