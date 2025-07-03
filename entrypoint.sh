#!/bin/sh

# Navigate to the server directory
cd /app/recogito-server

echo 'Push database schema'
yes | npx supabase db push --db-url postgresql://postgres:$POSTGRES_PASSWORD@$POSTGRES_HOST:$POSTGRES_PORT/postgres

echo 'Wait for the database to be ready'
sleep 5

echo 'Create default groups'
yes | node /app/recogito-server/create-default-groups.js -f /app/recogito-server/config.json

echo "Start the delayed command in the background"
(
  sed -i 's|proj_fyeypkhgyaejpiweobwq|proj_ojornoedwjbzoigcdkcn|g' /app/recogito-client/node_modules/@recogito/plugin-ner/src/trigger.config.ts
  echo "Waiting 30 seconds before running trigger.dev deploy..."
  sleep 30
  cd  /app/recogito-client/node_modules/@recogito/plugin-ner
  yes | npx trigger.dev@v4-beta login -a https://recogito-trigger-v4.acdh-dev.oeaw.ac.at --profile self-hosted
  yes | npx trigger.dev@v4-beta dev --profile self-hosted deploy -c ./src/trigger.config.ts
) &

echo "Client build completed"
node /app/recogito-client/dist/server/entry.mjs
