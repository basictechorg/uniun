# syntax=docker/dockerfile:1.7

# ── Stage 1: build ───────────────────────────────────────────────────────
# go.mod requires 1.24 (transitive via khatru → go-nostr); host Go
# version doesn't matter since the image carries its own toolchain.
FROM golang:1.24-alpine AS build

WORKDIR /src

COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

COPY *.go ./

# CGO off → static binary the distroless runtime can execute without glibc.
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=linux \
    go build -trimpath -ldflags="-s -w" -o /out/uniun .

# Pre-create /data/logs owned by uid 65532 so the named volume in
# docker-compose inherits these perms on first init. Without this the
# nonroot container user can't write to the volume mountpoint.
RUN mkdir -p /staging/data/logs && chown -R 65532:65532 /staging/data

# ── Stage 2: runtime ─────────────────────────────────────────────────────
FROM gcr.io/distroless/static-debian12:nonroot

WORKDIR /app
COPY --from=build /out/uniun /app/uniun
COPY --from=build --chown=nonroot:nonroot /staging/data /data

ENV WORKING_DIR=/data \
    RELAY_PORT=8082 \
    LOG_FILE=/data/logs/uniun.log \
    LOG_LEVEL=info

EXPOSE 8082

USER nonroot:nonroot

ENTRYPOINT ["/app/uniun"]
