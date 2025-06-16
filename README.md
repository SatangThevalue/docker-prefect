# Prefect Orchestration Stack: Production-Ready with Monitoring

## สารบัญ
1. [Overview](#overview)
2. [System Architecture Diagram (Mermaid)](#system-architecture-diagram-mermaid)
3. [สรุปพอร์ตที่ใช้ในระบบ](#สรุปพอร์ตที่ใช้ในระบบ)
4. [.env Configuration](#env-configuration)
5. [Key Features & Best Practices](#key-features--best-practices)
6. [Monitoring](#monitoring)
7. [How to Use](#how-to-use)
8. [Health Check & Load Balancer (nginx.conf)](#health-check--load-balancer-nginxconf)
9. [PostgreSQL: Production Note](#postgresql-production-note)
10. [Monitoring Example (prometheus.yml)](#monitoring-example-prometheusyml)
11. [การชี้ Prefect self-hosted server ไปยังเซิร์ฟเวอร์ของคุณเอง](#การชี้-prefect-self-hosted-server-ไปยังเซิร์ฟเวอร์ของคุณเอง)
12. [คำแนะนำเพิ่มเติม](#คำแนะนำเพิ่มเติม)
13. [License](#license)
14. [แหล่งอ้างอิง](#แหล่งอ้างอิง)

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

---

## การชี้ Prefect self-hosted server ไปยังเซิร์ฟเวอร์ของคุณเอง

การชี้ Prefect self-hosted server ไปยังเซิร์ฟเวอร์ของเราเองนั้นมีขั้นตอนหลักๆ คือการตั้งค่า `PREFECT_API_URL` ให้ชี้ไปยังที่อยู่ของ Prefect Server ที่คุณติดตั้งไว้ โดยมีวิธีการต่างๆ ดังนี้:

### 1. ติดตั้ง Prefect Server บนเซิร์ฟเวอร์ของคุณ

ก่อนอื่น คุณต้องติดตั้ง Prefect Server บนเซิร์ฟเวอร์ที่คุณต้องการให้เป็นศูนย์กลางในการจัดการเวิร์คโฟลว์ของคุณ Prefect มีหลายวิธีในการติดตั้ง เช่น:
- **ผ่าน CLI**: คุณสามารถรัน Prefect Server ได้โดยตรงจาก Command Line Interface (CLI)
- **ผ่าน Docker**: การใช้ Docker เป็นวิธีที่นิยมและแนะนำสำหรับการตั้งค่า production เนื่องจากช่วยให้การจัดการ Dependency และ Environment เป็นไปได้ง่ายขึ้น

ตัวอย่างการรัน Prefect Server ด้วย Docker:
```sh
docker run -p 4200:4200 -d --rm prefecthq/prefect:3-latest -- prefect server start --host 0.0.0.0
```
คำสั่งนี้จะรัน Prefect Server บนพอร์ต 4200 และให้ Prefect Server ฟังการเชื่อมต่อจากทุก IP (0.0.0.0) ซึ่งสำคัญมากเมื่อรันใน Docker เพื่อให้สามารถเข้าถึงได้จากภายนอกคอนเทนเนอร์

### 2. กำหนด PREFECT_API_URL เพื่อชี้ไปยังเซิร์ฟเวอร์ของคุณ

เมื่อ Prefect Server ของคุณทำงานอยู่ คุณต้องกำหนดค่า `PREFECT_API_URL` บนเครื่องที่คุณต้องการรัน Prefect Flows (เช่น เครื่องที่คุณพัฒนาโค้ด หรือเครื่องที่รัน Prefect Worker/Agent) เพื่อให้ Prefect Client, Worker, หรือ Agent รู้ว่าจะเชื่อมต่อไปยัง Prefect Server ที่ใด

คุณสามารถตั้งค่า `PREFECT_API_URL` ได้หลายวิธี:

#### ผ่าน Command Line (สำหรับ Active Profile):
```sh
prefect config set PREFECT_API_URL="http://your-server-hostname-or-ip:4200/api"
```
แทนที่ `your-server-hostname-or-ip` ด้วย IP Address หรือชื่อโฮสต์ของเซิร์ฟเวอร์ที่คุณติดตั้ง Prefect Server และ 4200 คือพอร์ตที่คุณเปิดให้ Prefect Server ฟัง (ค่าเริ่มต้นคือ 4200)

#### ผ่าน Environment Variable:
```sh
export PREFECT_API_URL="http://your-server-hostname-or-ip:4200/api"
```

#### ผ่านไฟล์ .env หรือ prefect.toml (สำหรับโปรเจกต์):
ในไฟล์ `.env`:
```env
PREFECT_API_URL="http://your-server-hostname-or-ip:4200/api"
```
ในไฟล์ `prefect.toml`:
```toml
[api]
url = "http://your-server-hostname-or-ip:4200/api"
```

### 3. การพิจารณาเพิ่มเติม

- **การตั้งค่าฐานข้อมูล (Database Configuration):** โดยค่าเริ่มต้น Prefect จะใช้ SQLite เป็นฐานข้อมูล ซึ่งเหมาะสำหรับการใช้งานส่วนบุคคลหรือการพัฒนา แต่สำหรับ production คุณควรพิจารณาใช้ฐานข้อมูลภายนอก เช่น PostgreSQL เพื่อความทนทานและความสามารถในการขยายขนาด

  คุณสามารถตั้งค่า `PREFECT_API_DATABASE_CONNECTION_URL` ได้เช่นกัน:
  ```sh
  prefect config set PREFECT_API_DATABASE_CONNECTION_URL="postgresql+asyncpg://user:password@host:port/prefect"
  ```

- **Prefect Worker แทน Agent:** Prefect แนะนำให้ใช้ Prefect Worker แทน Agent ในเวอร์ชันล่าสุด Worker มีความยืดหยุ่นและมีประสิทธิภาพมากกว่า

- **Firewall และ Network:** ตรวจสอบให้แน่ใจว่า Firewall บนเซิร์ฟเวอร์ของคุณอนุญาตให้มีการเชื่อมต่อขาเข้าบนพอร์ตที่ Prefect Server ใช้งานอยู่ (เช่น 4200) และเครือข่ายของคุณอนุญาตให้เครื่อง Client/Worker/Agent สามารถเข้าถึงเซิร์ฟเวอร์ Prefect ได้

- **HTTPS/SSL:** สำหรับ Production Environment ควรตั้งค่า Prefect Server ให้ทำงานบน HTTPS โดยการใช้ Reverse Proxy (เช่น Nginx หรือ Apache) และกำหนดค่า SSL certificates เพื่อความปลอดภัย

- **การจัดการผู้ใช้และการรับรองความถูกต้อง (User Management and Authentication):** สำหรับ Self-hosted Prefect ในเวอร์ชัน Community Edition การจัดการผู้ใช้อาจมีข้อจำกัด Prefect มีคุณสมบัติ Basic Authentication ที่สามารถตั้งค่าได้สำหรับเซิร์ฟเวอร์ที่ติดตั้งด้วยตัวเอง

  - บนเซิร์ฟเวอร์: `prefect config set server.api.auth_string="admin:your_password"`
  - บน Client/Worker: `prefect config set api.auth_string="admin:your_password"`

- **Profiles:** Prefect มีระบบ Profiles ที่ช่วยให้คุณจัดการการตั้งค่าต่างๆ ได้ คุณสามารถสร้าง Profile ใหม่สำหรับการเชื่อมต่อไปยัง Prefect Server ของคุณได้

---

## สคริปต์ติดตั้งเซิร์ฟเวอร์ (setup_docker.sh)

โปรเจคนี้มีสคริปต์สำหรับ Ubuntu เพื่อช่วยติดตั้ง Docker, Docker Compose และเพิ่มผู้ใช้เข้า group docker เพื่อใช้งานโดยไม่ต้องใช้ sudo

### รายละเอียดสคริปต์
- อัปเดตและอัปเกรดระบบ
- ติดตั้งแพ็กเกจที่จำเป็นและ GPG key ของ Docker
- เพิ่ม Docker repository และติดตั้ง Docker Engine, CLI, containerd, Docker Compose plugin
- เปิดใช้งานและสตาร์ท Docker service
- เพิ่มผู้ใช้ปัจจุบันเข้า group docker

### วิธีใช้งาน
```sh
sudo bash setup_docker.sh
```
หลังจากรันแล้ว ให้ logout/login ใหม่เพื่อใช้งาน docker โดยไม่ต้องใช้ sudo

### ข้อกำหนดระบบ (System Requirements)
- Ubuntu 20.04 LTS ขึ้นไป (แนะนำ)
- สถาปัตยกรรม 64-bit
- อินเทอร์เน็ต

### สเปค VM ที่แนะนำ
| ผู้ให้บริการ Cloud | vCPU | RAM  | Storage (SSD) | ตัวอย่าง Instance Type         |
|--------------------|------|------|---------------|-------------------------------|
| AWS EC2            | 2+   | 4GB+ | 40GB+         | t3.medium, t3.large           |
| Google Cloud       | 2+   | 4GB+ | 40GB+         | e2-standard-2, n2-standard-2  |
| Microsoft Azure    | 2+   | 4GB+ | 40GB+         | Standard_B2s, D2s_v3          |

- สำหรับ production แนะนำ 4 vCPU/8GB RAM ขึ้นไป หากต้องการรองรับโหลดสูงหรือ scale
- ทุกผู้ให้บริการรองรับ Ubuntu และ Docker

### แหล่งอ้างอิง
- [AWS EC2 Instance Types](https://aws.amazon.com/ec2/instance-types/)
- [Google Cloud Machine Types](https://cloud.google.com/compute/docs/general-purpose-machines)
- [Azure VM Sizes](https://learn.microsoft.com/en-us/azure/virtual-machines/sizes)
