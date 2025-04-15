#!/bin/bash

echo "Starting server build"

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
node ./create-default-groups.js -f ./config.json

echo "Server build completed"
