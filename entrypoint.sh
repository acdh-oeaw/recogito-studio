#!/bin/sh
set -e

cd /app/recogito-server

echo 'Push database schema'
export PGSSLMODE=disable

node_modules/.bin/supabase db push \
  --debug \
  --yes \
  --db-url "postgresql://postgres:$POSTGRES_PASSWORD@$POSTGRES_HOST:$POSTGRES_PORT/postgres" \
  --include-all

echo 'Wait for the database to be ready'
sleep 5

echo 'Waiting for Supabase REST API...'
until curl -s -H "apikey: ${SUPABASE_SERVICE_KEY}" \
  -o /dev/null -w '%{http_code}' \
  "${SUPABASE_HOST}/rest/v1/policies" | grep -q '200'; do
  echo "Supabase REST not ready at ${SUPABASE_HOST}..."
  sleep 3
done
echo 'Supabase REST API is ready!'

echo 'Create default groups'
yes | node /app/recogito-server/create-default-groups.js -f /app/recogito-server/config.json

echo 'Wait for the database to be ready'
sleep 10

cd /app/recogito-client
echo 'Starting Recogito client server...'
exec node /app/recogito-client/dist/server/entry.mjs
