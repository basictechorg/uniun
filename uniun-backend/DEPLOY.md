# Deploying the Uniun Relay

This document covers the migration from the current PM2-managed binary
to a Docker container, and ongoing operations once we're on Docker.

## What changes

| Aspect | Before (PM2) | After (Docker) |
|---|---|---|
| Process supervision | `pm2` | Docker daemon + `restart: unless-stopped` |
| Binary | `./uniun` built on the VM | Built inside the image; same source |
| Working dir | `/home/azureuser/uniun/uniun-backend` | `/data` inside container, bind-mounted from `./db` |
| Port | `127.0.0.1:8082` | Same — `127.0.0.1:8082` |
| nginx vhost | Unchanged | Unchanged |
| Env | Set inline via PM2 | Set in shell or `.env` next to `docker-compose.yml` |
| Logs | PM2 file logs | `uniun-logs` named docker volume (`uniun.log`, persists across rebuilds) + `docker logs uniun-relay` for live tail |
| BadgerDB | `./db/` | Same — bind-mounted as `./db:/data/db` |

## Prerequisites on the VM

```bash
docker --version           # ≥ 23 (BuildKit must be present — the
                           # Dockerfile uses --mount=type=cache for
                           # faster rebuilds. Docker 23+ enables it
                           # by default; older versions need
                           # DOCKER_BUILDKIT=1 in the env.)
docker-compose --version   # v2.x  (this VM has v2.33.1)
```

Both already installed on the VM (Docker 26.1.3 + compose v2.33.1).

**Note on host Go:** the VM has `go1.22.3`, but the dep graph
(khatru → go-nostr) requires Go 1.24+. That's why the Dockerfile pins
`golang:1.24-alpine`. The image carries its own toolchain — the VM's
host `go` is no longer used for building. If you want to keep the host
Go installed for any reason it doesn't hurt, but it can't build this
codebase directly.

## First-time migration (from PM2 to Docker)

```bash
cd /home/azureuser/uniun

# 1. Pull latest source (includes Dockerfile + docker-compose.yml).
git pull

cd uniun-backend

# 2. Set the runtime secrets. Two equivalent options:
#    (a) shell env for the current login session:
export AZURE_STORAGE_ACCOUNT_KEY='...paste-key...'
export RELAY_PUBKEY='...'        # if relay's own pubkey is set
export RELAY_CONTACT='...'       # optional NIP-11 contact

#    (b) persist in a .env file (docker-compose auto-loads it):
cat > .env <<'EOF'
AZURE_STORAGE_ACCOUNT_KEY=...paste-key...
RELAY_PUBKEY=...
RELAY_CONTACT=...
EOF
chmod 600 .env

# 3. Build the image. ~1 min the first time; subsequent rebuilds are
#    cached (only changed Go files are recompiled).
docker-compose build

# 4. Fix permissions on the BadgerDB bind-mount so the nonroot uid in
#    the container can write to it. nonroot in distroless is uid 65532.
#    (Logs use a named docker volume — no host-side prep needed.)
sudo chown -R 65532:65532 ./db

# 5. Stop the PM2 process (this is the only downtime window — a few
#    seconds. PM2 keeps the process saved so rollback is one command.)
pm2 stop uniun-backend

# 6. Bring the container up.
docker-compose up -d

# 7. Verify the relay is alive on the loopback port nginx expects.
sleep 3
curl -i http://127.0.0.1:8082/ | head -20
#   Expected: HTTP/1.1 200 OK + JSON NIP-11 relay info document.

# 8. Verify nginx still proxies correctly (TLS path).
curl -i https://dev.uniun.in:8080/ -k | head -20
#   Expected: same NIP-11 JSON, via the SSL vhost.

# 9. Tail logs for the first few connections.
docker logs -f uniun-relay
#   Expected: a few "New connection" lines as clients reconnect.

# 10. If everything looks good, permanently remove the PM2 entry.
pm2 delete uniun-backend
pm2 save
```

## Rollback (Docker → PM2)

If anything goes wrong in steps 6–9 of the migration, the PM2 entry is
still there (it's only `stop`ped, not `delete`d):

```bash
cd /home/azureuser/uniun/uniun-backend
docker-compose down            # stops + removes the container
sudo chown -R azureuser:azureuser ./db   # restore host ownership

pm2 start uniun-backend        # original config is still in PM2's dump
pm2 logs uniun-backend --lines 50
```

Zero data lost — the BadgerDB files in `./db/` are the same files PM2
was reading from.

## Ongoing operations

### View live logs

```bash
docker logs -f --tail 100 uniun-relay
```

### Restart the relay

```bash
docker-compose restart relay
# or, after pulling new code:
docker-compose up -d --build relay
```

### Update to a new code version (zero-downtime-ish)

```bash
cd /home/azureuser/uniun
git pull
cd uniun-backend
docker-compose build relay     # build new image; old container keeps running
docker-compose up -d relay     # docker swaps the container in ~2 seconds
docker logs -f --tail 50 uniun-relay
```

Note: WebSocket connections drop on container swap. Clients reconnect
automatically (the Flutter Gateway is built for this), so the visible
impact is a few seconds of "no new events." If you need true
zero-downtime, put two replicas behind nginx upstream — out of scope
for this migration.

### Shell into the container (debug)

The distroless image has no shell. To poke around:

```bash
# Inspect the running container:
docker inspect uniun-relay
docker top uniun-relay
docker stats uniun-relay --no-stream

# Files inside:
docker exec uniun-relay /app/uniun --version  # if a flag existed; it doesn't yet
docker cp uniun-relay:/data/db/LOCK /tmp/badger-lock   # copy files out

# For deeper poking, override the image to a busybox:
docker run --rm -it \
  -v $(pwd)/db:/data/db:ro \
  --entrypoint sh \
  alpine
```

### Backup the BadgerDB

```bash
# Stop the relay briefly so badger flushes cleanly.
docker-compose stop relay
sudo tar -czf /backup/uniun-relay-db-$(date +%F).tar.gz -C . db
docker-compose start relay
```

(Or set up `restic`/`duplicity` against `./db` on a cron — the files are
just files.)

