#!/bin/sh
set -e

# Run DB migrations if DATABASE_URL is set
if [ -n "${DATABASE_URL:-}" ]; then
  echo "Running DB migrations..."
  # Allow configurable retry attempts (default 3)
  MIGRATION_RETRIES=${MIGRATION_RETRIES:-3}
  ATTEMPT=1
  MIGRATED=0
  while [ $ATTEMPT -le $MIGRATION_RETRIES ]; do
    echo "Migration attempt $ATTEMPT of $MIGRATION_RETRIES"
    if npm run db:migrate; then
      echo "Migrations succeeded on attempt $ATTEMPT"
      MIGRATED=1
      break
    else
      echo "Migrations failed on attempt $ATTEMPT"
      ATTEMPT=$((ATTEMPT+1))
      sleep 2
    fi
  done

  if [ "$MIGRATED" -ne 1 ]; then
    echo "All migration attempts failed"
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
