# Monitoring & Observability Strategy

## 🎯 Observability Objectives

- **Full System Visibility**: End-to-end transaction tracing
- **Proactive Monitoring**: Issue detection before user impact
- **Performance Insights**: Optimize system performance continuously
- **Business Metrics**: Track KPIs and business health
- **Compliance Monitoring**: Ensure regulatory compliance
- **Incident Response**: Rapid issue resolution and root cause analysis

## 📊 Three Pillars of Observability

### 1. Metrics (What is happening?)
#### System Metrics
```javascript
// Prometheus metrics configuration
const promClient = require('prom-client');

// Custom metrics for business logic
const flightSearchCounter = new promClient.Counter({
  name: 'flight_searches_total',
  help: 'Total number of flight searches',
  labelNames: ['origin', 'destination', 'status']
});

const bookingDuration = new promClient.Histogram({
  name: 'booking_duration_seconds',
  help: 'Time taken to complete booking process',
  labelNames: ['payment_method', 'user_type'],
  buckets: [0.1, 0.5, 1, 2, 5, 10, 30]
});

const activeConnections = new promClient.Gauge({
  name: 'active_connections',
  help: 'Number of active database connections',
  labelNames: ['database', 'service']
});

// Business metrics
const revenueGauge = new promClient.Gauge({
  name: 'total_revenue_usd',
  help: 'Total revenue in USD',
  labelNames: ['period', 'region']
});
```

#### Infrastructure Metrics
```yaml
# Prometheus configuration
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'flight-booking-services'
    static_configs:
      - targets: ['user-service:3001', 'flight-service:3002', 'booking-service:3003']
    metrics_path: '/metrics'
    scrape_interval: 10s
    
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']
    
  - job_name: 'postgres-exporter'
    static_configs:
      - targets: ['postgres-exporter:9187']
    
  - job_name: 'redis-exporter'
    static_configs:
      - targets: ['redis-exporter:9121']
```

### 2. Logs (What happened?)
#### Structured Logging
```javascript
// Winston logger configuration
const winston = require('winston');

const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json(),
    winston.format.printf(info => {
      return JSON.stringify({
        timestamp: info.timestamp,
        level: info.level,
        message: info.message,
        service: process.env.SERVICE_NAME,
        version: process.env.SERVICE_VERSION,
        traceId: info.traceId,
        spanId: info.spanId,
        userId: info.userId,
        correlationId: info.correlationId,
        ...info.metadata
      });
    })
  ),
  defaultMeta: { service: 'flight-booking' },
  transports: [
    new winston.transports.File({ filename: 'error.log', level: 'error' }),
    new winston.transports.File({ filename: 'combined.log' }),
    new winston.transports.Console({
      format: winston.format.simple()
    })
  ]
});

// Contextual logging
class Logger {
  static info(message, metadata = {}) {
    const context = this.getContext();
    logger.info(message, { ...metadata, ...context });
  }
  
  static error(message, error, metadata = {}) {
    const context = this.getContext();
    logger.error(message, {
      error: {
        message: error.message,
        stack: error.stack,
        name: error.name
      },
      ...metadata,
      ...context
    });
  }
  
  static getContext() {
    return {
      traceId: AsyncStorage.getStore()?.traceId,
      spanId: AsyncStorage.getStore()?.spanId,
      userId: AsyncStorage.getStore()?.userId,
      sessionId: AsyncStorage.getStore()?.sessionId
    };
  }
}
```

#### Log Aggregation with ELK Stack
```yaml
# Elasticsearch configuration
version: '3.8'
services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.6.2
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
      - "ES_JAVA_OPTS=-Xms2g -Xmx2g"
    ports:
      - "9200:9200"
    volumes:
      - elasticsearch_data:/usr/share/elasticsearch/data

  logstash:
    image: docker.elastic.co/logstash/logstash:8.6.2
    ports:
      - "5044:5044"
    volumes:
      - ./logstash.conf:/usr/share/logstash/pipeline/logstash.conf
    depends_on:
      - elasticsearch

  kibana:
    image: docker.elastic.co/kibana/kibana:8.6.2
    ports:
      - "5601:5601"
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
    depends_on:
      - elasticsearch
```

#### Security & Audit Logging
```javascript
// Security event logging
class SecurityLogger {
  static logAuthEvent(event) {
    logger.info('SECURITY_EVENT', {
      eventType: 'authentication',
      action: event.action, // login, logout, failed_login
      userId: event.userId,
      ipAddress: event.ipAddress,
      userAgent: event.userAgent,
      location: event.location,
      success: event.success,
      failureReason: event.failureReason,
      riskScore: event.riskScore,
      mfaUsed: event.mfaUsed
    });
  }
  
  static logDataAccess(event) {
    logger.info('DATA_ACCESS', {
      eventType: 'data_access',
      userId: event.userId,
      resource: event.resource,
      action: event.action, // read, write, delete
      recordCount: event.recordCount,
      dataClassification: event.dataClassification,
      purpose: event.purpose
    });
  }
  
  static logPaymentEvent(event) {
    logger.info('PAYMENT_EVENT', {
      eventType: 'payment',
      transactionId: event.transactionId,
      amount: event.amount,
      currency: event.currency,
      paymentMethod: event.paymentMethod,
      status: event.status,
      gateway: event.gateway,
      fraudScore: event.fraudScore
    });
  }
}
```

### 3. Traces (Why did it happen?)
#### Distributed Tracing with OpenTelemetry
```javascript
// OpenTelemetry setup
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { JaegerExporter } = require('@opentelemetry/exporter-jaeger');

const jaegerExporter = new JaegerExporter({
  endpoint: process.env.JAEGER_ENDPOINT || 'http://jaeger:14268/api/traces',
});

const sdk = new NodeSDK({
  traceExporter: jaegerExporter,
  instrumentations: [getNodeAutoInstrumentations({
    '@opentelemetry/instrumentation-fs': {
      enabled: false,
    },
  })],
  serviceName: process.env.SERVICE_NAME,
  serviceVersion: process.env.SERVICE_VERSION,
});

sdk.start();

// Custom tracing for business operations
const { trace } = require('@opentelemetry/api');
const tracer = trace.getTracer('flight-booking-tracer');

class BookingService {
  async createBooking(bookingData) {
    return tracer.startActiveSpan('booking.create', async (span) => {
      try {
        span.setAttributes({
          'booking.userId': bookingData.userId,
          'booking.flightCount': bookingData.flights.length,
          'booking.totalAmount': bookingData.totalAmount
        });
        
        // Validate booking data
        await tracer.startActiveSpan('booking.validate', async (validateSpan) => {
          await this.validateBookingData(bookingData);
          validateSpan.end();
        });
        
        // Create booking record
        const booking = await tracer.startActiveSpan('booking.database.create', async (dbSpan) => {
          dbSpan.setAttributes({
            'db.operation': 'INSERT',
            'db.table': 'bookings'
          });
          return await this.db.bookings.create(bookingData);
        });
        
        // Process payment
        await tracer.startActiveSpan('booking.payment.process', async (paymentSpan) => {
          await this.paymentService.processPayment(booking.id, bookingData.payment);
          paymentSpan.end();
        });
        
        span.setStatus({ code: SpanStatusCode.OK });
        return booking;
      } catch (error) {
        span.recordException(error);
        span.setStatus({ code: SpanStatusCode.ERROR, message: error.message });
        throw error;
      } finally {
        span.end();
      }
    });
  }
}
```

## 📈 Key Performance Indicators (KPIs)

### Business Metrics
```javascript
const businessMetrics = {
  // Conversion metrics
  searchToBookingConversion: {
    query: `
      SELECT 
        COUNT(DISTINCT b.id) * 100.0 / COUNT(DISTINCT s.id) as conversion_rate
      FROM searches s
      LEFT JOIN bookings b ON b.user_id = s.user_id 
        AND b.created_at BETWEEN s.created_at AND s.created_at + INTERVAL '1 hour'
      WHERE s.created_at >= NOW() - INTERVAL '24 hours'
    `,
    threshold: 15, // Target: >15% conversion rate
    alert: 'conversion_rate < 10'
  },
  
  // Revenue metrics
  dailyRevenue: {
    query: `
      SELECT 
        DATE(created_at) as date,
        SUM(total_amount) as revenue,
        COUNT(*) as booking_count,
        AVG(total_amount) as avg_booking_value
      FROM bookings 
      WHERE status = 'confirmed' 
        AND created_at >= NOW() - INTERVAL '7 days'
      GROUP BY DATE(created_at)
    `,
    threshold: 50000, // Target: >$50k daily revenue
    alert: 'revenue < 30000'
  },
  
  // Customer satisfaction
  customerSatisfaction: {
    query: `
      SELECT 
        AVG(rating) as avg_rating,
        COUNT(*) as review_count
      FROM reviews 
      WHERE created_at >= NOW() - INTERVAL '30 days'
    `,
    threshold: 4.5, // Target: >4.5/5 rating
    alert: 'avg_rating < 4.0'
  }
};
```

### Technical Metrics
```javascript
const technicalMetrics = {
  // System performance
  responseTime: {
    prometheus: 'histogram_quantile(0.95, http_request_duration_seconds)',
    threshold: 2.0, // Target: <2s for 95th percentile
    alert: 'response_time > 5'
  },
  
  // System reliability
  errorRate: {
    prometheus: 'rate(http_requests_total{status=~"5.."}[5m])',
    threshold: 0.01, // Target: <1% error rate
    alert: 'error_rate > 0.05'
  },
  
  // Infrastructure health
  cpuUtilization: {
    prometheus: 'avg(cpu_usage_percent) by (service)',
    threshold: 70, // Target: <70% CPU usage
    alert: 'cpu_usage > 90'
  },
  
  memoryUtilization: {
    prometheus: 'avg(memory_usage_percent) by (service)',
    threshold: 80, // Target: <80% memory usage
    alert: 'memory_usage > 95'
  }
};
```

## 🚨 Alerting Strategy

### Alert Rules Configuration
```yaml
# Prometheus alerting rules
groups:
  - name: flight-booking-critical
    rules:
      - alert: ServiceDown
        expr: up{job="flight-booking-services"} == 0
        for: 1m
        labels:
          severity: critical
          team: platform
        annotations:
          summary: "Service {{ $labels.instance }} is down"
          description: "{{ $labels.instance }} has been down for more than 1 minute"
          
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.05
        for: 2m
        labels:
          severity: critical
          team: backend
        annotations:
          summary: "High error rate detected"
          description: "Error rate is {{ $value | humanizePercentage }} for the last 5 minutes"
          
      - alert: DatabaseConnectionsHigh
        expr: pg_stat_activity_count > 80
        for: 5m
        labels:
          severity: warning
          team: database
        annotations:
          summary: "High number of database connections"
          description: "Database has {{ $value }} active connections"
          
  - name: flight-booking-business
    rules:
      - alert: LowConversionRate
        expr: booking_conversion_rate < 0.10
        for: 15m
        labels:
          severity: warning
          team: product
        annotations:
          summary: "Booking conversion rate is low"
          description: "Conversion rate has been {{ $value | humanizePercentage }} for 15 minutes"
          
      - alert: PaymentFailuresHigh
        expr: rate(payment_failures_total[10m]) > 0.10
        for: 5m
        labels:
          severity: critical
          team: payments
        annotations:
          summary: "High payment failure rate"
          description: "Payment failure rate is {{ $value | humanizePercentage }}"
```

### Multi-channel Alerting
```javascript
// Alert routing and escalation
class AlertManager {
  constructor() {
    this.channels = {
      slack: new SlackWebhook(process.env.SLACK_WEBHOOK_URL),
      pagerduty: new PagerDutyClient(process.env.PAGERDUTY_API_KEY),
      email: new EmailService(),
      sms: new SMSService()
    };
    
    this.escalationMatrix = {
      critical: {
        immediate: ['slack', 'pagerduty'],
        after5min: ['sms'],
        after15min: ['email']
      },
      warning: {
        immediate: ['slack'],
        after30min: ['email']
      },
      info: {
        immediate: ['slack']
      }
    };
  }
  
  async handleAlert(alert) {
    const severity = alert.labels.severity;
    const team = alert.labels.team;
    
    // Get team-specific escalation rules
    const teamConfig = await this.getTeamConfig(team);
    const escalation = this.escalationMatrix[severity];
    
    // Send immediate notifications
    for (const channel of escalation.immediate) {
      await this.sendNotification(channel, alert, teamConfig);
    }
    
    // Schedule escalation notifications
    if (escalation.after5min) {
      setTimeout(() => {
        this.checkAndEscalate(alert, escalation.after5min, teamConfig);
      }, 5 * 60 * 1000);
    }
  }
}
```

## 📊 Monitoring Dashboards

### Grafana Dashboard Configuration
```json
{
  "dashboard": {
    "title": "Flight Booking System Overview",
    "panels": [
      {
        "title": "Request Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "sum(rate(http_requests_total[5m])) by (service)",
            "legendFormat": "{{ service }}"
          }
        ]
      },
      {
        "title": "Response Time",
        "type": "graph",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le, service))",
            "legendFormat": "95th percentile - {{ service }}"
          },
          {
            "expr": "histogram_quantile(0.50, sum(rate(http_request_duration_seconds_bucket[5m])) by (le, service))",
            "legendFormat": "50th percentile - {{ service }}"
          }
        ]
      },
      {
        "title": "Error Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "sum(rate(http_requests_total{status=~\"4..|5..\"}[5m])) by (service) / sum(rate(http_requests_total[5m])) by (service)",
            "legendFormat": "{{ service }}"
          }
        ]
      },
      {
        "title": "Business Metrics",
        "type": "stat",
        "targets": [
          {
            "expr": "sum(bookings_total)",
            "legendFormat": "Total Bookings"
          },
          {
            "expr": "sum(revenue_total_usd)",
            "legendFormat": "Total Revenue"
          },
          {
            "expr": "avg(booking_conversion_rate)",
            "legendFormat": "Conversion Rate"
          }
        ]
      }
    ]
  }
}
```

### Custom Business Intelligence Dashboard
```javascript
// Real-time business metrics dashboard
class BusinessDashboard {
  constructor() {
    this.metrics = {};
    this.refreshInterval = 30000; // 30 seconds
    this.startMetricsCollection();
  }
  
  async collectMetrics() {
    const now = new Date();
    const last24h = new Date(now - 24 * 60 * 60 * 1000);
    
    // Booking metrics
    this.metrics.bookings = await this.db.query(`
      SELECT 
        COUNT(*) as total_bookings,
        SUM(total_amount) as total_revenue,
        AVG(total_amount) as avg_booking_value,
        COUNT(DISTINCT user_id) as unique_customers
      FROM bookings 
      WHERE created_at >= $1 AND status = 'confirmed'
    `, [last24h]);
    
    // Search metrics
    this.metrics.searches = await this.db.query(`
      SELECT 
        COUNT(*) as total_searches,
        COUNT(DISTINCT user_id) as unique_searchers,
        COUNT(DISTINCT CONCAT(origin, '-', destination)) as unique_routes
      FROM flight_searches 
      WHERE created_at >= $1
    `, [last24h]);
    
    // Performance metrics
    this.metrics.performance = {
      avgResponseTime: await this.getAvgResponseTime(),
      errorRate: await this.getErrorRate(),
      systemLoad: await this.getSystemLoad()
    };
    
    // Update dashboard
    await this.updateDashboard();
  }
}
```

## 🔍 Synthetic Monitoring

### Health Checks
```javascript
// Comprehensive health check system
class HealthCheckService {
  constructor() {
    this.checks = {
      database: this.checkDatabase,
      redis: this.checkRedis,
      externalAPIs: this.checkExternalAPIs,
      criticalPaths: this.checkCriticalPaths
    };
  }
  
  async performHealthCheck() {
    const results = {};
    const overall = { status: 'healthy', checks: results };
    
    for (const [name, check] of Object.entries(this.checks)) {
      try {
        const startTime = Date.now();
        const result = await Promise.race([
          check(),
          new Promise((_, reject) => 
            setTimeout(() => reject(new Error('Timeout')), 5000)
          )
        ]);
        
        results[name] = {
          status: 'healthy',
          responseTime: Date.now() - startTime,
          details: result
        };
      } catch (error) {
        results[name] = {
          status: 'unhealthy',
          error: error.message,
          responseTime: Date.now() - startTime
        };
        overall.status = 'unhealthy';
      }
    }
    
    return overall;
  }
  
  async checkCriticalPaths() {
    // Test critical user journeys
    const testScenarios = [
      {
        name: 'flight_search',
        test: () => this.testFlightSearch('LAX', 'JFK', '2024-06-01')
      },
      {
        name: 'user_registration',
        test: () => this.testUserRegistration()
      },
      {
        name: 'booking_creation',
        test: () => this.testBookingCreation()
      }
    ];
    
    const results = {};
    for (const scenario of testScenarios) {
      try {
        await scenario.test();
        results[scenario.name] = 'passed';
      } catch (error) {
        results[scenario.name] = 'failed';
        throw new Error(`Critical path ${scenario.name} failed: ${error.message}`);
      }
    }
    
    return results;
  }
}
```

This comprehensive monitoring and observability strategy provides complete visibility into the Flight Booking System, enabling proactive issue detection, rapid incident response, and continuous performance optimization.