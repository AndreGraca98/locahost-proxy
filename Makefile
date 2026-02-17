
.PHONY: clean-cache
clean-cache: ## Flush the DNS cache on macOS
	sudo dscacheutil -flushcache
	sudo killall -HUP mDNSResponder

.PHONY: add-resolver
add-resolver: ## Add a resolver for the .docker domain
	sudo mkdir -p /etc/resolver
	echo "nameserver 127.0.0.1" | sudo tee /etc/resolver/docker