# syntax=docker/dockerfile:1.7
#
# Multi-stage build for the Uniun relay (Khatru + BadgerDB + Blossom).
#
# Stage 1 — build a static binary in a full Go toolchain image.
# Stage 2 — copy the binary into a tiny distroless runtime that has no
# shell, no package manager, no setuid binaries. Final image ~25 MB.

# ── Stage 1: build ───────────────────────────────────────────────────────
# Pinned to match the `go` directive in go.mod. A transitive dep
# (khatru → go-nostr) requires 1.24+ features, so we can't go lower
# without rolling back those packages. The production VM's host Go is
# only 1.22.3 — that's fine because the image carries its own
# toolchain; nothing on the host needs to build this code anymore.
FROM golang:1.24-alpine AS build

WORKDIR /src

# Module download is cached separately from source so editing a .go file
# doesn't re-fetch every dep.
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

COPY *.go ./

# CGO disabled → fully static binary that the distroless runtime can
# execute without glibc. -trimpath removes local paths from the binary
# for reproducible builds. -ldflags strips debug + symbol tables.
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=linux \
    go build \
      -trimpath \
      -ldflags="-s -w" \
      -o /out/uniun \
      .

# ── Stage 2: runtime ─────────────────────────────────────────────────────
# distroless/static is exactly libc/ssl-certs/timezone data + nothing else.
# nonroot tag drops us to uid 65532; root filesystem stays read-only.
FROM gcr.io/distroless/static-debian12:nonroot

WORKDIR /app
COPY --from=build /out/uniun /app/uniun

# Default config — overridable via env in docker-compose.yml.
#   WORKING_DIR=/data   → BadgerDB lives at /data/db (bind-mounted in compose)
#   RELAY_PORT=8082     → matches the nginx upstream on the production VM
#   LOG_FILE=""         → empty disables file logging; we want stdout/stderr
#                          so Docker captures logs (`docker logs`, journald,
#                          log driver of choice). Override to a path under
#                          /data if you want on-disk logs as well.
ENV WORKING_DIR=/data \
    RELAY_PORT=8082 \
    LOG_FILE="" \
    LOG_LEVEL=info

EXPOSE 8082

# nonroot user provided by the base image. The bind-mount on /data must
# be readable+writable by uid 65532 (chown on first migration).
USER nonroot:nonroot

ENTRYPOINT ["/app/uniun"]
