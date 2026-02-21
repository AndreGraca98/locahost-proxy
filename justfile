#!/usr/bin/env -S just --justfile

set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

network := "localhost_proxy_network"

# list all available tasks with descriptions
_list:
  @just -ul
# # just open the interactive menu to choose a task
# _choose:
#   @just -u --choose

[group: 'setup']
setup:
  brew install mkcert
  # firefox support with mkcert
  brew install nss 

  # install and trust the local CA (creates and trusts it in macOS keychains and firefox NSS DB)
  mkcert -install

# flush the DNS cache and restart mDNSResponder to ensure config changes are picked up immediately
[group: 'restart']
clean-cache:
  # flush (clear) the system DNS/lookup cache
  sudo dscacheutil -flushcache
  # send SIGHUP (hangup) to all the services that use mDNSResponder
  # reload configuration or restart gracefully. mDNSResponder is the 
  # daemon that handles DNS caching and mDNS/Bonjour resolution
  sudo killall -HUP mDNSResponder

# A convenience task to add a new domain, dnsmasq rule, and certs all in one go, then restart the stack to pick up changes
[group: 'new-domain']
add-domain domain='docker': 
  just add-resolver domain={{domain}}
  just add-dnsmasq domain={{domain}}
  just add-certs domain={{domain}}
  just restart

# Add a resolver for a domain
[group: 'new-domain']
add-resolver domain='docker':
  @sudo mkdir -p /etc/resolver
  @echo "adding resolver at /etc/resolver/{{domain}} to point to 127.0.0.1"
  @echo "nameserver 127.0.0.1" | sudo tee /etc/resolver/{{domain}} > /dev/null


# Add a dnsmasq rule for a TLD
[group: 'new-domain']
add-dnsmasq domain='docker':
  # add it in the local dnsmasq config instead of the macOS system config
  echo "address=/.{{domain}}/127.0.0.1" | tee ./dnsmasq.d/{{domain}}.conf > /dev/null

# Generate TLS certs for a domain with mkcert
[group: 'new-domain']
add-certs full_host='docker':
  #!/usr/bin/env python3
  import subprocess
  import sys
  from pathlib import Path

  full_host = "{{full_host}}"
  *subdomains, domain = full_host.split('.')

  certs_dir = Path('./certs')
  certs_dir.mkdir(exist_ok=True)
  cert_file = certs_dir / f'{full_host}.crt'
  key_file = certs_dir / f'{full_host}.key'
  cmd = f'mkcert -cert-file {cert_file} -key-file {key_file} "{domain}" "*.{domain}" "{full_host}"'
  print(f"Generating certs for {full_host} with command:\n{cmd}")
  subprocess.run(cmd, shell=True, check=True)
  print(f"Certs generated:\n  cert: {cert_file}\n  key:  {key_file}")
  
  tls_config = Path('./traefik/dynamic/tls.yaml')
  content = tls_config.read_text()  # ensure the file exists
  new_entry = f"\n    - certFile: /certs/{full_host}.crt\n      keyFile:  /certs/{full_host}.key"
  if new_entry in content:
    print(f"TLS config for {full_host} already exists in {tls_config}, skipping update")
  else:
      tls_config.write_text(content + new_entry)
      print(f"TLS config for {full_host} updated in {tls_config}")
# # mkcert -cert-file certs/docker.crt -key-file certs/docker.key "service-b.docker" "docker" "*.docker" 
# # mkcert -cert-file certs/{{domain}}.crt -key-file certs/{{domain}}.key "{{domain}}" "*.{{domain}}"
# mkcert -cert-file certs/{{domain}}.crt -key-file certs/{{domain}}.key "{{domain}}" "*.{{domain}}"
# @printf '\n    - certFile: /certs/{{domain}}.crt\n      keyFile:  /certs/{{domain}}.key\n' >> ./traefik/dynamic/tls.yaml

# Start the compose stack (ensures network exists first)
[group: 'docker']
run: add-proxy-network
  docker compose up -d --build

# Stop and remove the compose stack
[group: 'docker']
stop:
  docker compose down --remove-orphans
  @(docker network rm {{network}} 2>/dev/null 1>/dev/null && echo Removed network: {{network}} ) || true

# restart Traefik and dnsmasq so they pick up config changes
[group: 'docker']
restart: clean-cache
  docker compose restart

# Ensure the external Docker network exists
[group: 'docker']
add-proxy-network:
  @(docker network create {{network}} 2>/dev/null 1>/dev/null && echo Created network: {{network}} ) || true

# Run the example for Service A (HTTP only)
[group: 'examples']
run-example-a: add-proxy-network
  @docker compose -f examples/compose.yml up -d service-a 1>/dev/null
  @printf 'Open \033[1;94mhttp://service-a.docker\033[0m\n'
  @printf 'Open \033[1;94mhttps://service-a.docker\033[0m (should fail since it is not configured for TLS)\n'

# Run the example for Service B (HTTP + HTTPS)
[group: 'examples']
run-example-b: add-proxy-network
  @docker compose -f examples/compose.yml up -d service-b 1>/dev/null
  @printf 'Open \033[1;94mhttp://service-b.docker\033[0m\n'
  @printf 'Open \033[1;94mhttps://service-b.docker\033[0m (works as well, TLS is enabled for this service)\n'

# Stop all the examples
[group: 'examples']
stop-examples: 
  docker compose -f examples/compose.yml down --remove-orphans