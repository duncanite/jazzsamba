#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]:-$PWD}")" 2>/dev/null 1>&2 && pwd)/../"
readonly root

# shellcheck source=/dev/null
BIN_LOCATION="${BIN_LOCATION:-$root/cache/bin}" . "$root/hack/helpers/install-tools.sh"

# DL4006 is about setting pipefail (which we do, in our base SHELL)
if ! godolint --ignore DL4006 "$root"/*Dockerfile*; then
  printf >&2 "Failed linting on Dockerfile\n"
  exit 1
fi

while read -r line; do
  shellcheck "$line"
done < <(find "$root" -iname "*.sh" -not -path "*debuerreotype*" -not -path "*cache*" -not -path "*xxx*" 2>/dev/null || true)
