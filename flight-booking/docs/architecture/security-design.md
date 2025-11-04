# Security & Authentication Design

## 🔐 Security Architecture Overview

The Flight Booking System implements a comprehensive security framework following industry best practices and compliance requirements including PCI DSS, GDPR, and aviation security standards.

## 🎯 Security Principles

1. **Zero Trust Architecture**: Never trust, always verify
2. **Defense in Depth**: Multiple layers of security controls
3. **Principle of Least Privilege**: Minimal necessary access rights
4. **Data Classification**: Appropriate protection based on sensitivity
5. **Encryption Everywhere**: Data protection at rest and in transit
6. **Continuous Monitoring**: Real-time threat detection and response

## 🔑 Authentication Architecture

### Multi-Factor Authentication (MFA)
```
User Credentials → Primary Auth → Secondary Factor → Access Granted
     ↓               ↓              ↓
- Username/Password  - JWT Token    - SMS/Email OTP
- Social Login       - Session      - Authenticator App
- Biometrics        - Refresh       - Hardware Token
```

### Authentication Methods

#### 1. Primary Authentication
- **Username/Password**: Bcrypt hashed with salt (cost factor: 12)
- **Social Login**: OAuth 2.0 with Google, Facebook, Apple
- **Biometric**: WebAuthn for supported devices
- **Enterprise SSO**: SAML 2.0 for corporate customers

#### 2. Multi-Factor Authentication
- **SMS OTP**: Time-based one-time passwords
- **Email OTP**: Backup authentication method
- **TOTP**: Google Authenticator, Authy compatible
- **Hardware Tokens**: FIDO2/WebAuthn security keys
- **Push Notifications**: Mobile app approval

### JWT Token Strategy

#### Access Token Structure
```json
{
  "header": {
    "alg": "RS256",
    "typ": "JWT",
    "kid": "key-id-2024"
  },
  "payload": {
    "sub": "user-uuid",
    "iss": "flight-booking-api",
    "aud": "flight-booking-client",
    "exp": 1640995200,
    "iat": 1640991600,
    "jti": "token-uuid",
    "scope": ["read:profile", "write:bookings"],
    "roles": ["customer"],
    "session_id": "session-uuid",
    "ip": "192.168.1.1",
    "device_id": "device-uuid"
  }
}
```

#### Token Management
- **Access Token Lifetime**: 15 minutes
- **Refresh Token Lifetime**: 7 days
- **Token Rotation**: New refresh token on each use
- **Token Revocation**: Immediate invalidation support
- **Key Rotation**: Monthly RSA keypair rotation

### Session Management
```javascript
// Session configuration
const sessionConfig = {
  secret: process.env.SESSION_SECRET,
  name: 'flightBookingSession',
  cookie: {
    secure: true, // HTTPS only
    httpOnly: true, // Prevent XSS
    maxAge: 15 * 60 * 1000, // 15 minutes
    sameSite: 'strict' // CSRF protection
  },
  rolling: true, // Extend on activity
  resave: false,
  saveUninitialized: false
};
```

## 🛡️ Authorization Framework

### Role-Based Access Control (RBAC)

#### Role Hierarchy
```
Super Admin
├── System Admin
│   ├── Support Admin
│   └── Analytics Admin
├── Business Admin
│   ├── Revenue Manager
│   └── Operations Manager
└── Customer Service
    ├── Senior Agent
    └── Support Agent

Customer
├── Premium Customer
└── Regular Customer

Partner
├── Travel Agent
└── API Client
```

#### Permission Matrix
| Resource | Customer | Agent | Admin | System Admin |
|----------|----------|-------|--------|--------------|
| View Own Profile | ✓ | ✓ | ✓ | ✓ |
| Search Flights | ✓ | ✓ | ✓ | ✓ |
| Create Booking | ✓ | ✓ | ✓ | ✓ |
| View Any Booking | ✗ | ✓ | ✓ | ✓ |
| Cancel Any Booking | ✗ | ✓ | ✓ | ✓ |
| Manage Inventory | ✗ | ✗ | ✓ | ✓ |
| System Configuration | ✗ | ✗ | ✗ | ✓ |

### Attribute-Based Access Control (ABAC)
```javascript
// Policy example: Users can only access their own bookings
const accessPolicy = {
  resource: 'booking',
  action: 'read',
  condition: 'resource.userId === user.id OR user.role === "agent"',
  effect: 'allow'
};

// Dynamic permission evaluation
function evaluateAccess(user, resource, action) {
  const policies = getPoliciesForResource(resource);
  return policies.some(policy => 
    evaluateCondition(policy.condition, { user, resource, action })
  );
}
```

## 🔒 Data Protection

### Encryption Strategy

#### Data at Rest
```sql
-- Database-level encryption
CREATE TABLE users (
    id UUID PRIMARY KEY,
    email VARCHAR(255) NOT NULL,
    -- Store sensitive data encrypted
    phone_encrypted BYTEA, -- AES-256-GCM encrypted
    passport_encrypted BYTEA,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Application-level encryption helpers
CREATE OR REPLACE FUNCTION encrypt_sensitive_data(plaintext TEXT)
RETURNS BYTEA AS $$
BEGIN
    RETURN pgp_sym_encrypt(plaintext, current_setting('app.encryption_key'), 'cipher-algo=aes256');
END;
$$ LANGUAGE plpgsql;
```

#### Data in Transit
- **TLS 1.3**: All external communications
- **mTLS**: Inter-service communication
- **Certificate Pinning**: Mobile applications
- **HSTS**: HTTP Strict Transport Security
- **Perfect Forward Secrecy**: Ephemeral key exchange

#### Encryption Key Management
```javascript
// Hierarchical key structure
const keyHierarchy = {
  masterKey: 'HSM-stored root key',
  dataEncryptionKeys: {
    userdata: 'AES-256 key for user PII',
    payments: 'AES-256 key for payment data',
    bookings: 'AES-256 key for booking data'
  },
  rotationSchedule: {
    dataKeys: '90 days',
    masterKey: '1 year'
  }
};
```

### PCI DSS Compliance

#### Card Data Handling
```javascript
// PCI DSS compliant payment processing
class PaymentProcessor {
  async processPayment(paymentData) {
    // Tokenize card data immediately
    const token = await this.tokenizeCard(paymentData.card);
    
    // Store only token, never card data
    const transaction = {
      id: uuid(),
      bookingId: paymentData.bookingId,
      amount: paymentData.amount,
      cardToken: token, // Tokenized reference
      // Never store: PAN, CVV, expiry
    };
    
    // Process through PCI DSS compliant gateway
    return await this.gateway.charge(token, paymentData.amount);
  }
  
  async tokenizeCard(cardData) {
    // Use payment gateway tokenization
    // Card data never touches our servers
    return await this.gateway.createToken(cardData);
  }
}
```

#### PCI DSS Requirements Compliance
- **Requirement 1**: Firewall configuration ✓
- **Requirement 2**: Default passwords changed ✓
- **Requirement 3**: Stored cardholder data protected ✓
- **Requirement 4**: Encrypted transmission ✓
- **Requirement 5**: Anti-virus protection ✓
- **Requirement 6**: Secure systems and applications ✓
- **Requirement 7**: Restrict access by business need ✓
- **Requirement 8**: Unique IDs and strong authentication ✓
- **Requirement 9**: Restrict physical access ✓
- **Requirement 10**: Track and monitor network access ✓
- **Requirement 11**: Regular security testing ✓
- **Requirement 12**: Information security policy ✓

## 🛡️ Application Security

### Input Validation & Sanitization
```javascript
// Comprehensive input validation
const validationRules = {
  email: {
    type: 'string',
    format: 'email',
    maxLength: 255,
    required: true
  },
  flightSearch: {
    origin: {
      type: 'string',
      pattern: '^[A-Z]{3}$', // IATA code
      required: true
    },
    destination: {
      type: 'string',
      pattern: '^[A-Z]{3}$',
      required: true
    },
    departureDate: {
      type: 'string',
      format: 'date',
      minimum: new Date().toISOString().split('T')[0],
      required: true
    },
    passengers: {
      type: 'integer',
      minimum: 1,
      maximum: 9
    }
  }
};

// SQL injection prevention
const query = `
  SELECT * FROM flights 
  WHERE origin_airport = $1 
    AND destination_airport = $2 
    AND departure_date = $3
`;
// Always use parameterized queries
```

### XSS Protection
```javascript
// Content Security Policy
app.use((req, res, next) => {
  res.setHeader(
    'Content-Security-Policy',
    "default-src 'self'; " +
    "script-src 'self' 'unsafe-inline' https://trusted-cdn.com; " +
    "style-src 'self' 'unsafe-inline'; " +
    "img-src 'self' data: https:; " +
    "connect-src 'self' https://api.flightbooking.com"
  );
  next();
});

// Input sanitization
const sanitizer = require('sanitize-html');
const cleanInput = (input) => {
  return sanitizer(input, {
    allowedTags: [],
    allowedAttributes: {}
  });
};
```

### CSRF Protection
```javascript
// CSRF token implementation
app.use(csrf({
  cookie: {
    httpOnly: true,
    secure: true,
    sameSite: 'strict'
  }
}));

// API endpoints use double-submit cookie pattern
app.post('/api/bookings', (req, res) => {
  const csrfToken = req.headers['x-csrf-token'];
  const cookieToken = req.cookies.csrfToken;
  
  if (csrfToken !== cookieToken) {
    return res.status(403).json({ error: 'CSRF token mismatch' });
  }
  
  // Process request
});
```

## 🔍 Security Monitoring

### Real-time Threat Detection
```javascript
// Suspicious activity detection
const securityMonitor = {
  async detectSuspiciousActivity(event) {
    const rules = [
      // Multiple failed login attempts
      {
        name: 'brute_force',
        condition: (e) => e.type === 'login_failed' && e.count > 5,
        action: 'lock_account',
        severity: 'high'
      },
      
      // Unusual booking patterns
      {
        name: 'booking_anomaly',
        condition: (e) => e.type === 'booking_created' && 
                          e.amount > 10000 && 
                          e.user.accountAge < 7,
        action: 'flag_for_review',
        severity: 'medium'
      },
      
      // Geolocation anomalies
      {
        name: 'geo_anomaly',
        condition: (e) => e.location.distance > 1000 && 
                          e.timeDiff < 3600,
        action: 'require_mfa',
        severity: 'high'
      }
    ];
    
    for (const rule of rules) {
      if (rule.condition(event)) {
        await this.triggerSecurityAction(rule, event);
      }
    }
  }
};
```

### Audit Logging
```javascript
// Comprehensive audit trail
const auditLogger = {
  logSecurityEvent(event) {
    const auditEntry = {
      timestamp: new Date().toISOString(),
      eventType: event.type,
      userId: event.userId,
      sessionId: event.sessionId,
      ipAddress: event.ipAddress,
      userAgent: event.userAgent,
      resource: event.resource,
      action: event.action,
      result: event.result,
      riskScore: event.riskScore,
      metadata: event.metadata
    };
    
    // Log to multiple destinations
    logger.info('SECURITY_EVENT', auditEntry);
    elasticsearchClient.index({
      index: 'security-audit',
      body: auditEntry
    });
  }
};
```

## 🚨 Incident Response

### Security Incident Classification
| Level | Description | Response Time | Examples |
|-------|-------------|---------------|----------|
| P0 | Critical security breach | 15 minutes | Data breach, system compromise |
| P1 | High security risk | 1 hour | Account takeover, payment fraud |
| P2 | Medium security issue | 4 hours | Suspicious activity, failed attacks |
| P3 | Low security concern | 24 hours | Minor vulnerabilities |

### Automated Response Actions
```javascript
const incidentResponse = {
  async handleSecurityIncident(incident) {
    switch (incident.severity) {
      case 'critical':
        await this.lockdownSystem();
        await this.notifySecurityTeam();
        await this.alertExecutives();
        break;
        
      case 'high':
        await this.isolateAffectedAccounts();
        await this.increaseMonitoring();
        await this.notifySecurityTeam();
        break;
        
      case 'medium':
        await this.flagForReview();
        await this.logIncident();
        break;
    }
  },
  
  async lockdownSystem() {
    // Temporary system lockdown
    await redis.set('system:lockdown', 'true', 'EX', 3600);
    await this.disableNewRegistrations();
    await this.requireMFAForAllUsers();
  }
};
```

## 🔐 Privacy & Compliance

### GDPR Compliance
```javascript
// Data subject rights implementation
const gdprCompliance = {
  async handleDataSubjectRequest(request) {
    switch (request.type) {
      case 'access':
        return await this.exportUserData(request.userId);
        
      case 'rectification':
        return await this.updateUserData(request.userId, request.updates);
        
      case 'erasure':
        return await this.deleteUserData(request.userId);
        
      case 'portability':
        return await this.exportPortableData(request.userId);
        
      case 'restriction':
        return await this.restrictProcessing(request.userId);
    }
  },
  
  async deleteUserData(userId) {
    // Anonymize rather than delete for audit compliance
    await db.users.update(userId, {
      email: `deleted_${userId}@example.com`,
      firstName: 'DELETED',
      lastName: 'USER',
      phone: null,
      dateOfBirth: null,
      passportNumber: null,
      deletedAt: new Date()
    });
  }
};
```

### Data Retention Policy
```javascript
const retentionPolicy = {
  userProfiles: '7 years after account closure',
  bookingData: '7 years for tax/audit purposes',
  paymentData: '1 year (tokenized references only)',
  auditLogs: '10 years for compliance',
  sessionData: '30 days',
  systemLogs: '2 years'
};
```

## 🔧 Security Testing

### Automated Security Testing
```yaml
# Security testing pipeline
security_tests:
  static_analysis:
    - sonarqube_scan
    - semgrep_analysis
    - dependency_check
    
  dynamic_analysis:
    - owasp_zap_scan
    - api_security_test
    - penetration_test
    
  compliance_check:
    - pci_dss_scan
    - gdpr_compliance_check
    - security_audit
```

### Vulnerability Management
```javascript
const vulnerabilityManagement = {
  scanFrequency: {
    applications: 'daily',
    infrastructure: 'weekly',
    dependencies: 'on every build'
  },
  
  responseTime: {
    critical: '24 hours',
    high: '7 days',
    medium: '30 days',
    low: '90 days'
  }
};
```

This comprehensive security design ensures the Flight Booking System meets the highest security standards while maintaining usability and compliance with industry regulations.