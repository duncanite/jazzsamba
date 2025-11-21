#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]:-$PWD}")" 2>/dev/null 1>&2 && pwd)"
readonly root
# shellcheck source=/dev/null
. "$root/helpers.sh"
# shellcheck source=/dev/null
. "$root/mdns.sh"

helpers::logger::set "$LOG_LEVEL"

helpers::logger::log INFO "[entrypoint]" "🎬 Starting container"

helpers::logger::log INFO "[entrypoint]" "🔐 Checking permissions"

# Necessary for user accounts creation - and a royal PITA
helpers::dir::writable /etc

# Homes, shares, time machine
helpers::dir::writable "$XDG_DATA_HOME"/samba/home create
helpers::dir::writable "$XDG_DATA_HOME"/samba/share create
helpers::dir::writable "$XDG_DATA_HOME"/samba/timemachine create

# Add sticky bit
chmod g+srwx "$XDG_DATA_HOME"/samba/home
chmod g+srwx "$XDG_DATA_HOME"/samba/share
chmod g+srwx "$XDG_DATA_HOME"/samba/timemachine

# Internal folders for samba
helpers::dir::writable "$XDG_DATA_HOME"/samba/private create
helpers::dir::writable "$XDG_RUNTIME_DIR"/samba/lock create
helpers::dir::writable "$XDG_RUNTIME_DIR"/samba/pid create
helpers::dir::writable "$XDG_RUNTIME_DIR"/samba/rpc create
helpers::dir::writable "$XDG_CACHE_HOME"/samba/cache create
helpers::dir::writable "$XDG_STATE_HOME"/samba/state create
helpers::dir::writable "$XDG_STATE_HOME"/samba/cores create

# helper to create user accounts
helpers::createUser(){
  local login="$1"
  local password="$2"
  useradd -m -d "$XDG_DATA_HOME/samba/home/$login" -g smb-share -s /usr/sbin/nologin "$login" 2>/dev/null || {
    helpers::logger::log WARNING "⚠️ Failed creating user $login. Possibly it already exists."
  }

  # Ensure the user timemachine folder is there, owned by them
  helpers::dir::writable "$XDG_DATA_HOME/samba/timemachine/$login" create
  chown "$login:root" "$XDG_DATA_HOME/samba/timemachine/$login"

  printf "%s:%s" "$login" "$password" | chpasswd
  printf "%s\n%s\n" "$password" "$password" | smbpasswd -c "$XDG_CONFIG_DIRS"/samba/main.conf -a "$login" >/dev/null
}

helpers::logger::log INFO "[entrypoint]" "👥 Creating users"

# shellcheck disable=SC2206
USERS=($USERS)
# shellcheck disable=SC2206
PASSWORDS=($PASSWORDS)

for ((index=0; index<${#USERS[@]}; index++)); do
  helpers::createUser "${USERS[$index]}" "${PASSWORDS[$index]}"
done

# https://jonathanmumm.com/tech-it/mdns-bonjour-bible-common-service-strings-for-various-vendors/
# https://piware.de/2012/10/running-a-samba-server-as-normal-user-for-testing/
# Model controls the icon in the finder: RackMac - https://simonwheatley.co.uk/2008/04/avahi-finder-icons/

# Convert log level to samba lingo
ll=0
case "${LOG_LEVEL:-warning}" in
  "debug")
    ll=3
  ;;
  "info")
    ll=2
  ;;
  "warn")
    ll=1
  ;;
  "warning")
    ll=1
  ;;
  "error")
    ll=0
  ;;
esac

helpers::logger::log INFO "[entrypoint]" "📡 Starting mDNS"

helpers::logger::log INFO "[entrypoint]" "🚀 Starting Samba"

exec > >(helpers::logger::slurp "$LOG_LEVEL" "[samba]")
exec 2> >(helpers::logger::slurp ERROR "[samba]")

# mDNS
[ "${MOD_MDNS_ENABLED:-}" != true ] || {
  [ "${ADVANCED_MOD_MDNS_STATION:-}" != true ] || mdns::records::add "_workstation._tcp" "${MOD_MDNS_HOST}" "${MOD_MDNS_NAME:-}" "$_SERVICE_PORT"
  mdns::records::add "_smb._tcp" "${MOD_MDNS_HOST:-}" "${MOD_MDNS_NAME:-}" "$_SERVICE_PORT"
  # XXX fix goello
  # device info and adisk are not service, but informational. Port 0 is thus correct.
  mdns::records::add "_device-info._tcp"       "${MOD_MDNS_HOST:-}" "${MOD_MDNS_NAME:-}" "$_SERVICE_PORT" '["model='"${MODEL:-MacPro6,1}"'"]'
  mdns::records::add "_adisk._tcp"             "${MOD_MDNS_HOST:-}" "${MOD_MDNS_NAME:-}" "$_SERVICE_PORT" '["sys=waMa=0,adVF=0x100", "dk0=adVN=timemachine,adVF=0x82"]'
  mdns::start::broadcaster
}

exec smbd -F --debug-stdout -d="$ll" --no-process-group --configfile="$XDG_CONFIG_DIRS"/samba/main.conf "$@"
