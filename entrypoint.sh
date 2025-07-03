#!/bin/sh

# Navigate to the server directory
cd /app/recogito-server

echo 'Push database schema'
yes | npx supabase db push --db-url postgresql://postgres:$POSTGRES_PASSWORD@$POSTGRES_HOST:$POSTGRES_PORT/postgres

echo 'Wait for the database to be ready'
sleep 5

echo 'Create default groups'
yes | node /app/recogito-server/create-default-groups.js -f /app/recogito-server/config.json

#echo "adjust NER plugin to trigger-dev v4"
#sed -i 's|trigger.dev/sdk/v3|trigger.dev/sdk|g' /app/recogito-client/node_modules/@recogito/plugin-ner/src/trigger.config.ts
#sed -i 's|trigger.dev/sdk/v3|trigger.dev/sdk|g' /app/recogito-client/node_modules/@recogito/plugin-ner/src/trigger/stanfordCore.ts
#sed -i 's|trigger.dev/sdk/v3|trigger.dev/sdk|g' /app/recogito-client/node_modules/@recogito/plugin-ner/src/trigger/tasks/doStandfordNlp.ts
#sed -i 's|trigger.dev/sdk/v3|trigger.dev/sdk|g' /app/recogito-client/node_modules/@recogito/plugin-ner/src/trigger/tasks/nerToXML.ts
#sed -i 's|trigger.dev/sdk/v3|trigger.dev/sdk|g' /app/recogito-client/node_modules/@recogito/plugin-ner/src/trigger/tasks/plainTextToXML.ts
#sed -i 's|trigger.dev/sdk/v3|trigger.dev/sdk|g' /app/recogito-client/node_modules/@recogito/plugin-ner/src/trigger/tasks/uploadDocumentToRS.ts
#sed -i 's|trigger.dev/sdk/v3|trigger.dev/sdk|g' /app/recogito-client/node_modules/@recogito/plugin-ner/src/trigger/tasks/xmlToPlainText.ts

echo "adjust to acdh trigger project"
sed -i 's|proj_fyeypkhgyaejpiweobwq|proj_ojornoedwjbzoigcdkcn|g' /app/recogito-client/node_modules/@recogito/plugin-ner/src/trigger.config.ts


#echo "Start the delayed command in the background"
#(
#  echo "Waiting 30 seconds before running trigger.dev deploy..."
#  sleep 30
#  cd /app/recogito-client
#  yes | npx trigger.dev@v4-beta dev deploy -c /app/recogito-client/node_modules/@recogito/plugin-ner/src/trigger.config.ts
 # yes | npx trigger.dev@latest dev deploy -c /app/recogito-client/node_modules/@recogito/plugin-ner/src/trigger.config.ts
#) &

echo "Client build completed"
node /app/recogito-client/dist/server/entry.mjs
