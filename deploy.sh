#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

PROJECT_NAME="EFK + Monitoring-2"
PROJECT_DIR_NAME="$(basename "$ROOT_DIR")"
COMPOSE_NETWORK_CANDIDATE="${PROJECT_DIR_NAME}_monitoring-net"

WAIT_TIMEOUT_SECONDS=120
WAIT_INTERVAL_SECONDS=2

log() {
  echo "==> $*"
}

warn() {
  echo "WARN: $*"
}

die() {
  echo "ERROR: $*"
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

cleanup_start_from_scratch() {
  log "Cleanup (start from scratch)"
  # Важливо: контейнер Node.js НЕ керується docker compose, але ми підʼєднуємо його до compose-мережі.
  # Якщо він лишився, `docker compose down` може не видалити мережу з повідомленням:
  # "Resource is still in use".
  docker rm -f monitoring-2 >/dev/null 2>&1 || true

  # Зупиняємо та видаляємо весь стек EFK (контейнери/volumes/мережа/локальні образи compose).
  docker compose down --volumes --remove-orphans --rmi local || true

  # На Windows/Docker Desktop мережа інколи звільняється не миттєво.
  # Це не "костиль", а звичайне опитування стану (polling), щоб не падати через race condition.
  for _ in {1..20}; do
    docker network rm "$COMPOSE_NETWORK_CANDIDATE" >/dev/null 2>&1 && break || true
    sleep 1
  done

  # Локальний образ Node.js.
  docker image rm -f monitoring-2:local >/dev/null 2>&1 || true
}

detect_compose_network() {
  local network
  network="$(docker inspect -f '{{range $k, $v := .NetworkSettings.Networks}}{{println $k}}{{end}}' fluentd 2>/dev/null | head -n 1 || true)"

  if [[ -n "$network" ]]; then
    echo "$network"
    return 0
  fi

  # Фолбек на очікувану назву мережі.
  echo "$COMPOSE_NETWORK_CANDIDATE"
}

wait_for_fluentd_listening() {
  log "Waiting for Fluentd to listen on 24224"
  local start=$SECONDS

  while (( SECONDS - start < WAIT_TIMEOUT_SECONDS )); do
    if docker logs fluentd 2>&1 | grep -q 'listening port'; then
      log "OK: Fluentd is listening"
      return 0
    fi
    sleep "$WAIT_INTERVAL_SECONDS"
  done

  die "Fluentd did not start listening in time"
}

wait_for_http_ok() {
  local url="$1"
  local label="$2"
  local start=$SECONDS

  if ! need_cmd curl; then
    warn "'curl' not found; skipping readiness checks"
    return 0
  fi

  log "Waiting for $label ($url)"
  while (( SECONDS - start < WAIT_TIMEOUT_SECONDS )); do
    if curl -fsS "$url" >/dev/null 2>&1; then
      log "OK: $label is ready"
      return 0
    fi
    sleep "$WAIT_INTERVAL_SECONDS"
  done

  die "$label did not become ready in time"
}

generate_test_logs() {
  if ! need_cmd curl; then
    return 0
  fi

  log "Generating test logs"

  # 1) Гарантований 1-рядковий лог через Docker fluentd logging driver.
  docker run --rm --log-driver=fluentd --log-opt fluentd-address=localhost:24224 --log-opt tag=logtest alpine:3.20 sh -lc 'echo "hello-from-logtest"' >/dev/null 2>&1 || true

  # 2) Додатково: пробуємо сходити в /, щоб апка згенерувала власні логи.
  # Порт апки не проброшений на host, тому робимо запит з helper-контейнера у compose-мережі.
  for _ in {1..10}; do
    docker run --rm --network "$COMPOSE_NETWORK" curlimages/curl:8.5.0 -sS http://monitoring-2:10000/ >/dev/null 2>&1 && break || true
    sleep 2
  done
}

wait_for_fluentd_index() {
  if ! need_cmd curl; then
    return 0
  fi

  log "Quick check: Fluentd indices"

  local start=$SECONDS
  local out

  while (( SECONDS - start < WAIT_TIMEOUT_SECONDS )); do
    out="$(curl -s "http://localhost:9200/_cat/indices/fluentd-*?v" || true)"
    # Якщо індекс існує, перший стовпець буде починатися з health (yellow/green/red).
    if echo "$out" | grep -q '^yellow\|^green\|^red'; then
      echo "$out"
      return 0
    fi
    sleep "$WAIT_INTERVAL_SECONDS"
  done

  echo "$out"
  warn "fluentd-* index not visible yet. Give it ~10s and re-check:"
  warn "curl -s \"http://localhost:9200/_cat/indices/fluentd-*?v\""
}

log "Starting $PROJECT_NAME"
cleanup_start_from_scratch

log "Starting EFK via docker compose"
docker compose up -d --build

COMPOSE_NETWORK="$(detect_compose_network)"
log "Detected compose network: $COMPOSE_NETWORK"

wait_for_fluentd_listening
wait_for_http_ok "http://localhost:9200" "Elasticsearch"
wait_for_http_ok "http://localhost:5601/api/status" "Kibana"

log "Building Node.js app image"
docker build -t monitoring-2:local ./Monitoring-2

log "Starting Node.js container (Docker fluentd logging driver -> localhost:24224)"
docker rm -f monitoring-2 >/dev/null 2>&1 || true

RUN_ARGS=(
  -d
  --name monitoring-2
  --log-driver=fluentd
  --log-opt fluentd-address=localhost:24224
  --log-opt tag=monitoring-2
)

if [[ -n "$COMPOSE_NETWORK" ]]; then
  RUN_ARGS+=(--network "$COMPOSE_NETWORK")
fi

docker run "${RUN_ARGS[@]}" monitoring-2:local

echo
log "Done"
echo "Kibana: http://localhost:5601"
echo "Elasticsearch: http://localhost:9200"
echo "Fluentd is listening on host port 24224"

generate_test_logs
wait_for_fluentd_index
