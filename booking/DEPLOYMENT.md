# Flight Booking System - Local Deployment Guide

## Table of Contents
1. [Deployment Overview](#deployment-overview)
2. [Infrastructure Architecture](#infrastructure-architecture)
3. [Required Tools & Services](#required-tools--services)
4. [Docker Compose Setup](#docker-compose-setup)
5. [Network Configuration](#network-configuration)
6. [Service Deployment](#service-deployment)
7. [Database Setup](#database-setup)
8. [Monitoring & Logging](#monitoring--logging)
9. [Startup & Shutdown](#startup--shutdown)

---

## Deployment Overview

This guide covers deploying the **entire flight booking microservices system** on a **single Linux server** using Docker and Docker Compose. This is suitable for:

- ✅ **Development environment**
- ✅ **Local testing and demo**
- ✅ **Small-scale production** (low traffic)
- ❌ Not for high-traffic production (use Kubernetes instead)

**Target Environment**:
- **OS**: Linux (Ubuntu 22.04 LTS recommended)
- **RAM**: Minimum 16GB (32GB recommended)
- **CPU**: 4+ cores
- **Disk**: 50GB+ available space
- **Network**: Internet access for GDS APIs

---

## Infrastructure Architecture

### High-Level Deployment Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      LINUX SERVER (192.168.1.100)                            │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                         DOCKER HOST                                     │ │
│  │                                                                         │ │
│  │  ┌──────────────────────────────────────────────────────────────────┐  │ │
│  │  │                    NGINX (Reverse Proxy)                          │  │ │
│  │  │                    Port: 80, 443                                  │  │ │
│  │  │  • SSL Termination                                                │  │ │
│  │  │  • Load Balancing                                                 │  │ │
│  │  │  • Rate Limiting                                                  │  │ │
│  │  └──────────────┬───────────────────────────────────────────────────┘  │ │
│  │                 │                                                       │ │
│  │  ┌──────────────┴───────────────────────────────────────────────────┐  │ │
│  │  │                    API GATEWAY (Kong/Traefik)                     │  │ │
│  │  │                    Port: 8000                                     │  │ │
│  │  │  • Authentication                                                 │  │ │
│  │  │  • Request Routing                                                │  │ │
│  │  │  • API Versioning                                                 │  │ │
│  │  └──────┬────────┬────────┬────────┬────────┬────────┬──────────────┘  │ │
│  │         │        │        │        │        │        │                  │ │
│  │  ┌──────▼──┐ ┌──▼────┐ ┌─▼─────┐ ┌▼──────┐ ┌▼──────┐ ┌▼──────┐         │ │
│  │  │  User   │ │Search │ │Booking│ │Payment│ │Notif. │ │Review │         │ │
│  │  │ Service │ │Service│ │Service│ │Service│ │Service│ │Service│         │ │
│  │  │ :3001   │ │ :3002 │ │ :3003 │ │ :3004 │ │ :3005 │ │ :3006 │         │ │
│  │  └────┬────┘ └───┬───┘ └───┬───┘ └───┬───┘ └───┬───┘ └───┬───┘         │ │
│  │       │          │         │         │         │         │              │ │
│  │  ┌────┴──────────┴─────────┴─────────┴─────────┴─────────┴──────┐      │ │
│  │  │                    Docker Bridge Network                      │      │ │
│  │  │                    (booking-network)                           │      │ │
│  │  └────┬──────────┬─────────┬─────────┬─────────┬─────────────────┘      │ │
│  │       │          │         │         │         │                        │ │
│  │  ┌────▼────┐ ┌───▼────┐ ┌─▼──────┐ ┌▼───────┐ ┌▼────────┐              │ │
│  │  │PostgreSQL│ │ Redis  │ │MongoDB │ │RabbitMQ│ │  Nginx  │              │ │
│  │  │  :5432   │ │ :6379  │ │ :27017 │ │ :5672  │ │  :80    │              │ │
│  │  └──────────┘ └────────┘ └────────┘ └────────┘ └─────────┘              │ │
│  │                                                                         │ │
│  │  ┌─────────────────────────────────────────────────────────────────┐   │ │
│  │  │              MONITORING & LOGGING STACK                          │   │ │
│  │  ├──────────────┬──────────────┬──────────────┬────────────────────┤   │ │
│  │  │  Prometheus  │   Grafana    │     ELK      │     Jaeger         │   │ │
│  │  │    :9090     │    :3000     │   :9200      │     :16686         │   │ │
│  │  └──────────────┴──────────────┴──────────────┴────────────────────┘   │ │
│  │                                                                         │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                    PERSISTENT VOLUMES (Host Mounted)                     │ │
│  ├──────────────┬──────────────┬──────────────┬──────────────┬─────────────┤ │
│  │ /data/postgres│ /data/redis  │ /data/mongodb│ /data/logs   │/data/backups│ │
│  └──────────────┴──────────────┴──────────────┴──────────────┴─────────────┘ │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
                                   │
                                   │ Internet
                                   │
                    ┌──────────────┴──────────────┐
                    │   External Services         │
                    ├─────────────────────────────┤
                    │  • Amadeus GDS API          │
                    │  • Stripe Payment API       │
                    │  • SendGrid Email API       │
                    │  • Twilio SMS API           │
                    └─────────────────────────────┘
```

---

## Required Tools & Services

### 1. Core Infrastructure Components

| Component | Purpose | Port | Resource Requirement |
|-----------|---------|------|---------------------|
| **Docker** | Container runtime | - | 500MB RAM |
| **Docker Compose** | Multi-container orchestration | - | - |
| **Nginx** | Reverse proxy & load balancer | 80, 443 | 100MB RAM |
| **PostgreSQL 15** | Primary database | 5432 | 2GB RAM |
| **Redis 7** | Cache & session store | 6379 | 1GB RAM |
| **MongoDB 6** | Document store (logs) | 27017 | 1GB RAM |
| **RabbitMQ 3** | Message queue | 5672, 15672 | 512MB RAM |

**Total Base Infrastructure**: ~5GB RAM

### 2. Application Services

| Service | Runtime | Port | Replicas | RAM per Instance |
|---------|---------|------|----------|------------------|
| User Service | Node.js 20 | 3001 | 1-2 | 256MB |
| Search Service | Go 1.21 | 3002 | 2-3 | 512MB |
| Booking Service | Java 17 | 3003 | 2-3 | 512MB |
| Payment Service | Node.js 20 | 3004 | 1-2 | 256MB |
| Notification Service | Python 3.11 | 3005 | 1-2 | 256MB |
| Review Service | Node.js 20 | 3006 | 1 | 256MB |

**Total Application Services**: ~4-6GB RAM (with replicas)

### 3. Monitoring & Logging (Optional but Recommended)

| Component | Purpose | Port | RAM |
|-----------|---------|------|-----|
| **Prometheus** | Metrics collection | 9090 | 500MB |
| **Grafana** | Metrics visualization | 3000 | 250MB |
| **Elasticsearch** | Log storage & search | 9200 | 2GB |
| **Logstash** | Log processing | 5044 | 500MB |
| **Kibana** | Log visualization | 5601 | 500MB |
| **Jaeger** | Distributed tracing | 16686 | 500MB |

**Total Monitoring Stack**: ~4GB RAM

### 4. Total Resource Requirements

**Minimum Configuration**:
- **RAM**: 16GB (base infrastructure + apps)
- **CPU**: 4 cores
- **Disk**: 50GB

**Recommended Configuration**:
- **RAM**: 32GB (includes monitoring stack)
- **CPU**: 8 cores
- **Disk**: 100GB

---

## Docker Compose Setup

### Complete docker-compose.yml

```yaml
version: '3.8'

networks:
  booking-network:
    driver: bridge

volumes:
  postgres-data:
  redis-data:
  mongodb-data:
  rabbitmq-data:
  prometheus-data:
  grafana-data:
  elasticsearch-data:

services:
  # ============================================
  # INFRASTRUCTURE SERVICES
  # ============================================

  # PostgreSQL Database
  postgres:
    image: postgres:15-alpine
    container_name: booking-postgres
    restart: unless-stopped
    environment:
      POSTGRES_USER: booking_admin
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-SecureP@ssw0rd}
      POSTGRES_DB: booking_db
    ports:
      - "5432:5432"
    volumes:
      - postgres-data:/var/lib/postgresql/data
      - ./init-scripts/postgres:/docker-entrypoint-initdb.d
    networks:
      - booking-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U booking_admin"]
      interval: 10s
      timeout: 5s
      retries: 5

  # Redis Cache
  redis:
    image: redis:7-alpine
    container_name: booking-redis
    restart: unless-stopped
    command: redis-server --requirepass ${REDIS_PASSWORD:-RedisP@ssw0rd} --maxmemory 2gb --maxmemory-policy allkeys-lru
    ports:
      - "6379:6379"
    volumes:
      - redis-data:/data
    networks:
      - booking-network
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 3s
      retries: 5

  # MongoDB
  mongodb:
    image: mongo:6
    container_name: booking-mongodb
    restart: unless-stopped
    environment:
      MONGO_INITDB_ROOT_USERNAME: mongo_admin
      MONGO_INITDB_ROOT_PASSWORD: ${MONGO_PASSWORD:-MongoP@ssw0rd}
    ports:
      - "27017:27017"
    volumes:
      - mongodb-data:/data/db
      - ./init-scripts/mongo:/docker-entrypoint-initdb.d
    networks:
      - booking-network
    healthcheck:
      test: echo 'db.runCommand("ping").ok' | mongosh localhost:27017/test --quiet
      interval: 10s
      timeout: 5s
      retries: 5

  # RabbitMQ Message Queue
  rabbitmq:
    image: rabbitmq:3-management-alpine
    container_name: booking-rabbitmq
    restart: unless-stopped
    environment:
      RABBITMQ_DEFAULT_USER: rabbit_admin
      RABBITMQ_DEFAULT_PASS: ${RABBITMQ_PASSWORD:-RabbitP@ssw0rd}
    ports:
      - "5672:5672"   # AMQP
      - "15672:15672" # Management UI
    volumes:
      - rabbitmq-data:/var/lib/rabbitmq
    networks:
      - booking-network
    healthcheck:
      test: rabbitmq-diagnostics -q ping
      interval: 10s
      timeout: 5s
      retries: 5

  # ============================================
  # APPLICATION SERVICES
  # ============================================

  # User Service
  user-service:
    build:
      context: ./services/user-service
      dockerfile: Dockerfile
    container_name: booking-user-service
    restart: unless-stopped
    environment:
      NODE_ENV: production
      PORT: 3001
      DATABASE_URL: postgresql://booking_admin:${POSTGRES_PASSWORD:-SecureP@ssw0rd}@postgres:5432/user_db
      REDIS_URL: redis://:${REDIS_PASSWORD:-RedisP@ssw0rd}@redis:6379
      JWT_SECRET: ${JWT_SECRET:-YourSuperSecretJWTKey123!}
      NOTIFICATION_SERVICE_URL: http://notification-service:3005
    ports:
      - "3001:3001"
    depends_on:
      - postgres
      - redis
    networks:
      - booking-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3001/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M

  # Search Service
  search-service:
    build:
      context: ./services/search-service
      dockerfile: Dockerfile
    container_name: booking-search-service
    restart: unless-stopped
    environment:
      PORT: 3002
      REDIS_URL: redis://:${REDIS_PASSWORD:-RedisP@ssw0rd}@redis:6379
      POSTGRES_URL: postgresql://booking_admin:${POSTGRES_PASSWORD:-SecureP@ssw0rd}@postgres:5432/search_db
      AMADEUS_API_KEY: ${AMADEUS_API_KEY}
      AMADEUS_API_SECRET: ${AMADEUS_API_SECRET}
      SABRE_API_KEY: ${SABRE_API_KEY}
    ports:
      - "3002:3002"
    depends_on:
      - redis
      - postgres
    networks:
      - booking-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3002/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    deploy:
      replicas: 2
      resources:
        limits:
          cpus: '1.0'
          memory: 1G

  # Booking Service
  booking-service:
    build:
      context: ./services/booking-service
      dockerfile: Dockerfile
    container_name: booking-booking-service
    restart: unless-stopped
    environment:
      SPRING_PROFILES_ACTIVE: production
      SERVER_PORT: 3003
      SPRING_DATASOURCE_URL: jdbc:postgresql://postgres:5432/booking_db
      SPRING_DATASOURCE_USERNAME: booking_admin
      SPRING_DATASOURCE_PASSWORD: ${POSTGRES_PASSWORD:-SecureP@ssw0rd}
      SPRING_REDIS_HOST: redis
      SPRING_REDIS_PASSWORD: ${REDIS_PASSWORD:-RedisP@ssw0rd}
      RABBITMQ_HOST: rabbitmq
      RABBITMQ_USERNAME: rabbit_admin
      RABBITMQ_PASSWORD: ${RABBITMQ_PASSWORD:-RabbitP@ssw0rd}
      AMADEUS_API_KEY: ${AMADEUS_API_KEY}
      PAYMENT_SERVICE_URL: http://payment-service:3004
      NOTIFICATION_SERVICE_URL: http://notification-service:3005
    ports:
      - "3003:3003"
    depends_on:
      - postgres
      - redis
      - rabbitmq
    networks:
      - booking-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3003/actuator/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 1G

  # Payment Service
  payment-service:
    build:
      context: ./services/payment-service
      dockerfile: Dockerfile
    container_name: booking-payment-service
    restart: unless-stopped
    environment:
      NODE_ENV: production
      PORT: 3004
      DATABASE_URL: postgresql://booking_admin:${POSTGRES_PASSWORD:-SecureP@ssw0rd}@postgres:5432/payment_db
      RABBITMQ_URL: amqp://rabbit_admin:${RABBITMQ_PASSWORD:-RabbitP@ssw0rd}@rabbitmq:5672
      STRIPE_SECRET_KEY: ${STRIPE_SECRET_KEY}
      STRIPE_WEBHOOK_SECRET: ${STRIPE_WEBHOOK_SECRET}
      NOTIFICATION_SERVICE_URL: http://notification-service:3005
    ports:
      - "3004:3004"
    depends_on:
      - postgres
      - rabbitmq
    networks:
      - booking-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3004/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M

  # Notification Service
  notification-service:
    build:
      context: ./services/notification-service
      dockerfile: Dockerfile
    container_name: booking-notification-service
    restart: unless-stopped
    environment:
      PORT: 3005
      MONGODB_URL: mongodb://mongo_admin:${MONGO_PASSWORD:-MongoP@ssw0rd}@mongodb:27017/notifications?authSource=admin
      REDIS_URL: redis://:${REDIS_PASSWORD:-RedisP@ssw0rd}@redis:6379
      RABBITMQ_URL: amqp://rabbit_admin:${RABBITMQ_PASSWORD:-RabbitP@ssw0rd}@rabbitmq:5672
      SENDGRID_API_KEY: ${SENDGRID_API_KEY}
      TWILIO_ACCOUNT_SID: ${TWILIO_ACCOUNT_SID}
      TWILIO_AUTH_TOKEN: ${TWILIO_AUTH_TOKEN}
    ports:
      - "3005:3005"
    depends_on:
      - mongodb
      - rabbitmq
      - redis
    networks:
      - booking-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3005/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M

  # Review Service
  review-service:
    build:
      context: ./services/review-service
      dockerfile: Dockerfile
    container_name: booking-review-service
    restart: unless-stopped
    environment:
      NODE_ENV: production
      PORT: 3006
      DATABASE_URL: postgresql://booking_admin:${POSTGRES_PASSWORD:-SecureP@ssw0rd}@postgres:5432/review_db
      REDIS_URL: redis://:${REDIS_PASSWORD:-RedisP@ssw0rd}@redis:6379
      BOOKING_SERVICE_URL: http://booking-service:3003
    ports:
      - "3006:3006"
    depends_on:
      - postgres
      - redis
    networks:
      - booking-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3006/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    deploy:
      resources:
        limits:
          cpus: '0.25'
          memory: 256M

  # ============================================
  # API GATEWAY & REVERSE PROXY
  # ============================================

  # Nginx Reverse Proxy
  nginx:
    image: nginx:alpine
    container_name: booking-nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/ssl:/etc/nginx/ssl:ro
      - ./nginx/logs:/var/log/nginx
    depends_on:
      - user-service
      - search-service
      - booking-service
      - payment-service
      - notification-service
      - review-service
    networks:
      - booking-network
    healthcheck:
      test: ["CMD", "nginx", "-t"]
      interval: 30s
      timeout: 10s
      retries: 3

  # ============================================
  # MONITORING & LOGGING (OPTIONAL)
  # ============================================

  # Prometheus
  prometheus:
    image: prom/prometheus:latest
    container_name: booking-prometheus
    restart: unless-stopped
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/usr/share/prometheus/console_libraries'
      - '--web.console.templates=/usr/share/prometheus/consoles'
    networks:
      - booking-network

  # Grafana
  grafana:
    image: grafana/grafana:latest
    container_name: booking-grafana
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      GF_SECURITY_ADMIN_USER: admin
      GF_SECURITY_ADMIN_PASSWORD: ${GRAFANA_PASSWORD:-admin}
    volumes:
      - grafana-data:/var/lib/grafana
      - ./monitoring/grafana-dashboards:/etc/grafana/provisioning/dashboards
    depends_on:
      - prometheus
    networks:
      - booking-network

  # Elasticsearch
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.11.0
    container_name: booking-elasticsearch
    restart: unless-stopped
    environment:
      - discovery.type=single-node
      - "ES_JAVA_OPTS=-Xms1g -Xmx1g"
      - xpack.security.enabled=false
    ports:
      - "9200:9200"
    volumes:
      - elasticsearch-data:/usr/share/elasticsearch/data
    networks:
      - booking-network
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:9200/_cluster/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5

  # Kibana
  kibana:
    image: docker.elastic.co/kibana/kibana:8.11.0
    container_name: booking-kibana
    restart: unless-stopped
    ports:
      - "5601:5601"
    environment:
      ELASTICSEARCH_HOSTS: http://elasticsearch:9200
    depends_on:
      - elasticsearch
    networks:
      - booking-network

  # Jaeger (Distributed Tracing)
  jaeger:
    image: jaegertracing/all-in-one:latest
    container_name: booking-jaeger
    restart: unless-stopped
    ports:
      - "5775:5775/udp"
      - "6831:6831/udp"
      - "6832:6832/udp"
      - "5778:5778"
      - "16686:16686"  # UI
      - "14268:14268"
      - "14250:14250"
      - "9411:9411"
    environment:
      COLLECTOR_ZIPKIN_HOST_PORT: :9411
    networks:
      - booking-network
```

---

## Network Configuration

### Docker Bridge Network

```yaml
networks:
  booking-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.25.0.0/16
```

**Benefits**:
- ✅ Isolated network for all services
- ✅ Service discovery via container names
- ✅ Internal DNS resolution
- ✅ No port conflicts with host

### Port Mapping Summary

| Service | Internal Port | External Port | Access |
|---------|---------------|---------------|--------|
| Nginx | 80, 443 | 80, 443 | Public |
| User Service | 3001 | 3001 | Internal |
| Search Service | 3002 | 3002 | Internal |
| Booking Service | 3003 | 3003 | Internal |
| Payment Service | 3004 | 3004 | Internal |
| Notification Service | 3005 | 3005 | Internal |
| Review Service | 3006 | 3006 | Internal |
| PostgreSQL | 5432 | 5432 | Internal |
| Redis | 6379 | 6379 | Internal |
| MongoDB | 27017 | 27017 | Internal |
| RabbitMQ | 5672, 15672 | 5672, 15672 | Internal |
| Prometheus | 9090 | 9090 | Internal |
| Grafana | 3000 | 3000 | Public |
| Kibana | 5601 | 5601 | Public |
| Jaeger UI | 16686 | 16686 | Public |

---

## Service Deployment

### Directory Structure

```
/home/user/flight-booking/
├── docker-compose.yml
├── .env
├── nginx/
│   ├── nginx.conf
│   ├── ssl/
│   │   ├── cert.pem
│   │   └── key.pem
│   └── logs/
├── services/
│   ├── user-service/
│   │   ├── Dockerfile
│   │   ├── package.json
│   │   └── src/
│   ├── search-service/
│   │   ├── Dockerfile
│   │   ├── go.mod
│   │   └── main.go
│   ├── booking-service/
│   │   ├── Dockerfile
│   │   ├── pom.xml
│   │   └── src/
│   ├── payment-service/
│   │   ├── Dockerfile
│   │   ├── package.json
│   │   └── src/
│   ├── notification-service/
│   │   ├── Dockerfile
│   │   ├── requirements.txt
│   │   └── app/
│   └── review-service/
│       ├── Dockerfile
│       ├── package.json
│       └── src/
├── init-scripts/
│   ├── postgres/
│   │   └── 01-init-databases.sql
│   └── mongo/
│       └── 01-init-collections.js
├── monitoring/
│   ├── prometheus.yml
│   └── grafana-dashboards/
└── data/
    ├── postgres/
    ├── redis/
    ├── mongodb/
    ├── logs/
    └── backups/
```

### Nginx Configuration (nginx/nginx.conf)

```nginx
events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log warn;

    sendfile on;
    tcp_nopush on;
    keepalive_timeout 65;
    gzip on;

    # Rate limiting
    limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=search_limit:10m rate=5r/s;

    upstream user_service {
        least_conn;
        server user-service:3001 max_fails=3 fail_timeout=30s;
    }

    upstream search_service {
        least_conn;
        server search-service:3002 max_fails=3 fail_timeout=30s;
    }

    upstream booking_service {
        least_conn;
        server booking-service:3003 max_fails=3 fail_timeout=30s;
    }

    upstream payment_service {
        least_conn;
        server payment-service:3004 max_fails=3 fail_timeout=30s;
    }

    upstream notification_service {
        least_conn;
        server notification-service:3005 max_fails=3 fail_timeout=30s;
    }

    upstream review_service {
        least_conn;
        server review-service:3006 max_fails=3 fail_timeout=30s;
    }

    server {
        listen 80;
        server_name localhost;

        # Security headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;

        # API Gateway routes
        location /api/v1/auth {
            limit_req zone=api_limit burst=20 nodelay;
            proxy_pass http://user_service;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        location /api/v1/users {
            limit_req zone=api_limit burst=20 nodelay;
            proxy_pass http://user_service;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }

        location /api/v1/search {
            limit_req zone=search_limit burst=10 nodelay;
            proxy_pass http://search_service;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_read_timeout 30s;
        }

        location /api/v1/bookings {
            limit_req zone=api_limit burst=20 nodelay;
            proxy_pass http://booking_service;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }

        location /api/v1/payments {
            limit_req zone=api_limit burst=20 nodelay;
            proxy_pass http://payment_service;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }

        location /api/v1/notifications {
            limit_req zone=api_limit burst=20 nodelay;
            proxy_pass http://notification_service;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }

        location /api/v1/reviews {
            limit_req zone=api_limit burst=20 nodelay;
            proxy_pass http://review_service;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }

        # Health check endpoint
        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
    }
}
```

---

## Database Setup

### PostgreSQL Initialization Script (init-scripts/postgres/01-init-databases.sql)

```sql
-- Create separate databases for each service
CREATE DATABASE user_db;
CREATE DATABASE search_db;
CREATE DATABASE booking_db;
CREATE DATABASE payment_db;
CREATE DATABASE review_db;

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE user_db TO booking_admin;
GRANT ALL PRIVILEGES ON DATABASE search_db TO booking_admin;
GRANT ALL PRIVILEGES ON DATABASE booking_db TO booking_admin;
GRANT ALL PRIVILEGES ON DATABASE payment_db TO booking_admin;
GRANT ALL PRIVILEGES ON DATABASE review_db TO booking_admin;

-- Connect to each database and create extensions
\c user_db
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

\c search_db
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

\c booking_db
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

\c payment_db
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

\c review_db
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
```

### MongoDB Initialization Script (init-scripts/mongo/01-init-collections.js)

```javascript
// Switch to notifications database
db = db.getSiblingDB('notifications');

// Create collections with validation
db.createCollection('notifications', {
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['userId', 'type', 'channel', 'status'],
      properties: {
        userId: { bsonType: 'string' },
        type: { enum: ['booking_confirmation', 'payment_receipt', 'cancellation'] },
        channel: { enum: ['email', 'sms', 'push'] },
        status: { enum: ['pending', 'sent', 'failed'] }
      }
    }
  }
});

// Create indexes
db.notifications.createIndex({ userId: 1, createdAt: -1 });
db.notifications.createIndex({ status: 1 });
db.notifications.createIndex({ createdAt: 1 }, { expireAfterSeconds: 2592000 }); // 30 days TTL

// Analytics database
db = db.getSiblingDB('analytics');

db.createCollection('events');
db.events.createIndex({ eventType: 1, timestamp: -1 });
db.events.createIndex({ userId: 1, timestamp: -1 });
db.events.createIndex({ timestamp: 1 }, { expireAfterSeconds: 7776000 }); // 90 days TTL
```

---

## Monitoring & Logging

### Prometheus Configuration (monitoring/prometheus.yml)

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  # User Service
  - job_name: 'user-service'
    static_configs:
      - targets: ['user-service:3001']

  # Search Service
  - job_name: 'search-service'
    static_configs:
      - targets: ['search-service:3002']

  # Booking Service
  - job_name: 'booking-service'
    static_configs:
      - targets: ['booking-service:3003']

  # Payment Service
  - job_name: 'payment-service'
    static_configs:
      - targets: ['payment-service:3004']

  # Notification Service
  - job_name: 'notification-service'
    static_configs:
      - targets: ['notification-service:3005']

  # Review Service
  - job_name: 'review-service'
    static_configs:
      - targets: ['review-service:3006']

  # Infrastructure
  - job_name: 'postgres'
    static_configs:
      - targets: ['postgres:5432']

  - job_name: 'redis'
    static_configs:
      - targets: ['redis:6379']

  - job_name: 'rabbitmq'
    static_configs:
      - targets: ['rabbitmq:15672']
```

### Key Metrics to Monitor

| Metric | Threshold | Action |
|--------|-----------|--------|
| CPU Usage | > 80% | Scale up or optimize |
| Memory Usage | > 85% | Investigate memory leaks |
| Disk I/O | > 90% | Add storage or optimize queries |
| API Latency (p95) | > 1000ms | Optimize slow endpoints |
| Error Rate | > 1% | Investigate logs |
| Database Connections | > 80% of max | Increase pool size |
| Cache Hit Rate | < 70% | Review caching strategy |
| Queue Length | > 1000 | Scale consumers |

---

## Startup & Shutdown

### Environment Variables (.env)

```bash
# Database Passwords
POSTGRES_PASSWORD=SecureP@ssw0rd123
REDIS_PASSWORD=RedisP@ssw0rd123
MONGO_PASSWORD=MongoP@ssw0rd123
RABBITMQ_PASSWORD=RabbitP@ssw0rd123

# Application Secrets
JWT_SECRET=YourSuperSecretJWTKeyChangeThisInProduction123!

# External API Keys (Get from providers)
AMADEUS_API_KEY=your_amadeus_api_key
AMADEUS_API_SECRET=your_amadeus_api_secret
SABRE_API_KEY=your_sabre_api_key
STRIPE_SECRET_KEY=sk_test_your_stripe_key
STRIPE_WEBHOOK_SECRET=whsec_your_webhook_secret
SENDGRID_API_KEY=SG.your_sendgrid_key
TWILIO_ACCOUNT_SID=your_twilio_sid
TWILIO_AUTH_TOKEN=your_twilio_token

# Monitoring
GRAFANA_PASSWORD=admin123
```

### Deployment Steps

#### 1. Install Prerequisites

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install Docker Compose
sudo apt install docker-compose -y

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Verify installation
docker --version
docker-compose --version
```

#### 2. Clone & Setup Project

```bash
# Create project directory
mkdir -p ~/flight-booking
cd ~/flight-booking

# Create directory structure
mkdir -p {nginx/ssl,services,init-scripts/{postgres,mongo},monitoring,data/{postgres,redis,mongodb,logs,backups}}

# Copy docker-compose.yml and configuration files
# (paste the docker-compose.yml content from above)

# Create .env file
nano .env
# (paste environment variables)

# Set proper permissions
chmod 600 .env
chmod 755 init-scripts/postgres/*.sql
chmod 755 init-scripts/mongo/*.js
```

#### 3. Build & Start Services

```bash
# Build all service images
docker-compose build

# Start infrastructure services first
docker-compose up -d postgres redis mongodb rabbitmq

# Wait for databases to be ready (30 seconds)
sleep 30

# Start application services
docker-compose up -d user-service search-service booking-service payment-service notification-service review-service

# Start reverse proxy
docker-compose up -d nginx

# (Optional) Start monitoring stack
docker-compose up -d prometheus grafana elasticsearch kibana jaeger

# Verify all services are running
docker-compose ps
```

#### 4. Verify Deployment

```bash
# Check service health
curl http://localhost/health

# Check individual services
curl http://localhost:3001/health  # User Service
curl http://localhost:3002/health  # Search Service
curl http://localhost:3003/actuator/health  # Booking Service
curl http://localhost:3004/health  # Payment Service
curl http://localhost:3005/health  # Notification Service
curl http://localhost:3006/health  # Review Service

# Check database connections
docker exec -it booking-postgres pg_isready
docker exec -it booking-redis redis-cli ping
docker exec -it booking-mongodb mongosh --eval "db.adminCommand('ping')"
docker exec -it booking-rabbitmq rabbitmq-diagnostics ping

# View logs
docker-compose logs -f --tail=100
```

#### 5. Access Monitoring Dashboards

```bash
# Grafana: http://localhost:3000 (admin/admin123)
# Prometheus: http://localhost:9090
# RabbitMQ Management: http://localhost:15672 (rabbit_admin/password)
# Kibana: http://localhost:5601
# Jaeger UI: http://localhost:16686
```

### Shutdown Commands

```bash
# Stop all services
docker-compose down

# Stop and remove volumes (WARNING: deletes all data!)
docker-compose down -v

# Stop specific service
docker-compose stop user-service

# Restart specific service
docker-compose restart booking-service

# View logs for specific service
docker-compose logs -f user-service
```

### Backup & Restore

#### Backup Databases

```bash
# PostgreSQL backup
docker exec booking-postgres pg_dumpall -U booking_admin > ./data/backups/postgres_backup_$(date +%Y%m%d).sql

# MongoDB backup
docker exec booking-mongodb mongodump --out /data/db/backup
docker cp booking-mongodb:/data/db/backup ./data/backups/mongo_backup_$(date +%Y%m%d)

# Redis backup
docker exec booking-redis redis-cli --rdb /data/dump.rdb SAVE
docker cp booking-redis:/data/dump.rdb ./data/backups/redis_backup_$(date +%Y%m%d).rdb
```

#### Restore Databases

```bash
# PostgreSQL restore
cat ./data/backups/postgres_backup_20250105.sql | docker exec -i booking-postgres psql -U booking_admin

# MongoDB restore
docker exec booking-mongodb mongorestore /data/db/backup

# Redis restore
docker cp ./data/backups/redis_backup_20250105.rdb booking-redis:/data/dump.rdb
docker-compose restart redis
```

---

## Performance Optimization

### 1. Resource Limits

Set resource limits in `docker-compose.yml`:

```yaml
deploy:
  resources:
    limits:
      cpus: '1.0'
      memory: 1G
    reservations:
      cpus: '0.5'
      memory: 512M
```

### 2. Database Connection Pooling

**PostgreSQL** (in service configuration):
```yaml
POSTGRES_MAX_CONNECTIONS: 100
POSTGRES_SHARED_BUFFERS: 256MB
```

**Redis** (in redis.conf):
```
maxclients 10000
timeout 300
```

### 3. Nginx Caching

Add to `nginx.conf`:

```nginx
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=api_cache:10m max_size=1g inactive=60m;

location /api/v1/search {
    proxy_cache api_cache;
    proxy_cache_valid 200 5m;
    proxy_cache_key "$scheme$request_method$host$request_uri";
    add_header X-Cache-Status $upstream_cache_status;
    proxy_pass http://search_service;
}
```

---

## Troubleshooting

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Service won't start | Port conflict | Check `docker-compose ps` and change ports |
| Database connection failed | Database not ready | Increase `healthcheck` intervals |
| Out of memory | Insufficient RAM | Reduce replicas or add swap |
| Slow API responses | No caching | Enable Redis caching |
| Container keeps restarting | Application crash | Check logs: `docker-compose logs service-name` |

### Useful Commands

```bash
# View container resource usage
docker stats

# Inspect container
docker inspect booking-user-service

# Execute command in container
docker exec -it booking-postgres psql -U booking_admin

# View network configuration
docker network inspect booking_booking-network

# Clean up unused resources
docker system prune -a --volumes
```

---

## Security Checklist

- [ ] Change all default passwords in `.env`
- [ ] Use strong JWT secret (32+ characters)
- [ ] Enable SSL/TLS for Nginx (add certificates to `nginx/ssl/`)
- [ ] Restrict database access (only from Docker network)
- [ ] Enable firewall on host machine
- [ ] Regular security updates: `docker-compose pull && docker-compose up -d`
- [ ] Implement rate limiting in Nginx
- [ ] Use secrets management (Docker Secrets or Vault)
- [ ] Regular database backups (automated with cron)
- [ ] Monitor logs for suspicious activity

---

## Scaling Considerations

### When to Scale Up (Vertical)
- Single service CPU > 80%
- Memory usage > 85%
- Database connections maxed out

### When to Scale Out (Horizontal)
- Need > 1000 requests/second
- Multiple users experiencing slow responses
- High availability requirements

### Migration to Kubernetes

When you outgrow single-server deployment:

```
Docker Compose (Local) → Docker Swarm (Multi-server) → Kubernetes (Production)
```

**Kubernetes benefits**:
- Auto-scaling (HPA)
- Self-healing
- Rolling updates
- Multi-region deployment
- Better resource utilization

---

## Summary

This deployment setup provides:

✅ **Complete microservices stack** on a single Linux server  
✅ **Minimal resource requirements** (16GB RAM)  
✅ **Production-ready infrastructure** (databases, cache, queue)  
✅ **Monitoring & logging** (Prometheus, Grafana, ELK)  
✅ **Easy maintenance** (Docker Compose commands)  
✅ **Scalable architecture** (can migrate to Kubernetes later)  

**Next Steps**:
1. Clone repository and set up directory structure
2. Configure environment variables (`.env`)
3. Build service Docker images
4. Start infrastructure with `docker-compose up -d`
5. Verify all services are healthy
6. Configure external API keys (Amadeus, Stripe, etc.)
7. Test API endpoints via Nginx gateway
8. Set up automated backups
9. Monitor logs and metrics

For production deployment at scale, consider migrating to **Kubernetes** with **auto-scaling**, **multi-region deployment**, and **managed cloud services** (AWS RDS, ElastiCache, etc.).
