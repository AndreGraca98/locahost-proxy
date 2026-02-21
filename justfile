
set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

network := "localhost_proxy_network"

# list all available tasks with descriptions
_list:
  @just -ul
# # just open the interactive menu to choose a task
# _choose:
#   @just --choose

# flush the DNS cache and restart mDNSResponder to ensure config changes are picked up immediately
[group: 'restart']
clean-cache:
  # flush (clear) the system DNS/lookup cache
  sudo dscacheutil -flushcache
  # send SIGHUP (hangup) to all the services that use mDNSResponder
  # reload configuration or restart gracefully. mDNSResponder is the 
  # daemon that handles DNS caching and mDNS/Bonjour resolution
  sudo killall -HUP mDNSResponder

# a convenience task to add a new domain and restart the proxy to pick up changes
[group: 'new-domain']
add-domain: 
  just add-resolver
  just add-dnsmasq
  just restart-proxy

# Add a resolver for a domain
[group: 'new-domain']
add-resolver domain='docker':
  sudo mkdir -p /etc/resolver
  echo "adding resolver at /etc/resolver/{{domain}} to point to 127.0.0.1"
  echo "nameserver 127.0.0.1" | sudo tee /etc/resolver/{{domain}} > /dev/null

# Add a dnsmasq rule for a TLD
[group: 'new-domain']
add-dnsmasq domain='docker':
  # add it in the local dnsmasq config instead of the macOS system config
  echo "address=/.{{domain}}/127.0.0.1" | tee ./dnsmasq.d/{{domain}}.conf > /dev/null


# Start the compose stack (ensures network exists first)
[group: 'docker']
up: add-proxy-network
  docker compose up -d

# Stop and remove the compose stack
[group: 'docker']
down:
  docker compose down --remove-orphans
  @(docker network rm {{network}} 2>/dev/null 1>/dev/null && echo Removed network: {{network}} ) || true

# restart Traefik and dnsmasq so they pick up config changes
[group: 'docker']
restart: clean-cache
  docker restart traefik dnsmasq

# Ensure the external Docker network exists
[group: 'docker']
add-proxy-network:
  @(docker network create {{network}} 2>/dev/null 1>/dev/null && echo Created network: {{network}} ) || true
