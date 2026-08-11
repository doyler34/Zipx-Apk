FROM node:20-slim

WORKDIR /app

# Build tools in case better-sqlite3 has to compile its native module (it will
# use a prebuilt binary when one is available and skip this).
RUN apt-get update \
  && apt-get install -y --no-install-recommends python3 make g++ ca-certificates \
  && rm -rf /var/lib/apt/lists/*

COPY package.json ./
RUN npm install --omit=dev

COPY src ./src
RUN mkdir -p data

EXPOSE 3020
CMD ["node", "src/server.js"]
