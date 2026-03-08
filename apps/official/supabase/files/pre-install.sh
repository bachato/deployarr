#!/bin/bash
# Supabase Pre-Install Hook
# Generates secrets, JWT tokens, and injects them into compose files.
# Also copies vendored volume configs to appdata.
#
# Context: This script is SOURCED (not executed) by f_execute_app_hook.
# Available inherited variables:
#   $DOCKER_FOLDER  - Docker root folder
#   $HOSTNAME       - System hostname
#   $app_folder     - Path to this app's scaffold directory
# Available functions: f_print_substep, f_print_success, f_print_error, log_info, log_error

# ============================================================================
# VARIABLES
# ============================================================================
COMPOSE_DIR="$DOCKER_FOLDER/compose/$HOSTNAME"
SECRETS_DIR="$DOCKER_FOLDER/secrets"
APPDATA_DIR="$DOCKER_FOLDER/appdata/supabase"

# List of all compose files to sed-inject (main + 12 dependencies)
COMPOSE_FILES=(
    "supabase.yml"
    "supabase-kong.yml"
    "supabase-auth.yml"
    "supabase-rest.yml"
    "realtime-dev.supabase-realtime.yml"
    "supabase-storage.yml"
    "supabase-imgproxy.yml"
    "supabase-meta.yml"
    "supabase-edge-functions.yml"
    "supabase-analytics.yml"
    "supabase-db.yml"
    "supabase-vector.yml"
    "supabase-pooler.yml"
)

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

# base64url encode (no padding, URL-safe)
base64url_encode() {
    openssl base64 -e -A | tr '+/' '-_' | tr -d '='
}

# Generate a JWT token signed with HMAC-SHA256
# Usage: generate_jwt <payload_json> <secret>
generate_jwt() {
    local payload_json="$1"
    local secret="$2"

    # Header: {"alg":"HS256","typ":"JWT"}
    local header
    header=$(printf '{"alg":"HS256","typ":"JWT"}' | base64url_encode)

    # Payload
    local payload
    payload=$(printf '%s' "$payload_json" | base64url_encode)

    # Signature
    local signature
    signature=$(printf '%s.%s' "$header" "$payload" | openssl dgst -sha256 -hmac "$secret" -binary | base64url_encode)

    printf '%s.%s.%s' "$header" "$payload" "$signature"
}

# ============================================================================
# READ SECRETS
# ============================================================================
f_print_substep "Reading Supabase secrets..."

POSTGRES_PASSWORD=$(sudo cat "${SECRETS_DIR}/supabase_postgres_password" 2>/dev/null || echo "")
JWT_SECRET=$(sudo cat "${SECRETS_DIR}/supabase_jwt_secret" 2>/dev/null || echo "")
DASHBOARD_PASSWORD=$(sudo cat "${SECRETS_DIR}/supabase_dashboard_password" 2>/dev/null || echo "")
SECRET_KEY_BASE=$(sudo cat "${SECRETS_DIR}/supabase_secret_key_base" 2>/dev/null || echo "")
VAULT_ENC_KEY=$(sudo cat "${SECRETS_DIR}/supabase_vault_enc_key" 2>/dev/null || echo "")
PG_META_CRYPTO_KEY=$(sudo cat "${SECRETS_DIR}/supabase_pg_meta_crypto_key" 2>/dev/null || echo "")
LOGFLARE_PUBLIC_TOKEN=$(sudo cat "${SECRETS_DIR}/supabase_logflare_public_token" 2>/dev/null || echo "")
LOGFLARE_PRIVATE_TOKEN=$(sudo cat "${SECRETS_DIR}/supabase_logflare_private_token" 2>/dev/null || echo "")
S3_ACCESS_KEY_ID=$(sudo cat "${SECRETS_DIR}/supabase_s3_access_key_id" 2>/dev/null || echo "")
S3_ACCESS_KEY_SECRET=$(sudo cat "${SECRETS_DIR}/supabase_s3_access_key_secret" 2>/dev/null || echo "")
POOLER_TENANT_ID=$(sudo cat "${SECRETS_DIR}/supabase_pooler_tenant_id" 2>/dev/null || echo "")

if [[ -z "$POSTGRES_PASSWORD" || -z "$JWT_SECRET" || -z "$DASHBOARD_PASSWORD" ]]; then
    f_print_error "Critical Supabase secrets are missing from $SECRETS_DIR/"
    log_error "supabase" "Missing secrets - aborting pre-install"
    return 1
fi

# ============================================================================
# GENERATE JWT TOKENS
# ============================================================================
f_print_substep "Generating JWT tokens..."

# Generate ANON key: read-only public key
# Payload: {"role":"anon","iss":"supabase","iat":<now>,"exp":<now+5years>}
CURRENT_TS=$(date +%s)
EXPIRY_TS=$((CURRENT_TS + 157680000)) # 5 years

ANON_PAYLOAD=$(printf '{"role":"anon","iss":"supabase","iat":%d,"exp":%d}' "$CURRENT_TS" "$EXPIRY_TS")
ANON_KEY=$(generate_jwt "$ANON_PAYLOAD" "$JWT_SECRET")

# Generate SERVICE_ROLE key: full admin access
SERVICE_ROLE_PAYLOAD=$(printf '{"role":"service_role","iss":"supabase","iat":%d,"exp":%d}' "$CURRENT_TS" "$EXPIRY_TS")
SERVICE_ROLE_KEY=$(generate_jwt "$SERVICE_ROLE_PAYLOAD" "$JWT_SECRET")

# Persist generated JWT tokens to secrets files (use sudo tee — secrets dir is root-owned)
printf '%s' "$ANON_KEY" | sudo tee "${SECRETS_DIR}/supabase_anon_key" > /dev/null
printf '%s' "$SERVICE_ROLE_KEY" | sudo tee "${SECRETS_DIR}/supabase_service_role_key" > /dev/null

log_info "supabase" "Generated JWT tokens (anon + service_role)"

# ============================================================================
# COPY VOLUME CONFIGS TO APPDATA
# ============================================================================
f_print_substep "Copying volume configurations..."

# Create appdata directories
sudo mkdir -p "${APPDATA_DIR}/volumes/api"
sudo mkdir -p "${APPDATA_DIR}/volumes/db"
sudo mkdir -p "${APPDATA_DIR}/volumes/logs"
sudo mkdir -p "${APPDATA_DIR}/volumes/pooler"
sudo mkdir -p "${APPDATA_DIR}/volumes/functions/main"
sudo mkdir -p "${APPDATA_DIR}/volumes/functions/hello"
sudo mkdir -p "${APPDATA_DIR}/storage"
sudo mkdir -p "${APPDATA_DIR}/deno-cache"
sudo mkdir -p "$DOCKER_FOLDER/appdata/supabase-db/data"

# Copy vendored config files from scaffold to appdata
# Only copy if not already present (preserves user modifications)
# $app_folder is inherited from the framework (set by f_load_app_manifest)
[[ ! -f "${APPDATA_DIR}/volumes/api/kong.yml" ]] && \
    sudo cp "${app_folder}/files/volumes/api/kong.yml" "${APPDATA_DIR}/volumes/api/kong.yml"

for sqlFile in realtime.sql webhooks.sql roles.sql jwt.sql _supabase.sql logs.sql pooler.sql; do
    [[ ! -f "${APPDATA_DIR}/volumes/db/${sqlFile}" ]] && \
        sudo cp "${app_folder}/files/volumes/db/${sqlFile}" "${APPDATA_DIR}/volumes/db/${sqlFile}"
done

[[ ! -f "${APPDATA_DIR}/volumes/logs/vector.yml" ]] && \
    sudo cp "${app_folder}/files/volumes/logs/vector.yml" "${APPDATA_DIR}/volumes/logs/vector.yml"

[[ ! -f "${APPDATA_DIR}/volumes/pooler/pooler.exs" ]] && \
    sudo cp "${app_folder}/files/volumes/pooler/pooler.exs" "${APPDATA_DIR}/volumes/pooler/pooler.exs"

[[ ! -f "${APPDATA_DIR}/volumes/functions/main/index.ts" ]] && \
    sudo cp "${app_folder}/files/volumes/functions/main/index.ts" "${APPDATA_DIR}/volumes/functions/main/index.ts"

[[ ! -f "${APPDATA_DIR}/volumes/functions/hello/index.ts" ]] && \
    sudo cp "${app_folder}/files/volumes/functions/hello/index.ts" "${APPDATA_DIR}/volumes/functions/hello/index.ts"

log_info "supabase" "Volume configs copied to appdata"

# ============================================================================
# INJECT SECRETS INTO COMPOSE FILES
# ============================================================================
f_print_substep "Injecting secrets into compose files..."

DASHBOARD_USERNAME="supabase"

for composeFile in "${COMPOSE_FILES[@]}"; do
    local filePath="${COMPOSE_DIR}/${composeFile}"
    [[ ! -f "$filePath" ]] && continue

    # Postgres password
    sudo sed -i "s|POSTGRES-PASSWORD-PLACEHOLDER|${POSTGRES_PASSWORD}|g" "$filePath"

    # JWT secret
    sudo sed -i "s|JWT-SECRET-PLACEHOLDER|${JWT_SECRET}|g" "$filePath"

    # JWT tokens (ANON + SERVICE_ROLE)
    sudo sed -i "s|ANON-KEY-PLACEHOLDER|${ANON_KEY}|g" "$filePath"
    sudo sed -i "s|SERVICE-ROLE-KEY-PLACEHOLDER|${SERVICE_ROLE_KEY}|g" "$filePath"

    # Dashboard credentials
    sudo sed -i "s|DASHBOARD-USERNAME-PLACEHOLDER|${DASHBOARD_USERNAME}|g" "$filePath"
    sudo sed -i "s|DASHBOARD-PASSWORD-PLACEHOLDER|${DASHBOARD_PASSWORD}|g" "$filePath"

    # Secret key base (Realtime + Supavisor)
    sudo sed -i "s|SECRET-KEY-BASE-PLACEHOLDER|${SECRET_KEY_BASE}|g" "$filePath"

    # Vault encryption key (Supavisor)
    sudo sed -i "s|VAULT-ENC-KEY-PLACEHOLDER|${VAULT_ENC_KEY}|g" "$filePath"

    # PG Meta crypto key
    sudo sed -i "s|PG-META-CRYPTO-KEY-PLACEHOLDER|${PG_META_CRYPTO_KEY}|g" "$filePath"

    # Logflare tokens
    sudo sed -i "s|LOGFLARE-PUBLIC-TOKEN-PLACEHOLDER|${LOGFLARE_PUBLIC_TOKEN}|g" "$filePath"
    sudo sed -i "s|LOGFLARE-PRIVATE-TOKEN-PLACEHOLDER|${LOGFLARE_PRIVATE_TOKEN}|g" "$filePath"

    # Storage S3 credentials
    sudo sed -i "s|S3-ACCESS-KEY-ID-PLACEHOLDER|${S3_ACCESS_KEY_ID}|g" "$filePath"
    sudo sed -i "s|S3-ACCESS-KEY-SECRET-PLACEHOLDER|${S3_ACCESS_KEY_SECRET}|g" "$filePath"

    # Pooler tenant ID
    sudo sed -i "s|POOLER-TENANT-ID-PLACEHOLDER|${POOLER_TENANT_ID}|g" "$filePath"
done

f_print_success "Supabase secrets configured"
log_info "supabase" "All secrets injected into compose files"
