#!/usr/bin/env bash
set -euo pipefail

# Set SCOPEDB_DB_PASSWORD to the new role's password. Pass administrator
# connection options to psql, for example --host=db.example --username=postgres --password.
: "${SCOPEDB_DB_PASSWORD:?Set SCOPEDB_DB_PASSWORD for the scopedb role}"

exec psql -X --set=ON_ERROR_STOP=1 "$@" --dbname=postgres <<'SQL'
\getenv app_password SCOPEDB_DB_PASSWORD

SELECT format('CREATE USER scopedb WITH PASSWORD %L', :'app_password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'scopedb') \gexec

SELECT 'CREATE DATABASE scopedb_meta'
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'scopedb_meta') \gexec

GRANT ALL PRIVILEGES ON DATABASE scopedb_meta TO scopedb;
ALTER DATABASE scopedb_meta OWNER TO scopedb;

SELECT datname, pg_get_userbyid(datdba) AS owner
FROM pg_database
WHERE datname = 'scopedb_meta';
SQL
