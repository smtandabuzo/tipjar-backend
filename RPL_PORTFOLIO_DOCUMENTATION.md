# TipJar Application - Recognition of Prior Learning (RPL) Portfolio Documentation

## Project Overview

**TipJar** is a full-stack digital tipping platform designed to facilitate cashless tipping for service workers in South Africa. The application enables service providers (car guards, waiters, petrol attendendants, etc.) to receive digital payments from customers via QR codes, providing a modern alternative to traditional cash tipping.

### Problem Statement

In South Africa, tipping is a significant part of service workers' income, but cash-based tipping presents several challenges:
- Security risks for workers carrying cash
- Inconvenience for customers who may not carry cash
- Lack of transaction records and accountability
- Difficulty tracking earnings and payment history
- Limited payment options for customers

### Solution

TipJar provides a comprehensive digital solution that:
- Enables cashless tipping through multiple payment methods
- Provides QR code-based provider identification
- Offers real-time earnings tracking and dashboard analytics
- Maintains comprehensive audit trails for all transactions
- Supports bank payment workflows with approval processes
- Delivers a secure, scalable cloud-based infrastructure

## Technical Architecture

### System Components

**1. Backend API (Node.js/Express)**
- RESTful API with comprehensive endpoint coverage
- PostgreSQL database with advanced stored procedures
- File upload handling with Multer middleware
- CORS configuration for cross-origin requests
- Health check endpoints for monitoring
- Comprehensive error handling and logging

**2. Database Design (PostgreSQL)**
- Normalized relational schema with 4 core tables
- Custom ENUM types for type safety
- 15+ stored procedures for business logic
- Database functions for data aggregation
- Triggers for automatic timestamp management
- Comprehensive audit logging system

**3. Frontend Application (React/Vue)**
- Modern single-page application
- QR code generation and scanning
- Real-time dashboard with earnings analytics
- Provider registration and profile management
- Payment initiation and receipt generation
- Responsive design for mobile accessibility

**4. Cloud Infrastructure (AWS)**
- **Elastic Beanstalk**: Backend deployment and scaling
- **RDS PostgreSQL**: Managed database service
- **S3**: File storage for provider photos
- **CloudFront**: CDN with HTTPS termination
- **Amplify**: Frontend hosting and deployment
- **ACM**: SSL certificate management

### Technology Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| Backend | Node.js 24 | Server runtime |
| API Framework | Express.js | REST API development |
| Database | PostgreSQL 15 | Relational data storage |
| ORM | pg (node-postgres) | Database connectivity |
| File Upload | Multer | Multipart form data handling |
| CORS | cors | Cross-origin resource sharing |
| Frontend | React/Vue | User interface |
| Build Tool | Vite | Frontend build system |
| Cloud Platform | AWS | Infrastructure hosting |
| Load Balancer | Elastic Beanstalk | Application scaling |
| CDN | CloudFront | Content delivery and HTTPS |
| Frontend Hosting | Amplify | Static site deployment |

## Database Architecture

### Schema Design

The database demonstrates advanced relational design principles:

**Core Tables:**
- **providers**: Service provider profiles with unique codes
- **tips**: Payment/tip records with status tracking
- **provider_earnings**: Aggregated earnings for analytics
- **payment_log**: Comprehensive audit trail

**Custom Types:**
- `service_type_enum`: Type-safe service categorization
- `payment_method_enum`: Payment method standardization
- `payment_status_enum`: Payment lifecycle management
- `action_type_enum`: Audit action classification

**Advanced Features:**
- Unique provider code generation algorithm
- Automatic timestamp triggers
- Foreign key constraints for data integrity
- Index optimization for query performance
- Transaction management for data consistency

### Stored Procedures

The application implements 15+ stored procedures demonstrating:
- Business logic encapsulation at database level
- Transaction management and error handling
- Complex data aggregation and analytics
- Payment workflow orchestration
- Audit trail maintenance

**Key Procedures:**
- `sp_register_provider`: Provider registration with code generation
- `sp_get_provider_dashboard`: Real-time earnings analytics
- `sp_create_tip`: Payment initiation with reference generation
- `sp_complete_payment`: Payment completion and earnings update
- `sp_get_provider_payment_history`: Historical data retrieval

### Database Functions

Utility functions demonstrating:
- Data transformation and formatting
- Statistical calculations (averages, counts, sums)
- QR code URL generation
- Receipt formatting
- Validation logic

## API Architecture

### RESTful Design Principles

The API follows REST best practices:
- Resource-based URL structure
- Proper HTTP method usage (GET, POST, PUT, DELETE)
- Consistent response formats
- Comprehensive error handling
- Status code standardization

### Endpoint Categories

**Provider Management:**
- `POST /api/providers/register` - Register new provider
- `GET /api/providers/:code` - Retrieve provider by code
- `PUT /api/providers/:id` - Update provider profile
- `GET /api/providers/:id/dashboard` - Get provider statistics
- `GET /api/providers/:id/tips/recent` - Get recent tips

**Payment Operations:**
- `POST /api/tips` - Create new tip/payment
- `POST /api/tips/:id/complete` - Complete payment
- `POST /api/tips/:id/fail` - Mark payment as failed
- `GET /api/tips/:id/receipt` - Get payment receipt

**Bank Payment Workflows:**
- `POST /api/payments/initiate` - Initiate bank payment
- `GET /api/payments/:reference` - Get payment request details
- `POST /api/payments/:reference/approve` - Approve bank payment
- `POST /api/payments/:reference/decline` - Decline bank payment

**File Operations:**
- `POST /api/upload` - Upload provider photo
- `GET /api/uploads/:filename` - Retrieve uploaded file

### Security Implementation

- CORS configuration for cross-origin requests
- Input validation and sanitization
- SQL injection prevention through parameterized queries
- File upload validation (type, size restrictions)
- Environment variable configuration for sensitive data
- HTTPS enforcement via CloudFront

## Cloud Infrastructure & DevOps

### Deployment Architecture

**Backend Deployment (Elastic Beanstalk):**
- Automated deployment via S3 upload
- Environment configuration management
- Health monitoring and auto-scaling
- Post-deployment hooks for database migration
- Rolling updates for zero-downtime deployments

**Database (RDS PostgreSQL):**
- Managed database service with automated backups
- Multi-AZ deployment for high availability
- SSL/TLS encryption for data in transit
- Automated patch management
- Connection pooling optimization

**Frontend (Amplify):**
- Git-based continuous deployment
- Automatic build and deployment pipeline
- Branch-specific preview URLs
- Environment variable management
- Global CDN distribution

**Content Delivery (CloudFront):**
- HTTPS termination and SSL certificate management
- Global edge caching for performance
- Origin protocol policy (HTTP to backend)
- Custom error handling
- Cache optimization for API responses

### Infrastructure as Code

**Elastic Beanstalk Configuration:**
- `.ebextensions/02-env.config` - Environment variables
- `.platform/hooks/postdeploy/04_load_schema.sh` - Database migration
- Automated schema loading and stored procedure deployment

**CI/CD Pipeline:**
- Git-based version control
- Automated testing and deployment
- Environment-specific configurations
- Rollback capabilities

## Development Skills Demonstrated

### Backend Development
- RESTful API design and implementation
- Node.js/Express framework proficiency
- PostgreSQL database design and optimization
- Stored procedure development
- Database function creation
- Transaction management
- Error handling and logging
- File upload handling
- CORS configuration
- Environment variable management

### Database Administration
- Relational database design
- Normalization principles
- Index optimization
- Query performance tuning
- Stored procedure development
- Trigger implementation
- Data integrity constraints
- Audit trail design
- Migration scripting

### Cloud Computing
- AWS service integration (Elastic Beanstalk, RDS, S3, CloudFront, Amplify)
- Infrastructure deployment and management
- Load balancing configuration
- CDN implementation
- SSL certificate management
- Environment configuration
- Health monitoring
- Auto-scaling configuration

### DevOps & Deployment
- CI/CD pipeline implementation
- Automated deployment strategies
- Database migration automation
- Environment management
- Rolling updates
- Zero-downtime deployments
- Post-deployment hooks
- Configuration management

### Security Implementation
- CORS configuration
- Input validation
- SQL injection prevention
- File upload security
- HTTPS enforcement
- Environment variable security
- Data encryption in transit

### Problem-Solving Capabilities
- Mixed content error resolution (HTTPS/HTTP)
- CORS troubleshooting
- Database connection pooling
- API endpoint optimization
- Cloud service integration
- Performance optimization
- Error debugging and resolution

## Project Complexity & Scale

### Technical Complexity
- **Multi-tier architecture**: Frontend, backend, database layers
- **Cloud-native deployment**: Multiple AWS services integration
- **Real-time data processing**: Dashboard analytics and statistics
- **Payment workflows**: Complex payment lifecycle management
- **File handling**: Image upload and storage
- **API security**: CORS, validation, encryption

### Data Volume Handling
- **Scalable database design**: Optimized for growth
- **Efficient queries**: Stored procedures for performance
- **Audit trails**: Comprehensive logging system
- **Data aggregation**: Real-time statistics calculation

### Production Readiness
- **Error handling**: Comprehensive exception management
- **Monitoring**: Health check endpoints
- **Logging**: Application and database logging
- **Backup strategy**: RDS automated backups
- **High availability**: Multi-AZ deployment
- **Security**: Multiple security layers

## Learning Outcomes & Competencies

### Technical Competencies Demonstrated

1. **Full-Stack Development**
   - End-to-end application development
   - Frontend-backend integration
   - Database design and optimization
   - API development and documentation

2. **Cloud Computing**
   - AWS service utilization
   - Infrastructure management
   - Deployment automation
   - Scalability planning

3. **Database Management**
   - Advanced SQL development
   - Stored procedure programming
   - Performance optimization
   - Data integrity management

4. **Software Engineering**
   - RESTful API design
   - Error handling patterns
   - Security implementation
   - Code organization and maintainability

5. **Problem-Solving**
   - Technical debugging
   - Performance optimization
   - Security implementation
   - Integration challenges

### Academic Equivalencies

This project demonstrates competencies equivalent to:

- **Database Systems**: Advanced database design, SQL programming, stored procedures
- **Web Development**: Full-stack web application development
- **Cloud Computing**: AWS services, infrastructure management
- **Software Engineering**: API design, security, deployment
- **Systems Analysis**: Requirements analysis, system design
- **Project Management**: End-to-end project delivery

## Conclusion

The TipJar application represents a comprehensive full-stack project that demonstrates advanced technical skills across multiple domains including backend development, database administration, cloud computing, and DevOps. The project showcases production-ready code, scalable architecture, and real-world problem-solving capabilities that are directly applicable to professional software development roles.

The successful deployment of this application to production AWS infrastructure, with proper security measures, monitoring, and scalability considerations, demonstrates a level of technical competence that aligns with undergraduate and postgraduate computing program outcomes.

---

**Project Duration**: 4 weeks (development and deployment)
**Lines of Code**: ~2,500+ (backend + database)
**Database Objects**: 4 tables, 15+ stored procedures, 7 functions, 4 triggers
**API Endpoints**: 15+ REST endpoints
**Cloud Services**: 6 AWS services integrated
**Deployment Status**: Production-ready and live
