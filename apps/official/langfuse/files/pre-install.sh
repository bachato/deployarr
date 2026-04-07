#!/bin/bash
# Langfuse Pre-Install Hook
# Injects auto-generated secrets into all Langfuse compose files via sed placeholders
# Optionally configures headless initialization using existing Deployrr credentials

COMPOSE_DIR="$DOCKER_FOLDER/compose/$HOSTNAME"

# ============================================================
# SECTION 1: Read and validate secrets
# ============================================================
POSTGRESQL_PASSWORD=$(sudo cat "$DOCKER_FOLDER/secrets/langfuse_postgresql_password" 2>/dev/null)
REDIS_PASSWORD=$(sudo cat "$DOCKER_FOLDER/secrets/langfuse_redis_password" 2>/dev/null)
CLICKHOUSE_PASSWORD=$(sudo cat "$DOCKER_FOLDER/secrets/langfuse_clickhouse_password" 2>/dev/null)
MINIO_PASSWORD=$(sudo cat "$DOCKER_FOLDER/secrets/langfuse_minio_password" 2>/dev/null)
NEXTAUTH_SECRET=$(sudo cat "$DOCKER_FOLDER/secrets/langfuse_nextauth_secret" 2>/dev/null)
SALT=$(sudo cat "$DOCKER_FOLDER/secrets/langfuse_salt" 2>/dev/null)
ENCRYPTION_KEY=$(sudo cat "$DOCKER_FOLDER/secrets/langfuse_encryption_key" 2>/dev/null)

if [[ -z "$POSTGRESQL_PASSWORD" || -z "$REDIS_PASSWORD" || -z "$CLICKHOUSE_PASSWORD" || \
      -z "$MINIO_PASSWORD" || -z "$NEXTAUTH_SECRET" || -z "$SALT" || -z "$ENCRYPTION_KEY" ]]; then
    f_print_error "One or more Langfuse secrets are missing from $DOCKER_FOLDER/secrets/"
    log_error "langfuse" "Missing secrets - aborting pre-install"
    return 1
fi

f_print_substep "Injecting secrets into Langfuse compose files..."

# ============================================================
# SECTION 2: Inject secrets into compose files
# ============================================================

# --- Inject into main compose (langfuse-web) ---
local web_compose="$COMPOSE_DIR/langfuse.yml"
if [[ -f "$web_compose" ]]; then
    f_safe_sed "s|POSTGRESQL-PASSWORD-PLACEHOLDER|$POSTGRESQL_PASSWORD|g" "$web_compose"
    f_safe_sed "s|REDIS-PASSWORD-PLACEHOLDER|$REDIS_PASSWORD|g" "$web_compose"
    f_safe_sed "s|CLICKHOUSE-PASSWORD-PLACEHOLDER|$CLICKHOUSE_PASSWORD|g" "$web_compose"
    f_safe_sed "s|MINIO-PASSWORD-PLACEHOLDER|$MINIO_PASSWORD|g" "$web_compose"
    f_safe_sed "s|NEXTAUTH-SECRET-PLACEHOLDER|$NEXTAUTH_SECRET|g" "$web_compose"
    f_safe_sed "s|SALT-PLACEHOLDER|$SALT|g" "$web_compose"
    f_safe_sed "s|ENCRYPTION-KEY-PLACEHOLDER|$ENCRYPTION_KEY|g" "$web_compose"
    log_info "langfuse" "Injected secrets into langfuse.yml"
fi

# --- Inject into worker compose ---
local worker_compose="$COMPOSE_DIR/langfuse-worker.yml"
if [[ -f "$worker_compose" ]]; then
    f_safe_sed "s|POSTGRESQL-PASSWORD-PLACEHOLDER|$POSTGRESQL_PASSWORD|g" "$worker_compose"
    f_safe_sed "s|REDIS-PASSWORD-PLACEHOLDER|$REDIS_PASSWORD|g" "$worker_compose"
    f_safe_sed "s|CLICKHOUSE-PASSWORD-PLACEHOLDER|$CLICKHOUSE_PASSWORD|g" "$worker_compose"
    f_safe_sed "s|MINIO-PASSWORD-PLACEHOLDER|$MINIO_PASSWORD|g" "$worker_compose"
    f_safe_sed "s|SALT-PLACEHOLDER|$SALT|g" "$worker_compose"
    f_safe_sed "s|ENCRYPTION-KEY-PLACEHOLDER|$ENCRYPTION_KEY|g" "$worker_compose"
    log_info "langfuse" "Injected secrets into langfuse-worker.yml"
fi

# --- Inject into PostgreSQL compose ---
local pg_compose="$COMPOSE_DIR/langfuse-postgresql.yml"
if [[ -f "$pg_compose" ]]; then
    f_safe_sed "s|POSTGRESQL-PASSWORD-PLACEHOLDER|$POSTGRESQL_PASSWORD|g" "$pg_compose"
    log_info "langfuse" "Injected secrets into langfuse-postgresql.yml"
fi

# --- Inject into Redis compose ---
local redis_compose="$COMPOSE_DIR/langfuse-redis.yml"
if [[ -f "$redis_compose" ]]; then
    f_safe_sed "s|REDIS-PASSWORD-PLACEHOLDER|$REDIS_PASSWORD|g" "$redis_compose"
    log_info "langfuse" "Injected secrets into langfuse-redis.yml"
fi

# --- Inject into ClickHouse compose ---
local ch_compose="$COMPOSE_DIR/langfuse-clickhouse.yml"
if [[ -f "$ch_compose" ]]; then
    f_safe_sed "s|CLICKHOUSE-PASSWORD-PLACEHOLDER|$CLICKHOUSE_PASSWORD|g" "$ch_compose"
    log_info "langfuse" "Injected secrets into langfuse-clickhouse.yml"
fi

# --- Inject into MinIO compose ---
local minio_compose="$COMPOSE_DIR/langfuse-minio.yml"
if [[ -f "$minio_compose" ]]; then
    f_safe_sed "s|MINIO-PASSWORD-PLACEHOLDER|$MINIO_PASSWORD|g" "$minio_compose"
    log_info "langfuse" "Injected secrets into langfuse-minio.yml"
fi

f_print_success "Langfuse secrets configured"

# ============================================================
# SECTION 3: Headless initialization prompt
# ============================================================
local headless_choice
headless_choice=$(dialog \
    --backtitle "Deployrr - Langfuse Setup" \
    --title "Account Initialization" \
    --menu "\nHow would you like to set up your Langfuse admin account?\n" 0 0 2 \
    "1" "Use existing Deployrr credentials (recommended)" \
    "2" "Set up manually via web UI after install" \
    3>&1 1>&2 2>&3)

local dialog_exit=$?
if [[ $dialog_exit -ne 0 ]]; then
    headless_choice="2"
fi

if [[ "$headless_choice" == "1" ]]; then
    # --- Read existing Deployrr credentials ---
    local basic_user basic_pass
    basic_user=$(sudo cat "$DOCKER_FOLDER/secrets/basic_auth_username" 2>/dev/null)
    basic_pass=$(sudo cat "$DOCKER_FOLDER/secrets/basic_auth_password" 2>/dev/null)

    if [[ -z "$basic_user" || -z "$basic_pass" ]]; then
        f_print_warning "Could not read Deployrr credentials - falling back to manual setup"
        log_warning "langfuse" "basic_auth credentials not found, skipping headless init"
        headless_choice="2"
    fi
fi

if [[ "$headless_choice" == "1" ]]; then
    # --- Prompt for email ---
    local user_email
    user_email=$(dialog \
        --backtitle "Deployrr - Langfuse Setup" \
        --title "Admin Email" \
        --inputbox "\nEnter the email address for your Langfuse admin account:\n" 10 60 \
        3>&1 1>&2 2>&3)

    local email_exit=$?
    if [[ $email_exit -ne 0 || -z "$user_email" ]]; then
        f_print_warning "No email provided - falling back to manual setup"
        log_warning "langfuse" "No email provided, skipping headless init"
        headless_choice="2"
    fi
fi

if [[ "$headless_choice" == "1" ]]; then
    # --- Prompt for org name ---
    local org_name
    org_name=$(dialog \
        --backtitle "Deployrr - Langfuse Setup" \
        --title "Organization Name" \
        --inputbox "\nEnter a name for your Langfuse organization:\n" 10 60 "Deployrr" \
        3>&1 1>&2 2>&3)
    [[ -z "$org_name" ]] && org_name="Deployrr"

    # --- Prompt for project name ---
    local project_name
    project_name=$(dialog \
        --backtitle "Deployrr - Langfuse Setup" \
        --title "Project Name" \
        --inputbox "\nEnter a name for your first Langfuse project:\n" 10 60 "Default Project" \
        3>&1 1>&2 2>&3)
    [[ -z "$project_name" ]] && project_name="Default Project"

    # --- Derive IDs from names (lowercase, spaces to hyphens) ---
    local org_id project_id
    org_id=$(echo "$org_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
    project_id=$(echo "$project_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')

    # --- Inject headless init values ---
    f_print_substep "Configuring headless initialization..."

    f_safe_sed "s|HEADLESS-ORG-PLACEHOLDER|$org_id|g" "$web_compose"
    f_safe_sed "s|HEADLESS-ORGNAME-PLACEHOLDER|$org_name|g" "$web_compose"
    f_safe_sed "s|HEADLESS-PROJECT-PLACEHOLDER|$project_id|g" "$web_compose"
    f_safe_sed "s|HEADLESS-PROJECTNAME-PLACEHOLDER|$project_name|g" "$web_compose"
    f_safe_sed "s|HEADLESS-EMAIL-PLACEHOLDER|$user_email|g" "$web_compose"
    f_safe_sed "s|HEADLESS-USERNAME-PLACEHOLDER|$basic_user|g" "$web_compose"
    f_safe_sed "s|HEADLESS-PASSWORD-PLACEHOLDER|$basic_pass|g" "$web_compose"

    f_print_success "Admin account will be created on first startup"
    log_info "langfuse" "Headless init configured: user=$basic_user email=$user_email"
else
    # --- Remove headless init placeholders ---
    if [[ -f "$web_compose" ]]; then
        f_safe_sed "/HEADLESS-.*-PLACEHOLDER/d" "$web_compose"
        log_info "langfuse" "Headless init skipped - placeholders removed"
    fi
    f_print_substep "Manual account setup selected - create your account via the web UI"
fi
