FROM node:26-slim

WORKDIR /app

# Environment variables
ENV NODE_OPTIONS="--max-old-space-size=8192" \
    NODE_ENV=production \
    HOST=0.0.0.0 \
    PORT=3000 \
    BRANCH=1.12.0

# Copy the startup script
COPY entrypoint.sh /app/entrypoint.sh

RUN chmod +x /app/entrypoint.sh && \
    chown -R 1000:1000 /app

# Install required system packages
RUN apt-get update && apt-get install -y \
    python3 \
    make \
    g++ \
    git \
    curl \
    iputils-ping \
    vim \
    && rm -rf /var/lib/apt/lists/*

USER node

# Clone the Recogito server
RUN git clone --depth 1 --branch "${BRANCH}" \
    https://github.com/recogito/recogito-server.git

# Replace the server configuration
RUN curl -fL \
    "https://raw.githubusercontent.com/recogito/recogito-studio/${BRANCH}/docker/config/config.json" \
    -o /app/recogito-server/config.json

WORKDIR /app/recogito-server

# Install server dependencies
RUN --mount=type=secret,uid=1000,gid=1000,id=secrets_env,dst=/secrets_env \
    --mount=type=cache,target=/tmp/cache \
    set -e; \
    if [ -f /secrets_env ]; then . /secrets_env; fi; \
    npm install --include=dev --save-dev --save-exact supabase@2.121.0; \
    test -x node_modules/.bin/supabase; \
    node_modules/.bin/supabase --version

WORKDIR /app

# Clone the Recogito client
RUN git clone --depth 1 --branch "${BRANCH}" \
    https://github.com/recogito/recogito-client.git

# Replace the client configuration
RUN curl -fL \
    "https://raw.githubusercontent.com/recogito/recogito-studio/${BRANCH}/docker/config/config.json" \
    -o /app/recogito-client/src/config.json

# Copy the custom Astro configuration
COPY --chown=node:node astro.config.node.mjs \
    /app/recogito-client/astro.config.node.mjs

WORKDIR /app/recogito-client

# Fix password recovery redirect to preserve the current locale
RUN python3 - <<'PY'
from pathlib import Path

p = Path("src/apps/auth-forgot-password/ForgotPassword.tsx")
s = p.read_text()

old = "const redirectTo = `${host}/reset-password`;"
new = """const redirectTo = `${host}${window.location.pathname.replace(
        /\\/forgot-password$/,
        '/reset-password'
      )}`;"""

if old not in s:
    raise SystemExit("Password recovery redirect source not found")

p.write_text(s.replace(old, new))
PY

# Install plugins before Astro loads INSTALLED_PLUGINS.
# Pin the plugin releases currently used by this deployment.
ENV INSTALLED_PLUGINS="@recogito/plugin-geotagging@0.6.0,@recogito/plugin-ner@0.5.1,@recogito/plugin-revisions@0.2.0,@recogito/plugin-tei-inliner@0.2.0"

COPY --chown=node:node verify-sdk.cjs /app/verify-sdk.cjs

RUN --mount=type=secret,uid=1000,gid=1000,id=secrets_env,dst=/secrets_env \
    --mount=type=cache,target=/tmp/cache \
    set -e; \
    if [ -f /secrets_env ]; then . /secrets_env; fi; \
    npm ci --include=dev; \
    npm pkg set 'overrides[@recogito/studio-sdk]=$@recogito/studio-sdk' \
        'overrides[@trigger.dev/sdk]=$@trigger.dev/sdk'; \
    npm install --include=dev --save-exact \
        trigger.dev@4.8.3 \
        @trigger.dev/sdk@4.8.3 \
        @trigger.dev/build@4.8.3 \
        @recogito/plugin-geotagging@0.6.0 \
        @recogito/plugin-ner@0.5.1 \
        @recogito/plugin-revisions@0.2.0 \
        @recogito/plugin-tei-inliner@0.2.0; \
    npm ls @recogito/studio-sdk @trigger.dev/sdk @trigger.dev/build; \
    node /app/verify-sdk.cjs; \
    npm run build-node; \
    node /app/verify-sdk.cjs

WORKDIR /app

EXPOSE 3000

CMD ["sh", "-c", "/app/entrypoint.sh"]
