#!/bin/sh
set -e

# Run DB migrations if DATABASE_URL is set
if [ -n "${DATABASE_URL:-}" ]; then
  echo "Running DB migrations..."
  if npm run db:migrate; then
    echo "Migrations succeeded"
  else
    echo "Migrations failed"
    if [ "${NODE_ENV:-}" = "production" ]; then
      echo "NODE_ENV=production - aborting startup due to migration failure"
      exit 1
    else
      echo "Non-production environment - continuing startup despite migration failure"
    fi
  fi
else
  echo "DATABASE_URL not set — skipping migrations"
fi

echo "Starting application..."
exec node server.mjs
