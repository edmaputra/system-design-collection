# Backend Application Architecture

## 🎯 Overview

This document outlines the backend application architecture for the Flight Booking System, focusing on scalable, reliable, and maintainable design patterns and implementation strategies.

## 🏗️ Architecture Principles

### Core Principles
1. **Domain-Driven Design (DDD)**: Clear business domain boundaries
2. **SOLID Principles**: Single responsibility, Open/closed, Liskov substitution, Interface segregation, Dependency inversion
3. **Clean Architecture**: Dependency inversion with clear layers
4. **Microservices Pattern**: Independent, loosely coupled services
5. **Event-Driven Architecture**: Asynchronous communication and eventual consistency
6. **CQRS**: Command Query Responsibility Segregation for complex operations
7. **Saga Pattern**: Distributed transaction management

### Design Goals
- **Scalability**: Handle millions of concurrent users
- **Reliability**: 99.99% uptime with graceful failure handling
- **Maintainability**: Clean code, modular design, comprehensive testing
- **Performance**: Sub-200ms response times for critical operations
- **Security**: Zero-trust architecture with defense in depth

## 🔧 Backend Technology Stack

```mermaid
graph TB
    subgraph "Programming Languages"
        JAVA[Java 17+ with Spring Boot 3.x]
        NODE[Node.js 18+ with Express/Fastify]
        PYTHON[Python 3.11+ with FastAPI]
        GO[Go 1.21+ for high-performance services]
    end

    subgraph "Frameworks & Libraries"
        SPRING[Spring Boot, Spring Security, Spring Data]
        EXPRESS[Express.js, Helmet, Joi]
        FASTAPI[FastAPI, Pydantic, SQLAlchemy]
        GIN[Gin, GORM, Validator]
    end

    subgraph "Data Layer"
        POSTGRES[PostgreSQL 15+ Primary DB]
        REDIS[Redis 7+ Caching & Session]
        MONGO[MongoDB 6+ Document Store]
        ELASTIC[Elasticsearch 8+ Search & Analytics]
    end

    subgraph "Messaging & Events"
        KAFKA[Apache Kafka Event Streaming]
        RABBITMQ[RabbitMQ Task Queues]
        GRPC[gRPC Service Communication]
        WEBSOCKET[WebSocket Real-time Updates]
    end

    subgraph "Monitoring & Observability"
        PROMETHEUS[Prometheus Metrics]
        JAEGER[Jaeger Distributed Tracing]
        ELASTIC_STACK[ELK Stack Logging]
        GRAFANA[Grafana Dashboards]
    end
```

## 🏢 Service Architecture Pattern

### Hexagonal Architecture (Ports & Adapters)

Each microservice follows the hexagonal architecture pattern for maximum testability and maintainability:

```mermaid
graph TB
    subgraph "Service Architecture"
        subgraph "External Adapters"
            REST[REST API Controller]
            GRPC_ADAPTER[gRPC Adapter]
            EVENT_LISTENER[Event Listener]
            SCHEDULER[Scheduled Tasks]
        end

        subgraph "Application Layer"
            USE_CASES[Use Cases/Application Services]
            HANDLERS[Command/Query Handlers]
            VALIDATORS[Input Validators]
            MAPPERS[DTO Mappers]
        end

        subgraph "Domain Layer"
            ENTITIES[Domain Entities]
            VALUE_OBJECTS[Value Objects]
            DOMAIN_SERVICES[Domain Services]
            BUSINESS_RULES[Business Rules]
            EVENTS[Domain Events]
        end

        subgraph "Infrastructure Layer"
            REPOS[Repository Implementations]
            DB_ADAPTERS[Database Adapters]
            EXTERNAL_APIS[External API Clients]
            EVENT_PUBLISHERS[Event Publishers]
            CACHE[Cache Adapters]
        end
    end

    REST --> USE_CASES
    GRPC_ADAPTER --> USE_CASES
    EVENT_LISTENER --> HANDLERS
    USE_CASES --> DOMAIN_SERVICES
    HANDLERS --> ENTITIES
    DOMAIN_SERVICES --> REPOS
    REPOS --> DB_ADAPTERS
```

## 📊 Service-by-Service Architecture

### 1. User Service Architecture

```mermaid
graph TB
    subgraph "User Service"
        subgraph "API Layer"
            USER_REST[User REST API]
            AUTH_REST[Auth REST API]
            PROFILE_REST[Profile REST API]
        end

        subgraph "Application Layer"
            USER_COMMAND[User Commands]
            USER_QUERY[User Queries]
            AUTH_SERVICE[Authentication Service]
            PROFILE_SERVICE[Profile Service]
        end

        subgraph "Domain Layer"
            USER_ENTITY[User Entity]
            AUTH_VO[Auth Value Objects]
            USER_EVENTS[User Domain Events]
            PASSWORD_POLICY[Password Policy]
        end

        subgraph "Infrastructure"
            USER_REPO[User Repository]
            JWT_PROVIDER[JWT Token Provider]
            PASSWORD_HASHER[Password Hasher]
            EMAIL_CLIENT[Email Client]
        end

        subgraph "External Dependencies"
            POSTGRES_USER[(PostgreSQL)]
            REDIS_SESSION[(Redis Sessions)]
            KAFKA_EVENTS[Kafka Events]
        end
    end

    USER_REST --> USER_COMMAND
    AUTH_REST --> AUTH_SERVICE
    USER_COMMAND --> USER_ENTITY
    AUTH_SERVICE --> JWT_PROVIDER
    USER_REPO --> POSTGRES_USER
```

### 2. Flight Service Architecture

```mermaid
graph TB
    subgraph "Flight Service"
        subgraph "API Layer"
            SEARCH_API[Flight Search API]
            SCHEDULE_API[Schedule Management API]
            PRICE_API[Pricing API]
        end

        subgraph "Application Layer"
            SEARCH_SERVICE[Flight Search Service]
            SCHEDULE_SERVICE[Schedule Service]
            PRICE_SERVICE[Pricing Service]
            CACHE_SERVICE[Cache Service]
        end

        subgraph "Domain Layer"
            FLIGHT_ENTITY[Flight Entity]
            ROUTE_ENTITY[Route Entity]
            PRICE_CALCULATOR[Price Calculator]
            AVAILABILITY_CHECKER[Availability Checker]
        end

        subgraph "Infrastructure"
            FLIGHT_REPO[Flight Repository]
            SEARCH_ENGINE[Elasticsearch Client]
            PRICE_CACHE[Redis Price Cache]
            EXTERNAL_GDS[GDS API Client]
        end

        subgraph "Data Sources"
            POSTGRES_FLIGHT[(PostgreSQL)]
            ELASTIC_SEARCH[(Elasticsearch)]
            REDIS_CACHE[(Redis)]
            GDS_APIS[External GDS APIs]
        end
    end

    SEARCH_API --> SEARCH_SERVICE
    SEARCH_SERVICE --> SEARCH_ENGINE
    SEARCH_ENGINE --> ELASTIC_SEARCH
```

### 3. Booking Service Architecture

```mermaid
graph TB
    subgraph "Booking Service"
        subgraph "API Layer"
            BOOKING_API[Booking API]
            RESERVATION_API[Reservation API]
            MODIFICATION_API[Modification API]
        end

        subgraph "Application Layer"
            BOOKING_ORCHESTRATOR[Booking Orchestrator]
            SAGA_COORDINATOR[Saga Coordinator]
            INVENTORY_CLIENT[Inventory Client]
            PAYMENT_CLIENT[Payment Client]
        end

        subgraph "Domain Layer"
            BOOKING_AGGREGATE[Booking Aggregate]
            RESERVATION_ENTITY[Reservation Entity]
            BOOKING_RULES[Booking Business Rules]
            STATE_MACHINE[Booking State Machine]
        end

        subgraph "Infrastructure"
            BOOKING_REPO[Booking Repository]
            EVENT_STORE[Event Store]
            SAGA_STORE[Saga State Store]
            OUTBOX[Outbox Pattern]
        end

        subgraph "External Dependencies"
            POSTGRES_BOOKING[(PostgreSQL)]
            KAFKA_SAGA[Kafka Saga Events]
            REDIS_LOCKS[(Redis Distributed Locks)]
        end
    end

    BOOKING_API --> BOOKING_ORCHESTRATOR
    BOOKING_ORCHESTRATOR --> SAGA_COORDINATOR
    SAGA_COORDINATOR --> BOOKING_AGGREGATE
    BOOKING_AGGREGATE --> EVENT_STORE
```

## 🔗 Inter-Service Communication Patterns

### 1. Synchronous Communication

```mermaid
sequenceDiagram
    participant Client
    participant APIGateway
    participant BookingService
    participant FlightService
    participant InventoryService
    participant PaymentService

    Client->>APIGateway: POST /bookings
    APIGateway->>BookingService: Create Booking Request
    
    BookingService->>FlightService: Validate Flight (gRPC)
    FlightService-->>BookingService: Flight Details
    
    BookingService->>InventoryService: Check Availability (HTTP)
    InventoryService-->>BookingService: Availability Status
    
    BookingService->>PaymentService: Process Payment (HTTP)
    PaymentService-->>BookingService: Payment Result
    
    BookingService-->>APIGateway: Booking Created
    APIGateway-->>Client: Booking Response
```

### 2. Asynchronous Communication (Event-Driven)

```mermaid
sequenceDiagram
    participant BookingService
    participant Kafka
    participant InventoryService
    participant NotificationService
    participant AnalyticsService

    BookingService->>Kafka: Publish BookingCreated Event
    
    Kafka->>InventoryService: BookingCreated Event
    InventoryService->>InventoryService: Update Seat Inventory
    InventoryService->>Kafka: InventoryUpdated Event
    
    Kafka->>NotificationService: BookingCreated Event
    NotificationService->>NotificationService: Send Confirmation Email
    
    Kafka->>AnalyticsService: BookingCreated Event
    AnalyticsService->>AnalyticsService: Update Booking Metrics
```

## 🔄 Data Management Patterns

### 1. Database per Service Pattern

```mermaid
graph TB
    subgraph "User Service"
        USER_DB[(User Database<br/>PostgreSQL)]
    end

    subgraph "Flight Service"
        FLIGHT_DB[(Flight Database<br/>PostgreSQL)]
        FLIGHT_SEARCH[(Search Index<br/>Elasticsearch)]
        FLIGHT_CACHE[(Flight Cache<br/>Redis)]
    end

    subgraph "Booking Service"
        BOOKING_DB[(Booking Database<br/>PostgreSQL)]
        BOOKING_EVENTS[(Event Store<br/>PostgreSQL)]
    end

    subgraph "Payment Service"
        PAYMENT_DB[(Payment Database<br/>PostgreSQL<br/>Encrypted)]
    end

    subgraph "Analytics Service"
        ANALYTICS_DB[(Analytics Database<br/>MongoDB)]
        METRICS_DB[(Metrics Store<br/>InfluxDB)]
    end
```

### 2. CQRS Pattern Implementation

```mermaid
graph TB
    subgraph "Command Side (Write)"
        COMMAND_API[Command API]
        COMMAND_HANDLER[Command Handler]
        AGGREGATE[Domain Aggregate]
        EVENT_STORE_W[(Event Store Write)]
    end

    subgraph "Query Side (Read)"
        QUERY_API[Query API]
        QUERY_HANDLER[Query Handler]
        READ_MODEL[Read Model]
        READ_DB[(Read Database)]
    end

    subgraph "Event Processing"
        EVENT_BUS[Event Bus<br/>Kafka]
        PROJECTION_HANDLER[Projection Handler]
    end

    COMMAND_API --> COMMAND_HANDLER
    COMMAND_HANDLER --> AGGREGATE
    AGGREGATE --> EVENT_STORE_W
    EVENT_STORE_W --> EVENT_BUS
    EVENT_BUS --> PROJECTION_HANDLER
    PROJECTION_HANDLER --> READ_MODEL
    READ_MODEL --> READ_DB
    QUERY_API --> QUERY_HANDLER
    QUERY_HANDLER --> READ_DB
```

## 🔐 Security Architecture

### 1. Zero-Trust Security Model

```mermaid
graph TB
    subgraph "Security Layers"
        subgraph "Perimeter Security"
            WAF[Web Application Firewall]
            DDoS[DDoS Protection]
            RATE_LIMIT[Rate Limiting]
        end

        subgraph "Authentication & Authorization"
            IAM[Identity & Access Management]
            JWT_AUTH[JWT Authentication]
            RBAC[Role-Based Access Control]
            MFA[Multi-Factor Authentication]
        end

        subgraph "Service Mesh Security"
            mTLS[Mutual TLS]
            SERVICE_AUTH[Service Authentication]
            NETWORK_POLICY[Network Policies]
        end

        subgraph "Data Security"
            ENCRYPTION[Data Encryption at Rest]
            TLS[TLS in Transit]
            VAULT[Secret Management]
            PII_MASKING[PII Data Masking]
        end
    end

    WAF --> IAM
    IAM --> SERVICE_AUTH
    SERVICE_AUTH --> ENCRYPTION
```

### 2. Authentication Flow

```mermaid
sequenceDiagram
    participant Client
    participant APIGateway
    participant AuthService
    participant UserService
    participant Redis

    Client->>APIGateway: Login Request
    APIGateway->>AuthService: Authenticate User
    AuthService->>UserService: Validate Credentials
    UserService-->>AuthService: User Details
    AuthService->>Redis: Store Session
    AuthService-->>APIGateway: JWT Token
    APIGateway-->>Client: Access Token + Refresh Token
    
    Note over Client,Redis: Subsequent Requests
    Client->>APIGateway: API Request + JWT
    APIGateway->>AuthService: Validate Token
    AuthService->>Redis: Check Session
    Redis-->>AuthService: Session Valid
    AuthService-->>APIGateway: Token Valid
    APIGateway->>UserService: Forward Request
```

## 📈 Scalability Patterns

### 1. Horizontal Scaling Strategy

```mermaid
graph TB
    subgraph "Load Balancing"
        LB[Load Balancer<br/>Auto-scaling Group]
    end

    subgraph "Service Instances"
        SERVICE1[Service Instance 1]
        SERVICE2[Service Instance 2]
        SERVICE3[Service Instance 3]
        SERVICEN[Service Instance N]
    end

    subgraph "Data Layer Scaling"
        MASTER[(Master DB)]
        REPLICA1[(Read Replica 1)]
        REPLICA2[(Read Replica 2)]
        CACHE_CLUSTER[Redis Cluster]
    end

    LB --> SERVICE1
    LB --> SERVICE2
    LB --> SERVICE3
    LB --> SERVICEN

    SERVICE1 --> MASTER
    SERVICE2 --> REPLICA1
    SERVICE3 --> REPLICA2
    SERVICEN --> CACHE_CLUSTER
```

### 2. Caching Strategy

```mermaid
graph TB
    subgraph "Multi-Level Caching"
        CDN[CDN<br/>Static Content]
        API_CACHE[API Gateway Cache<br/>Response Caching]
        
        subgraph "Application Level"
            L1_CACHE[L1: In-Memory Cache<br/>Caffeine/Hazelcast]
            L2_CACHE[L2: Distributed Cache<br/>Redis Cluster]
        end
        
        subgraph "Database Level"
            QUERY_CACHE[Query Result Cache]
            CONNECTION_POOL[Connection Pooling]
        end
    end

    CDN --> API_CACHE
    API_CACHE --> L1_CACHE
    L1_CACHE --> L2_CACHE
    L2_CACHE --> QUERY_CACHE
    QUERY_CACHE --> CONNECTION_POOL
```

## 🔄 Resilience Patterns

### 1. Circuit Breaker Pattern

```mermaid
stateDiagram-v2
    [*] --> Closed
    Closed --> Open: Failure threshold reached
    Open --> HalfOpen: Timeout expired
    HalfOpen --> Closed: Success threshold reached
    HalfOpen --> Open: Failure detected
    
    state Closed {
        [*] --> Normal_Operation
        Normal_Operation --> Track_Failures: Request fails
        Track_Failures --> Normal_Operation: Request succeeds
    }
    
    state Open {
        [*] --> Fail_Fast
        Fail_Fast --> [*]: Return cached/default response
    }
    
    state HalfOpen {
        [*] --> Limited_Requests
        Limited_Requests --> Test_Recovery: Allow few requests through
    }
```

### 2. Retry with Exponential Backoff

```mermaid
sequenceDiagram
    participant Service
    participant ExternalAPI
    participant RetryHandler

    Service->>ExternalAPI: Request (Attempt 1)
    ExternalAPI-->>Service: Failure
    Service->>RetryHandler: Schedule Retry
    
    Note over RetryHandler: Wait 1s (2^0)
    RetryHandler->>ExternalAPI: Request (Attempt 2)
    ExternalAPI-->>RetryHandler: Failure
    
    Note over RetryHandler: Wait 2s (2^1)
    RetryHandler->>ExternalAPI: Request (Attempt 3)
    ExternalAPI-->>RetryHandler: Failure
    
    Note over RetryHandler: Wait 4s (2^2)
    RetryHandler->>ExternalAPI: Request (Attempt 4)
    ExternalAPI-->>RetryHandler: Success
    RetryHandler-->>Service: Response
```

## 📊 Monitoring & Observability

### 1. Three Pillars of Observability

```mermaid
graph TB
    subgraph "Metrics"
        BUSINESS_METRICS[Business Metrics<br/>Bookings/min, Revenue]
        SYSTEM_METRICS[System Metrics<br/>CPU, Memory, Disk]
        APPLICATION_METRICS[Application Metrics<br/>Response Time, Error Rate]
    end

    subgraph "Logs"
        STRUCTURED_LOGS[Structured Logs<br/>JSON Format]
        CENTRALIZED_LOGS[Centralized Logging<br/>ELK Stack]
        LOG_CORRELATION[Correlation IDs<br/>Request Tracing]
    end

    subgraph "Traces"
        DISTRIBUTED_TRACING[Distributed Tracing<br/>Jaeger/Zipkin]
        SPAN_CREATION[Span Creation<br/>Service Boundaries]
        TRACE_SAMPLING[Trace Sampling<br/>Performance Optimization]
    end

    BUSINESS_METRICS --> PROMETHEUS[Prometheus]
    SYSTEM_METRICS --> PROMETHEUS
    APPLICATION_METRICS --> PROMETHEUS

    STRUCTURED_LOGS --> ELASTICSEARCH[Elasticsearch]
    CENTRALIZED_LOGS --> ELASTICSEARCH
    LOG_CORRELATION --> ELASTICSEARCH

    DISTRIBUTED_TRACING --> JAEGER[Jaeger]
    SPAN_CREATION --> JAEGER
    TRACE_SAMPLING --> JAEGER

    PROMETHEUS --> GRAFANA[Grafana Dashboards]
    ELASTICSEARCH --> KIBANA[Kibana Dashboards]
    JAEGER --> JAEGER_UI[Jaeger UI]
```

### 2. Health Check Architecture

```mermaid
graph TB
    subgraph "Health Check Types"
        LIVENESS[Liveness Probe<br/>Is service running?]
        READINESS[Readiness Probe<br/>Can handle requests?]
        STARTUP[Startup Probe<br/>Has service started?]
    end

    subgraph "Health Check Components"
        APP_HEALTH[Application Health]
        DB_HEALTH[Database Health]
        CACHE_HEALTH[Cache Health]
        EXTERNAL_HEALTH[External Service Health]
    end

    subgraph "Orchestration"
        K8S[Kubernetes<br/>Pod Management]
        LOAD_BALANCER[Load Balancer<br/>Traffic Routing]
        MONITORING[Monitoring System<br/>Alerting]
    end

    LIVENESS --> APP_HEALTH
    READINESS --> DB_HEALTH
    READINESS --> CACHE_HEALTH
    STARTUP --> EXTERNAL_HEALTH

    APP_HEALTH --> K8S
    DB_HEALTH --> LOAD_BALANCER
    CACHE_HEALTH --> MONITORING
```

## 🧪 Testing Strategy

### 1. Testing Pyramid

```mermaid
graph TB
    subgraph "Testing Pyramid"
        E2E[End-to-End Tests<br/>10%<br/>Selenium, Cypress]
        INTEGRATION[Integration Tests<br/>20%<br/>TestContainers, WireMock]
        UNIT[Unit Tests<br/>70%<br/>JUnit, Jest, PyTest]
    end

    subgraph "Test Types"
        CONTRACT[Contract Tests<br/>Pact, Spring Cloud Contract]
        PERFORMANCE[Performance Tests<br/>JMeter, k6]
        SECURITY[Security Tests<br/>OWASP ZAP, SonarQube]
        CHAOS[Chaos Engineering<br/>Chaos Monkey, Litmus]
    end

    E2E --> CONTRACT
    INTEGRATION --> PERFORMANCE
    UNIT --> SECURITY
```

### 2. Testing Architecture per Service

```mermaid
graph TB
    subgraph "Service Testing"
        subgraph "Unit Tests"
            DOMAIN_TESTS[Domain Logic Tests]
            SERVICE_TESTS[Application Service Tests]
            UTIL_TESTS[Utility Tests]
        end

        subgraph "Integration Tests"
            DB_TESTS[Database Integration]
            API_TESTS[API Integration]
            MESSAGE_TESTS[Message Queue Integration]
        end

        subgraph "Contract Tests"
            CONSUMER_TESTS[Consumer Contract Tests]
            PROVIDER_TESTS[Provider Contract Tests]
        end

        subgraph "Test Infrastructure"
            TESTCONTAINERS[TestContainers<br/>Database, Redis, Kafka]
            WIREMOCK[WireMock<br/>External API Mocking]
            TEST_DATA[Test Data Builders]
        end
    end

    DOMAIN_TESTS --> TESTCONTAINERS
    DB_TESTS --> TESTCONTAINERS
    API_TESTS --> WIREMOCK
    MESSAGE_TESTS --> TESTCONTAINERS
```

## 📋 Implementation Guidelines

### 1. Service Development Checklist

#### Domain Layer
- [ ] Define domain entities with business rules
- [ ] Implement value objects for type safety
- [ ] Create domain services for complex business logic
- [ ] Define domain events for cross-service communication
- [ ] Implement aggregate roots for consistency boundaries

#### Application Layer
- [ ] Create command and query handlers
- [ ] Implement use cases with clear boundaries
- [ ] Add input validation and sanitization
- [ ] Implement DTO mapping and transformation
- [ ] Add comprehensive error handling

#### Infrastructure Layer
- [ ] Implement repository patterns with interfaces
- [ ] Create database adapters with connection pooling
- [ ] Implement external API clients with retries
- [ ] Add caching layers with appropriate TTL
- [ ] Implement message publishers and consumers

#### API Layer
- [ ] Design RESTful APIs with proper HTTP methods
- [ ] Implement authentication and authorization
- [ ] Add request/response validation
- [ ] Implement rate limiting and throttling
- [ ] Add comprehensive API documentation

### 2. Code Quality Standards

```mermaid
graph TB
    subgraph "Code Quality Gates"
        STATIC_ANALYSIS[Static Code Analysis<br/>SonarQube, ESLint]
        SECURITY_SCAN[Security Scanning<br/>Snyk, OWASP Dependency Check]
        TEST_COVERAGE[Test Coverage<br/>Minimum 80%]
        PERFORMANCE[Performance Testing<br/>Response time < 200ms]
    end

    subgraph "CI/CD Pipeline"
        BUILD[Build & Compile]
        TEST[Run Tests]
        QUALITY_GATE[Quality Gate]
        DEPLOY[Deploy to Environment]
    end

    BUILD --> TEST
    TEST --> STATIC_ANALYSIS
    STATIC_ANALYSIS --> SECURITY_SCAN
    SECURITY_SCAN --> TEST_COVERAGE
    TEST_COVERAGE --> PERFORMANCE
    PERFORMANCE --> QUALITY_GATE
    QUALITY_GATE --> DEPLOY
```

### 3. Performance Optimization Guidelines

#### Database Optimization
- Use connection pooling with appropriate pool sizes
- Implement database indexing strategies
- Use read replicas for read-heavy operations
- Implement database sharding for large datasets
- Use pagination for large result sets

#### Caching Strategy
- Implement multi-level caching (L1, L2, CDN)
- Use cache-aside pattern for frequently accessed data
- Implement cache warming for critical data
- Set appropriate TTL values based on data volatility
- Use cache invalidation strategies for data consistency

#### API Optimization
- Implement response compression (gzip)
- Use HTTP/2 for improved multiplexing
- Implement API versioning for backward compatibility
- Use appropriate HTTP status codes
- Implement request deduplication for idempotent operations

## 🚀 Deployment Architecture

### 1. Container Orchestration

```mermaid
graph TB
    subgraph "Kubernetes Cluster"
        subgraph "Control Plane"
            API_SERVER[API Server]
            SCHEDULER[Scheduler]
            CONTROLLER[Controller Manager]
            ETCD[(etcd)]
        end

        subgraph "Worker Nodes"
            subgraph "Node 1"
                KUBELET1[Kubelet]
                PROXY1[Kube-proxy]
                POD1[Service Pods]
            end

            subgraph "Node 2"
                KUBELET2[Kubelet]
                PROXY2[Kube-proxy]
                POD2[Service Pods]
            end

            subgraph "Node N"
                KUBELETN[Kubelet]
                PROXYN[Kube-proxy]
                PODN[Service Pods]
            end
        end

        subgraph "Storage"
            PV[Persistent Volumes]
            SC[Storage Classes]
        end

        subgraph "Networking"
            INGRESS[Ingress Controller]
            SERVICE_MESH[Service Mesh<br/>Istio]
            NETWORK_POLICY[Network Policies]
        end
    end

    API_SERVER --> KUBELET1
    API_SERVER --> KUBELET2
    API_SERVER --> KUBELETN
    POD1 --> PV
    POD2 --> PV
    PODN --> PV
```

### 2. Blue-Green Deployment Strategy

```mermaid
sequenceDiagram
    participant Developer
    participant CI_CD
    participant LoadBalancer
    participant BlueEnv
    participant GreenEnv
    participant Database

    Developer->>CI_CD: Push Code
    CI_CD->>CI_CD: Run Tests
    CI_CD->>GreenEnv: Deploy New Version
    GreenEnv->>Database: Run Migrations (if needed)
    CI_CD->>GreenEnv: Health Check
    CI_CD->>LoadBalancer: Switch Traffic to Green
    LoadBalancer->>GreenEnv: Route 100% Traffic
    CI_CD->>BlueEnv: Keep as Rollback Option
    
    Note over BlueEnv,GreenEnv: Monitor for Issues
    alt Rollback Needed
        CI_CD->>LoadBalancer: Switch Traffic to Blue
        LoadBalancer->>BlueEnv: Route 100% Traffic
    else Success
        CI_CD->>BlueEnv: Terminate Old Version
    end
```

## 📚 Best Practices Summary

### Development Best Practices
1. **Follow SOLID principles** for maintainable code
2. **Implement comprehensive testing** at all levels
3. **Use dependency injection** for loose coupling
4. **Apply defensive programming** for error handling
5. **Document APIs** with OpenAPI/Swagger specifications
6. **Use semantic versioning** for API compatibility
7. **Implement proper logging** with correlation IDs
8. **Follow security best practices** (OWASP guidelines)

### Operational Best Practices
1. **Implement health checks** for all services
2. **Use infrastructure as code** (Terraform, Helm)
3. **Monitor all critical metrics** and set up alerts
4. **Implement distributed tracing** for debugging
5. **Use feature flags** for safe deployments
6. **Automate security scanning** in CI/CD pipelines
7. **Regular security updates** and vulnerability patching
8. **Implement disaster recovery** and backup strategies

### Performance Best Practices
1. **Profile application performance** regularly
2. **Optimize database queries** and use proper indexing
3. **Implement caching strategies** at multiple levels
4. **Use connection pooling** for database connections
5. **Implement rate limiting** to prevent abuse
6. **Monitor and optimize memory usage**
7. **Use asynchronous processing** for long-running tasks
8. **Implement circuit breakers** for external service calls

This backend architecture provides a solid foundation for building a scalable, reliable, and maintainable flight booking system. Each component is designed to work independently while contributing to the overall system resilience and performance.