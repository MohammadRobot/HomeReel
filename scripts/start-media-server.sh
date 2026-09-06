#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="${MEDIA_SERVER_PROJECT_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)}"
COMPOSE_ARGS=(
  --env-file .env
  -f docker-compose.yml
  -f docker-compose.gpu.yml
)
ACTION="${1:-start}"
ACTION_LABEL="$ACTION"

pause_before_exit() {
  local exit_code=$?

  if [ -t 0 ]; then
    echo
    if [ "$exit_code" -eq 0 ]; then
      echo "Media server $ACTION_LABEL finished successfully."
    else
      echo "Media server $ACTION_LABEL failed with exit code $exit_code."
    fi
    read -r -p "Press Enter to close this window..." _
  fi

  exit "$exit_code"
}

trap pause_before_exit EXIT

usage() {
  cat <<'EOF'
Usage:
  start-media-server.sh [start]
  start-media-server.sh update

Commands:
  start   Validate Compose, start the GPU-enabled stack, and run health checks.
  update  Pull configured images, recreate containers, and run health checks.
EOF
}

wait_for_http() {
  local name="$1"
  local url="$2"
  local print_response="${3:-false}"
  local response=""

  for attempt in $(seq 1 30); do
    if response="$(curl -fsS --max-time 5 "$url" 2>/dev/null)"; then
      if [ "$print_response" = "true" ]; then
        printf '%s\n' "$response"
      fi
      return 0
    fi

    printf '%s not ready yet (%s/30)\n' "$name" "$attempt"
    sleep 2
  done

  echo "$name did not respond at $url"
  return 1
}

read_env_value() {
  local name="$1"

  sed -n "s/^${name}=//p" .env | tail -n 1 | tr -d '\"'
}

load_runtime_settings() {
  LAN_BIND_IP="$(read_env_value LAN_BIND_IP)"
  LANDING_PORT="$(read_env_value LANDING_PORT)"
  JELLYFIN_PORT="$(read_env_value JELLYFIN_PORT)"
  QBT_WEBUI_PORT="$(read_env_value QBT_WEBUI_PORT)"
  QBT_TORRENT_PORT="$(read_env_value QBT_TORRENT_PORT)"
  SONARR_PORT="$(read_env_value SONARR_PORT)"
  RADARR_PORT="$(read_env_value RADARR_PORT)"
  JACKETT_PORT="$(read_env_value JACKETT_PORT)"

  LAN_BIND_IP="${LAN_BIND_IP:-127.0.0.1}"
  LANDING_PORT="${LANDING_PORT:-8090}"
  JELLYFIN_PORT="${JELLYFIN_PORT:-8096}"
  QBT_WEBUI_PORT="${QBT_WEBUI_PORT:-8080}"
  QBT_TORRENT_PORT="${QBT_TORRENT_PORT:-6881}"
  SONARR_PORT="${SONARR_PORT:-8989}"
  RADARR_PORT="${RADARR_PORT:-7878}"
  JACKETT_PORT="${JACKETT_PORT:-9117}"

  LANDING_URL="http://${LAN_BIND_IP}:${LANDING_PORT}"
  JELLYFIN_HEALTH_URL="http://${LAN_BIND_IP}:${JELLYFIN_PORT}/health"
}

require_env_file() {
  if [ ! -f .env ]; then
    echo "Missing .env at $PROJECT_DIR/.env"
    echo "Create it from .env.example before starting or updating the stack."
    exit 1
  fi
}

select_docker_command() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "Docker is not installed or is not available in PATH."
    exit 1
  fi

  DOCKER=(docker)
  if ! docker info >/dev/null 2>&1; then
    DOCKER=(sudo docker)
  fi
}

validate_compose() {
  echo "Validating Docker Compose configuration..."
  "${DOCKER[@]}" compose "${COMPOSE_ARGS[@]}" config --quiet
}

check_port_listeners() {
  local found="false"
  local matches=""
  local ports=(
    "$LANDING_PORT"
    "$JELLYFIN_PORT"
    "$QBT_WEBUI_PORT"
    "$QBT_TORRENT_PORT"
    "$SONARR_PORT"
    "$RADARR_PORT"
    "$JACKETT_PORT"
  )

  if ! command -v ss >/dev/null 2>&1; then
    echo "Skipping port listener check because ss is not available."
    return 0
  fi

  if ! ss -H -ltn >/dev/null 2>&1; then
    echo "Skipping port listener check because socket state is not readable."
    return 0
  fi

  echo "Checking host port listeners for configured published ports..."
  for port in "${ports[@]}"; do
    matches="$(ss -H -ltnp "sport = :$port" 2>/dev/null || true)"
    if [ -n "$matches" ]; then
      found="true"
      printf 'TCP port %s already has a listener:\n%s\n' "$port" "$matches"
    fi
  done

  matches="$(ss -H -lunp "sport = :$QBT_TORRENT_PORT" 2>/dev/null || true)"
  if [ -n "$matches" ]; then
    found="true"
    printf 'UDP port %s already has a listener:\n%s\n' "$QBT_TORRENT_PORT" "$matches"
  fi

  if [ "$found" = "false" ]; then
    echo "No listeners found on configured published ports before Compose runs."
  else
    echo "Existing listeners may be this stack if it is already running; investigate unexpected processes before continuing."
  fi
}

print_container_status() {
  echo
  echo "Container status:"
  "${DOCKER[@]}" compose "${COMPOSE_ARGS[@]}" ps
}

run_health_checks() {
  if command -v curl >/dev/null 2>&1; then
    echo
    echo "Checking landing page at $LANDING_URL..."
    wait_for_http "Landing page" "$LANDING_URL"

    echo
    echo "Checking Jellyfin health at $JELLYFIN_HEALTH_URL..."
    wait_for_http "Jellyfin" "$JELLYFIN_HEALTH_URL" true
  fi

  echo
  echo "Checking Jellyfin GPU visibility..."
  if ! "${DOCKER[@]}" compose "${COMPOSE_ARGS[@]}" exec -T jellyfin nvidia-smi; then
    echo
    echo "Jellyfin started, but the GPU check did not pass."
    echo "Confirm the NVIDIA Container Toolkit is installed and Docker was restarted."
    exit 1
  fi
}

open_landing_page() {
  echo
  echo "Landing page: $LANDING_URL"

  if command -v xdg-open >/dev/null 2>&1 && [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
    xdg-open "$LANDING_URL" >/dev/null 2>&1 || true
  fi
}

prepare_project() {
  cd "$PROJECT_DIR"
  export MEDIA_SERVER_PROJECT_DIR="$PROJECT_DIR"

  echo "Project: $PROJECT_DIR"
  echo

  require_env_file
  select_docker_command
  load_runtime_settings
  validate_compose
  check_port_listeners
}

start_project() {
  ACTION_LABEL="start"

  echo "Starting media server with Jellyfin GPU support..."
  prepare_project

  echo "Starting containers..."
  "${DOCKER[@]}" compose "${COMPOSE_ARGS[@]}" up -d

  print_container_status
  run_health_checks
  open_landing_page
}

update_project() {
  ACTION_LABEL="update"

  echo "Updating media server with configured image tags..."
  prepare_project

  echo "Pulling configured registry images..."
  "${DOCKER[@]}" compose "${COMPOSE_ARGS[@]}" pull --ignore-buildable

  echo
  echo "Building local images and recreating containers..."
  "${DOCKER[@]}" compose "${COMPOSE_ARGS[@]}" up -d --build --remove-orphans

  print_container_status
  run_health_checks
  open_landing_page
}

if [ "$#" -gt 1 ]; then
  usage
  exit 64
fi

case "$ACTION" in
  start)
    start_project
    ;;
  update)
    update_project
    ;;
  -h|--help|help)
    ACTION_LABEL="help"
    usage
    ;;
  *)
    echo "Unknown command: $ACTION"
    echo
    usage
    exit 64
    ;;
esac
