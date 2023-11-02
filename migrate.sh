#!/bin/bash

sleep 2

set -o pipefail

export TERM=ansi
_GREEN=$(tput setaf 2)
_BLUE=$(tput setaf 4)
_MAGENTA=$(tput setaf 5)
_CYAN=$(tput setaf 6)
_RED=$(tput setaf 1)
_YELLOW=$(tput setaf 3)
_RESET=$(tput sgr0)
_BOLD=$(tput bold)

# Function to print error messages and exit
error_exit() {
    printf "[ ${_RED}ERROR${_RESET} ] ${_RED}$1${_RESET}\n" >&2
    exit 1
}

section() {
  printf "${_RESET}\n"
  echo "${_BOLD}${_BLUE}==== $1 ====${_RESET}"
}

write_ok() {
  echo "[$_GREEN OK $_RESET] $1"
}

write_warn() {
  echo "[$_YELLOW WARN $_RESET] $1"
}

trap 'echo "An error occurred. Exiting..."; exit 1;' ERR

printf "${_BOLD}${_MAGENTA}"
echo "+-------------------------------------+"
echo "|                                     |"
echo "|  Railway Postgres Migration Script  |"
echo "|                                     |"
echo "+-------------------------------------+"
printf "${_RESET}\n"

echo "For more information, see https://docs.railway.app/database/migration"
echo "If you run into any issues, please reach out to us on Discord: https://discord.gg/railway"
printf "${_RESET}\n"

section "Validating environment variables"

# Parse components using a tool like 'sed' or 'awk'
PLUGIN_USER=$(echo $PLUGIN_URL | sed -e 's/mysql:\/\/\(.*\):.*@.*/\1/')
PLUGIN_PASSWORD=$(echo $PLUGIN_URL | sed -e 's/mysql:\/\/.*:\(.*\)@.*/\1/')
PLUGIN_HOST=$(echo $PLUGIN_URL | sed -e 's/mysql:\/\/.*@\(.*\):.*/\1/')
PLUGIN_PORT=$(echo $PLUGIN_URL | sed -e 's/mysql:\/\/.*@.*:\(.*\)\/.*/\1/')
PLUGIN_DB=$(echo $PLUGIN_URL | sed -e 's/mysql:\/\/.*@.*\/\(.*\)/\1/')

NEW_USER=$(echo $NEW_URL | sed -e 's/mysql:\/\/\(.*\):.*@.*/\1/')
NEW_PASSWORD=$(echo $NEW_URL | sed -e 's/mysql:\/\/.*:\(.*\)@.*/\1/')
NEW_HOST=$(echo $NEW_URL | sed -e 's/mysql:\/\/.*@\(.*\):.*/\1/')
NEW_PORT=$(echo $NEW_URL | sed -e 's/mysql:\/\/.*@.*:\(.*\)\/.*/\1/')
NEW_DB=$(echo $NEW_URL | sed -e 's/mysql:\/\/.*@.*\/\(.*\)/\1/')

# Validate that PLUGIN_URL environment variable exists
if [ -z "$PLUGIN_URL" ]; then
    error_exit "PLUGIN_URL environment variable is not set."
fi

write_ok "PLUGIN_URL correctly set"

# Validate that NEW_URL environment variable exists
if [ -z "$NEW_URL" ]; then
    error_exit "NEW_URL environment variable is not set."
fi

write_ok "NEW_URL correctly set"

section "Checking if NEW_URL is empty"

tables=$(mysql --silent --skip-column-names -h"$NEW_HOST" -u"$NEW_USER" -p"$NEW_PASSWORD" --port "$NEW_PORT" -e "SHOW TABLES FROM $NEW_DB")

echo "tables=$tables"

if [[ -z "$tables" ]]; then
  if [ -z "$OVERWRITE_DATABASE" ]; then
    write_ok "The new database is empty. Proceeding with restore."
  fi
else
  if [ -z "$OVERWRITE_DATABASE" ]; then
    error_exit "The new database is not empty. Aborting migration.\nSet the OVERWRITE_DATABASE environment variable to overwrite the new database."
  fi
  write_warn "The new database is not empty. Found OVERWRITE_DATABASE environment variable. Proceeding with restore."
fi

section "Dumping database from PLUGIN_URL" 

dump_file="plugin_dump.sql"
mysqldump -u $PLUGIN_USER -p$PLUGIN_PASSWORD -h $PLUGIN_HOST -P $PLUGIN_PORT $PLUGIN_DB > $dump_file

write_ok "Successfully saved dump to $dump_file"

dump_file_size=$(ls -lh "$dump_file" | awk '{print $5}')
echo "Dump file size: $dump_file_size"

section "Restoring database to NEW_URL"

# Restore that data to the new database
mysql --silent --skip-column-names -h"$NEW_HOST" -u"$NEW_USER" -p"$NEW_PASSWORD" --port "$NEW_PORT" "$NEW_DB" < $dump_file

write_ok "Successfully restored database to NEW_URL"

printf "${_RESET}\n"
printf "${_RESET}\n"
echo "${_BOLD}${_GREEN}Migration completed successfully${_RESET}"
printf "${_RESET}\n"
echo "Next steps..."
echo "1. Update your application's DATABASE_URL environment variable to point to the new database."
echo '  - You can use variable references to do this. For example `${{ MySQL.DATABASE_URL }}`'
echo "2. Verify that your application is working as expected."
echo "3. Remove the legacy plugin and this service from your Railway project."

printf "${_RESET}\n"
