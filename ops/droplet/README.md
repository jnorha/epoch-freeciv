# Droplet lockdown runbook — palatine-ov2 (<DROPLET_IP>)

Goal: let the friend group play over the WAN **without leaving an open,
unauthenticated public server**. The design:

```
              DigitalOcean Cloud Firewall  (edge — the real port lock)
                     │  allows only 22, 80, 443 inbound
                     ▼
   ┌─────────────────────────────────────────────────────────────┐
   │ droplet (Ubuntu 24.04)                                        │
   │                                                               │
   │  Caddy  :80/:443  ── basic_auth (shared password) ──┐         │
   │                                                     ▼         │
   │                          freeciv-web container  127.0.0.1:8080│
   │                          (nginx → Tomcat → freeciv-proxy →    │
   │                           civserver; the game WebSocket is    │
   │                           proxied inside the container)       │
   │                                                               │
   │  sshd :22  key-only + fail2ban  (host)                        │
   └───────────────────────────────────────────────────────────────┘
```

Two independent controls, both required:

| Control | What it does | Where |
|---|---|---|
| **DO Cloud Firewall** | Closes every port except 22/80/443 at the network edge. **This is the authoritative port lock** — `ufw` cannot block Docker-published ports (8080, 4002, 6000-7009, 8888), Docker's iptables bypass it. | DO dashboard |
| **Caddy + basic_auth** | Puts a shared-password prompt in front of the game. The only public HTTP door (80/443) is locked. | `Caddyfile.example` |
| SSH hardening | Key-only auth, no password login, fail2ban, auto security updates. Defense-in-depth for admin access. | `harden-droplet.sh` |

---

## Order of operations (do this exactly)

> ⚠️ Keep **two** SSH sessions open to the droplet the whole time. If a step
> breaks SSH, you fix it from the other session instead of getting locked out.

### 1. Confirm key auth works FIRST
From your machine: `ssh root@<DROPLET_IP>` must log in with **no password
prompt**. If it asks for a password, run `ssh-copy-id root@<DROPLET_IP>`
before going further. The hardening script aborts if it finds no authorized key,
but confirm anyway.

### 2. SSH + host hardening
```bash
scp ops/droplet/harden-droplet.sh root@<DROPLET_IP>:/root/
ssh root@<DROPLET_IP> 'bash /root/harden-droplet.sh'
```
Then, from a **second** terminal, verify you can still open a fresh SSH session.
Only once that works should you trust the change.

### 3. Caddy password gate
On the droplet:
```bash
# install caddy (see the header of ops/droplet/Caddyfile.example for the apt commands)
caddy hash-password --plaintext 'PICK-A-SHARED-PASSWORD'      # copy the $2a$... hash
```
Copy the template and fill it in (the filled-in `Caddyfile` is gitignored so the
password hash never lands in the repo):
```bash
cp ops/droplet/Caddyfile.example ops/droplet/Caddyfile   # then edit: replace REPLACE_ME_HASH
sudo cp ops/droplet/Caddyfile /etc/caddy/Caddyfile
sudo mkdir -p /var/log/caddy
sudo systemctl enable --now caddy
sudo systemctl reload caddy
```
Test locally on the droplet: `curl -sI http://127.0.0.1/` should return
`401 Unauthorized` (the gate is up), and `curl -sI -u epoch:PICK-A-SHARED-PASSWORD
http://127.0.0.1/` should return `200`.

### 4. DigitalOcean Cloud Firewall (the real port lock)
DO dashboard → **Networking → Firewalls → Create Firewall** → attach to
`palatine-ov2`. Inbound rules:

| Type | Protocol | Port | Sources |
|---|---|---|---|
| SSH | TCP | 22 | **See the :22 decision below** |
| HTTP | TCP | 80 | All IPv4 / All IPv6 |
| HTTPS | TCP | 443 | All IPv4 / All IPv6 |

Add **nothing else**. Leaving 8080/4002/6000-7009/8888 out of the list is what
closes them to the public — players reach the game only through Caddy on 80/443.
Outbound: leave the default allow-all.

### 5. Verify end to end
- From outside: `http://<DROPLET_IP>:8080/` should now **fail/time out**
  (good — the direct game port is closed at the edge).
- `http://<DROPLET_IP>/` should prompt for the password, then load the client.
- **Play-test the WebSocket with ONE friend before a real session** (see caveat).

---

## The `:22` decision (GitHub Actions deploy vs. tightest lockdown)

The deploy workflow (`.github/workflows/deploy-droplet.yml`) SSHes into the
droplet on port 22 from GitHub's runners, so how tight you make 22 is a tradeoff:

- **Recommended — 22 open to all sources, but key-only + fail2ban.** Password
  auth is off and fail2ban bans brute-forcers, so an open 22 is low-risk, and
  `git tag v… && git push --tags` keeps auto-deploying. This is what
  `harden-droplet.sh` sets up. Set the Cloud-Firewall SSH source to *All IPv4*.
- **Tighter — allowlist 22 to your home/office IP only.** Most secure, but it
  **breaks the GitHub Actions deploy** (runner IPs won't be in the allowlist).
  If you choose this, deploy by SSHing in manually and running the same steps
  (`cd /opt/epoch && git fetch && git checkout -f … && docker compose build &&
  docker compose up -d`), or self-host a runner. GitHub publishes its runner
  ranges (`https://api.github.com/meta`) but they're large and rotate — not
  worth allowlisting.

Pick one; the rest of the setup is identical.

---

## ⚠️ Caveat: verify the game WebSocket through Caddy before a real session

Web play rides a WebSocket that the container's nginx proxies internally, so a
same-origin connection through Caddy *should* just work (`reverse_proxy` upgrades
WS automatically). But the freeciv-web client can be finicky about how it builds
the socket URL. **Before you gather everyone**, have one friend connect through
`http://<DROPLET_IP>/`, enter the password, and actually start/join a game to
confirm the socket connects — not just that the page loads. If it fails to
connect, the fix is small (adjust the client's socket origin or add an explicit
`/civsocket` proxy path in the Caddyfile) — flag it and we'll sort it. Don't
discover this with five people waiting.

---

## What this does NOT change

- No repo/image changes — `docker-compose.yml` still publishes 8080 on the host;
  the Cloud Firewall (not compose) is what keeps it off the public internet, and
  Caddy reaches it via `127.0.0.1:8080`. (If you'd rather bind it to localhost in
  compose as belt-and-suspenders, change `"8080:80"` → `"127.0.0.1:8080:80"` and
  redeploy — optional, the edge firewall already covers it.)
- Savegame persistence / ephemeral-droplet automation is unrelated future work.
