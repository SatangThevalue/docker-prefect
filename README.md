# Prefect Orchestration Stack with PostgreSQL, Redis, pgAdmin, ARDM, and Automated Backups

## Overview
โปรเจคนี้เป็นระบบ Orchestration สำหรับ Prefect ที่พร้อมใช้งานในสภาพแวดล้อม production ด้วย Docker Compose ประกอบด้วยบริการหลักดังนี้:

- **Prefect Server**: ระบบ workflow orchestration สำหรับ data pipeline และ automation
- **PostgreSQL**: ฐานข้อมูลหลักสำหรับ Prefect
- **Redis**: ใช้สำหรับ messaging และ caching ของ Prefect
- **pgAdmin**: UI สำหรับจัดการและดูแล PostgreSQL
- **Another Redis Desktop Manager (ARDM)**: UI สำหรับจัดการ Redis
- **Automated PostgreSQL Backups**: สำรองข้อมูลอัตโนมัติทุกวัน

ระบบนี้แยก network เป็น frontend/backend เพื่อความปลอดภัยและการจัดการที่ดี

---

## Service Details

- **postgres**: ฐานข้อมูล PostgreSQL สำหรับ Prefect
- **redis**: Redis สำหรับ messaging/caching
- **migrate**: รัน database migration อัตโนมัติให้ Prefect
- **prefect-api**: API และ UI ของ Prefect (scale ได้)
- **prefect-background**: Background services ของ Prefect
- **ardm**: Another Redis Desktop Manager สำหรับดูแล Redis
- **pgadmin**: pgAdmin สำหรับดูแล PostgreSQL
- **pgbackups**: สำรองข้อมูล PostgreSQL อัตโนมัติทุกวัน

---

## .env Configuration

ไฟล์ `.env` ใช้สำหรับตั้งค่าตัวแปรสำคัญต่าง ๆ ของระบบ เช่น

```
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
```

**หมายเหตุ:**
- สามารถเปลี่ยนชื่อโปรเจคได้ที่ `PROJECT_NAME` เพื่อให้ container_name ทุกตัวมี prefix ตามโปรเจค
- สามารถเปลี่ยนรหัสผ่าน, อีเมล, และพอร์ตต่าง ๆ ได้ตามต้องการ

---

## Usage

1. แก้ไขไฟล์ `.env` ให้เหมาะสมกับสภาพแวดล้อมของคุณ
2. สั่งรันด้วยคำสั่ง:
   ```sh
   docker compose up -d
   ```
3. เข้าถึงแต่ละบริการผ่านพอร์ตที่กำหนดใน `.env` เช่น
   - Prefect UI: http://localhost:4200
   - pgAdmin: http://localhost:8888
   - ARDM: http://localhost:8081
4. ไฟล์ backup ของ PostgreSQL จะถูกเก็บไว้ที่โฟลเดอร์ `./postgres_backups` ในเครื่องของคุณ

---

## Network Separation
- **backend**: สำหรับ service ภายใน เช่น postgres, redis, prefect core
- **frontend**: สำหรับ UI tools เช่น pgAdmin, ARDM, prefect-api

---

## Security & Scaling
- สามารถปรับจำนวน replica ของ prefect-api ได้ใน docker-compose
- สามารถเปลี่ยนรหัสผ่านและพอร์ตเพื่อความปลอดภัย
- ข้อมูลสำรอง postgres จะถูกเก็บไว้ในเครื่องและสามารถนำไปกู้คืนได้ง่าย

---

## How to Manage Settings

### View current configuration
To view all available settings and their active values from the command line, run:

```sh
prefect config view --show-defaults
```
These settings are type-validated and you may verify your setup at any time with:

```sh
prefect config validate
```

### Configure settings for the active profile
To update a setting for the active profile, run:

```sh
prefect config set <setting>=<value>
```
For example, to set the `PREFECT_API_URL` setting to `http://127.0.0.1:4200/api`, run:

```sh
prefect config set PREFECT_API_URL=http://127.0.0.1:4200/api
```
To restore the default value for a setting, run:

```sh
prefect config unset <setting>
```
For example, to restore the default value for the `PREFECT_API_URL` setting, run:

```sh
prefect config unset PREFECT_API_URL
```

### Create a new profile
To create a new profile, run:

```sh
prefect profile create <profile>
```
To switch to a new profile, run:

```sh
prefect profile use <profile>
```

### Configure settings for a project
To configure settings for a project, create a `prefect.toml` or `.env` file in the project directory and add the settings with the values you want to use.

For example, to configure the `PREFECT_API_URL` setting to `http://127.0.0.1:4200/api`, create a `.env` file with the following content:

```env
PREFECT_API_URL=http://127.0.0.1:4200/api
```
To configure the `PREFECT_API_URL` setting to `http://127.0.0.1:4200/api` in a `prefect.toml` file, create a `prefect.toml` file with the following content:

```toml
api.url = "http://127.0.0.1:4200/api"
```
Refer to the [setting concept guide](https://docs.prefect.io/latest/concepts/settings/) for more information on how to configure settings and the [settings reference guide](https://docs.prefect.io/latest/reference/settings/) for more information on the available settings.

### Configure temporary settings for a process
To configure temporary settings for a process, set an environment variable with the name matching the setting you want to configure.

For example, to configure the `PREFECT_API_URL` setting to `http://127.0.0.1:4200/api` for a process, set the `PREFECT_API_URL` environment variable to `http://127.0.0.1:4200/api`:

```sh
export PREFECT_API_URL=http://127.0.0.1:4200/api
```
You can use this to run a command with the temporary setting:

```sh
PREFECT_LOGGING_LEVEL=DEBUG python my_script.py
```

---

## License
MIT
