FROM  node:alpine

WORKDIR /app

# Update the package list and install the necessary packages
RUN apk update && apk add --no-cache \
    git \
    vim \
    curl \
    iputils

ENV NODE_ENV=production

# Clone the Recogito server repository
RUN git clone --depth 1 --branch 1.4.0 https://github.com/recogito/recogito-server.git

# Remove the default server config and download the custom config
RUN rm -f ./recogito-server/config.json && \
    curl -LJ https://raw.githubusercontent.com/recogito/recogito-studio/1.4.0/docker/config/config.json -o ./recogito-server/config.json

# Build the server
WORKDIR /app/recogito-server

# Clone the Recogito client repository
WORKDIR /app
RUN git clone --depth 1 --branch 1.4.0 https://github.com/recogito/recogito-client.git

# Remove the default client config and download the custom config
RUN rm -f ./recogito-client/src/config.json && \
    curl -LJ https://raw.githubusercontent.com/recogito/recogito-studio/1.4.0/docker/config/config.json -o ./recogito-client/src/config.json

# Configure the client
WORKDIR /app/recogito-client
RUN rm .env* && \
    git clone --branch v0.1 https://github.com/recogito/geotagger.git /recogito-client/plugins/geotagger && \
    rm -f /recogito-client/astro.config.mjs 
COPY astro.config.mjs /recogito-client/astro.config.mjs 

ENV HOST=0.0.0.0
ENV PORT=3000

# Expose the necessary port
EXPOSE 3000

# Copy the post-deployment script
COPY build-server.sh /app/build-server.sh
RUN chmod +x /app/build-server.sh 

# Switch to the non-root user
RUN chown -R 1000:1000 /app
USER node  

# Start the server and client applications
CMD ["sh", "-c", "/app/build-server.sh"]
