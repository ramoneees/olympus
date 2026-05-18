# Build stage: compile OpenClaude with Bun
FROM oven/bun:1.2-alpine AS builder
WORKDIR /build

RUN apk add --no-cache git && \
    git clone --depth 1 https://github.com/Gitlawb/openclaude.git . && \
    bun install --frozen-lockfile && \
    bun run build

# Runtime stage
FROM node:22-alpine AS runtime
WORKDIR /app

RUN apk add --no-cache git ripgrep curl && \
    KUBECTL_VER=1.32.0 && \
    ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/') && \
    curl -fsSL "https://dl.k8s.io/release/v${KUBECTL_VER}/bin/linux/${ARCH}/kubectl" -o /usr/local/bin/kubectl && \
    chmod +x /usr/local/bin/kubectl

# Copy compiled OpenClaude artifacts
COPY --from=builder /build/dist ./dist
COPY --from=builder /build/node_modules ./node_modules
COPY --from=builder /build/src/proto ./src/proto
COPY --from=builder /build/package.json ./package.json

# Copy and install HTTP adapter
COPY http-adapter/ ./http-adapter/
RUN cd http-adapter && npm install --omit=dev --ignore-scripts

# Set up entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh && chown node:node /entrypoint.sh

USER node

EXPOSE 50051 8080

ENTRYPOINT ["/entrypoint.sh"]
