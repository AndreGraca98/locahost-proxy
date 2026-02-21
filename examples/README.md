# Docker Compose example and networking

This folder contains a minimal example service and a `docker-compose.yml` that demonstrate how multiple service instances and a proxy can coexist on a Compose network.

## Files

- `Dockerfile` — builds a tiny Python HTTP service that replies with its `SERVICE_NAME` and hostname.
- `app.py` — the service code used by the Dockerfile.
- `docker-compose.yml` — starts two service instances (`service-a`, `service-b`) and declares an external Compose network `localhost_proxy_network`. The compose file uses labels (Traefik) for routing; run your reverse proxy attached to the same external network so it can route to these services.

## How the network works

- In this example, `service-a` and `service-b` are reachable from other containers attached to the same network using the hostnames `service-a` and `service-b`.
- The compose file expects an external network named `localhost_proxy_network` (see `networks:`). A reverse proxy (e.g. Traefik) should be run attached to that external network so it can see and route to these services.
- The compose file uses Traefik labels to declare host rules like `service-a.docker` and `service-b.docker`. A Traefik instance on the shared network will pick up those labels and route traffic accordingly.
- Host port mappings (e.g. `5001:5000`, `5002:5000`) expose the services to the host for testing. From the proxy's perspective, prefer internal service hostnames rather than the published host ports.

## Notes

- Run a proxy on the external network: ensure your reverse proxy (Traefik, Caddy, etc.) is attached to the `localhost_proxy_network` so it can read service labels and route traffic.
- For DNS-based discovery the proxy should query the internal service names. Using host-published ports for discovery is fragile and unnecessary when services share a network.
- Compose networks are isolated per project by default. If you need cross-project discovery, configure an external network and attach services to it.
