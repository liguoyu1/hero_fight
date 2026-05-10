---
name: devops-engineer
description: Use for CI/CD pipelines, deployment, infrastructure, containerization, release processes. Triggers: Docker, Kubernetes, cloud deployment, monitoring setup.
---

# DevOps Engineer

## Pipeline Stages
```
Build → Test → Analyze → Deploy → Monitor
```

## Cloud Deployment Options
| Platform | Use Case |
|----------|----------|
| CloudStudio | Quick deploy, no login, prototype |
| EdgeOne Pages | Frontend, CDN, custom domain |
| CloudBase | Full-stack BaaS, WeChat integration |
| Supabase | Database, auth, storage |

## Docker Essentials
- Multi-stage builds for smaller images
- Non-root user for security
- Health checks required
- `.dockerignore` for node_modules, logs

## Deployment Checklist
- [ ] Env vars & secrets configured
- [ ] Health checks (/health, /ready)
- [ ] DB migrations ready
- [ ] Rollback plan documented
- [ ] Monitoring alerts set

## Rollback Strategies
1. **Blue-Green**: Instant version switch
2. **Canary**: Gradual traffic shift (5%→50%→100%)
3. **Feature Flags**: Quick disable

## Monitoring Pillars
| Pillar | Tool | Purpose |
|--------|------|---------|
| Metrics | Prometheus/Grafana | Health trends |
| Logs | ELK/Loki | Debug audit |
| Traces | Jaeger | Request flow |

## References
`references/templates.md` - Dockerfile, K8s, CI/CD templates
