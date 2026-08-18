#!/usr/bin/env bash
# Pornire: daemon Docker interior -> depozit -> `just stack up`.
#
# Tot ce este scump (clonarea, compilarea Rust, pachetul frontend, migrările,
# indexurile de căutare) se face la prima pornire și rămâne pe volumele
# persistente. Repornirile ulterioare refolosesc cache-ul.
set -euo pipefail

REPO_URL="${MACRO_REPO_URL:-https://github.com/macro-inc/macro.git}"
REPO_REF="${MACRO_REPO_REF:-main}"
REPO_DIR=/srv/macro/repo
ENV_OVERLAY=/srv/macro/env/overlay.env

log() { echo "[macro] $*"; }

log "pornesc dockerd"
dockerd >/var/log/dockerd.log 2>&1 &

for _ in $(seq 1 120); do
  docker info >/dev/null 2>&1 && break
  sleep 1
done
if ! docker info >/dev/null 2>&1; then
  log "dockerd nu a pornit:"
  tail -n 50 /var/log/dockerd.log
  exit 1
fi
log "dockerd este gata"

# Containere rămase de la o pornire anterioară a aceluiași volum: `stack up` le
# recreează oricum, dar unul cu politică de restart poate răspunde pe :8090 cu
# stiva veche înainte ca cea nouă să existe.
stale="$(docker ps -q)"
if [ -n "$stale" ]; then
  log "opresc $(echo "$stale" | wc -l) containere rămase din rularea anterioară"
  echo "$stale" | xargs -r docker kill >/dev/null 2>&1 || true
fi

mkdir -p /srv/macro "$(dirname "$ENV_OVERLAY")"

if [ ! -d "$REPO_DIR/.git" ]; then
  log "clonez $REPO_URL ($REPO_REF)"
  git clone "$REPO_URL" "$REPO_DIR"
fi

cd "$REPO_DIR"
if [ "${MACRO_AUTO_UPDATE:-true}" = "true" ]; then
  log "aduc $REPO_REF"
  git fetch --tags origin "$REPO_REF"
  git checkout -f "$REPO_REF"
  git reset --hard "origin/$REPO_REF" 2>/dev/null || true
fi
log "depozit la $(git rev-parse --short HEAD)"

# Secretele de integrare (chei AI etc.). Modul local nu are nevoie de niciunul
# ca să pornească: infrastructura este definită în cod (LocalStack, Mailpit,
# FusionAuth cu identitate fixă). Ce este dat aici se suprapune peste ele.
env_args=()
if [ -n "${MACRO_ENV_OVERLAY:-}" ]; then
  log "scriu $ENV_OVERLAY din variabila MACRO_ENV_OVERLAY"
  printf '%s\n' "$MACRO_ENV_OVERLAY" > "$ENV_OVERLAY"
fi
if [ -s "$ENV_OVERLAY" ]; then
  log "suprapun $ENV_OVERLAY"
  env_args=(--env-file "$ENV_OVERLAY")
fi

log "ridic stiva (prima pornire compilează tot depozitul — durează mult)"
nix develop --command just stack up --no-doppler "${env_args[@]}"

log "stiva este pornită — proxy pe :8090"
nix develop --command just stack status || true

exec sleep infinity
