# Imaginea „stiva Macro într-un singur container".
#
# Macro nu are o stivă de self-hosting: singurul mod suportat de a rula produsul
# complet este stiva locală (`just stack up`), care pornește ea însăși ~25 de
# containere prin docker compose. Previzualizările oficiale pe Fly fac exact
# asta într-o mașină virtuală, cu un daemon Docker interior — vezi
# `infra/preview/` din depozit. Această imagine este același model, pentru
# Coolify: Docker-in-Docker plus lanțul de compilare Nix al depozitului.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      docker.io \
      docker-buildx \
      docker-compose-v2 \
      git \
      iproute2 \
      iptables \
      jq \
      sudo \
      xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Nix, instalare single-user. Lanțul de compilare (Rust, cargo-zigbuild, Zig,
# Bun, sqlx-cli, just) vine din `flake.nix` al depozitului, deci versiunile sunt
# cele pe care le folosesc dezvoltatorii Macro. `filter-syscalls = false` este
# necesar în container; sandbox-ul Nix nu poate rula aici.
RUN curl -L https://nixos.org/nix/install -o /tmp/nix-install.sh \
    && sh /tmp/nix-install.sh --no-daemon \
    && rm /tmp/nix-install.sh \
    && mkdir -p /etc/nix \
    && printf 'experimental-features = nix-command flakes\nfilter-syscalls = false\nsandbox = false\n' > /etc/nix/nix.conf

ENV PATH=/root/.nix-profile/bin:/root/.local/state/nix/profile/bin:$PATH

COPY entrypoint.sh /srv/entrypoint.sh
RUN chmod +x /srv/entrypoint.sh

# Portul proxy-ului Caddy al stivei — o singură origine pentru frontend, API-uri,
# WebSocket și Mailpit.
EXPOSE 8090

ENTRYPOINT ["/srv/entrypoint.sh"]
