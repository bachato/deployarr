# Contributing Community Apps to Deployrr

Welcome! This guide explains how to contribute apps to the Deployrr community app store. Community apps extend Deployrr's functionality and help fellow homelab enthusiasts.

## Table of Contents

- [Quick Start](#quick-start)
- [Directory Structure](#directory-structure)
- [The Manifest File](#the-manifest-file)
- [The Compose File](#the-compose-file)
- [Environment Variables & Placeholders](#environment-variables--placeholders)
- [Registering Your App](#registering-your-app)
- [Testing Your App](#testing-your-app)
- [Submission Checklist](#submission-checklist)
- [Examples](#examples)

---

## Quick Start

To add a community app, you need to create:

1. **A folder** named after your app (lowercase, hyphens for spaces)
2. **`manifest.json`** - App metadata and configuration
3. **`compose.yml`** - Docker Compose definition

```
apps/community/
├── apps.json              # Registry of all community apps
└── your-app-name/
    ├── manifest.json      # App configuration
    └── compose.yml        # Docker Compose file
```

---

## Directory Structure

### Folder Naming Rules

- Use **lowercase** letters only
- Use **hyphens** (`-`) to separate words
- Match the container name when possible
- Maximum 32 characters

**Good:** `uptime-kuma`, `it-tools`, `home-assistant`
**Bad:** `UptimeKuma`, `it_tools`, `HomeAssistant`

---

## The Manifest File

The `manifest.json` file is the heart of your app definition. It tells Deployrr everything it needs to know about your app.

### Complete Manifest Structure

```json
{
  "$schema": "../../../apps/manifest-schema.json",
  "version": "1.2",

  "app": {
    "sname": "your-app",
    "pname": "Your App",
    "description": "A detailed description of what your app does. This appears in the app info dialog.",
    "descriptionShort": "Brief description (max 42 chars)",
    "icon": "sh-your-app",
    "category": "community",
    "menuNumber": "07",
    "tags": ["category1", "category2", "category3"]
  },

  "deployment": {
    "type": "single",
    "compose": "compose.yml",
    "profiles": ["apps", "all"],
    "networks": ["default"],
    "webui": true,
    "port": 8080,
    "protocol": "http"
  },

  "requirements": {
    "prerequisites": ["prerequisites"],
    "apps": []
  },

  "traefik": {
    "supported": true
  },

  "dashboard": {
    "enabled": true,
    "location": "local",
    "showStats": true,
    "portVariable": "YOURAPP_PORT"
  },

  "env": {
    "variables": [
      {
        "name": "YOURAPP_PORT",
        "description": "Web interface port",
        "type": "port",
        "default": 8080,
        "prompt": true,
        "required": true,
        "validation": {
          "type": "port",
          "min": 1,
          "max": 65535
        }
      }
    ]
  },

  "status": {
    "file": "07_yourapp_status",
    "successMessage": "Your App Setup Completed",
    "telemetryAction": "yourapp"
  }
}
```

### Manifest Field Reference

#### `app` Section (Required)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `sname` | string | Yes | Service/container name. Lowercase, hyphens only. Max 32 chars. Pattern: `^[a-z0-9-]+$` |
| `pname` | string | Yes | Display name shown to users (e.g., "Uptime Kuma") |
| `description` | string | Yes | Full description for app info dialog |
| `descriptionShort` | string | Yes | Short description for menus. **Max 42 characters** |
| `icon` | string | Yes | Icon identifier. Use format `sh-appname` (selfh.st/icons) |
| `category` | string | Yes | Must be `"community"` for community apps |
| `menuNumber` | string | Yes | Must be `"07"` for community apps |
| `tags` | array | No | Keywords for filtering (e.g., `["monitoring", "dashboard"]`) |

#### `deployment` Section (Required)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | No | `"single"` for Tier 1 apps (default) |
| `compose` | string | Yes | Compose filename, always `"compose.yml"` |
| `profiles` | array | Yes | Docker profiles. Use `["apps", "all"]` for most apps |
| `networks` | array | No | Networks needed. Default: `["default"]` |
| `webui` | boolean | Yes | `true` if app has a web interface |
| `port` | number | No | Default port number (required if `webui: true`) |
| `protocol` | string | No | `"http"` or `"https"` |

#### `requirements` Section (Required)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `prerequisites` | array | Yes | Always include `["prerequisites"]` |
| `apps` | array | No | Other apps that must be running (e.g., `["mariadb"]`) |

#### `traefik` Section

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `supported` | boolean | No | `true` if app can work behind Traefik reverse proxy |

#### `dashboard` Section

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `enabled` | boolean | No | `true` to show on Deployrr dashboard |
| `location` | string | No | `"local"`, `"remote"`, or `"other"` |
| `showStats` | boolean | No | `true` to show container stats |
| `portVariable` | string | No | Env var name containing the port (e.g., `"YOURAPP_PORT"`) |

#### `env` Section

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `variables` | array | No | Environment variables to configure |

**Variable Object Fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Variable name (e.g., `YOURAPP_PORT`) |
| `description` | string | No | Human-readable description |
| `type` | string | Yes | `"port"`, `"string"`, or `"password"` |
| `default` | any | No | Default value |
| `prompt` | boolean | No | `true` to ask user during install |
| `required` | boolean | No | `true` if value must be provided |
| `validation` | object | No | Validation rules |

#### `status` Section (Required)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `file` | string | Yes | Status filename. Format: `07_appname_status` |
| `successMessage` | string | Yes | Message shown on successful install |
| `telemetryAction` | string | Yes | Telemetry identifier (lowercase, no hyphens) |

---

## The Compose File

The `compose.yml` file defines your Docker container(s).

### Basic Template

```yaml
services:
  # App Name - Short Description
  your-app:
    image: publisher/image:latest
    container_name: your-app
    security_opt:
      - no-new-privileges:true
    restart: unless-stopped
    profiles: ["apps", "all"]
    networks:
      - default
    ports:
      - "$YOURAPP_PORT:8080"
    volumes:
      - $DOCKERDIR/appdata/your-app:/config
    environment:
      PUID: $PUID
      PGID: $PGID
      TZ: $TZ
    # DOCKER-LABELS-PLACEHOLDER
```

### Compose File Rules

1. **Service name** must match `sname` in manifest
2. **Container name** must match `sname` in manifest
3. **Always include** `security_opt: - no-new-privileges:true`
4. **Always include** `restart: unless-stopped`
5. **Profiles** must match manifest's `deployment.profiles`
6. **Networks** must match manifest's `deployment.networks`
7. **End with** `# DOCKER-LABELS-PLACEHOLDER` comment (for Traefik labels)

### Required Elements

| Element | Purpose |
|---------|---------|
| `security_opt: - no-new-privileges:true` | Security hardening |
| `restart: unless-stopped` | Auto-restart on failure |
| `profiles` | Control when container starts |
| `networks` | Network connectivity |
| `# DOCKER-LABELS-PLACEHOLDER` | Traefik label injection point |

---

## Environment Variables & Placeholders

### System Variables (Always Available)

These variables are automatically provided by Deployrr:

| Variable | Description | Example |
|----------|-------------|---------|
| `$DOCKERDIR` | Docker root directory | `/home/user/docker` |
| `$PUID` | User ID for permissions | `1000` |
| `$PGID` | Group ID for permissions | `1000` |
| `$TZ` | Timezone | `America/New_York` |
| `$DOMAINNAME_1` | Primary domain (if configured) | `example.com` |

### Port Variables

For apps with a web UI, define a port variable:

**In manifest.json:**
```json
"env": {
  "variables": [
    {
      "name": "YOURAPP_PORT",
      "description": "Web interface port",
      "type": "port",
      "default": 8080,
      "prompt": true,
      "required": true,
      "validation": {
        "type": "port",
        "min": 1,
        "max": 65535
      }
    }
  ]
}
```

**In compose.yml:**
```yaml
ports:
  - "$YOURAPP_PORT:8080"
```

### Port Naming Convention

- Use `APPNAME_PORT` format
- Remove hyphens from app name
- All uppercase

| App Name | Port Variable |
|----------|---------------|
| `uptime-kuma` | `UPTIMEKUMA_PORT` |
| `it-tools` | `ITTOOLS_PORT` |
| `home-assistant` | `HOMEASSISTANT_PORT` |

### Volume Paths

Always use the standard appdata path format:

```yaml
volumes:
  - $DOCKERDIR/appdata/your-app:/config
```

---

## Registering Your App

Add your app to `apps/community/apps.json`:

```json
{
  "version": "2.1",
  "description": "Community Deployrr Apps Registry",
  "lastUpdated": "2026-01-24",
  "apps": [
    "existing-app",
    "your-app"
  ]
}
```

Keep apps sorted alphabetically by name.

---

## Testing Your App

Before submitting, verify:

1. **JSON Validation**
   ```bash
   # Validate manifest.json syntax
   python -m json.tool apps/community/your-app/manifest.json
   ```

2. **YAML Validation**
   ```bash
   # Validate compose.yml syntax
   docker compose -f apps/community/your-app/compose.yml config
   ```

3. **Container Test**
   ```bash
   # Test the container starts
   docker compose -f apps/community/your-app/compose.yml up -d
   docker logs your-app
   ```

4. **Verify Required Fields**
   - [ ] `sname` matches folder name
   - [ ] `sname` matches compose service name
   - [ ] `sname` matches compose container_name
   - [ ] `category` is `"community"`
   - [ ] `menuNumber` is `"07"`
   - [ ] `descriptionShort` is 42 characters or less
   - [ ] Status file uses `07_` prefix

---

## Submission Checklist

- [ ] Folder name matches `sname`
- [ ] `manifest.json` is valid JSON
- [ ] `compose.yml` is valid YAML
- [ ] All required manifest sections present
- [ ] `category` set to `"community"`
- [ ] `menuNumber` set to `"07"`
- [ ] Port variable defined (if webui: true)
- [ ] `# DOCKER-LABELS-PLACEHOLDER` at end of compose
- [ ] App added to `apps.json`
- [ ] Tested container starts successfully
- [ ] No hardcoded paths (use `$DOCKERDIR`)
- [ ] Security options included

---

## Examples

### Example 1: Simple Web App (IT-Tools)

**manifest.json:**
```json
{
  "$schema": "../../../apps/manifest-schema.json",
  "version": "1.2",

  "app": {
    "sname": "it-tools",
    "pname": "IT-Tools",
    "description": "IT-Tools is a collection of handy online tools for developers and IT professionals.",
    "descriptionShort": "Set of IT tools",
    "icon": "sh-it-tools",
    "category": "community",
    "menuNumber": "07",
    "tags": ["tools", "developer", "utilities"]
  },

  "deployment": {
    "type": "single",
    "compose": "compose.yml",
    "profiles": ["apps", "all"],
    "networks": ["default"],
    "webui": true,
    "port": 8080,
    "protocol": "http"
  },

  "requirements": {
    "prerequisites": ["prerequisites"],
    "apps": []
  },

  "traefik": {
    "supported": true
  },

  "dashboard": {
    "enabled": true,
    "location": "local",
    "showStats": true,
    "portVariable": "ITTOOLS_PORT"
  },

  "env": {
    "variables": [
      {
        "name": "ITTOOLS_PORT",
        "description": "Web interface port",
        "type": "port",
        "default": 8080,
        "prompt": true,
        "required": true,
        "validation": {
          "type": "port",
          "min": 1,
          "max": 65535
        }
      }
    ]
  },

  "status": {
    "file": "07_ittools_status",
    "successMessage": "IT-Tools Setup Completed",
    "telemetryAction": "ittools"
  }
}
```

**compose.yml:**
```yaml
services:
  # IT-Tools - IT Tools Dashboard
  it-tools:
    image: corentinth/it-tools
    container_name: it-tools
    security_opt:
      - no-new-privileges:true
    restart: unless-stopped
    profiles: ["apps", "all"]
    networks:
      - default
    ports:
      - "$ITTOOLS_PORT:80"
    # DOCKER-LABELS-PLACEHOLDER
```

### Example 2: App with Persistent Data (Uptime Kuma)

**manifest.json:**
```json
{
  "$schema": "../../../apps/manifest-schema.json",
  "version": "1.2",

  "app": {
    "sname": "uptime-kuma",
    "pname": "Uptime-Kuma",
    "description": "Uptime Kuma is a fancy, self-hosted monitoring tool with a beautiful status page.",
    "descriptionShort": "Self-hosted monitoring tool",
    "icon": "sh-uptime-kuma",
    "category": "community",
    "menuNumber": "07",
    "tags": ["monitoring", "uptime", "status"]
  },

  "deployment": {
    "type": "single",
    "compose": "compose.yml",
    "profiles": ["apps", "all"],
    "networks": ["default"],
    "webui": true,
    "port": 3001,
    "protocol": "http"
  },

  "requirements": {
    "prerequisites": ["prerequisites"],
    "apps": []
  },

  "traefik": {
    "supported": true
  },

  "dashboard": {
    "enabled": true,
    "location": "local",
    "showStats": true,
    "portVariable": "UPTIMEKUMA_PORT"
  },

  "env": {
    "variables": [
      {
        "name": "UPTIMEKUMA_PORT",
        "description": "Web interface port",
        "type": "port",
        "default": 3001,
        "prompt": true,
        "required": true,
        "validation": {
          "type": "port",
          "min": 1,
          "max": 65535
        }
      }
    ]
  },

  "status": {
    "file": "07_uptimekuma_status",
    "successMessage": "Uptime-Kuma Setup Completed",
    "telemetryAction": "uptimekuma"
  }
}
```

**compose.yml:**
```yaml
services:
  # Uptime Kuma - Status Page & Monitoring Server
  uptime-kuma:
    image: louislam/uptime-kuma
    container_name: uptime-kuma
    security_opt:
      - no-new-privileges:true
    restart: unless-stopped
    profiles: ["apps", "all"]
    networks:
      - default
    ports:
      - "$UPTIMEKUMA_PORT:3001"
    volumes:
      - $DOCKERDIR/appdata/uptime-kuma:/app/data
    # DOCKER-LABELS-PLACEHOLDER
```

### Example 3: App Without Web UI (Watchtower)

**manifest.json:**
```json
{
  "$schema": "../../../apps/manifest-schema.json",
  "version": "1.2",

  "app": {
    "sname": "watchtower",
    "pname": "Watchtower",
    "description": "Watchtower automatically updates running Docker containers when new images are available.",
    "descriptionShort": "Container auto-updater",
    "icon": "sh-watchtower",
    "category": "community",
    "menuNumber": "07",
    "tags": ["docker", "automation", "updates"]
  },

  "deployment": {
    "type": "single",
    "compose": "compose.yml",
    "profiles": ["apps", "all"],
    "networks": ["default"],
    "webui": false,
    "port": null,
    "protocol": "http"
  },

  "requirements": {
    "prerequisites": ["prerequisites"],
    "apps": []
  },

  "traefik": {
    "supported": false
  },

  "dashboard": {
    "enabled": false,
    "location": "local",
    "showStats": true
  },

  "env": {
    "variables": []
  },

  "status": {
    "file": "07_watchtower_status",
    "successMessage": "Watchtower Setup Completed",
    "telemetryAction": "watchtower"
  }
}
```

**compose.yml:**
```yaml
services:
  # Watchtower - Container Monitoring and Management
  watchtower:
    image: containrrr/watchtower
    container_name: watchtower
    security_opt:
      - no-new-privileges:true
    restart: always
    profiles: ["apps", "all"]
    networks:
      - default
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      TZ: $TZ
      WATCHTOWER_CLEANUP: true
      WATCHTOWER_INCLUDE_RESTARTING: true
      WATCHTOWER_POLL_INTERVAL: 36000
    # DOCKER-LABELS-PLACEHOLDER
```

---

## Getting Help

- **Questions?** Open an issue on GitHub
- **Found a bug?** Submit a bug report
- **Want to contribute?** Fork the repo and submit a PR

Thank you for contributing to Deployrr!
