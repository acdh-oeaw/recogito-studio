#!/bin/sh
set -e

#############################################
# 1) Setup Recogito Server (Postgres etc.)
#############################################

cd /app/recogito-server

echo 'Push database schema'
export PGSSLMODE=disable
yes | node_modules/.bin/supabase db push \
  --db-url "postgresql://postgres:$POSTGRES_PASSWORD@$POSTGRES_HOST:$POSTGRES_PORT/postgres"

echo 'Wait for the database to be ready'
sleep 5

echo 'Create default groups'
yes | node /app/recogito-server/create-default-groups.js -f /app/recogito-server/config.json

echo 'Wait for the database to be ready'
sleep 10


#############################################
# 2) Patch NER plugin Trigger project
#############################################

# Adjust project ID inside plugin-ner (legacy fix)
sed -i 's|proj_fyeypkhgyaejpiweobwq|proj_cafkhcwrdntlvmvqkdwg|g' \
  /app/recogito-client/node_modules/@recogito/plugin-ner/src/trigger.config.ts


#############################################
# 3) Patch recogito-client trigger.config.ts
#############################################

#echo "🔧 Patch for trigger.config.ts ..."

# Remove all imports from @trigger.dev/build/*
#sed -i '/@trigger.dev\/build/d' /app/recogito-client/trigger.config.ts

# Remove any build:{...} block safely
#sed -i '/build:[[:space:]]*{/,/}/d' /app/recogito-client/trigger.config.ts


#############################################
# 4) Install client deps + build client
#############################################

cd /app/recogito-client/

npm install
npm run build-node

echo "Client build completed"


#############################################
# 5) Trigger.dev deploy (async background job)
#############################################

echo "🚀 Starting Trigger.dev deploy in background..."

(
  cd /app/recogito-client

  echo "Waiting 10 seconds before running Trigger.dev deploy..."
  sleep 10
  
  echo "Running: npx trigger.dev@latest deploy -c ./trigger.config.ts"
  npx trigger.dev@latest deploy -c ./trigger.config.ts || \
    echo "⚠ Warning: Trigger.dev deploy failed, continuing anyway"
) &


#############################################
# 6) Start Recogito Client server
#############################################

echo "Starting Recogito client server..."
exec node /app/recogito-client/dist/server/entry.mjs
