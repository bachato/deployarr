#!/bin/bash
# Guacamole post-install hook
# Initializes the database schema using v5 style (dynamic SQL generation)

APP_SNAME="guacamole"
APP_PNAME="Guacamole"

f_print_step "1/3" "Waiting for $APP_PNAME MariaDB to be ready..."
f_print_substep "Ensuring database is fully initialized..."
f_blank_line_sleep 5
echo

f_print_step "2/3" "Initializing $APP_PNAME database schema..."

# Get database credentials from .env
GUACAMOLE_DB_USER="guacamole_db_user"
GUACAMOLE_DB_PASSWORD=$(grep "^GUACAMOLE_MARIADB_PASSWORD=" "$DOCKER_FOLDER/.env" | cut -d'=' -f2)

# Get version pin from .env (fallback to latest)
GUACAMOLE_VERSION_PIN=$(grep "^GUACAMOLE_VERSION_PIN=" "$DOCKER_FOLDER/.env" | cut -d'=' -f2)
GUACAMOLE_VERSION_PIN="${GUACAMOLE_VERSION_PIN:-latest}"

# Check if database is already initialized (check for guacamole_user table)
DB_INITIALIZED=$(sudo docker exec guacamole-mariadb mariadb -u"$GUACAMOLE_DB_USER" -p"$GUACAMOLE_DB_PASSWORD" guacamole -e "SHOW TABLES LIKE 'guacamole_user';" 2>/dev/null | grep -c "guacamole_user" || echo "0")

if [[ "$DB_INITIALIZED" -gt 0 ]]; then
    f_print_substep "Database schema already initialized, skipping..."
else
    f_print_substep "Generating database schema from Guacamole image..."

    # Generate the init SQL from the guacamole image (v5 style)
    INIT_SQL_FILE="/tmp/guacamole_initdb.sql"
    sudo docker run --rm guacamole/guacamole:${GUACAMOLE_VERSION_PIN} /opt/guacamole/bin/initdb.sh --mysql > "$INIT_SQL_FILE" 2>/dev/null

    if [[ ! -s "$INIT_SQL_FILE" ]]; then
        f_print_error "Failed to generate database schema"
        rm -f "$INIT_SQL_FILE"
        return 1
    fi

    f_print_substep "Applying schema to guacamole-mariadb..."

    # Apply the schema to the database
    sudo docker exec -i guacamole-mariadb mariadb -u"$GUACAMOLE_DB_USER" -p"$GUACAMOLE_DB_PASSWORD" guacamole < "$INIT_SQL_FILE" 2>/dev/null

    if [[ $? -eq 0 ]]; then
        f_print_substep "Database schema applied successfully"
    else
        f_print_warning "Database initialization may have had issues - check Guacamole logs"
    fi

    # Cleanup
    rm -f "$INIT_SQL_FILE"
fi

echo

f_print_step "3/3" "Restarting $APP_PNAME to connect to initialized database..."
f_docker_compose_recreate "guacamole" "06"

f_print_success "$APP_PNAME database initialization complete"
