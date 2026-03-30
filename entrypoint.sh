
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

##########################################################
# WAIT FOR SUPABASE REST API (fixes null results)
##########################################################
echo "Waiting for Supabase REST API..."
until curl -s -H "apikey: ${SUPABASE_SERVICE_KEY}" \
  -o /dev/null -w "%{http_code}" \
  "${SUPABASE_HOST}/rest/v1/policies" | grep -q "200"; do

  echo "Supabase REST not ready at ${SUPABASE_HOST}..."
  sleep 3
done
echo "Supabase REST API is ready!"
##########################################################

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
# 3) Install client deps + build client
#############################################

cd /app/recogito-client/

npm install
npm run build-node

echo "Client build completed"

#############################################
# 4) Start Recogito Client server
#############################################

echo "Starting Recogito client server..."
exec node /app/recogito-client/dist/server/entry.mjs
