#!/bin/bash

#================
# Log Definitions
#================
export LINE='\n'                        # Line Break
export RESET='\033[0m'                  # Text Reset
export WhiteText='\033[0;37m'           # White

# Bold
export RedBoldText='\033[1;31m'         # Red
export GreenBoldText='\033[1;32m'       # Green
export YellowBoldText='\033[1;33m'      # Yellow
export CyanBoldText='\033[1;36m'        # Cyan
#================
# End Log Definitions
#================

LogInfo() {
  Log "$1" "$WhiteText"
}
LogWarn() {
  Log "$1" "$YellowBoldText"
}
LogError() {
  Log "$1" "$RedBoldText"
}
LogSuccess() {
  Log "$1" "$GreenBoldText"
}
LogAction() {
  Log "$1" "$CyanBoldText" "====" "===="
}
Log() {
  local message="$1"
  local color="$2"
  local prefix="$3"
  local suffix="$4"
  printf "$color%s$RESET$LINE" "$prefix$message$suffix"
}

install() {
  LogAction "Starting server install"
  LogInfo "Installing RuneScape: DragonWilds Dedicated Server"

  /depotdownloader/DepotDownloader \
    -app 4019830 \
    -os linux \
    -dir /home/steam/server-files \
    -validate

  LogSuccess "Server install complete"
}

write_dedicated_server_config() {
  local config_file="$1"
  local config_dir
  local input_file
  local tmp_file

  config_dir="$(dirname "$config_file")"
  mkdir -p "$config_dir"

  input_file="$config_file"
  if [ ! -f "$input_file" ]; then
    input_file="/dev/null"
  fi
  tmp_file="$(mktemp "${config_file}.tmp.XXXXXX")"

  if ! awk \
    -v admin_password="${ADMIN_PASSWORD}" \
    -v owner_id="${OWNER_ID}" \
    -v world_password="${WORLD_PASSWORD}" \
    -v server_name="${SERVER_NAME}" \
    -v default_world_name="${DEFAULT_WORLD_NAME}" \
    '
      BEGIN {
        save_section = "[SectionsToSave]"
        server_section = "[/Script/Dominion.DedicatedServerSettings]"

        managed_count = 5
        managed_keys[1] = "AdminPassword"
        managed_keys[2] = "OwnerId"
        managed_keys[3] = "WorldPassword"
        managed_keys[4] = "ServerName"
        managed_keys[5] = "DefaultWorldName"

        managed_values["AdminPassword"] = admin_password
        managed_values["OwnerId"] = owner_id
        managed_values["WorldPassword"] = world_password
        managed_values["ServerName"] = server_name
        managed_values["DefaultWorldName"] = default_world_name
      }

      function trim(value) {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
        return value
      }

      function key_for(line, parts, key) {
        if (line !~ /^[[:space:]]*[^#;\[][A-Za-z0-9_]*[[:space:]]*=/) {
          return ""
        }

        split(line, parts, "=")
        key = trim(parts[1])
        return key
      }

      function print_missing_save_key() {
        if (!seen_save_key) {
          print "bCanSaveAllSections=true"
          seen_save_key = 1
        }
      }

      function print_missing_server_keys(i, key) {
        for (i = 1; i <= managed_count; i++) {
          key = managed_keys[i]
          if (!seen_managed[key]) {
            print key "=" managed_values[key]
            seen_managed[key] = 1
          }
        }
      }

      function close_section() {
        if (current_section == save_section) {
          print_missing_save_key()
        } else if (current_section == server_section) {
          print_missing_server_keys()
        }
      }

      /^[[:space:]]*\[[^]]+\][[:space:]]*$/ {
        close_section()

        current_section = trim($0)
        if (current_section == save_section) {
          seen_save_section = 1
        } else if (current_section == server_section) {
          seen_server_section = 1
        }

        print
        wrote_anything = 1
        next
      }

      {
        key = key_for($0)

        if (current_section == save_section && key == "bCanSaveAllSections") {
          print_missing_save_key()
          wrote_anything = 1
          next
        }

        if (current_section == server_section && (key in managed_values)) {
          if (!seen_managed[key]) {
            print key "=" managed_values[key]
            seen_managed[key] = 1
            wrote_anything = 1
          }
          next
        }

        print
        wrote_anything = 1
      }

      END {
        close_section()

        if (!seen_save_section) {
          if (wrote_anything) {
            print ""
          }
          print save_section
          print_missing_save_key()
          wrote_anything = 1
        }

        if (!seen_server_section) {
          if (wrote_anything) {
            print ""
          }
          print server_section
          print_missing_server_keys()
          print "ServerGuid="
        }
      }
    ' "$input_file" > "$tmp_file"; then
    rm -f "$tmp_file"
    return 1
  fi

  mv "$tmp_file" "$config_file"
}

build_launch_args() {
  local default_port="${DEFAULT_PORT:-7777}"

  LAUNCH_ARGS=(
    "RSDragonwilds"
    "-log"
    "-NewConsole"
    "-Port=${default_port}"
    "-ini:Game:[/Script/Engine.GameSession]:MaxPlayers=${MAX_PLAYERS}"
    "-ini:Game:[/Script/Dominion.DedicatedServerSettings]:OwnerId=${OWNER_ID}"
    "-ini:Game:[/Script/Dominion.DedicatedServerSettings]:ServerName=${SERVER_NAME}"
    "-ini:Game:[/Script/Dominion.DedicatedServerSettings]:DefaultWorldName=${DEFAULT_WORLD_NAME}"
  )

  if [ -n "${MULTIHOME:-}" ]; then
    LAUNCH_ARGS+=("-MULTIHOME=${MULTIHOME}")
  fi
}

# Attempt to shutdown the server gracefully
# Returns 0 if it is shutdown
# Returns 1 if it is not able to be shutdown
shutdown_server() {
  local return_val=0
  LogAction "Attempting graceful server shutdown"

  local pid
  pid=$(pgrep -f "RSDragonwilds")

  if [ -n "$pid" ]; then
    kill -SIGTERM "$pid"

    local count=0
    while [ $count -lt 30 ] && kill -0 "$pid" 2>/dev/null; do
      sleep 1
      count=$((count + 1))
    done

    if kill -0 "$pid" 2>/dev/null; then
      LogWarn "Server did not shutdown gracefully, forcing shutdown"
      return_val=1
    else
      LogSuccess "Server shutdown gracefully"
    fi
  else
    LogWarn "Server process not found"
    return_val=1
  fi

  return "$return_val"
}
