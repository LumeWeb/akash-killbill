FROM killbill/killbill:0.24.0

# Install required packages
RUN apt-get update && apt-get install -y \
    mariadb-client \
    && rm -rf /var/lib/apt/lists/*

# Copy Caddy binary from GitHub Actions artifact
COPY caddy /usr/bin/caddy
RUN chmod +x /usr/bin/caddy

# Copy configuration files
COPY docker-entrypoint-initdb.d/ /docker-entrypoint-initdb.d/
COPY Caddyfile /etc/caddy/Caddyfile
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
