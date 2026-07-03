#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/functions.sh
source "$ROOT_DIR/scripts/functions.sh"

assert_contains() {
  local file="$1"
  local expected="$2"

  if ! grep -Fqx "$expected" "$file"; then
    printf 'Expected to find line: %s\n' "$expected" >&2
    printf 'File contents:\n' >&2
    cat "$file" >&2
    exit 1
  fi
}

assert_not_contains() {
  local file="$1"
  local unexpected="$2"

  if grep -Fqx "$unexpected" "$file"; then
    printf 'Did not expect to find line: %s\n' "$unexpected" >&2
    printf 'File contents:\n' >&2
    cat "$file" >&2
    exit 1
  fi
}

assert_arg() {
  local index="$1"
  local expected="$2"

  if [ "${LAUNCH_ARGS[$index]}" != "$expected" ]; then
    printf 'Expected LAUNCH_ARGS[%s] to be: %s\n' "$index" "$expected" >&2
    printf 'Actual value: %s\n' "${LAUNCH_ARGS[$index]}" >&2
    exit 1
  fi
}

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

CONFIG_FILE="$TMP_DIR/DedicatedServer.ini"
cat > "$CONFIG_FILE" <<'INI'
[SectionsToSave]
bCanSaveAllSections=false

[/Script/Dominion.DedicatedServerSettings]
AdminPassword=old-admin
OwnerId=old-owner
WorldPassword=old-world
ServerName=OldServer
DefaultWorldName=OldWorld
ServerGuid=existing-guid
KnownPlayerList=(PlayerId="abc")

[OtherSection]
UnmanagedKey=keep-me
INI

export ADMIN_PASSWORD="new-admin"
export OWNER_ID="new-owner"
export WORLD_PASSWORD="new-world"
export SERVER_NAME="New Server"
export DEFAULT_WORLD_NAME="RealNinjasOnly"

write_dedicated_server_config "$CONFIG_FILE"

assert_contains "$CONFIG_FILE" "bCanSaveAllSections=true"
assert_contains "$CONFIG_FILE" "AdminPassword=new-admin"
assert_contains "$CONFIG_FILE" "OwnerId=new-owner"
assert_contains "$CONFIG_FILE" "WorldPassword=new-world"
assert_contains "$CONFIG_FILE" "ServerName=New Server"
assert_contains "$CONFIG_FILE" "DefaultWorldName=RealNinjasOnly"
assert_contains "$CONFIG_FILE" "ServerGuid=existing-guid"
assert_contains "$CONFIG_FILE" 'KnownPlayerList=(PlayerId="abc")'
assert_contains "$CONFIG_FILE" "UnmanagedKey=keep-me"
assert_not_contains "$CONFIG_FILE" "DefaultWorldName=OldWorld"

NEW_CONFIG_FILE="$TMP_DIR/new/DedicatedServer.ini"
write_dedicated_server_config "$NEW_CONFIG_FILE"

assert_contains "$NEW_CONFIG_FILE" "[SectionsToSave]"
assert_contains "$NEW_CONFIG_FILE" "bCanSaveAllSections=true"
assert_contains "$NEW_CONFIG_FILE" "[/Script/Dominion.DedicatedServerSettings]"
assert_contains "$NEW_CONFIG_FILE" "DefaultWorldName=RealNinjasOnly"
assert_contains "$NEW_CONFIG_FILE" "ServerGuid="

DEFAULT_PORT=7777
MAX_PLAYERS=6
MULTIHOME="0.0.0.0"
build_launch_args

if [ "${#LAUNCH_ARGS[@]}" -ne 9 ]; then
  printf 'Expected 9 launch args, got %s\n' "${#LAUNCH_ARGS[@]}" >&2
  printf '%s\n' "${LAUNCH_ARGS[@]}" >&2
  exit 1
fi

assert_arg 0 "RSDragonwilds"
assert_arg 4 "-ini:Game:[/Script/Engine.GameSession]:MaxPlayers=6"
assert_arg 5 "-ini:Game:[/Script/Dominion.DedicatedServerSettings]:OwnerId=new-owner"
assert_arg 6 "-ini:Game:[/Script/Dominion.DedicatedServerSettings]:ServerName=New Server"
assert_arg 7 "-ini:Game:[/Script/Dominion.DedicatedServerSettings]:DefaultWorldName=RealNinjasOnly"
assert_arg 8 "-MULTIHOME=0.0.0.0"

for arg in "${LAUNCH_ARGS[@]}"; do
  case "$arg" in
    *AdminPassword*|*WorldPassword*)
      printf 'Secret setting leaked into launch args: %s\n' "$arg" >&2
      exit 1
      ;;
  esac
done

printf 'config_writer_test.sh passed\n'
