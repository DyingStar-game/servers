# Auth Server

Authentication server for Dying Star using Keycloak with PostgreSQL database and Traefik reverse proxy.

## Prerequisites

- Docker and Docker Compose installed
- Domain name configured for your auth server

## Environment Variables

Create a `.env` file in this directory with the following variables:

```env
# Database configuration
DB_USER=your_db_user
DB_PASSWORD=your_secure_db_password

# Keycloak admin configuration
KC_ADMIN_PASSWORD=your_secure_admin_password

# Domain configuration
DOMAIN_AUTH=auth.yourdomain.com

# Let's Encrypt configuration
EMAIL_LETSENCRYPT=your-email@example.com
ACME_CASERVER=https://acme-v02.api.letsencrypt.org/directory
```

## Setup

1. Create the Traefik authentication file:
   ```bash
   mkdir -p traefik
   # Generate htpasswd file for Traefik dashboard access
   htpasswd -c traefik/.htpasswd your_username
   ```

2. Start the services:
   ```bash
   docker-compose up -d
   ```

## Services

- **Traefik**: Reverse proxy and SSL termination (ports 80/443)
- **PostgreSQL**: Database for Keycloak (internal)
- **Keycloak**: Authentication server accessible at `https://${DOMAIN_AUTH}`

## Access

- Keycloak Admin Console: `https://${DOMAIN_AUTH}/admin`
  - Username: `admin`
  - Password: `${KC_ADMIN_PASSWORD}`

- Traefik Dashboard: `https://traefik.srv934816.hstgr.cloud`
  - Uses basic auth from `.htpasswd` file

## Commands

```bash
# Start services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down

# Stop and remove volumes
docker-compose down -v
```