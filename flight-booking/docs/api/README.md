# API Design & Documentation

## 🎯 API Design Principles

1. **RESTful Design**: Following REST architectural constraints
2. **Consistency**: Uniform naming conventions and response formats
3. **Versioning**: API versioning strategy for backward compatibility
4. **Security**: Authentication and authorization on all endpoints
5. **Performance**: Pagination, filtering, and caching support
6. **Documentation**: OpenAPI 3.0 specification for all endpoints

## 🗂️ API Architecture

### Base URL Structure
```
Production: https://api.flightbooking.com/v1
Staging:    https://staging-api.flightbooking.com/v1
Development: http://localhost:8080/v1
```

### Standard Response Format
```json
{
  "success": true,
  "data": {},
  "metadata": {
    "timestamp": "2024-01-15T10:30:00Z",
    "version": "1.0",
    "requestId": "req_123456789"
  },
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 100,
    "totalPages": 5
  }
}
```

### Error Response Format
```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid input parameters",
    "details": [
      {
        "field": "email",
        "message": "Email format is invalid"
      }
    ]
  },
  "metadata": {
    "timestamp": "2024-01-15T10:30:00Z",
    "version": "1.0",
    "requestId": "req_123456789"
  }
}
```

## 🔐 Authentication & Authorization

### Authentication Methods
- **JWT Bearer Tokens**: For user authentication
- **API Keys**: For partner integrations
- **OAuth 2.0**: For third-party applications

### Authorization Header
```
Authorization: Bearer <jwt_token>
X-API-Key: <api_key> (for partner APIs)
```

## 📋 Core API Endpoints

### 1. User Service API

#### Authentication Endpoints

**POST /auth/register**
```json
{
  "email": "user@example.com",
  "password": "SecurePassword123!",
  "firstName": "John",
  "lastName": "Doe",
  "phone": "+1234567890",
  "dateOfBirth": "1990-01-15",
  "nationality": "US"
}
```

**POST /auth/login**
```json
{
  "email": "user@example.com",
  "password": "SecurePassword123!"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "user": {
      "id": "uuid",
      "email": "user@example.com",
      "firstName": "John",
      "lastName": "Doe",
      "roles": ["customer"]
    },
    "tokens": {
      "accessToken": "jwt_access_token",
      "refreshToken": "jwt_refresh_token",
      "expiresIn": 3600
    }
  }
}
```

**POST /auth/refresh**
```json
{
  "refreshToken": "jwt_refresh_token"
}
```

**POST /auth/logout**
```json
{
  "refreshToken": "jwt_refresh_token"
}
```

#### User Management Endpoints

**GET /users/profile**
- Returns current user profile
- Requires: Bearer token

**PUT /users/profile**
```json
{
  "firstName": "John",
  "lastName": "Doe",
  "phone": "+1234567890",
  "preferences": {
    "seatPreference": "window",
    "mealPreference": "vegetarian",
    "currency": "USD",
    "language": "en"
  }
}
```

**POST /users/verify-email**
```json
{
  "token": "verification_token"
}
```

### 2. Flight Service API

#### Flight Search Endpoints

**GET /flights/search**

Query Parameters:
- `origin` (required): Origin airport IATA code
- `destination` (required): Destination airport IATA code
- `departureDate` (required): Departure date (YYYY-MM-DD)
- `returnDate` (optional): Return date for round-trip
- `passengers` (optional): Number of passengers (default: 1)
- `class` (optional): Cabin class (economy, premium_economy, business, first)
- `maxStops` (optional): Maximum number of stops
- `airlines` (optional): Comma-separated airline codes
- `maxPrice` (optional): Maximum price filter
- `sortBy` (optional): price, duration, departure_time, arrival_time
- `page` (optional): Page number (default: 1)
- `limit` (optional): Results per page (default: 20, max: 100)

**Example Request:**
```
GET /flights/search?origin=LAX&destination=JFK&departureDate=2024-03-15&passengers=2&class=economy&sortBy=price
```

**Response:**
```json
{
  "success": true,
  "data": {
    "flights": [
      {
        "id": "flight_instance_uuid",
        "flightNumber": "AA123",
        "airline": {
          "code": "AA",
          "name": "American Airlines",
          "logo": "https://cdn.example.com/aa-logo.png"
        },
        "route": {
          "origin": {
            "code": "LAX",
            "name": "Los Angeles International",
            "city": "Los Angeles",
            "country": "US",
            "timezone": "America/Los_Angeles"
          },
          "destination": {
            "code": "JFK",
            "name": "John F. Kennedy International",
            "city": "New York",
            "country": "US",
            "timezone": "America/New_York"
          }
        },
        "schedule": {
          "departure": "2024-03-15T08:00:00-08:00",
          "arrival": "2024-03-15T16:30:00-05:00",
          "duration": "5h 30m"
        },
        "aircraft": {
          "type": "Boeing 737-800",
          "configuration": "3-3"
        },
        "availability": {
          "economy": {
            "available": 45,
            "price": {
              "amount": 299.99,
              "currency": "USD"
            }
          },
          "business": {
            "available": 8,
            "price": {
              "amount": 899.99,
              "currency": "USD"
            }
          }
        },
        "amenities": ["wifi", "power_outlets", "entertainment"],
        "baggage": {
          "carry_on": "1 piece included",
          "checked": "First bag $30"
        }
      }
    ]
  },
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 156,
    "totalPages": 8
  }
}
```

**GET /flights/{flightInstanceId}**
- Returns detailed flight information
- Includes real-time status, gate info, delays

**GET /flights/{flightInstanceId}/seats**
- Returns available seats with layout
- Query parameters: `class` (optional)

#### Airport & Route Information

**GET /airports**
- Search airports by city, name, or code
- Query parameters: `search`, `country`, `limit`

**GET /airports/{code}**
- Get specific airport details

**GET /airlines**
- List all airlines
- Query parameters: `country`, `active`

### 3. Booking Service API

#### Booking Management

**POST /bookings**
```json
{
  "flights": [
    {
      "flightInstanceId": "uuid",
      "class": "economy",
      "passengers": [
        {
          "type": "adult",
          "title": "Mr",
          "firstName": "John",
          "lastName": "Doe",
          "dateOfBirth": "1990-01-15",
          "gender": "male",
          "nationality": "US",
          "passport": {
            "number": "123456789",
            "expiryDate": "2030-01-15",
            "country": "US"
          },
          "seatPreference": "window",
          "mealPreference": "standard",
          "frequentFlyerNumber": "AA123456789"
        }
      ]
    }
  ],
  "contact": {
    "email": "john.doe@example.com",
    "phone": "+1234567890"
  },
  "specialRequests": "Wheelchair assistance required"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "booking": {
      "id": "uuid",
      "reference": "ABC123",
      "status": "pending",
      "expiresAt": "2024-01-15T11:00:00Z",
      "totalAmount": {
        "amount": 599.98,
        "currency": "USD"
      },
      "segments": [
        {
          "id": "uuid",
          "flightNumber": "AA123",
          "route": {
            "origin": "LAX",
            "destination": "JFK"
          },
          "schedule": {
            "departure": "2024-03-15T08:00:00-08:00",
            "arrival": "2024-03-15T16:30:00-05:00"
          },
          "passengers": [
            {
              "id": "uuid",
              "name": "John Doe",
              "seat": "12A",
              "boardingPass": {
                "issued": false,
                "gate": null,
                "boardingGroup": "B"
              }
            }
          ]
        }
      ]
    }
  }
}
```

**GET /bookings**
- List user's bookings
- Query parameters: `status`, `dateFrom`, `dateTo`, `page`, `limit`

**GET /bookings/{bookingId}**
- Get specific booking details

**PUT /bookings/{bookingId}**
- Modify booking (subject to airline policies)
- Supports passenger details updates, seat changes

**DELETE /bookings/{bookingId}**
- Cancel booking
- Returns refund information

#### Seat Management

**GET /bookings/{bookingId}/seats**
- Get current seat assignments

**PUT /bookings/{bookingId}/seats**
```json
{
  "seatAssignments": [
    {
      "passengerId": "uuid",
      "segmentId": "uuid",
      "seatNumber": "14F"
    }
  ]
}
```

#### Check-in

**POST /bookings/{bookingId}/checkin**
```json
{
  "passengerIds": ["uuid1", "uuid2"]
}
```

**GET /bookings/{bookingId}/boarding-passes**
- Download boarding passes (PDF)

### 4. Payment Service API

#### Payment Processing

**POST /payments**
```json
{
  "bookingId": "uuid",
  "amount": {
    "amount": 599.98,
    "currency": "USD"
  },
  "paymentMethod": {
    "type": "credit_card",
    "card": {
      "number": "4111111111111111",
      "expiryMonth": 12,
      "expiryYear": 2025,
      "cvv": "123",
      "holderName": "John Doe"
    },
    "billingAddress": {
      "street": "123 Main St",
      "city": "Los Angeles",
      "state": "CA",
      "postalCode": "90210",
      "country": "US"
    }
  }
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "transaction": {
      "id": "uuid",
      "status": "completed",
      "amount": {
        "amount": 599.98,
        "currency": "USD"
      },
      "paymentMethod": "•••• 1111",
      "receipt": {
        "id": "receipt_123",
        "url": "https://receipts.example.com/receipt_123.pdf"
      }
    }
  }
}
```

**GET /payments/{transactionId}**
- Get transaction details

**POST /payments/{transactionId}/refund**
```json
{
  "amount": 599.98,
  "reason": "cancellation"
}
```

#### Saved Payment Methods

**GET /payment-methods**
- List user's saved payment methods

**POST /payment-methods**
- Save new payment method

**DELETE /payment-methods/{methodId}**
- Remove saved payment method

### 5. Notification Service API

#### Notification Management

**GET /notifications**
- Get user notifications
- Query parameters: `type`, `read`, `page`, `limit`

**PUT /notifications/{notificationId}/read**
- Mark notification as read

**POST /notifications/preferences**
```json
{
  "email": {
    "bookingConfirmation": true,
    "flightUpdates": true,
    "promotions": false
  },
  "sms": {
    "flightUpdates": true,
    "checkInReminder": true
  },
  "push": {
    "flightUpdates": true,
    "gateChanges": true
  }
}
```

## 📊 API Rate Limiting

### Rate Limits by Endpoint Category

| Category | Requests per Minute | Burst Limit |
|----------|-------------------|-------------|
| Authentication | 10 | 20 |
| Flight Search | 60 | 100 |
| Booking Operations | 30 | 50 |
| Payment Processing | 10 | 15 |
| User Profile | 30 | 50 |

### Rate Limit Headers
```
X-RateLimit-Limit: 60
X-RateLimit-Remaining: 45
X-RateLimit-Reset: 1640995200
```

## 🔍 API Filtering & Pagination

### Standard Query Parameters
- `page`: Page number (default: 1)
- `limit`: Items per page (default: 20, max: 100)
- `sort`: Sort field and direction (`field:asc` or `field:desc`)
- `filter`: JSON filter object

### Example Filtering
```
GET /bookings?filter={"status":"confirmed","dateFrom":"2024-01-01"}&sort=createdAt:desc&page=1&limit=25
```

## 📝 Error Handling

### HTTP Status Codes
- `200` - Success
- `201` - Created
- `400` - Bad Request
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Not Found
- `409` - Conflict
- `422` - Validation Error
- `429` - Rate Limited
- `500` - Internal Server Error
- `503` - Service Unavailable

### Error Codes
```javascript
const ERROR_CODES = {
  // Authentication
  INVALID_CREDENTIALS: 'INVALID_CREDENTIALS',
  TOKEN_EXPIRED: 'TOKEN_EXPIRED',
  ACCOUNT_LOCKED: 'ACCOUNT_LOCKED',
  
  // Validation
  VALIDATION_ERROR: 'VALIDATION_ERROR',
  MISSING_REQUIRED_FIELD: 'MISSING_REQUIRED_FIELD',
  INVALID_FORMAT: 'INVALID_FORMAT',
  
  // Business Logic
  FLIGHT_NOT_AVAILABLE: 'FLIGHT_NOT_AVAILABLE',
  INSUFFICIENT_SEATS: 'INSUFFICIENT_SEATS',
  BOOKING_EXPIRED: 'BOOKING_EXPIRED',
  PAYMENT_FAILED: 'PAYMENT_FAILED',
  
  // System
  SERVICE_UNAVAILABLE: 'SERVICE_UNAVAILABLE',
  RATE_LIMIT_EXCEEDED: 'RATE_LIMIT_EXCEEDED'
};
```

## 🔧 API Versioning Strategy

### URL Versioning
```
/v1/flights/search  (Current)
/v2/flights/search  (Future)
```

### Header Versioning (Alternative)
```
Accept: application/vnd.flightbooking.v1+json
```

### Deprecation Process
1. Announce deprecation 6 months in advance
2. Add deprecation warnings in response headers
3. Maintain backward compatibility for 12 months
4. Provide migration guides and tools

## 📋 OpenAPI Specification

The complete OpenAPI 3.0 specification is available at:
- **Development**: http://localhost:8080/docs
- **Staging**: https://staging-api.flightbooking.com/docs
- **Production**: https://api.flightbooking.com/docs

### Swagger UI Features
- Interactive API documentation
- Request/response examples
- Authentication testing
- Code generation samples
- Export capabilities (JSON, YAML)

This API design provides a comprehensive, RESTful interface for the Flight Booking System with proper authentication, error handling, and documentation to ensure ease of integration and maintenance.