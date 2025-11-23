#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

# helpers::dir::writable checks if a certain directory exists and is writable, optionally trying to create it
helpers::dir::writable(){
  local path="$1"
  local create="${2:-}"
  # shellcheck disable=SC2015
  ( [ ! "$create" ] || mkdir -p "$path" 2>/dev/null ) && [ -w "$path" ] && [ -d "$path" ] || {
    helpers::logger::log ERROR "sanity" "$path does not exist, is not writable, or cannot be created. Check your mount permissions."
    exit 1
  }
}

# helpers::emergency will kill PID 1 and exit. Should be used to capture sidecar process failing.
helpers::emergency() {
  local process="$1"
  shift
  helpers::logger::log ERROR "🚨 CRITICAL" "$process failed: $*"
  kill -s TERM 1
  exec sleep infinity
}

# shellcheck disable=SC2034
readonly DC_COLOR_BLACK=0
# shellcheck disable=SC2034
readonly DC_COLOR_RED=1
# shellcheck disable=SC2034
readonly DC_COLOR_GREEN=2
# shellcheck disable=SC2034
readonly DC_COLOR_YELLOW=3
# shellcheck disable=SC2034
readonly DC_COLOR_BLUE=4
# shellcheck disable=SC2034
readonly DC_COLOR_MAGENTA=5
# shellcheck disable=SC2034
readonly DC_COLOR_CYAN=6
# shellcheck disable=SC2034
readonly DC_COLOR_WHITE=7
# shellcheck disable=SC2034
readonly DC_COLOR_DEFAULT=9

# shellcheck disable=SC2034
readonly DC_LOGGER_DEBUG=4
# shellcheck disable=SC2034
readonly DC_LOGGER_INFO=3
# shellcheck disable=SC2034
readonly DC_LOGGER_WARNING=2
# shellcheck disable=SC2034
readonly DC_LOGGER_ERROR=1

# shellcheck disable=SC2034
DC_LOGGER_STYLE_DEBUG=( setaf "$DC_COLOR_WHITE" )
# shellcheck disable=SC2034
DC_LOGGER_STYLE_INFO=( setaf "$DC_COLOR_GREEN" )
# shellcheck disable=SC2034
DC_LOGGER_STYLE_WARNING=( setaf "$DC_COLOR_YELLOW" )
# shellcheck disable=SC2034
DC_LOGGER_STYLE_ERROR=( setaf "$DC_COLOR_RED" )

_DC_PRIVATE_LOGGER_LEVEL="$DC_LOGGER_WARNING"

helpers::logger::set() {
  local level
  level="$(printf "%s" "${!1:-}" | tr '[:lower:]' '[:upper:]')"
  case "$level" in
  DEBUG|INFO|ERROR|WARNING) ;;
  *)
    helpers::logger::log WARNING "logger" "Unrecognized log level '${!1:-}', defaulting to warning"
    level="WARNING"
  ;;
  esac

  local desired="DC_LOGGER_$level"
  _DC_PRIVATE_LOGGER_LEVEL="${!desired}"
  export "$1=$(printf "%s\n" "$level" | tr '[:upper:]' '[:lower:]')"
}

helpers::logger::log(){
  local severity="$1"
  local module="$2"
  shift
  shift

  local level="DC_LOGGER_$severity"
  local style="DC_LOGGER_STYLE_${severity}[@]"

  [ "$_DC_PRIVATE_LOGGER_LEVEL" -ge "${!level}" ] || return 0

  # If you wonder about why that crazy shit: https://stackoverflow.com/questions/12674783/bash-double-process-substitution-gives-bad-file-descriptor
  exec 3>&2
  [ ! "$TERM" ] || [ ! -t 2 ] || >&2 tput "${!style}" 2>/dev/null || true
  >&2 printf "[%s] [%s] [%s] %s\n" "$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || true)" "$severity" "$module" "$*"
  [ ! "$TERM" ] || [ ! -t 2 ] || >&2 tput op 2>/dev/null || true
  exec 3>&-
}

# helpers::logger::slurp will slurp up input from stdin and reoutput as formatted logs
helpers::logger::slurp(){
  local level
  level="$(printf "%s" "${1:-warning}" |  tr '[:lower:]' '[:upper:]')"
  shift
  while read -r line; do
    helpers::logger::log "$level" "$@" "$line";
  done
}

# helpers::logger::ingest will wait for a certain file to show up then slurp it up
helpers::logger::ingest() {
  local level="$1"
  local module="$2"
  local fd="$3"
  tail -F "$fd" 2>/dev/null | sed -u 's/\[[^]]*\] //' | helpers::logger::slurp "$level" "$module"
}
