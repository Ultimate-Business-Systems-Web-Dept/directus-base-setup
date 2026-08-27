#!/bin/sh
set -e

normalize_env_var() {
  var_name="$1"
  eval "raw_value=\${$var_name-}"

  if [ -z "$raw_value" ]; then
    return 0
  fi

  normalized_value=$(printf '%s' "$raw_value" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')

  case "$normalized_value" in
    \"*\")
      normalized_value=${normalized_value#\"}
      normalized_value=${normalized_value%\"}
      ;;
    \'*\')
      normalized_value=${normalized_value#\'}
      normalized_value=${normalized_value%\'}
      ;;
  esac

  export "$var_name=$normalized_value"
}

wait_for_host_port() {
  host="$1"
  port="$2"
  label="$3"
  attempts="${4:-30}"
  sleep_seconds="${5:-2}"
  attempt=1

  while [ "$attempt" -le "$attempts" ]; do
    if node -e "const dns=require('node:dns'); const net=require('node:net'); const host=process.argv[1]; const port=Number(process.argv[2]); dns.lookup(host, (dnsErr) => { if (dnsErr) process.exit(1); const socket = net.connect({ host, port }); socket.setTimeout(2000); socket.on('connect', () => { socket.destroy(); process.exit(0); }); socket.on('error', () => process.exit(1)); socket.on('timeout', () => { socket.destroy(); process.exit(1); }); });" "$host" "$port"
    then
      echo "$label is reachable at $host:$port"
      return 0
    fi

    echo "Waiting for $label at $host:$port ($attempt/$attempts)..."
    attempt=$((attempt + 1))
    sleep "$sleep_seconds"
  done

  echo "$label did not become reachable at $host:$port"
  return 1
}

disable_redis_cache() {
  export CACHE_ENABLED="false"
  unset CACHE_STORE
  unset REDIS_HOST
  unset REDIS_PORT
  unset REDIS_PASSWORD
}

bootstrap_directus() {
  bootstrap_log=$(mktemp)

  if node /directus/cli.js bootstrap >"$bootstrap_log" 2>&1; then
    cat "$bootstrap_log"
    rm -f "$bootstrap_log"
    return 0
  fi

  cat "$bootstrap_log"

  if grep -Eiq "already installed|already exists|has already been installed" "$bootstrap_log"; then
    rm -f "$bootstrap_log"
    return 0
  fi

  rm -f "$bootstrap_log"
  return 1
}

normalize_env_var DB_HOST
normalize_env_var DB_PORT
normalize_env_var DB_DATABASE
normalize_env_var DB_USER
normalize_env_var DB_PASSWORD
normalize_env_var CACHE_ENABLED
normalize_env_var CACHE_STORE
normalize_env_var REDIS_HOST
normalize_env_var REDIS_PORT
normalize_env_var REDIS_PASSWORD

DB_PORT="${DB_PORT:-5432}"
REDIS_PORT="${REDIS_PORT:-6379}"

echo "Ensuring Directus writable directories exist..."
mkdir -p /directus/extensions /directus/uploads /directus/snapshot

echo "Fixing Directus directory permissions..."
chown -R node:node /directus/extensions /directus/uploads /directus/snapshot || true
chmod -R 755 /directus/extensions /directus/uploads /directus/snapshot || true

if [ -n "${DB_HOST:-}" ]; then
  echo "Waiting for database connectivity..."
  wait_for_host_port "$DB_HOST" "$DB_PORT" "Database" || {
    echo "Database host is not reachable. Stopping startup."
    exit 1
  }
fi

if [ "${CACHE_ENABLED:-false}" = "true" ] && [ "${CACHE_STORE:-}" = "redis" ]; then
  if [ -z "${REDIS_HOST:-}" ]; then
    echo "Redis cache is enabled but REDIS_HOST is empty. Falling back to in-memory cache."
    disable_redis_cache
  elif ! wait_for_host_port "$REDIS_HOST" "$REDIS_PORT" "Redis" 3 1 >/dev/null 2>&1; then
    echo "Redis host $REDIS_HOST:$REDIS_PORT is not reachable. Falling back to in-memory cache."
    disable_redis_cache
  fi
fi

echo "Ensuring Directus system tables are installed..."
bootstrap_directus || {
  echo "Directus bootstrap failed. Stopping startup."
  exit 1
}

echo "Starting Directus..."
node /directus/cli.js start &
DIRECTUS_PID=$!

wait_for_host_port "127.0.0.1" "${PORT:-8055}" "Directus API" || {
  echo "Directus API did not become reachable. Stopping startup."
  kill "$DIRECTUS_PID" 2>/dev/null || true
  wait "$DIRECTUS_PID" 2>/dev/null || true
  exit 1
}

wait "$DIRECTUS_PID"
