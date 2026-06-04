#!/bin/sh
set -e

echo "Ensuring Directus writable directories exist..."
mkdir -p /directus/extensions /directus/uploads /directus/snapshot

echo "Fixing Directus directory permissions..."
chown -R node:node /directus/extensions /directus/uploads /directus/snapshot || true
chmod -R 755 /directus/extensions /directus/uploads /directus/snapshot || true

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