#!/bin/bash
set -eo pipefail

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

# Validate required environment variables
validate_env_vars() {
    log "Validating environment variables..."

    # All required environment variables
    local required_vars=(
        # MySQL variables
        "MYSQL_HOST"
        "MYSQL_PORT"
        "MYSQL_USER"
        "MYSQL_PASSWORD"
        
        # Kill Bill variables
        "KB_ADMIN_PASSWORD"
        
        # Caddy variables
        "CADDY_EMAIL"
        "CADDY_S3_BUCKET"
        "CADDY_S3_ENDPOINT"
        "CADDY_S3_ACCESS_KEY"
        "CADDY_S3_SECRET_KEY"
    )

    local missing_vars=()

    # Check all required vars
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var}" ]]; then
            missing_vars+=("$var")
        fi
    done

    # Check Kill Bill plugins var (optional but validate format if present)
    if [[ -n "$KILLBILL_PLUGINS" ]]; then
        IFS=' ' read -ra PLUGINS <<< "$KILLBILL_PLUGINS"
        for plugin in "${PLUGINS[@]}"; do
            IFS=':' read -ra PLUGIN_INFO <<< "$plugin"
            case "${PLUGIN_INFO[0]}" in
                "standard")
                    if [[ ${#PLUGIN_INFO[@]} -ne 3 ]]; then
                        log "Error: Invalid standard plugin format. Expected 'standard:name:version'"
                        exit 1
                    fi
                    ;;
                "custom")
                    if [[ ${#PLUGIN_INFO[@]} -ne 5 ]]; then
                        log "Error: Invalid custom plugin format. Expected 'custom:url:group-id:artifact-id:version'"
                        exit 1
                    fi
                    ;;
                *)
                    log "Error: Unknown plugin type '${PLUGIN_INFO[0]}'. Expected 'standard' or 'custom'"
                    exit 1
                    ;;
            esac
        done
    fi

    # Exit if any required variables are missing
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log "Error: Missing required environment variables:"
        printf '%s\n' "${missing_vars[@]}"
        exit 1
    fi

    log "Environment validation successful"
}

# Wait for MySQL to be ready
wait_for_mysql() {
    local retries=30
    local wait_time=10

    log "Waiting for MySQL connection..."
    while ! mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "SELECT 1" >/dev/null 2>&1; do
        retries=$((retries - 1))
        if [ $retries -eq 0 ]; then
            log "Error: Could not connect to MySQL after 300 seconds"
            exit 1
        fi
        log "MySQL not ready, waiting ${wait_time}s... ($retries attempts left)"
        sleep $wait_time
    done
    log "MySQL connection established"
}

# Initialize database
init_database() {
    log "Checking and initializing databases if needed..."
    
    # Set MySQL connection options
    local mysql_cmd="mysql -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER -p$MYSQL_PASSWORD"
    
    # Check if killbill database exists
    if ! $mysql_cmd -e "USE killbill" 2>/dev/null; then
        log "Creating killbill database..."
        $mysql_cmd -e "CREATE DATABASE IF NOT EXISTS killbill;"
        $mysql_cmd killbill -e "SET GLOBAL binlog_format = 'ROW';"
        
        # Install Kill Bill DDL
        log "Installing Kill Bill schema..."
        wget -qO- "http://docs.killbill.io/$KILLBILL_VERSION/ddl.sql" | $mysql_cmd killbill
        
        # Install popular plugins DDL
        log "Installing plugin schemas..."
        wget -qO- "https://raw.githubusercontent.com/killbill/killbill-stripe-plugin/master/src/main/resources/ddl.sql" | $mysql_cmd killbill
        wget -qO- "https://raw.githubusercontent.com/killbill/killbill-analytics-plugin/master/src/main/resources/org/killbill/billing/plugin/analytics/ddl.sql" | $mysql_cmd killbill
    else
        log "Kill Bill database already exists, skipping initialization"
    fi
}

# Install Kill Bill plugins
install_plugins() {
    log "Installing Kill Bill plugins..."
    IFS=' ' read -ra PLUGINS <<< "$KILLBILL_PLUGINS"
    for plugin in "${PLUGINS[@]}"; do
        # Split on : but keep URL intact by limiting splits
        IFS=':' read -ra PLUGIN_INFO <<< "$plugin"
        plugin_type="${PLUGIN_INFO[0]}"

        case $plugin_type in
            "standard")
                # Standard Kill Bill plugin format: standard:name:version
                plugin_name="${PLUGIN_INFO[1]}"
                plugin_version="${PLUGIN_INFO[2]}"

                log "Installing standard plugin: $plugin_name version $plugin_version"
                kpm install_java_plugin "$plugin_name" --version="$plugin_version" || {
                    log "Failed to install plugin: $plugin_name"
                    exit 1
                }
                ;;

            "custom")
                # Custom plugin format: custom:url:group-id:artifact-id:version
                plugin_url="${PLUGIN_INFO[1]}"
                group_id="${PLUGIN_INFO[2]}"
                artifact_id="${PLUGIN_INFO[3]}"
                version="${PLUGIN_INFO[4]}"

                log "Installing custom plugin: $artifact_id from $plugin_url"
                kpm install_java_plugin \
                    --overrides "url=$plugin_url" \
                    --group-id "$group_id" \
                    --artifact-id "$artifact_id" \
                    --version "$version" || {
                    log "Failed to install custom plugin: $artifact_id"
                    exit 1
                }
                ;;

            *)
                log "Unknown plugin type: $plugin_type"
                exit 1
                ;;
        esac
    done
}

# Start Caddy in background
start_caddy() {
    log "Starting Caddy server..."
    /usr/local/bin/caddy run --config /etc/caddy/Caddyfile &
}

# Main execution
main() {
    validate_env_vars
    wait_for_mysql
    init_database
    install_plugins
    start_caddy

    log "Starting Kill Bill..."
    exec /var/lib/killbill/killbill.sh
}

main "$@"
