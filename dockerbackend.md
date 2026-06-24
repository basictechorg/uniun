Good — I have enough to draft the dockerization. Before I start, let me ask
  for the few server-side things I actually need so I don't guess. A short list
  of questions and you can dump answers from the VM in one go.

  What I need from the server

  Please paste outputs of these on the VM:

  # 1. PM2 process details — env vars, working dir, args, log paths
  pm2 describe uniun-backend

  # 2. nginx vhost — show me how /relay or wss:// is proxied
  sudo cat /etc/nginx/sites-enabled/* 2>/dev/null | grep -A 50 -i "uniun\|8080\|relay" | head -100

  # 3. Where the BadgerDB lives + size (we need to mount it as a volume)
  ls -la /home/azureuser/uniun/uniun-backend/db/ 2>&1 | head -10
  du -sh /home/azureuser/uniun/uniun-backend/db/ 2>&1

  # 4. The env file (REDACT secrets when pasting — I just need the KEY names)
  ls -la /home/azureuser/uniun/uniun-backend/.env*
  /home/azureuser/uniun/uniun-backend/*.env 2>/dev/null
  # OR if PM2 has env inline:
  pm2 env <id>   # use the id from `pm2 list`

  # 5. TLS — Let's Encrypt or self-managed? Where do certs live?
  sudo ls /etc/letsencrypt/live/ 2>&1

  # 6. Docker presence check
  docker --version 2>&1
  docker compose version 2>&1

  What the Docker migration will look like (preview so you can sanity-check)

  uniun-backend/
  ├── Dockerfile                  ← multi-stage Go build → distroless runtime
  ├── docker-compose.yml          ← relay + named volume for BadgerDB + .env
  ├── .dockerignore               ← skips db/, uniun.log, .git
  ├── .env.example                ← documented template, no secrets
  └── ... (existing Go source)

  Dockerfile shape:
  - Stage 1 (golang:1.25-alpine): go mod download && go build -trimpath 
  -ldflags="-s -w" → static binary
  - Stage 2 (gcr.io/distroless/static-debian12:nonroot): copy binary + run as
  nonroot uid 65532
  - EXPOSE 8080, VOLUME /data, WORKDIR /app
  - WORKING_DIR=/data so BadgerDB persists across container rebuilds via a named
  volume / bind mount

  docker-compose.yml shape:
  - Service relay on a custom bridge network, restart=unless-stopped
  - Reads .env, mounts ./db (or named volume) at /data/db
  - Binds 127.0.0.1:8080:8080 — nginx already terminates TLS and proxies to
  localhost, so no need to expose 8080 publicly
  - Healthcheck via wget -qO- http://localhost:8080/ (Khatru returns NIP-11 doc
  on GET)

  Migration script (one-shot, idempotent):
  - pm2 stop uniun-backend && pm2 delete uniun-backend && pm2 save
  - Copy existing db/ into new volume mount path (or just point to it — Badger
  files are portable)
  - docker compose up -d
  - Verify docker logs -f uniun-backend then re-check nginx still proxies fine

  nginx: probably zero changes needed if your current vhost already proxies to
  127.0.0.1:8080. If it proxies to a unix socket or PM2's port, send me the
  snippet and I'll adjust.

  What I want to confirm before writing code

  1. go 1.25.0 in go.mod is unusual — that version doesn't exist as a stable
  release yet (current stable is 1.23.x). Did you bump it to test? I'll pin the
  Dockerfile base to golang:1.23-alpine and revert go.mod to go 1.23 unless you
  tell me otherwise. Confirm what Go version actually compiles this locally.
  2. MySQL mirror — MYSQL_DSN env var exists. Are you using it in prod? If yes,
  do you want MySQL in the same compose file or stays external?
  3. BadgerDB data path — I see references to path.Join(config.WorkingDirectory,
  "/db") and your VM has it at /home/azureuser/uniun/uniun-backend/db/. Want
  to:
    - (a) Bind-mount the existing path into the container (zero data movement,
  easy rollback), or
    - (b) Create a Docker named volume and cp -r the data into it (cleaner, but
  the data is now invisible from the host)?

  I'd recommend (a) for the first migration — easier to rollback to PM2 if
  anything goes wrong.
  4. Azure blob creds — AZURE_STORAGE_ACCOUNT_KEY needs to be in the compose
  .env. Are you OK with that in a file on the VM, or do you want it pulled from
  a secret manager (Docker secrets, Azure Key Vault)? For the first cut I'll
  just use .env with chmod 600.
  5. Issue #90 — I don't have access to your private repo from here. Paste the
  issue body if there are specific acceptance criteria (e.g. "container must
  restart on crash", "must support zero-downtime deploys", "must work behind
  nginx", etc).

  Order of operations

  Once you've answered the above:

  1. I write Dockerfile, docker-compose.yml, .dockerignore, .env.example in
  uniun-backend/.
  2. I write uniun-backend/DEPLOY.md with exact migration commands (the PM2-stop 
  → docker-up dance).
  3. You run docker compose build locally to confirm the image builds.   
  4. On the VM: stop pm2, run the migration script, verify relay still answers,
  verify nginx still proxies.
  5. If green: pm2 delete uniun-backend permanently. If not: docker compose down
  and pm2 start to roll back. 
 
  Send the answers + the dumps above and I'll write the files.


from the server 


samarthsinh@samarthsinh-IdeaPad:~/Desktop/Work/payroll$ uniun-server
Welcome to Ubuntu 20.04.6 LTS (GNU/Linux 5.15.0-1089-azure x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/pro

 * Strictly confined Kubernetes makes edge and IoT secure. Learn how MicroK8s
   just raised the bar for easy, resilient and secure K8s cluster deployment.

   https://ubuntu.com/engage/secure-kubernetes-at-the-edge

Expanded Security Maintenance for Infrastructure is not enabled.

18 updates can be applied immediately.
To see these additional updates run: apt list --upgradable

184 additional security updates can be applied with ESM Infra.
Learn more about enabling ESM Infra service for Ubuntu 20.04 at
https://ubuntu.com/20-04

New release '22.04.5 LTS' available.
Run 'do-release-upgrade' to upgrade to it.


Last login: Sat Jun 20 05:55:17 2026 from 103.249.233.123
azureuser@sharedVM:~$ pm2 describe uniun-backend

>>>> In-memory PM2 is out-of-date, do:
>>>> $ pm2 update
In memory PM2 version: 6.0.10
Local PM2 version: 6.0.14

 Describing process with id 7 - name uniun-backend 
┌───────────────────┬───────────────────────────────────────────────────┐
│ status            │ online                                            │
│ name              │ uniun-backend                                     │
│ namespace         │ default                                           │
│ version           │ N/A                                               │
│ restarts          │ 1                                                 │
│ uptime            │ 6D                                                │
│ script path       │ /home/azureuser/uniun/uniun-backend/uniun         │
│ script args       │ N/A                                               │
│ error log path    │ /home/azureuser/.pm2/logs/uniun-backend-error.log │
│ out log path      │ /home/azureuser/.pm2/logs/uniun-backend-out.log   │
│ pid path          │ /home/azureuser/.pm2/pids/uniun-backend-7.pid     │
│ interpreter       │ none                                              │
│ interpreter args  │ N/A                                               │
│ script id         │ 7                                                 │
│ exec cwd          │ /home/azureuser/uniun/uniun-backend               │
│ exec mode         │ fork_mode                                         │
│ node.js version   │ N/A                                               │
│ node env          │ N/A                                               │
│ watch & reload    │ ✘                                                 │
│ unstable restarts │ 0                                                 │
│ created at        │ 2026-06-14T10:37:33.568Z                          │
└───────────────────┴───────────────────────────────────────────────────┘
 Divergent env variables from local env 
┌────────────────┬──────────────────────┐
│ SSH_AUTH_SOCK  │ /tmp/ssh-fXNbBZ6zO3/ │
│ PWD            │ /home/azureuser/uniu │
│ SSH_CONNECTION │ 103.86.19.66 22344 1 │
│ XDG_SESSION_ID │ 66429                │
│ SSH_CLIENT     │ 103.86.19.66 22344 2 │
│ SSH_TTY        │ /dev/pts/1           │
└────────────────┴──────────────────────┘

 Add your own code metrics: http://bit.ly/code-metrics
 Use `pm2 logs uniun-backend [--lines 1000]` to display logs
 Use `pm2 env 7` to display environment variables
 Use `pm2 monit` to monitor CPU and Memory usage uniun-backend
azureuser@sharedVM:~$ sudo cat /etc/nginx/sites-enabled/* 2>/dev/null | grep -A 50 -i
Usage: grep [OPTION]... PATTERNS [FILE]...
Try 'grep --help' for more information.
azureuser@sharedVM:~$   "uniun\|8080\|relay" | head -100
uniun\|8080\|relay: command not found
azureuser@sharedVM:~$ sudo cat /etc/nginx/sites-enabled/* 2>/dev/null | grep -A 50 -i "uniun\|8080\|relay" | head -100
    server_name dev.uniun.in;

    # WS (non-SSL)
    location / {
        proxy_pass http://localhost:8082;
        proxy_http_version 1.1;

        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
    }
}

server {
    listen 8080 ssl;
    server_name dev.uniun.in;

    ssl_certificate /etc/letsencrypt/live/dev.uniun.in/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/dev.uniun.in/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # WSS (SSL)
    location / {
        proxy_pass http://localhost:8082;
        proxy_http_version 1.1;

        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
    }
}
azureuser@sharedVM:~$ ls -la /home/azureuser/uniun/uniun-backend/db/ 2>&1 | head -10
total 392
drwx------ 2 azureuser azureuser       4096 Jun 14 10:37 .
drwxrwxr-x 3 azureuser azureuser       4096 May 25 09:35 ..
-rw-rw-r-- 1 azureuser azureuser     268674 Jun 14 10:37 000001.sst
-rw-rw-r-- 1 azureuser azureuser         20 Jun 14 10:37 000001.vlog
-rw-rw-r-- 1 azureuser azureuser 2147483646 Jun 14 10:37 000002.vlog
-rw-rw-r-- 1 azureuser azureuser  134217728 Jun 19 20:53 00002.mem
-rw-rw-r-- 1 azureuser azureuser    1048576 May 25 09:32 DISCARD
-rw------- 1 azureuser azureuser         28 May 25 09:32 KEYREGISTRY
-rw-rw-r-- 1 azureuser azureuser          7 Jun 14 10:37 LOCK
azureuser@sharedVM:~$ du -sh /home/azureuser/uniun/uniun-backend/db/ 2>&1
388K	/home/azureuser/uniun/uniun-backend/db/
azureuser@sharedVM:~$ ls -la /home/azureuser/uniun/uniun-backend/.env*
ls: cannot access '/home/azureuser/uniun/uniun-backend/.env*': No such file or directory
azureuser@sharedVM:~$ pm2 list

>>>> In-memory PM2 is out-of-date, do:
>>>> $ pm2 update
In memory PM2 version: 6.0.10
Local PM2 version: 6.0.14

┌────┬────────────────────┬──────────┬──────┬───────────┬──────────┬──────────┐
│ id │ name               │ mode     │ ↺    │ status    │ cpu      │ memory   │
├────┼────────────────────┼──────────┼──────┼───────────┼──────────┼──────────┤
│ 0  │ hillsquills        │ fork     │ 0    │ online    │ 0%       │ 35.7mb   │
│ 5  │ political-dashboa… │ fork     │ 10   │ online    │ 0%       │ 35.9mb   │
│ 7  │ uniun-backend      │ fork     │ 1    │ online    │ 0%       │ 70.3mb   │
└────┴────────────────────┴──────────┴──────┴───────────┴──────────┴──────────┘
azureuser@sharedVM:~$ pm2 env 7

>>>> In-memory PM2 is out-of-date, do:
>>>> $ pm2 update
In memory PM2 version: 6.0.10
Local PM2 version: 6.0.14

AZURE_FOR_BLOSSOM: true
namespace: default
km_link: false
vizion_running: false
NODE_APP_INSTANCE: 0
SHELL: /bin/bash
NVM_INC: /home/azureuser/.nvm/versions/node/v18.20.7/include/node
SSH_AUTH_SOCK: /tmp/ssh-fXNbBZ6zO3/agent.1922767
PWD: /home/azureuser/uniun/uniun-backend
LOGNAME: azureuser
XDG_SESSION_TYPE: tty
MOTD_SHOWN: pam
HOME: /home/azureuser
LANG: C.UTF-8
LS_COLORS: rs=0:di=01;34:ln=01;36:mh=00:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:mi=00:su=37;41:sg=30;43:ca=30;41:tw=30;42:ow=34;42:st=37;44:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arc=01;31:*.arj=01;31:*.taz=01;31:*.lha=01;31:*.lz4=01;31:*.lzh=01;31:*.lzma=01;31:*.tlz=01;31:*.txz=01;31:*.tzo=01;31:*.t7z=01;31:*.zip=01;31:*.z=01;31:*.dz=01;31:*.gz=01;31:*.lrz=01;31:*.lz=01;31:*.lzo=01;31:*.xz=01;31:*.zst=01;31:*.tzst=01;31:*.bz2=01;31:*.bz=01;31:*.tbz=01;31:*.tbz2=01;31:*.tz=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.war=01;31:*.ear=01;31:*.sar=01;31:*.rar=01;31:*.alz=01;31:*.ace=01;31:*.zoo=01;31:*.cpio=01;31:*.7z=01;31:*.rz=01;31:*.cab=01;31:*.wim=01;31:*.swm=01;31:*.dwm=01;31:*.esd=01;31:*.jpg=01;35:*.jpeg=01;35:*.mjpg=01;35:*.mjpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.svg=01;35:*.svgz=01;35:*.mng=01;35:*.pcx=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.m2v=01;35:*.mkv=01;35:*.webm=01;35:*.ogm=01;35:*.mp4=01;35:*.m4v=01;35:*.mp4v=01;35:*.vob=01;35:*.qt=01;35:*.nuv=01;35:*.wmv=01;35:*.asf=01;35:*.rm=01;35:*.rmvb=01;35:*.flc=01;35:*.avi=01;35:*.fli=01;35:*.flv=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.yuv=01;35:*.cgm=01;35:*.emf=01;35:*.ogv=01;35:*.ogx=01;35:*.aac=00;36:*.au=00;36:*.flac=00;36:*.m4a=00;36:*.mid=00;36:*.midi=00;36:*.mka=00;36:*.mp3=00;36:*.mpc=00;36:*.ogg=00;36:*.ra=00;36:*.wav=00;36:*.oga=00;36:*.opus=00;36:*.spx=00;36:*.xspf=00;36:
LC_TERMINAL: iTerm2
SSH_CONNECTION: 103.86.19.66 22344 10.0.0.4 22
NVM_DIR: /home/azureuser/.nvm
SGX_AESM_ADDR: 1
LESSCLOSE: /usr/bin/lesspipe %s %s
XDG_SESSION_CLASS: user
TERM: xterm-256color
LESSOPEN: | /usr/bin/lesspipe %s
USER: azureuser
LC_TERMINAL_VERSION: 3.6.9
SHLVL: 1
NVM_CD_FLAGS: 
XDG_SESSION_ID: 66429
XDG_RUNTIME_DIR: /run/user/1000
SSH_CLIENT: 103.86.19.66 22344 22
XDG_DATA_DIRS: /usr/local/share:/usr/share:/var/lib/snapd/desktop
PATH: /home/azureuser/.local/bin:/home/azureuser/.nvm/versions/node/v18.20.7/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin:/usr/local/go/bin
DBUS_SESSION_BUS_ADDRESS: unix:path=/run/user/1000/bus
NVM_BIN: /home/azureuser/.nvm/versions/node/v18.20.7/bin
SSH_TTY: /dev/pts/1
OLDPWD: /home/azureuser/uniun
_: /usr/local/bin/pm2
PM2_USAGE: CLI
PM2_HOME: /home/azureuser/.pm2
unique_id: cf775e2a-487d-45cc-8ca8-ccfd619b1296
version: N/A
azureuser@sharedVM:~$ sudo ls /etc/letsencrypt/live/ 2>&1
README	dev.uniun.in  www.kumbhmilan.in
azureuser@sharedVM:~$ docker --version
Docker version 26.1.3, build 26.1.3-0ubuntu1~20.04.1
azureuser@sharedVM:~$ docker compsoe version
docker: 'compsoe' is not a docker command.
See 'docker --help'
azureuser@sharedVM:~$ docker-compose version
Docker Compose version v2.33.1
azureuser@sharedVM:~$ 

## important thing for the backend has the config.go for the config ass env also and for the blossom it set false even in the production server also it set flase in that file but manual at the pm2 env it is set true so we also have to change that to true

 sudo grep -RIl "AZURE_STORAGE_ACCOUNT_KEY\|AzStorageAccountKey" \ /home/azureuser /etc 2>/dev/null
azureuser@sharedVM:~$ sudo grep -RIl "AZURE_STORAGE_ACCOUNT_KEY\|AzStorageAccountKey"
inventory-management-system-backend/.env.development.local
inventory-management-system-backend/src/services/backup.service.ts
inventory-management-system-backend/src/config/env.ts
go/pkg/mod/github.com/!azure/azure-sdk-for-go/sdk/storage/azblob@v1.6.4/service/client_test.go
go/pkg/mod/github.com/!azure/azure-sdk-for-go/sdk/storage/azblob@v1.6.4/service/examples_test.go
go/pkg/mod/github.com/!azure/azure-sdk-for-go/sdk/storage/azblob@v1.6.4/blockblob/client_test.go
go/pkg/mod/github.com/!azure/azure-sdk-for-go/sdk/storage/azblob@v1.6.4/blockblob/examples_test.go
go/pkg/mod/github.com/!azure/azure-sdk-for-go/sdk/storage/azblob@v1.6.4/doc.go
go/pkg/mod/github.com/!azure/azure-sdk-for-go/sdk/storage/azblob@v1.6.4/lease/examples_test.go
go/pkg/mod/github.com/!azure/azure-sdk-for-go/sdk/storage/azblob@v1.6.4/test-resources.json
go/pkg/mod/github.com/!azure/azure-sdk-for-go/sdk/storage/azblob@v1.6.4/examples_test.go
go/pkg/mod/github.com/!azure/azure-sdk-for-go/sdk/storage/azblob@v1.6.4/sas/examples_test.go
go/pkg/mod/github.com/!azure/azure-sdk-for-go/sdk/storage/azblob@v1.6.4/appendblob/client_test.go
go/pkg/mod/github.com/!azure/azure-sdk-for-go/sdk/storage/azblob@v1.6.4/pageblob/client_test.go
go/pkg/mod/github.com/!azure/azure-sdk-for-go/sdk/storage/azblob@v1.6.4/internal/testcommon/clients_auth.go
go/pkg/mod/github.com/!azure/azure-sdk-for-go/sdk/storage/azblob@v1.6.4/container/examples_test.go
go/pkg/mod/github.com/!azure/azure-sdk-for-go/sdk/storage/azblob@v1.6.4/blob/client_test.go
go/pkg/mod/github.com/!azure/azure-sdk-for-go/sdk/storage/azblob@v1.6.4/blob/examples_test.go
uniun/docs/BACKEND.md
uniun/uniun-backend/config.go
uniun/uniun-backend/azure_blob.go
.viminfo
grep: .pm2/rpc.sock: No such device or address
grep: .pm2/pub.sock: No such device or address
azureuser@sharedVM:~$ 

azureuser@sharedVM:~$ sudo cat /etc/nginx/sites-enabled/uniun* 2>/dev/null
server {
    listen 8081;
    server_name dev.uniun.in;

    # WS (non-SSL)
    location / {
        proxy_pass http://localhost:8082;
        proxy_http_version 1.1;

        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
    }
}

server {
    listen 8080 ssl;
    server_name dev.uniun.in;

    ssl_certificate /etc/letsencrypt/live/dev.uniun.in/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/dev.uniun.in/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # WSS (SSL)
    location / {
        proxy_pass http://localhost:8082;
        proxy_http_version 1.1;

        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
    }
}


## The "AZURE_FOR_BLOSSOM" default question — should we flip the default in   config.go to `true`, or keep the env-override discipline(You said "we also have to change that to true". Confirm you mean source default.) yes change it from the backend file 
