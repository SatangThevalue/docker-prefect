#!/bin/bash
# Script to generate prometheus.yml from .env parameters for each job_name
# Usage: bash prometheus.sh

set -e

# Load .env variables
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
else
  echo ".env file not found!"
  exit 1
fi

# Set default values if not set in .env
PREFECT_API_HOST=${PREFECT_API_HOST:-prefect-api}
PREFECT_API_PORT=${PREFECT_API_PORT:-4200}

cat > prometheus.yml <<EOF
global:
  scrape_interval: 15s # Scrape ทุก 15 วินาที (สามารถปรับได้)

scrape_configs:
  - job_name: 'prefect-api' # ชื่อ job ที่จะแสดงใน Prometheus
    metrics_path: '/metrics' # Path ที่ Prefect API expose metrics (โดยทั่วไปคือ /metrics)
    static_configs:
      - targets: ['${PREFECT_API_HOST}:${PREFECT_API_PORT}'] # ใช้ค่าจาก .env หรือค่า default
  - job_name: 'postgres'
    static_configs:
      - targets: ['${POSTGRES_HOST:-postgres-db}:${POSTGRES_PORT:-5432}']
  - job_name: 'redis'
    static_configs:
      - targets: ['${REDIS_HOST:-redis-server}:${REDIS_PORT:-6379}']
  - job_name: 'redisinsight'
    static_configs:
      - targets: ['${RI_APP_HOST:-redisinsight}:${RI_APP_PORT:-5540}']
  - job_name: 'pgadmin'
    static_configs:
      - targets: ['${PGADMIN_HOST:-pgadmin}:${PGADMIN_PORT:-80}']
  - job_name: 'grafana'
    static_configs:
      - targets: ['${GRAFANA_HOST:-grafana}:${GRAFANA_PORT:-3000}']
EOF

echo "prometheus.yml generated successfully."
