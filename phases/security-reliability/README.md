# Phase 7: Security & Reliability (JWT, Kong Plugins, CI Security, SLO/Alerts, WAF)

Phase 7 focuses on **security hardening** and **reliability engineering (SRE)**: improving authentication (JWT), Kong security plugins, CI/CD security, SLO-based alerting, and Web Application Firewall (WAF).

## Goals

- **JWT Hardening**: Secure authentication with JWT tokens (RS256 or HS256), token refresh, expiration handling.
- **Kong Security Plugins**: Rate limiting, IP restriction, request validation, CORS, bot detection.
- **CI/CD Security**: GitHub Actions security (secrets scanning, dependency scanning, SAST), Docker image scanning.
- **SRE/SLO**: Define Service Level Objectives (SLO) and error budgets; create Prometheus alerts based on SLO.
- **WAF**: Web Application Firewall design – detect/block malicious requests (SQL injection, XSS, etc.).

## Directory Structure

```text
security-reliability/
├── README.md                   # This file – Phase 7 overview
├── auth-hardening/
│   └── JWT-DESIGN.md           # JWT token design (RS256/HS256, refresh token, expiration)
├── kong-security/
│   └── KONG-PLUGINS.md         # Kong security plugins (rate limit, IP allow/deny, request validator, CORS, bot detection)
├── ci-security/
│   └── GHA-SECURITY.md         # GitHub Actions security (Dependabot, CodeQL, secret scanning, image scanning)
├── sre/
│   └── SLO-ALERTING.md         # SLO definition, error budgets, Prometheus alerts (based on Phase 3)
└── waf/
    └── WAF-DESIGN.md           # WAF design (ModSecurity, Kong plugins, request filtering)
```

## Implementation Roadmap (suggested)

1. **JWT Hardening** – read `auth-hardening/JWT-DESIGN.md`. Implement RS256 JWT with refresh tokens; update auth-service to issue/verify JWT; frontend stores token and sends in Authorization header.
2. **Kong Security Plugins** – read `kong-security/KONG-PLUGINS.md`. Add Kong plugins: rate-limiting (per IP/user), IP restriction (allow/deny list), request-validator (check headers/body), CORS, bot-detection.
3. **CI/CD Security** – read `ci-security/GHA-SECURITY.md`. Enable GitHub Dependabot, CodeQL (SAST), secret scanning in repo; add Docker image scanning (Trivy/Snyk) in CI pipeline.
4. **SRE/SLO** – read `sre/SLO-ALERTING.md`. Define SLO (e.g. 99.9% availability, <500ms latency); create Prometheus alerts when SLO is breached; set up on-call rotation.
5. **WAF** – read `waf/WAF-DESIGN.md`. Deploy ModSecurity WAF or use Kong request-validator plugin to detect/block SQL injection, XSS, etc.

## Prerequisites

- **Phase 2** Helm chart banking-demo is running (namespace `banking`).
- **Phase 3** monitoring (Prometheus + Grafana) installed for SLO metrics.
- **Phase 5** (optional) if using Kong in separate namespace with dedicated DB.

## Key Concepts

- **JWT (JSON Web Token)**: Standard for securely transmitting information between parties. RS256 uses public/private key pair for signing; HS256 uses shared secret.
- **Kong Plugins**: Kong API Gateway supports 50+ plugins for security, traffic control, logging, transformations.
- **SAST (Static Application Security Testing)**: Analyze source code for vulnerabilities before runtime (e.g. CodeQL).
- **SLO (Service Level Objective)**: Target for service performance (e.g. 99.9% uptime); basis for error budgets and alerts.
- **WAF (Web Application Firewall)**: Monitors and filters HTTP traffic to web applications, protecting against attacks like SQL injection, XSS.

## Related Phases

- **Phase 2**: `phases/helm-chart/banking-demo` – deployed app that will be secured in Phase 7.
- **Phase 3**: `phases/monitoring-keda` – Prometheus metrics used for SLO alerts.
- **Phase 9**: `phases/gitops-platform` – CI/CD pipeline (Jenkins) that can integrate Phase 7 security scans.
