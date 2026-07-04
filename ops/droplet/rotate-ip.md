# Rotating the droplet's public IP (retiring the leaked address)

The droplet's original public IP was committed to this public repo. The only way
to make that leaked address *worthless* is to stop using it — DigitalOcean cannot
change a droplet's native IPv4 in place, so we snapshot the current box, recreate
from the snapshot (new native IP), then destroy the old droplet (releases the old
IP back to DO's pool).

Bonus: once the old droplet is destroyed, the IP still sitting in git **history**
points at nothing, so **no history rewrite is needed** — the leak is neutralized
at the source.

> ⚠️ Never commit the new IP. It goes in the `DO_HOST` GitHub secret and is shared
> with friends **out of band** (Discord/text), not in this repo. The repo now
> uses a `<DROPLET_IP>` placeholder everywhere and gitignores droplet-local config.

---

## Steps (all in the DigitalOcean dashboard / your machine)

### 1. Snapshot the current droplet
DO dashboard → the droplet → **Snapshots** → **Take Snapshot** (name it e.g.
`epoch-pre-rotate`). Powering off first gives the cleanest snapshot; a live
snapshot is usually fine for this stack. This captures the built image, the
`/opt/epoch` clone, Docker, swap, and any hand-setup — so you don't rebuild.

### 2. (Recommended) Create a Reserved IP for future-proofing
DO → **Networking → Reserved IPs** → reserve one in the droplet's region. Assign
it to the *new* droplet in step 3. A Reserved IP can be detached/reattached
between droplets, so future session-droplets can reuse one stable address you
control — and you rotate it by moving it, without ever leaking a native IP again.
(Optional; skip if you'd rather just use the new native IP.)

### 3. Recreate from the snapshot
DO → **Create → Droplets → Snapshots** tab → pick `epoch-pre-rotate` → same
region, same size (2 vCPU / 3.8 GB was the baseline; bump to 8 GB if you want
headroom for a populated session — see the roadmap sizing notes) → **add your SSH
key at creation** (don't rely on password auth). The new droplet boots with a
**new native public IP**. Assign the Reserved IP from step 2 now if using one.

### 4. Point everything at the new address
- **GitHub secret**: repo → Settings → Secrets and variables → Actions →
  update **`DO_HOST`** to the new IP (or the Reserved IP). The deploy workflow
  re-scans the host key each run (`ssh-keyscan`), so nothing else changes there.
- **Your `~/.ssh/known_hosts`**: remove the stale old-IP line to avoid a host-key
  mismatch warning: `ssh-keygen -R <OLD_IP>` (and `-R <NEW_IP>` is unnecessary;
  it'll be added on first connect).
- **Friends**: send them the new address (or Reserved IP) out of band.

### 5. Verify the new droplet
```bash
ssh root@<NEW_IP>            # key auth, no password prompt
# on the box:
cd /opt/epoch && docker compose ps       # game container up?
curl -fsS http://localhost:8080/ >/dev/null && echo "game OK"
```
Then run the lockdown on the NEW droplet (it's a fresh box):
`harden-droplet.sh` + Caddy gate + DO Cloud Firewall — see `README.md`. (If you
snapshotted *after* already hardening, verify the rules carried over instead.)

### 6. Destroy the old droplet — this releases the leaked IP
Once the new droplet is confirmed healthy and locked down: DO → the **old**
droplet → **Destroy**. The old IP (the leaked one) is released. Anyone hitting it
later reaches either nothing or, eventually, an unrelated DO customer — your box
is no longer there. **Leak neutralized.**

### 7. (Optional) Delete the snapshot
Snapshots cost a little per month. Once the new droplet is proven, delete
`epoch-pre-rotate` unless you want it as a rebuild baseline.

---

## After rotation: history rewrite is unnecessary
Because the leaked IP no longer points at your infrastructure, its presence in old
commits is harmless — it's a dead address. You can skip `git filter-repo`. (If you
still want it gone for tidiness later, it's a separate, destructive force-push
step — ask and I'll walk through it.)

## Savegame note
This stack keeps game state inside the container's `data` volume. If a live game's
save matters, copy it off the OLD droplet before destroying it (or take the
snapshot while the save exists — the snapshot includes the volume). Decoupled
savegame persistence (Volume/Spaces) is tracked as future ephemeral-lifecycle work
in the roadmap.
