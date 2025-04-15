# Use the official Node.js image as the base image
FROM node:lts

# Set the working directory
WORKDIR /app

# Install necessary tools
RUN apt update -y && apt install -y git vim-nox curl iputils-ping

# Clone the Recogito server repository
RUN git clone --depth 1 --branch 1.4.0 https://github.com/recogito/recogito-server.git

# Remove the default server config and download the custom config
RUN rm -f ./recogito-server/config.json && \
    curl -LJ https://raw.githubusercontent.com/recogito/recogito-studio/1.4.0/docker/config/config.json -o ./recogito-server/config.json

# Build the server
WORKDIR /app/recogito-server
RUN npm init -y && npm install
# Clone the Recogito client repository
WORKDIR /app
RUN git clone --depth 1 --branch 1.4.0 https://github.com/recogito/recogito-client.git

# Remove the default client config and download the custom config
RUN rm -f ./recogito-client/src/config.json && \
    curl -LJ https://raw.githubusercontent.com/recogito/recogito-studio/1.4.0/docker/config/config.json -o ./recogito-client/src/config.json

# Build the client
WORKDIR /app/recogito-client
RUN rm .env* && \
    git clone --branch v0.1 https://github.com/recogito/geotagger.git /recogito-client/plugins/geotagger && \
    rm -f /recogito-client/astro.config.mjs && \
    cp /astro.config.mjs /recogito-client/astro.config.mjs 

# Expose the necessary port
EXPOSE 3000

# Copy the post-deployment script
COPY build-server.sh /app/build-server.sh
RUN chmod +x /app/build-server.sh 

# Start the server and client applications
CMD ["bash", "-c", "cd /app/recogito-server && ./build-server.sh && wait 60 && cd /app/recogito-client && npm install && npm run build-node && node ./dist/server/entry.mjs"]
