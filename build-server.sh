#!/bin/sh

echo "Starting server build"
export NODE_OPTIONS="--max-old-space-size=8192"

# Navigate to the server directory
cd /app/recogito-server

echo "Building Server app"

npm init -y
npm install

# Push database schema
yes | npx supabase db push --db-url postgresql://postgres:$POSTGRES_PASSWORD@$POSTGRES_HOST:$POSTGRES_PORT/postgres

# Wait for the database to be ready
sleep 5

# Create default groups
# node ./create-default-groups.js -f ./config.json

echo "Server build completed"

echo "Building Client app"

cd /app/recogito-client 

npm install
npm run build-node 

echo "Client build completed"
node ./dist/server/entry.mjs