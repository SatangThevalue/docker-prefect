# Prefect Orchestration Stack: Production-Ready with Monitoring

## Overview

ระบบนี้เป็น Prefect orchestration stack ที่พร้อมใช้งาน production ด้วย Docker Compose ประกอบด้วยบริการหลัก:
- **Prefect Server** (API, Background, Migrate)
- **PostgreSQL** (พร้อมสำรองข้อมูลและ extension pg_trgm)
- **Redis**
- **pgAdmin** (UI จัดการ PostgreSQL)
- **ARDM** (UI จัดการ Redis)
- **Nginx** (Load Balancer + Health Check)
- **Prometheus & Grafana** (Monitoring)

ระบบแยก network frontend/backend เพื่อความปลอดภัยและรองรับ multi-server deployment

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

- รองรับ multi-server deployment (scale API ได้)
- ใช้ Nginx เป็น Load Balancer พร้อม health check `/api/health`
- PostgreSQL ติดตั้ง extension `pg_trgm` อัตโนมัติ (สำหรับ Prefect)
- สำรองข้อมูล Postgres อัตโนมัติ (pgbackups)
- Monitoring ครบวงจรด้วย Prometheus + Grafana
- แยก network frontend/backend
- ตั้งค่าทุกอย่างผ่าน .env

---

## Monitoring
- **Database connections**: เฝ้าระวัง connection pool exhaustion
- **Redis memory**: ตรวจสอบ memory queue
- **API response times**: ติดตาม latency endpoint ต่าง ๆ
- **Background service lag**: เฝ้าดูเวลาระหว่าง event creation และ processing
- **Prometheus**: เก็บ metrics จาก Prefect, Postgres, Redis
- **Grafana**: Dashboard สำหรับดูสถานะระบบ

---

## How to Use

1. แก้ไขไฟล์ `.env` ให้เหมาะสมกับสภาพแวดล้อมของคุณ
2. สั่งรันด้วยคำสั่ง:
   ```sh
   docker compose up -d
   ```
3. เข้าถึงแต่ละบริการผ่านพอร์ตที่กำหนดใน `.env` เช่น
   - Prefect UI: http://localhost:4200
   - pgAdmin: http://localhost:8888
   - ARDM: http://localhost:8081
   - Prometheus: http://localhost:9090
   - Grafana: http://localhost:3000
4. สำรองข้อมูล Postgres จะอยู่ใน `./postgres_backups`
5. หากต้องการ scale Prefect API ให้เพิ่ม replicas ใน docker-compose และเพิ่ม server ใน nginx.conf

---

## Health Check & Load Balancer (nginx.conf)

- Health endpoint: `/api/health` (HTTP 200, JSON `{"status": "healthy"}`)
- ตัวอย่าง nginx.conf:

```nginx
upstream prefect_api {
    least_conn;
    server ${PROJECT_NAME}-prefect-api:4200 max_fails=3 fail_timeout=30s;
    # เพิ่ม server เพิ่มเติมหาก scale ด้วยชื่อ container จริง
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
- เหมาะสำหรับ production, high availability, multi-server deployments
- Prefect ต้องใช้ extension `pg_trgm` (ติดตั้งอัตโนมัติด้วย init-pg_trgm.sh)
- หากใช้ฐานข้อมูลเดิม ให้รันสคริปต์นี้ใน container postgres:

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

## สรุปพอร์ตที่ใช้ในระบบ

| Service                | Port (Host) | Port (Container) | Network    | Description                        |
|------------------------|-------------|------------------|------------|------------------------------------|
| Nginx (Load Balancer)  | 4200        | 4200             | frontend   | Prefect UI/REST (ผ่าน LB)          |
| Prefect API            | 4200-4202   | 4200             | backend    | Prefect API (replica)              |
| pgAdmin                | 8888        | 80               | frontend   | PostgreSQL Web UI                  |
| ARDM (Redis Manager)   | 8081        | 8081             | frontend   | Redis Web UI                       |
| Prometheus             | 9090        | 9090             | backend    | Monitoring                         |
| Grafana                | 3000        | 3000             | backend    | Monitoring Dashboard               |
| PostgreSQL             | (internal)  | 5432             | backend    | Database (ไม่ expose ออก host)     |
| Redis                  | (internal)  | 6379             | backend    | Message Broker (ไม่ expose ออก host)|

> หมายเหตุ: สามารถเปลี่ยนพอร์ตฝั่ง host ได้ในไฟล์ .env หรือ docker-compose.yml ตามต้องการ

---

## คำแนะนำเพิ่มเติม
- เริ่มต้น Prefect API 2-3 instance และ scale ตาม load จริง
- ใช้ connection pooling กับฐานข้อมูล
- ติดตั้ง monitoring ก่อน scale เพิ่มเติม
- ทดสอบ failover scenario เป็นประจำ

---

## License
MIT
