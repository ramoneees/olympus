#!/bin/sh
set -e

export GRPC_HOST="${GRPC_HOST:-0.0.0.0}"
export GRPC_PORT="${GRPC_PORT:-50051}"

# Start gRPC server in background
node dist/scripts/start-grpc.mjs &
GRPC_PID=$!
echo "[entrypoint] gRPC server started (pid ${GRPC_PID})"

# Wait for gRPC to initialize
sleep 2

# Start HTTP adapter in foreground
exec node http-adapter/index.js
