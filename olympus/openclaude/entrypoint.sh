#!/bin/sh
set -e

export GRPC_HOST="${GRPC_HOST:-0.0.0.0}"
export GRPC_PORT="${GRPC_PORT:-50051}"

# Start gRPC server in background (no exec, just run and background)
node dist/cli.mjs dev:grpc &
GRPC_PID=$!
echo "[entrypoint] gRPC server started (pid ${GRPC_PID})"

# Wait for gRPC to initialize
sleep 3

# Start HTTP adapter - this stays as PID 1 and manages the gRPC child
node http-adapter/index.js
