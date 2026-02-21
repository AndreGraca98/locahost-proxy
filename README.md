# Overview

## Purpose

Provide a local Traefik-based reverse-proxy so you can open `*.docker` hostnames and have Traefik route them to app services running in other Docker Compose projects or on your host.

## Prerequisites

- `docker` and `docker compose` (Compose V2). If your system uses the legacy `docker-compose` binary, adjust commands accordingly.
- `just` (helper task runner). Install via your package manager (homebrew: `brew install just`) or see <https://github.com/casey/just>.

## Quickstart

1. Create the shared network (one-time):

```bash
just add-proxy-network
```

1. Add a TLD resolver and dnsmasq rule (example `.docker`):

```bash
just add-domain domain=docker
```

1. Start the proxy stack:

```bash
just run
```

Notes:

- The `add-resolver` and `clean-cache` tasks will prompt for `sudo` because they modify system DNS configuration on macOS.
- `clean-cache` is macOS-specific; Linux users may need different commands (see Troubleshooting).

## How it works

- Traefik listens on host ports 80/443 and routes to backend Docker services that share the external network `localhost_proxy_network`.
- Traefik will only route containers that set `traefik.enable=true` and are reachable on the shared network; routing rules are declared with Docker labels on your services.
- For `*.localhost` names you normally don't need extra DNS configuration; for custom TLDs (e.g. `.docker`) this repo uses `dnsmasq` plus an OS resolver file in `/etc/resolver/<tld>` so the OS forwards queries to the local dnsmasq instance.

## Add other domains

1. add a new line to `dnsmasq.conf` for your new TLD
(example `address=/.docker/127.0.0.1`)
2. add the host to your

## Routing & labels (current setup)

Traefik is configured to only route containers that set `traefik.enable=true`. Use labels in your app Compose to declare router rules and the internal port Traefik should target.

Example (other Compose project):

```yaml
services:
  api:
    image: your-api-image
    networks:
      - localhost_proxy_network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.api.rule=Host(`api.docker`)"
      - "traefik.http.routers.api.entrypoints=web"
      - "traefik.http.services.api.loadbalancer.server.port=80"

  docs:
    image: your-docs-image
    networks:
      - localhost_proxy_network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.docs.rule=Host(`docs.docker`)"
      - "traefik.http.routers.docs.entrypoints=web"
      - "traefik.http.services.docs.loadbalancer.server.port=8000"

```

## localhost-proxy

Local Traefik-based reverse-proxy for development. Routes `*.localhost` (and optionally other local TLDs such as `*.docker`) to services running in other Docker Compose projects via a shared Docker network.

## Components

- Traefik: HTTP reverse-proxy using the Docker provider. Only routes containers with `traefik.enable=true`.
- dnsmasq: provides local TLD support (e.g. `*.docker`) by answering DNS queries on `127.0.0.1`.
- shared Docker network: `localhost_proxy_network` (external) — used so Traefik can reach backend containers by service name.

### Notes about safety and options

- `sudo` is required for `/etc/resolver` and anything touching system DNS state on macOS.
- Prefer `killall -HUP mDNSResponder` over `killall -9` so the daemon can restart cleanly.
- The `justfile` uses `docker compose` (Compose V2). If you use `docker-compose` v1 adapt commands accordingly.

## Example: add `.docker` TLD and start proxy

```bash
just add-domain domain=docker
just up
```

Then in another project Compose file, join the `localhost_proxy_network` (declare it `external: true`) and add Traefik labels. Example snippet:

```yaml
services:
  app:
    image: your-image
    networks:
      - localhost_proxy_network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.app.rule=Host(`app.localhost`)"
      - "traefik.http.services.app.loadbalancer.server.port=80"

networks:
  localhost_proxy_network:
    external: true
```

## Troubleshooting

- Traefik doesn't route my container: verify the container has `traefik.enable=true` and is attached to `localhost_proxy_network`.
- Name resolution issues on macOS: after creating `/etc/resolver/<tld>` and dnsmasq config, run:

```bash
just clean-cache
just restart
```

- Quick DNS test (checks dnsmasq on the local resolver):

```bash
dig @127.0.0.1 example.<tld> A
# or: host example.<tld> 127.0.0.1
```

- If dnsmasq doesn't answer, ensure the container is running and bound to `127.0.0.1:53` as in `compose.yml`.

- Linux alternatives for flushing DNS cache (if not on macOS):

```bash
# systemd-resolved (Ubuntu):
sudo systemd-resolve --flush-caches
# or restart the resolver service:
sudo systemctl restart systemd-resolved
```

## Security

- Avoid exposing the Traefik dashboard or unsecured ports to non-local networks.
- The resolver files and dnsmasq config here are for local development only; don't apply the same config in production.

## Next steps I can do for you

- Run `just --list` in the repo and update task descriptions to match exactly.
- Add example Compose files that demonstrate `localhost_proxy_network` usage with real port/label examples.
