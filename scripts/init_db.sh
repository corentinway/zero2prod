#!/usr/bin/env bash
set -x
set -eo pipefail

if ! [ -x "$(command -v psql)" ]; then
  echo >&2 "Error psql not installed"
  exit 1
fi

if ! [ -x "$(command -v sqlx)" ]; then
  echo >&2 "Error sqlx not installed"
  echo >&2 "Use : "
  echo >&2 "    cargo install --version="~0.7" sqlx-cli --no-default-features --features rustls,postgres"
  echo >&2 "To install it"
  exit 1
fi


# check if a custom user has been set, otherwise default to 'postgres'
DB_USER=${POSTGRES_USER:=postgres}
# check if a custom password has been set, otherwise default to 'password'
DB_PASSWORD=${POSTGRES_PASSWORD:=password}
# check if a custom database name has been set, otherwise default to 'newsletter'
DB_NAME=${POSTGRES_DB:=newsletter}
DB_PORT=${POSTGRES_PORT:=5432}
DB_HOST=${POSTGRES_HOST:=localhost}

# launch docker
if [[ -z "${SKIP_DOCKER}" ]]
then
  docker run \
    -e POSTGRES_USER=${DB_USER} \
    -e POSTGRES_PASSWORD=${DB_PASSWORD} \
    -e POSTGRES_DB=${DB_NAME} \
    -p "${DB_PORT}":5432 \
    -d postgres \
    postgres -N 1000
fi

export PGPASSWORD=${DB_PASSWORD}
until psql -h "${DB_HOST}" -U "${DB_USER}" -p "${DB_PORT}" -d "postgres" -c '\q'
do
  >&2 echo "Postgres is still unavailable"
  sleep 1
done

>&2 echo "Postgress is up and running on port ${DB_PORT}!"

DATABASE_URL=postgres://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}
export DATABASE_URL
sqlx database create
sqlx migrate run

>&2 echo "Postgress has been migrated, ready to go!"
