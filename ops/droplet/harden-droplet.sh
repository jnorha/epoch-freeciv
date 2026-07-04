#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# harden-droplet.sh — one-shot SSH + host hardening for palatine-ov2 (Ubuntu 24.04)
#
# Run this ON THE DROPLET as root (or via sudo), e.g.:
#     scp ops/droplet/harden-droplet.sh root@<DROPLET_IP>:/root/
#     ssh root@<DROPLET_IP> 'bash /root/harden-droplet.sh'
#
# It is idempotent — safe to re-run. It does NOT touch Docker or the game
# container. It hardens the HOST: SSH daemon, fail2ban, ufw, auto security
# updates.
#
# ── IMPORTANT: what this can and cannot block ────────────────────────────────
#   * `ufw` here protects HOST services (SSH). It is defense-in-depth.
#   * `ufw` does NOT block Docker-published ports (8080/4002/6000-7009/8888):
#     Docker writes its own iptables rules that bypass ufw. The AUTHORITATIVE
#     control for those is the **DigitalOcean Cloud Firewall** (edge, applied
#     before traffic reaches the droplet). See ops/droplet/README.md — you MUST
#     set that up too; this script alone does not close the game/debug ports.
#   * The password gate for the game is Caddy (ops/droplet/Caddyfile.example), not this.
#
# ── SSH access note ──────────────────────────────────────────────────────────
#   This DISABLES SSH password authentication (key-only). Before it does, it
#   verifies at least one authorized_key exists for the current user and root,
#   and ABORTS if not (so you can't lock yourself out). Make sure your key works
#   BEFORE running: `ssh root@<DROPLET_IP>` should already succeed with no
#   password prompt.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then echo "Run as root (or: sudo bash $0)"; exit 1; fi

log() { printf '\n\033[1;32m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m!! %s\033[0m\n' "$*"; }

# ── 0. Lock-out guard: refuse to disable password auth without a working key ──
have_key=false
for f in /root/.ssh/authorized_keys "$(eval echo ~"${SUDO_USER:-root}")/.ssh/authorized_keys"; do
  if [ -s "$f" ]; then have_key=true; fi
done
if [ "$have_key" != true ]; then
  warn "No authorized_keys found for root or the invoking user."
  warn "Refusing to disable password auth — you would lock yourself out."
  warn "Add your public key first:  ssh-copy-id root@<host>   then re-run."
  exit 1
fi

# ── 1. Base packages ─────────────────────────────────────────────────────────
log "Installing fail2ban, ufw, unattended-upgrades"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq fail2ban ufw unattended-upgrades >/dev/null

# ── 2. SSH hardening (key-only, no root password, sane limits) ───────────────
log "Hardening sshd (key-only auth, no password login)"
mkdir -p /etc/ssh/sshd_config.d
cat > /etc/ssh/sshd_config.d/99-epoch-hardening.conf <<'EOF'
# Managed by ops/droplet/harden-droplet.sh — do not edit by hand.
PasswordAuthentication no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
PermitRootLogin prohibit-password
PubkeyAuthentication yes
PermitEmptyPasswords no
X11Forwarding no
MaxAuthTries 3
LoginGraceTime 20
ClientAliveInterval 300
ClientAliveCountMax 2
EOF
# Validate config before reloading so a typo can't brick sshd.
sshd -t && systemctl reload ssh
log "sshd reloaded — password auth is now OFF (key-only)."

# ── 3. fail2ban on sshd ──────────────────────────────────────────────────────
log "Enabling fail2ban sshd jail"
cat > /etc/fail2ban/jail.d/epoch-sshd.local <<'EOF'
[sshd]
enabled  = true
mode     = aggressive
maxretry = 4
findtime = 10m
bantime  = 1h
EOF
systemctl enable --now fail2ban >/dev/null
systemctl restart fail2ban

# ── 4. ufw (host-level defense-in-depth; see caveat in header) ───────────────
# Allow SSH (22), and HTTP/HTTPS (80/443) for the Caddy password-gate front end.
# We deliberately do NOT open 8080/4002/6000-7009/8888 — those must stay off the
# public internet (enforced at the DO Cloud Firewall; players reach the game
# only through Caddy on 80/443).
log "Configuring ufw (allow 22, 80, 443)"
ufw --force reset >/dev/null
ufw default deny incoming >/dev/null
ufw default allow outgoing >/dev/null
ufw allow 22/tcp   comment 'SSH (key-only; also used by GitHub Actions deploy)' >/dev/null
ufw allow 80/tcp   comment 'HTTP  -> Caddy password gate' >/dev/null
ufw allow 443/tcp  comment 'HTTPS -> Caddy password gate' >/dev/null
ufw --force enable >/dev/null
ufw status verbose

# ── 5. Automatic security updates ────────────────────────────────────────────
log "Enabling unattended security upgrades"
cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
systemctl enable --now unattended-upgrades >/dev/null 2>&1 || true

log "Host hardening complete."
cat <<'EOF'

NEXT (not done by this script — see ops/droplet/README.md):
  1. DigitalOcean Cloud Firewall (edge) — the real port lock for Docker ports.
     Inbound: 22 (SSH), 80 (HTTP), 443 (HTTPS). Nothing else.
  2. Caddy reverse proxy + basic auth — the password gate for the game
     (ops/droplet/Caddyfile).
  3. Verify you can still SSH in from a SECOND terminal BEFORE closing this one.
EOF
