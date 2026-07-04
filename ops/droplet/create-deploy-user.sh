#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# create-deploy-user.sh — dedicated low(er)-privilege user for the GitHub
# Actions deploy workflow, instead of using the deploy key with root.
#
# Run this ON THE DROPLET as root (or via sudo):
#     scp ops/droplet/create-deploy-user.sh root@<DROPLET_IP>:/root/
#     ssh root@<DROPLET_IP> 'bash /root/create-deploy-user.sh <PUBKEY_FILE_OR_STRING>'
#
# Idempotent — safe to re-run (e.g. to rotate the key: just re-run with a new
# pubkey and it replaces authorized_keys).
#
# ── What this does ───────────────────────────────────────────────────────────
#   1. Creates system user "epochdeploy" (no login shell needed beyond SSH+git,
#      but we give it bash so `docker compose` etc. work over the SSH command).
#   2. Adds it to the `docker` group so `docker compose build/up` works without
#      sudo — NOTE: docker-group membership is root-equivalent for the whole
#      host via the Docker socket (well-known Docker caveat). This user is an
#      audit/rotation boundary, not a hard security sandbox — see the header
#      note in ops/droplet/README.md.
#   3. Grants ownership of /opt/epoch to this user (git fetch/checkout need
#      write access to the working tree and .git).
#   4. Installs the given SSH public key into its authorized_keys (key-only;
#      no password set on this account at all).
#
# ── Usage ─────────────────────────────────────────────────────────────────────
#   Pass either a path to a .pub file readable on the droplet, or the raw
#   public-key string, as $1:
#     bash create-deploy-user.sh /root/epoch_deploy.pub
#     bash create-deploy-user.sh "ssh-ed25519 AAAA... epoch-deploy"
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then echo "Run as root (or: sudo bash $0 <pubkey-or-path>)"; exit 1; fi
if [ $# -lt 1 ] || [ -z "$1" ]; then
  echo "Usage: $0 <path-to-pubkey-file OR raw public-key string>"
  exit 1
fi

log() { printf '\n\033[1;32m==> %s\033[0m\n' "$*"; }

USER_NAME="epochdeploy"
REPO_DIR="/opt/epoch"

# Accept either a file path or a raw key string.
if [ -f "$1" ]; then
  PUBKEY="$(cat "$1")"
else
  PUBKEY="$1"
fi
case "$PUBKEY" in
  ssh-ed25519\ *|ssh-rsa\ *|ecdsa-sha2-*\ *) ;;
  *) echo "That doesn't look like an SSH public key (expected ssh-ed25519/ssh-rsa/... prefix)."; exit 1 ;;
esac

log "Creating user '$USER_NAME' (if not present)"
if ! id -u "$USER_NAME" >/dev/null 2>&1; then
  useradd -m -s /bin/bash "$USER_NAME"
else
  echo "  already exists, continuing"
fi

log "Adding '$USER_NAME' to the docker group"
usermod -aG docker "$USER_NAME"

log "Installing SSH key (key-only, no password login on this account)"
install -d -m 700 -o "$USER_NAME" -g "$USER_NAME" "/home/$USER_NAME/.ssh"
printf '%s\n' "$PUBKEY" > "/home/$USER_NAME/.ssh/authorized_keys"
chmod 600 "/home/$USER_NAME/.ssh/authorized_keys"
chown "$USER_NAME:$USER_NAME" "/home/$USER_NAME/.ssh/authorized_keys"
passwd -l "$USER_NAME" >/dev/null   # lock password auth for this account entirely

log "Granting ownership of $REPO_DIR to '$USER_NAME'"
if [ -d "$REPO_DIR" ]; then
  chown -R "$USER_NAME:$USER_NAME" "$REPO_DIR"
else
  echo "  $REPO_DIR does not exist yet — clone it as $USER_NAME once the account exists:"
  echo "    sudo -u $USER_NAME git clone https://github.com/jnorha/epoch-freeciv.git $REPO_DIR"
fi

log "Verifying docker access for '$USER_NAME'"
if sudo -u "$USER_NAME" docker ps >/dev/null 2>&1; then
  echo "  OK — docker ps works as $USER_NAME (group membership takes effect on next SSH session)"
else
  echo "  NOTE: group membership needs a fresh login to take effect — this will work over a"
  echo "  new SSH connection even though it just failed in this same shell."
fi

log "Done."
cat <<EOF

Next:
  1. Set the GitHub repo secret DO_USER = $USER_NAME  (was probably "root")
  2. DO_SSH_KEY stays the PRIVATE half matching the pubkey you just installed.
  3. Test:  ssh $USER_NAME@<DROPLET_IP> 'docker compose -f $REPO_DIR/docker-compose.yml ps'
  4. (Optional, tighter) restrict this user's sudo/root entirely — it already has
     no password and no sudoers entry by default on Ubuntu, so this is done
     unless something else granted it.
EOF
