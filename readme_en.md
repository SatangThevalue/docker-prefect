# Prefect Orchestration Stack: Production-Ready with Monitoring

## Table of Contents
1. [Overview](#overview)
2. [System Architecture Diagram (Mermaid)](#system-architecture-diagram-mermaid)
3. [Port Summary](#port-summary)
4. [.env Configuration](#env-configuration)
5. [Key Features & Best Practices](#key-features--best-practices)
6. [Monitoring](#monitoring)
7. [How to Use](#how-to-use)
8. [Health Check & Load Balancer (nginx.conf)](#health-check--load-balancer-nginxconf)
9. [PostgreSQL: Production Note](#postgresql-production-note)
10. [Monitoring Example (prometheus.yml)](#monitoring-example-prometheusyml)
11. [Pointing Prefect self-hosted server to your own server](#pointing-prefect-self-hosted-server-to-your-own-server)
12. [Additional Recommendations](#additional-recommendations)
13. [License](#license)
14. [References](#references)
15. [Read this guide in Thai](./README.md)

---

## Overview
This project provides a production-ready Prefect orchestration stack using Docker Compose, including:
- **Prefect Server** (API, Background, Migrate)
- **PostgreSQL** (with backup and pg_trgm extension)
- **Redis**
- **pgAdmin** (PostgreSQL Web UI)
- **ARDM** (Redis Web UI)
- **Nginx** (Load Balancer + Health Check)
- **Prometheus & Grafana** (Monitoring)

The system separates frontend/backend networks for security and supports multi-server deployment.

---

## System Architecture Diagram (Mermaid)

```mermaid
graph TD
  subgraph Backend Network
    postgres_db[(PostgreSQL)]
    redis_server[(Redis)]
    prefect_migrate[(Prefect Migrate)]
    prefect_background[(Prefect Background)]
    prefect_api1[(Prefect API 1)]
    prefect_api2[(Prefect API 2)]
    prefect_api3[(Prefect API 3)]
    pgbackups[(Postgres Backup)]
    prometheus[(Prometheus)]
    grafana[(Grafana)]
  end

  subgraph Frontend Network
    nginx[(Nginx LB)]
    pgadmin[(pgAdmin)]
    ardm[(ARDM)]
  end

  nginx -- LB --> prefect_api1
  nginx -- LB --> prefect_api2
  nginx -- LB --> prefect_api3
  pgadmin -- Connects to --> postgres_db
  ardm -- Connects to --> redis_server
  prometheus -- Scrape --> prefect_api1
  prometheus -- Scrape --> prefect_api2
  prometheus -- Scrape --> prefect_api3
  prometheus -- Scrape --> postgres_db
  prometheus -- Scrape --> redis_server
  grafana -- Dashboard --> prometheus
  prefect_api1 -- Connects to --> postgres_db
  prefect_api1 -- Connects to --> redis_server
  prefect_api2 -- Connects to --> postgres_db
  prefect_api2 -- Connects to --> redis_server
  prefect_api3 -- Connects to --> postgres_db
  prefect_api3 -- Connects to --> redis_server
  prefect_background -- Connects to --> postgres_db
  prefect_background -- Connects to --> redis_server
  prefect_migrate -- Connects to --> postgres_db
  pgbackups -- Connects to --> postgres_db

  classDef frontend fill:#e0f7fa,stroke:#00796b;
  classDef backend fill:#f3e5f5,stroke:#6a1b9a;
  class nginx,pgadmin,ardm frontend;
  class postgres_db,redis_server,prefect_migrate,prefect_background,prefect_api1,prefect_api2,prefect_api3,pgbackups,prometheus,grafana backend;
```

---

## Port Summary

| Service                | Port (Host) | Port (Container) | Network    | Description                        |
|------------------------|-------------|------------------|------------|------------------------------------|
| Nginx (Load Balancer)  | 4200        | 4200             | frontend   | Prefect UI/REST (via LB)           |
| Prefect API            | 4200-4202   | 4200             | backend    | Prefect API (replica)              |
| pgAdmin                | 8888        | 80               | frontend   | PostgreSQL Web UI                  |
| ARDM (Redis Manager)   | 8081        | 8081             | frontend   | Redis Web UI                       |
| Prometheus             | 9090        | 9090             | backend    | Monitoring                         |
| Grafana                | 3000        | 3000             | backend    | Monitoring Dashboard               |
| PostgreSQL             | (internal)  | 5432             | backend    | Database (not exposed to host)     |
| Redis                  | (internal)  | 6379             | backend    | Message Broker (not exposed to host)|

> Note: You can change host ports in the .env or docker-compose.yml as needed.

---

## .env Configuration

```env
# Project name for container prefix
PROJECT_NAME=prefectstack

# Database user for PostgreSQL
POSTGRES_USER=prefect
# Database password for PostgreSQL
POSTGRES_PASSWORD=prefect
# Database name for PostgreSQL
POSTGRES_DB=prefect

# Prefect API database connection string
PREFECT_API_DATABASE_CONNECTION_URL=postgresql+asyncpg://prefect:prefect@postgres:5432/prefect
# Disable auto-migration on API start (handled by migrate service)
PREFECT_API_DATABASE_MIGRATE_ON_START=false
# Prefect messaging broker backend
PREFECT_MESSAGING_BROKER=prefect_redis.messaging
# Prefect messaging cache backend
PREFECT_MESSAGING_CACHE=prefect_redis.messaging
# Redis host for Prefect messaging
PREFECT_REDIS_MESSAGING_HOST=redis
# Redis port for Prefect messaging
PREFECT_REDIS_MESSAGING_PORT=6379
# Port for Another Redis Desktop Manager (ARDM) web UI
ARDM_PORT=8081

# pgAdmin default email for login
PGADMIN_DEFAULT_EMAIL=admin@admin.com
# pgAdmin default password for login
PGADMIN_DEFAULT_PASSWORD=admin123
# Port for pgAdmin web UI
PGADMIN_PORT=8888

# Grafana admin user
GRAFANA_ADMIN_USER=admin
# Grafana admin password
GRAFANA_ADMIN_PASSWORD=admin123
```

---

## Key Features & Best Practices

- Supports multi-server deployment (scalable API)
- Nginx as Load Balancer with health check `/api/health`
- PostgreSQL auto-installs `pg_trgm` extension (for Prefect)
- Automated Postgres backup (pgbackups)
- Full monitoring with Prometheus + Grafana
- Frontend/backend network separation
- All settings via .env

---

## Monitoring
- **Database connections**: Watch for connection pool exhaustion
- **Redis memory**: Ensure adequate memory for message queues
- **API response times**: Track latency across endpoints
- **Background service lag**: Monitor time between event creation and processing
- **Prometheus**: Collects metrics from Prefect, Postgres, Redis
- **Grafana**: Dashboards for system status

---

## How to Use

1. Edit the `.env` file to match your environment
2. Start the stack:
   ```sh
   docker compose up -d
   ```
3. Access services via the ports defined in `.env`:
   - Prefect UI: http://localhost:4200
   - pgAdmin: http://localhost:8888
   - ARDM: http://localhost:8081
   - Prometheus: http://localhost:9090
   - Grafana: http://localhost:3000
4. Postgres backups are stored in `./postgres_backups`
5. To scale Prefect API, increase replicas in docker-compose and add servers in nginx.conf

---

## Health Check & Load Balancer (nginx.conf)

- Health endpoint: `/api/health` (HTTP 200, JSON `{"status": "healthy"}`)
- Example nginx.conf:

```nginx
upstream prefect_api {
    least_conn;
    server ${PROJECT_NAME}-prefect-api:4200 max_fails=3 fail_timeout=30s;
    # Add more servers if scaling with actual container names
}

server {
    listen 4200;
    
    location /api/health {
        proxy_pass http://prefect_api;
        proxy_connect_timeout 1s;
        proxy_read_timeout 1s;
    }
    
    location / {
        proxy_pass http://prefect_api;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

---

## PostgreSQL: Production Note
- Best for production, high availability, and multi-server deployments
- Prefect requires the `pg_trgm` extension (auto-installed with init-pg_trgm.sh)
- For existing databases, run this in the postgres container:

```sh
docker exec -it ${PROJECT_NAME}-postgres-db bash
psql -U $POSTGRES_USER -d $POSTGRES_DB -c "CREATE EXTENSION IF NOT EXISTS pg_trgm;"
```

---

## Monitoring Example (prometheus.yml)

```yaml
global:
  scrape_interval: 10s

scrape_configs:
  - job_name: 'prefect-api'
    static_configs:
      - targets: ['${PROJECT_NAME}-prefect-api:4200']
  - job_name: 'postgres'
    static_configs:
      - targets: ['${PROJECT_NAME}-postgres-db:5432']
  - job_name: 'redis'
    static_configs:
      - targets: ['${PROJECT_NAME}-redis-server:6379']
```

---

## Pointing Prefect self-hosted server to your own server

To point your Prefect self-hosted server to your own server, set `PREFECT_API_URL` to the address of your Prefect Server. Main steps:

### 1. Install Prefect Server on your server
- **Via CLI**: Run Prefect Server directly from CLI
- **Via Docker**: Recommended for production

Example (Docker):
```sh
docker run -p 4200:4200 -d --rm prefecthq/prefect:3-latest -- prefect server start --host 0.0.0.0
```

### 2. Set `PREFECT_API_URL` to your server
Set `PREFECT_API_URL` on any machine running Prefect Flows (client/worker/agent):

#### Via CLI (active profile):
```sh
prefect config set PREFECT_API_URL="http://your-server-hostname-or-ip:4200/api"
```
#### Via environment variable:
```sh
export PREFECT_API_URL="http://your-server-hostname-or-ip:4200/api"
```
#### Via .env or prefect.toml:
.env:
```env
PREFECT_API_URL="http://your-server-hostname-or-ip:4200/api"
```
prefect.toml:
```toml
[api]
url = "http://your-server-hostname-or-ip:4200/api"
```

### 3. Additional considerations
- **Database**: For production, use PostgreSQL (set `PREFECT_API_DATABASE_CONNECTION_URL`)
- **Worker vs Agent**: Prefer Worker for new deployments
- **Firewall/Network**: Ensure port 4200 is open and accessible
- **HTTPS/SSL**: Use a reverse proxy and SSL for production
- **Authentication**: Set up basic auth if needed
- **Profiles**: Use Prefect profiles for different environments

---

## Additional Recommendations
- Start with 2-3 Prefect API instances and scale as needed
- Use connection pooling for database
- Monitor extensively before scaling
- Test failover scenarios regularly

---

## License
MIT

---

## References
- https://docs.prefect.io/latest/
- https://github.com/PrefectHQ/prefect
- https://hub.docker.com/r/prefecthq/prefect
- https://hub.docker.com/_/postgres
- https://hub.docker.com/_/redis
- https://hub.docker.com/r/dpage/pgadmin4
- https://hub.docker.com/r/qishibo/another-redis-desktop-manager
- https://hub.docker.com/r/prom/prometheus
- https://hub.docker.com/r/grafana/grafana
- https://prometheus.io/docs/introduction/overview/
- https://grafana.com/docs/grafana/latest/
- https://www.nginx.com/resources/wiki/
- [Read this guide in Thai](./README.md)

---

## Server Setup Script (setup_docker.sh)

This project includes a script for Ubuntu systems to install Docker, Docker Compose, and add the current user to the docker group for non-root usage.

### Script Details
- Updates and upgrades the system
- Installs required packages and Docker’s official GPG key
- Adds the Docker repository and installs Docker Engine, CLI, containerd, and Docker Compose plugin
- Enables and starts the Docker service
- Adds the current user to the docker group

### Usage
```sh
sudo bash setup_docker.sh
```
After running, log out and log in again to use Docker without sudo.

### System Requirements
- Ubuntu 20.04 LTS or later (recommended)
- 64-bit architecture
- Internet connection

### Recommended VM Specs
| Cloud Provider    | vCPU | RAM  | Storage (SSD) | Example Instance Type         |
|------------------|------|------|---------------|------------------------------|
| AWS EC2          | 2+   | 4GB+ | 40GB+         | t3.medium, t3.large          |
| Google Cloud     | 2+   | 4GB+ | 40GB+         | e2-standard-2, n2-standard-2 |
| Microsoft Azure  | 2+   | 4GB+ | 40GB+         | Standard_B2s, D2s_v3         |

- For production, 4 vCPU/8GB RAM or higher is recommended for high load or scaling.
- All providers support Ubuntu images and Docker installation.

### References
- [AWS EC2 Instance Types](https://aws.amazon.com/ec2/instance-types/)
- [Google Cloud Machine Types](https://cloud.google.com/compute/docs/general-purpose-machines)
- [Azure VM Sizes](https://learn.microsoft.com/en-us/azure/virtual-machines/sizes)
