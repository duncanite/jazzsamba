#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

export SUITE=trixie
export DATE=2025-11-01

export BIN_LOCATION="${BIN_LOCATION:-$HOME/bin}"
export PATH="$BIN_LOCATION:$PATH"
readonly IMAGE_TOOLS="${IMAGE_TOOLS:-dubodubonduponey/tools:$(uname -s | grep -q Darwin && printf "macos" || printf "linux-dev")-$SUITE-$DATE}"

export SHELLCHECK_VERSION=0.10.0

setup::tools(){
  local location="$1"

  if  ! command -v "godolint" > /dev/null; then
    go install github.com/farcloser/godolint/cmd/godolint@v0.1.0
  fi

  if  command -v "$location/cue" > /dev/null &&
      command -v "$location/buildctl" > /dev/null &&
      command -v "$location/docker" > /dev/null &&
      command -v "$location/shellcheck" > /dev/null; then
    return
  fi

  mkdir -p "$location"
  docker rm -f dubo-tools >/dev/null 2>&1 || true
  docker run -d --pull always --name dubo-tools --entrypoint sleep "$IMAGE_TOOLS" inf > /dev/null
  docker cp dubo-tools:/magnetar/bin/cue "$location"
  docker cp dubo-tools:/magnetar/bin/buildctl "$location"
  docker rm -f dubo-tools >/dev/null 2>&1

  curl --proto '=https' --tlsv1.2 -sSfL -o shellcheck.tar.xz "https://github.com/koalaman/shellcheck/releases/download/v$SHELLCHECK_VERSION/shellcheck-v$SHELLCHECK_VERSION.$(uname -s | tr '[:upper:]' '[:lower:]').$(uname -m).tar.xz"
  tar -xf shellcheck.tar.xz
  mv ./shellcheck-v$SHELLCHECK_VERSION/shellcheck "$location"
  rm shellcheck.tar.xz
  rm -Rf ./shellcheck-v$SHELLCHECK_VERSION
}

setup::tools "$BIN_LOCATION"
