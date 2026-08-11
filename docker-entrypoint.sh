#!/bin/sh
set -e

# Run DB migrations if DATABASE_URL is set
if [ -n "${DATABASE_URL:-}" ]; then
  echo "Running DB migrations..."
  npm run db:migrate || echo "Migrations failed; continuing to start server";
else
  echo "DATABASE_URL not set — skipping migrations"
fi

echo "Starting application..."
exec node server.mjs
