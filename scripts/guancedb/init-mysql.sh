#!/usr/bin/env bash
set -euo pipefail

# Set GUANCE_META_DB_PASSWORD to the new account's password. Pass administrator
# connection options to mysql, for example --host=db.example --user=root --password.
: "${GUANCE_META_DB_PASSWORD:?Set GUANCE_META_DB_PASSWORD for the guance_meta account}"

# In NO_BACKSLASH_ESCAPES mode, double single quotes to quote the password as a SQL literal.
password=${GUANCE_META_DB_PASSWORD//\'/\'\'}

{
  cat <<'SQL'
SET SESSION sql_mode = 'NO_BACKSLASH_ESCAPES';

CREATE DATABASE IF NOT EXISTS `guance_meta`
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;
SQL

  printf "CREATE USER IF NOT EXISTS 'guance_meta'@'%%' IDENTIFIED BY '%s';\n" "$password"

  cat <<'SQL'
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, DROP, INDEX
ON `guance_meta`.* TO 'guance_meta'@'%';

FLUSH PRIVILEGES;
SHOW GRANTS FOR 'guance_meta'@'%';
SQL
} | mysql "$@" --batch --binary-mode --default-character-set=utf8mb4
