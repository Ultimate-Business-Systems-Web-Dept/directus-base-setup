#!/bin/sh
set -e

echo "Ensuring Directus writable directories exist..."
mkdir -p /directus/extensions /directus/uploads /directus/snapshot

echo "Fixing Directus directory permissions..."
chown -R node:node /directus/extensions /directus/uploads /directus/snapshot || true
chmod -R 755 /directus/extensions /directus/uploads /directus/snapshot || true

echo "Waiting for PostgreSQL..."

MAX_RETRIES=60
RETRY_COUNT=0

until node -e "
const net = require('net');

const host = process.env.DB_HOST;
const port = Number(process.env.DB_PORT || 5432);

const socket = net.createConnection({ host, port }, () => {
  socket.end();
  process.exit(0);
});

socket.on('error', () => process.exit(1));
socket.setTimeout(2000, () => {
  socket.destroy();
  process.exit(1);
});
"; do
  RETRY_COUNT=$((RETRY_COUNT + 1))

  if [ "$RETRY_COUNT" -ge "$MAX_RETRIES" ]; then
    echo "PostgreSQL was not reachable after $MAX_RETRIES attempts. Exiting."
    exit 1
  fi

  echo "PostgreSQL not ready yet. Retry $RETRY_COUNT/$MAX_RETRIES..."
  sleep 2
done

echo "PostgreSQL is reachable."

if [ -f "/directus/snapshot/schema.yaml" ]; then
  echo "Applying Directus schema snapshot..."
  node /directus/cli.js schema apply /directus/snapshot/schema.yaml || {
    echo "Schema apply failed. Stopping startup."
    exit 1
  }
else
  echo "No schema snapshot found at /directus/snapshot/schema.yaml. Skipping schema apply."
fi

echo "Starting Directus..."
exec node /directus/cli.js start
