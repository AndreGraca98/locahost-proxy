# Overview

## Purpose

Provide a local Traefik-based reverse-proxy so you can open `*.docker` hostnames and have Traefik route them to app services running in other Docker Compose projects or on your host.

## How it works

- **Traefik container:** accepts incoming HTTP(S) requests for `*.docker` and routes by hostname to backend services using Docker labels.
- **Service discovery:** Traefik reaches backends by Docker service name when containers share the external Docker network `localhost_proxy_network`.
- **DNS:** most OSes map `*.localhost` to `127.0.0.1`; no custom DNS is required for `*.localhost` names, but we use `dnsmasq` to allow custom TLDs like `*.docker`

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
      - "traefik.http.routers.api.rule=Host(`api.localhost`)"
      - "traefik.http.routers.api.entrypoints=web"
      - "traefik.http.services.api.loadbalancer.server.port=80"

  docs:
    image: your-docs-image
    networks:
      - localhost_proxy_network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.docs.rule=Host(`docs.localhost`)"
      - "traefik.http.routers.docs.entrypoints=web"
      - "traefik.http.services.docs.loadbalancer.server.port=8000"

  ui:
    image: your-ui-image
    networks:
      - localhost_proxy_network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.ui.rule=HostRegexp(`{subdomain:[^.]+}.localhost`)"
      - "traefik.http.routers.ui.entrypoints=web"
      - "traefik.http.services.ui.loadbalancer.server.port=80"

networks:
  localhost_proxy_network:
    external: true
```

Notes:

- `traefik.http.services.<name>.loadbalancer.server.port` tells Traefik which port the container serves internally.
- Use unique router/service names to avoid collisions across projects.

**Setup steps (Traefik)**

1. Create the external network (one-time):

```bash
docker network create localhost_proxy_network
```

1. Start the proxy stack in this repo:

```bash
docker compose -f compose.yml up -d traefik
```

1. In your app Compose files, add the Traefik labels and join `localhost_proxy_network`, then start them.

2. Open in browser:

- `http://api.localhost` → forwarded to your `api` service
- `http://docs.localhost` → forwarded to your `docs` service
- `http://anything.localhost` → forwarded to `ui` per the `HostRegexp` rule

**Security & troubleshooting**

- If Traefik doesn't route a container, confirm the container has the correct labels and is on `localhost_proxy_network`.
- If you expose the Traefik dashboard (`:8080`) keep it secure in non-local environments.

**Host resolution and `/etc/hosts`**

- For `*.localhost` you normally do NOT need to add entries to `/etc/hosts`. Modern OSes and browsers follow RFC 6761 and resolve any `*.localhost` name to `127.0.0.1`.
- Use `/etc/hosts` or a DNS server only if you use a non-`.localhost` dev TLD (for example `myapp.test`) or need names to resolve on other machines on your LAN.
- Example to add an entry on macOS:

```bash
echo "127.0.0.1 api.localhost" | sudo tee -a /etc/hosts
sudo killall -HUP mDNSResponder
```

**What your app(s) must do (recommended)**

- Join the shared network `localhost_proxy_network` and set the Traefik labels shown above.
- Listen on the internal port Traefik expects (commonly `80` or `8000` as configured per service). You do not need to publish that port to the host when using the shared network.

**If you cannot join the shared network**

- Publish the backend port to the host in your other Compose (example `ports: ["8080:80"]`) and update Traefik labels to point at `host.docker.internal:8080` using a `service` target or a TCP proxy rule.

**TLS & HTTPS**

- Traefik can manage TLS automatically or via provided certificates. This repo's Traefik runs with the Docker provider; configure TLS via labels or dynamic configuration if you need HTTPS locally.

**Next actions**

- Attach your `api`, `docs`, and `ui` services to `localhost_proxy_network`, or tell me the host ports and I'll update instructions to use `host.docker.internal` targets.
