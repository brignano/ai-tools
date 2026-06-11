---
description: Deploy a local app to the homelab for friends to preview via Cloudflare Tunnel, then tear it down
argument-hint: [app dir] [port] [hostname]
---

**Purpose:** Deploy a local app to the homelab for friends to preview via Cloudflare Tunnel, then tear it down when done.

Parse **$ARGUMENTS** for the app directory, port, and public hostname if provided; ask for any that are missing.

## Inputs required
- App directory path
- Port the app listens on
- Public hostname to expose (e.g. `preview.yourdomain.com`)
- How long to keep it up (or "until I say so")

## Steps

### Deploy
1. Check that a `Dockerfile` or `docker-compose.yml` exists in the app directory
2. If Dockerfile only: build an image tagged `preview-<appname>:latest`
3. Create a minimal `docker-compose.yml` in a temp location:
   - Image: the built image or the compose service
   - Port: `127.0.0.1:<port>:<port>`
   - Network: joins `tunnel_tunnel` so cloudflared can proxy to it
   - Restart: `no` (preview — don't restart on reboot)
4. Bring it up: `docker compose up -d`
5. Add the public hostname route in Cloudflare Zero Trust (provide the dashboard URL and exact settings)
6. Confirm it's reachable by curling the internal address

### Tear down
1. `docker compose down` for the preview stack
2. Remind me to remove the Public Hostname route from Cloudflare Zero Trust dashboard
3. If a preview image was built: `docker rmi preview-<appname>:latest`
