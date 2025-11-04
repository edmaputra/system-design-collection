# Development Environment Setup

## 🎯 Development Environment Objectives

- **Consistent Development**: Standardized tools and configurations across team
- **Rapid Setup**: Quick onboarding for new developers
- **CI/CD Integration**: Automated testing, building, and deployment
- **Quality Assurance**: Code quality, security, and performance checks
- **Documentation**: Comprehensive guides and standards

## 🛠️ Technology Stack & Tools

### Core Technologies
```yaml
Backend:
  - Runtime: Node.js 18+ (LTS)
  - Frameworks: Express.js, Fastify
  - Database: PostgreSQL 15+, MongoDB 6+, Redis 7+
  - Message Queue: Apache Kafka, RabbitMQ
  - Search: Elasticsearch 8+

Frontend:
  - Framework: React 18+ / Next.js 13+
  - Language: TypeScript 5+
  - Styling: Tailwind CSS, Material-UI
  - State Management: Redux Toolkit, Zustand

Mobile:
  - Framework: React Native / Flutter
  - State Management: Redux Toolkit

Infrastructure:
  - Containerization: Docker, Docker Compose
  - Orchestration: Kubernetes
  - Cloud: AWS / GCP / Azure
  - IaC: Terraform, Helm
  - Monitoring: Prometheus, Grafana, Jaeger
```

### Development Tools
```yaml
Code Quality:
  - Linting: ESLint, Prettier
  - Type Checking: TypeScript
  - Testing: Jest, Cypress, k6
  - Security: Snyk, SonarQube

Version Control:
  - Git with conventional commits
  - Branch protection rules
  - Pre-commit hooks

IDE/Editor:
  - VS Code with extensions
  - IntelliJ IDEA (optional)
  - Vim/Neovim configurations

Database Tools:
  - pgAdmin, DataGrip
  - MongoDB Compass
  - Redis Insight
```

## 🏗️ Project Structure

### Repository Organization
```
flight-booking/
├── README.md
├── .gitignore
├── .env.example
├── docker-compose.yml
├── docker-compose.dev.yml
├── Makefile
│
├── docs/                          # Documentation
│   ├── requirements/              # Requirements and specifications
│   ├── architecture/              # System architecture
│   ├── api/                      # API documentation
│   ├── deployment/               # Deployment guides
│   └── development/              # Development guides
│
├── services/                      # Microservices
│   ├── user-service/
│   │   ├── src/
│   │   │   ├── controllers/
│   │   │   ├── services/
│   │   │   ├── models/
│   │   │   ├── middleware/
│   │   │   ├── routes/
│   │   │   ├── utils/
│   │   │   └── app.js
│   │   ├── tests/
│   │   │   ├── unit/
│   │   │   ├── integration/
│   │   │   └── e2e/
│   │   ├── docker/
│   │   │   ├── Dockerfile
│   │   │   └── Dockerfile.dev
│   │   ├── package.json
│   │   ├── .env.example
│   │   └── README.md
│   │
│   ├── flight-service/
│   ├── booking-service/
│   ├── payment-service/
│   ├── notification-service/
│   └── inventory-service/
│
├── frontend/                      # Frontend applications
│   ├── web-app/                  # React web application
│   ├── mobile-app/               # React Native mobile app
│   └── admin-dashboard/          # Admin interface
│
├── shared/                        # Shared libraries and utilities
│   ├── libraries/
│   │   ├── auth/                 # Authentication utilities
│   │   ├── database/             # Database utilities
│   │   ├── messaging/            # Message queue utilities
│   │   ├── logging/              # Logging utilities
│   │   └── validation/           # Input validation
│   ├── schemas/                  # API schemas and contracts
│   └── types/                    # TypeScript type definitions
│
├── infrastructure/                # Infrastructure as Code
│   ├── terraform/
│   │   ├── environments/
│   │   │   ├── dev/
│   │   │   ├── staging/
│   │   │   └── production/
│   │   └── modules/
│   ├── kubernetes/
│   │   ├── base/
│   │   ├── overlays/
│   │   └── monitoring/
│   ├── docker/
│   │   ├── base-images/
│   │   └── compose/
│   └── helm/
│       └── flight-booking/
│
├── tests/                         # Integration and E2E tests
│   ├── integration/
│   ├── e2e/
│   ├── load/
│   └── security/
│
├── tools/                         # Development tools and scripts
│   ├── scripts/
│   │   ├── setup.sh
│   │   ├── migrate.sh
│   │   ├── seed-data.sh
│   │   └── deploy.sh
│   ├── monitoring/
│   └── security/
│
└── .github/                       # GitHub workflows
    ├── workflows/
    │   ├── ci.yml
    │   ├── cd.yml
    │   ├── security-scan.yml
    │   └── dependency-update.yml
    └── PULL_REQUEST_TEMPLATE.md
```

## 🐳 Development Environment Setup

### Docker Development Environment
```yaml
# docker-compose.dev.yml
version: '3.8'

services:
  # Databases
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: flight_booking
      POSTGRES_USER: dev_user
      POSTGRES_PASSWORD: dev_password
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./infrastructure/docker/postgres/init:/docker-entrypoint-initdb.d
    
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data
  
  mongodb:
    image: mongo:6
    ports:
      - "27017:27017"
    environment:
      MONGO_INITDB_ROOT_USERNAME: admin
      MONGO_INITDB_ROOT_PASSWORD: password
    volumes:
      - mongodb_data:/data/db
  
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.6.2
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
      - "ES_JAVA_OPTS=-Xms1g -Xmx1g"
    ports:
      - "9200:9200"
    volumes:
      - elasticsearch_data:/usr/share/elasticsearch/data
  
  # Message Queue
  kafka:
    image: confluentinc/cp-kafka:latest
    depends_on:
      - zookeeper
    ports:
      - "9092:9092"
    environment:
      KAFKA_BROKER_ID: 1
      KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://localhost:9092
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
  
  zookeeper:
    image: confluentinc/cp-zookeeper:latest
    ports:
      - "2181:2181"
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181
      ZOOKEEPER_TICK_TIME: 2000
  
  # Monitoring
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./infrastructure/monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
  
  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana_data:/var/lib/grafana

volumes:
  postgres_data:
  redis_data:
  mongodb_data:
  elasticsearch_data:
  grafana_data:
```

### Quick Setup Script
```bash
#!/bin/bash
# tools/scripts/setup.sh

set -e

echo "🚀 Setting up Flight Booking System development environment..."

# Check prerequisites
command -v docker >/dev/null 2>&1 || { echo "❌ Docker is required but not installed. Aborting." >&2; exit 1; }
command -v docker-compose >/dev/null 2>&1 || { echo "❌ Docker Compose is required but not installed. Aborting." >&2; exit 1; }
command -v node >/dev/null 2>&1 || { echo "❌ Node.js is required but not installed. Aborting." >&2; exit 1; }

# Clone repository if running remotely
if [ ! -f "package.json" ]; then
    echo "📥 Cloning repository..."
    git clone https://github.com/your-org/flight-booking-system.git
    cd flight-booking-system
fi

# Install dependencies
echo "📦 Installing dependencies..."
npm install

# Copy environment files
echo "⚙️ Setting up environment files..."
for service in services/*/; do
    if [ -f "$service/.env.example" ]; then
        cp "$service/.env.example" "$service/.env"
        echo "Created $service/.env from template"
    fi
done

# Start infrastructure services
echo "🐳 Starting infrastructure services..."
docker-compose -f docker-compose.dev.yml up -d

# Wait for services to be ready
echo "⏳ Waiting for services to be ready..."
./tools/scripts/wait-for-services.sh

# Run database migrations
echo "🗄️ Running database migrations..."
npm run migrate

# Seed test data
echo "🌱 Seeding test data..."
npm run seed

# Install git hooks
echo "🪝 Installing git hooks..."
npx husky install

echo "✅ Development environment setup complete!"
echo ""
echo "🌐 Available services:"
echo "  - Web App: http://localhost:3000"
echo "  - API Gateway: http://localhost:8080"
echo "  - Grafana: http://localhost:3001 (admin/admin)"
echo "  - Prometheus: http://localhost:9090"
echo "  - Elasticsearch: http://localhost:9200"
echo ""
echo "📚 Next steps:"
echo "  1. Start services: npm run dev"
echo "  2. Run tests: npm test"
echo "  3. View documentation: npm run docs"
```

## 🔧 Development Workflow

### Branch Strategy (GitFlow)
```
main branch (production)
├── develop branch (integration)
│   ├── feature/user-authentication
│   ├── feature/flight-search
│   └── feature/booking-system
├── release/v1.0.0
└── hotfix/critical-bug-fix
```

### Commit Convention
```bash
# Format: <type>(<scope>): <subject>
# Examples:
feat(auth): add JWT token refresh mechanism
fix(booking): resolve seat selection race condition
docs(api): update flight search endpoint documentation
test(payment): add integration tests for refund process
refactor(db): optimize flight search query performance
chore(deps): update security dependencies
```

### Pre-commit Hooks
```yaml
# .husky/pre-commit
#!/usr/bin/env sh
. "$(dirname -- "$0")/_/husky.sh"

# Run linting
npm run lint

# Run type checking
npm run type-check

# Run unit tests
npm run test:unit

# Security scan
npm audit --audit-level high

# Check for secrets
npm run check-secrets
```

## 🧪 Testing Strategy

### Test Structure
```javascript
// Example: services/booking-service/tests/unit/booking.service.test.js
describe('BookingService', () => {
  let bookingService;
  let mockDb;
  let mockPaymentService;
  
  beforeEach(() => {
    mockDb = {
      bookings: {
        create: jest.fn(),
        findById: jest.fn(),
        update: jest.fn()
      }
    };
    mockPaymentService = {
      processPayment: jest.fn()
    };
    bookingService = new BookingService(mockDb, mockPaymentService);
  });
  
  describe('createBooking', () => {
    it('should create booking successfully', async () => {
      // Arrange
      const bookingData = {
        userId: 'user123',
        flights: [{ flightId: 'flight123', class: 'economy' }],
        totalAmount: 299.99
      };
      
      mockDb.bookings.create.mockResolvedValue({
        id: 'booking123',
        ...bookingData
      });
      
      // Act
      const result = await bookingService.createBooking(bookingData);
      
      // Assert
      expect(result.id).toBe('booking123');
      expect(mockDb.bookings.create).toHaveBeenCalledWith(bookingData);
    });
    
    it('should handle payment failure', async () => {
      // Test error scenarios
    });
  });
});
```

### Testing Commands
```json
{
  "scripts": {
    "test": "npm run test:unit && npm run test:integration",
    "test:unit": "jest --config=jest.unit.config.js",
    "test:integration": "jest --config=jest.integration.config.js",
    "test:e2e": "cypress run",
    "test:load": "k6 run tests/load/flight-search.js",
    "test:security": "npm audit && snyk test",
    "test:watch": "jest --watch",
    "test:coverage": "jest --coverage --coverageReporters=text-lcov | coveralls"
  }
}
```

## 🚀 CI/CD Pipeline

### GitHub Actions Workflow
```yaml
# .github/workflows/ci.yml
name: Continuous Integration

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

jobs:
  test:
    runs-on: ubuntu-latest
    
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Node.js
      uses: actions/setup-node@v3
      with:
        node-version: '18'
        cache: 'npm'
    
    - name: Install dependencies
      run: npm ci
    
    - name: Run linting
      run: npm run lint
    
    - name: Run type checking
      run: npm run type-check
    
    - name: Run unit tests
      run: npm run test:unit
    
    - name: Run integration tests
      run: npm run test:integration
      env:
        DATABASE_URL: postgresql://postgres:postgres@localhost:5432/test
    
    - name: Security scan
      run: |
        npm audit --audit-level high
        npx snyk test
    
    - name: Build services
      run: npm run build
    
    - name: Upload coverage reports
      uses: codecov/codecov-action@v3
      with:
        file: ./coverage/lcov.info

  build-and-push:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v2
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: us-east-1
    
    - name: Login to Amazon ECR
      id: login-ecr
      uses: aws-actions/amazon-ecr-login@v1
    
    - name: Build and push Docker images
      run: |
        for service in services/*/; do
          service_name=$(basename $service)
          docker build -t $ECR_REGISTRY/$service_name:$GITHUB_SHA $service
          docker push $ECR_REGISTRY/$service_name:$GITHUB_SHA
        done
      env:
        ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
```

### Deployment Pipeline
```yaml
# .github/workflows/deploy.yml
name: Deploy to Environment

on:
  workflow_run:
    workflows: ["Continuous Integration"]
    branches: [main]
    types: [completed]

jobs:
  deploy-staging:
    if: ${{ github.event.workflow_run.conclusion == 'success' }}
    runs-on: ubuntu-latest
    environment: staging
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Deploy to staging
      run: |
        kubectl set image deployment/user-service user-service=$ECR_REGISTRY/user-service:$GITHUB_SHA
        kubectl set image deployment/flight-service flight-service=$ECR_REGISTRY/flight-service:$GITHUB_SHA
        kubectl rollout status deployment/user-service
        kubectl rollout status deployment/flight-service
      env:
        KUBECONFIG: ${{ secrets.KUBE_CONFIG_STAGING }}
    
    - name: Run smoke tests
      run: npm run test:smoke:staging

  deploy-production:
    needs: deploy-staging
    runs-on: ubuntu-latest
    environment: production
    if: github.ref == 'refs/heads/main'
    
    steps:
    - name: Deploy to production
      run: |
        # Blue-green deployment strategy
        ./tools/scripts/blue-green-deploy.sh
      env:
        KUBECONFIG: ${{ secrets.KUBE_CONFIG_PRODUCTION }}
```

## 📋 Development Standards

### Code Quality Standards
```javascript
// ESLint configuration (.eslintrc.js)
module.exports = {
  extends: [
    'eslint:recommended',
    '@typescript-eslint/recommended',
    'prettier'
  ],
  parser: '@typescript-eslint/parser',
  plugins: ['@typescript-eslint', 'security', 'import'],
  rules: {
    'no-console': 'warn',
    'no-debugger': 'error',
    'prefer-const': 'error',
    'no-var': 'error',
    'security/detect-sql-injection': 'error',
    'security/detect-object-injection': 'error',
    'import/order': ['error', { 'newlines-between': 'always' }],
    '@typescript-eslint/no-unused-vars': 'error',
    '@typescript-eslint/explicit-function-return-type': 'warn'
  }
};
```

### API Development Standards
```typescript
// Example: Standardized API controller
export class FlightController {
  constructor(
    private flightService: FlightService,
    private logger: Logger
  ) {}

  @Get('/search')
  @ValidateQuery(FlightSearchSchema)
  @RateLimit({ max: 100, windowMs: 60000 })
  async searchFlights(
    @Query() query: FlightSearchQuery,
    @Req() req: AuthenticatedRequest
  ): Promise<ApiResponse<FlightSearchResult[]>> {
    const startTime = Date.now();
    
    try {
      this.logger.info('Flight search initiated', {
        userId: req.user.id,
        searchParams: query
      });
      
      const results = await this.flightService.searchFlights(query);
      
      this.logger.info('Flight search completed', {
        userId: req.user.id,
        resultCount: results.length,
        responseTime: Date.now() - startTime
      });
      
      return {
        success: true,
        data: results,
        metadata: {
          timestamp: new Date().toISOString(),
          requestId: req.id
        }
      };
    } catch (error) {
      this.logger.error('Flight search failed', error, {
        userId: req.user.id,
        searchParams: query
      });
      
      throw new HttpException(
        'Flight search failed',
        HttpStatus.INTERNAL_SERVER_ERROR
      );
    }
  }
}
```

This comprehensive development environment setup ensures consistent, high-quality development practices across the entire Flight Booking System project.