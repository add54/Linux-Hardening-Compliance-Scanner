# 🚀 Kubernetes Deployment Guide

Complete guide for deploying the Linux Hardening & Compliance Scanner on Kubernetes clusters.

## 📋 Prerequisites

### Required Tools
- **kubectl** - Kubernetes CLI (v1.24+)
- **Helm** - Package manager (v3.8+) _optional but recommended_
- **Docker** - For local development

### Cluster Requirements
- **Kubernetes** v1.24+
- **Storage Class** for persistent volumes
- **Ingress Controller** (NGINX recommended)
- **Cert-Manager** for SSL certificates _optional_

### Network Requirements
- **Domain name** for ingress (e.g., `scanner.yourdomain.com`)
- **SSL certificate** (Let's Encrypt via Cert-Manager recommended)
- **Load balancer** (cloud provider or MetalLB)

---

## 🏗️ Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Ingress       │    │   Services      │    │   Deployments   │
│   (External)    │◄──►│   (Internal)    │◄──►│   (Pods)        │
│                 │    │                 │    │                 │
│ • scanner.com   │    │ • webapp:80     │    │ • webapp (2)    │
│ • api.scanner.com│    │ • api:80        │    │ • scanner (1)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  ConfigMaps     │    │   Secrets       │    │  Persistent     │
│                 │    │                 │    │  Volumes        │
│ • app config    │    │ • db keys       │    │ • data (10GB)   │
│ • scanner opts  │    │ • jwt secrets   │    │ • logs (5GB)    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Components
- **Web Application**: Flask app with REST API
- **Scanner Worker**: Background security scanning
- **Scheduled Jobs**: CronJobs for automated scans
- **Storage**: Persistent volumes for data/logs
- **Ingress**: External access with SSL termination

---

## 🚀 Quick Start Deployment

### Method 1: Helm (Recommended)

```bash
# Add Helm repository (if hosted)
helm repo add linux-scanner https://charts.yourdomain.com
helm repo update

# Install with default values
helm install linux-scanner ./helm/linux-scanner

# Or with custom values
helm install linux-scanner ./helm/linux-scanner \
  --set global.domain=scanner.yourdomain.com \
  --set webapp.replicaCount=3 \
  --create-namespace
```

### Method 2: kubectl Manifests

```bash
# Create namespace
kubectl apply -f k8s/namespace.yaml

# Deploy storage
kubectl apply -f k8s/pvc.yaml

# Deploy configuration
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secret.yaml

# Deploy applications
kubectl apply -f k8s/deployment-webapp.yaml
kubectl apply -f k8s/deployment-scanner.yaml

# Deploy networking
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/ingress.yaml

# Deploy scheduled jobs
kubectl apply -f k8s/cronjob.yaml

# Deploy autoscaling
kubectl apply -f k8s/hpa.yaml
```

### Method 3: One-Command Deploy

```bash
# Deploy everything at once
kubectl apply -f k8s/

# Or with kustomization
kubectl apply -k k8s/
```

---

## ⚙️ Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `FLASK_ENV` | `production` | Flask environment |
| `SCANNER_TIMEOUT` | `1800` | Scan timeout (seconds) |
| `LOG_LEVEL` | `INFO` | Logging level |
| `SECRET_KEY` | _required_ | Flask secret key |
| `DATABASE_KEY` | _required_ | Database encryption key |

### Custom Configuration

```bash
# Via Helm
helm upgrade linux-scanner ./helm/linux-scanner \
  --set webapp.env.FLASK_DEBUG=true \
  --set webapp.replicaCount=3 \
  --set ingress.hosts[0].host=scanner.yourcompany.com

# Via kubectl
kubectl set env deployment/scanner-webapp FLASK_DEBUG=true
```

### Secrets Management

```bash
# Update secrets
kubectl create secret generic scanner-secrets \
  --from-literal=SECRET_KEY=your-new-secret-key \
  --from-literal=DATABASE_KEY=your-db-key \
  --dry-run=client -o yaml | kubectl apply -f -

# Or edit existing secret
kubectl edit secret scanner-secrets
```

---

## 🔍 Monitoring & Troubleshooting

### Check Pod Status
```bash
# All pods in namespace
kubectl get pods -n linux-scanner

# Pod details
kubectl describe pod scanner-webapp-12345 -n linux-scanner

# Pod logs
kubectl logs scanner-webapp-12345 -n linux-scanner

# Follow logs
kubectl logs -f scanner-webapp-12345 -n linux-scanner
```

### Check Services
```bash
# Service status
kubectl get services -n linux-scanner

# Service endpoints
kubectl get endpoints -n linux-scanner
```

### Check Ingress
```bash
# Ingress status
kubectl get ingress -n linux-scanner

# Ingress details
kubectl describe ingress scanner-ingress -n linux-scanner
```

### Debug Commands
```bash
# Exec into pod
kubectl exec -it scanner-webapp-12345 -n linux-scanner -- /bin/bash

# Check pod events
kubectl get events -n linux-scanner --sort-by=.metadata.creationTimestamp

# Check resource usage
kubectl top pods -n linux-scanner
```

---

## 🔄 Scaling & Updates

### Horizontal Scaling
```bash
# Scale webapp deployment
kubectl scale deployment scanner-webapp -n linux-scanner --replicas=5

# Via Helm
helm upgrade linux-scanner ./helm/linux-scanner --set webapp.replicaCount=5
```

### Rolling Updates
```bash
# Update image
kubectl set image deployment/scanner-webapp webapp=ghcr.io/add54/linux-hardening-compliance-scanner:v1.1.0 -n linux-scanner

# Check rollout status
kubectl rollout status deployment/scanner-webapp -n linux-scanner

# Rollback if needed
kubectl rollout undo deployment/scanner-webapp -n linux-scanner
```

### Autoscaling
```bash
# Check HPA status
kubectl get hpa -n linux-scanner

# HPA details
kubectl describe hpa scanner-webapp-hpa -n linux-scanner
```

---

## 🔐 Security Best Practices

### Network Security
```yaml
# NetworkPolicy example
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: scanner-secure
spec:
  podSelector:
    matchLabels:
      app: linux-hardening-compliance-scanner
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 5000
```

### Pod Security
```yaml
# Security context
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000
  privileged: false  # Only for scanner pods
```

### Secrets Rotation
```bash
# Rotate secrets
kubectl delete secret scanner-secrets -n linux-scanner
kubectl apply -f k8s/secret.yaml
kubectl rollout restart deployment scanner-webapp -n linux-scanner
```

---

## 📊 Scheduled Scans

### View CronJobs
```bash
# List cronjobs
kubectl get cronjobs -n linux-scanner

# Check job history
kubectl get jobs -n linux-scanner

# View cronjob logs
kubectl logs job/scanner-scheduled-scan-12345 -n linux-scanner
```

### Manual Scan Execution
```bash
# Run immediate scan
kubectl create job manual-scan --from=cronjob/scanner-scheduled-scan -n linux-scanner

# Check results
kubectl logs job/manual-scan -n linux-scanner
```

---

## 🔄 Backup & Recovery

### Database Backup
```bash
# Backup SQLite database
kubectl exec scanner-webapp-12345 -n linux-scanner -- sqlite3 /app/data/scanner.db ".backup /tmp/backup.db"
kubectl cp linux-scanner/scanner-webapp-12345:/tmp/backup.db ./scanner-backup.db
```

### Configuration Backup
```bash
# Backup all resources
kubectl get all -n linux-scanner -o yaml > backup.yaml

# Backup persistent volumes
kubectl get pvc -n linux-scanner -o yaml > pvc-backup.yaml
```

### Disaster Recovery
```bash
# Restore from backup
kubectl apply -f backup.yaml

# Restore PVC data (varies by storage provider)
# For example, with hostPath volumes:
kubectl cp ./scanner-backup.db linux-scanner/scanner-webapp-12345:/app/data/scanner.db
```

---

## 🌐 Production Deployment

### Prerequisites
```bash
# Install NGINX Ingress Controller
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install nginx-ingress ingress-nginx/ingress-nginx

# Install Cert-Manager for SSL
helm repo add jetstack https://charts.jetstack.io
helm install cert-manager jetstack/cert-manager --set installCRDs=true

# Create ClusterIssuer for Let's Encrypt
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@yourdomain.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
```

### Production Helm Install
```bash
# Production deployment with SSL
helm install linux-scanner ./helm/linux-scanner \
  --set global.domain=scanner.yourcompany.com \
  --set ingress.tls[0].hosts[0]=scanner.yourcompany.com \
  --set cert-manager.enabled=true \
  --set webapp.replicaCount=3 \
  --set persistence.data.size=50Gi \
  --create-namespace
```

---

## 📚 Learning Resources

### Kubernetes Concepts Covered
- ✅ **Pods & Containers**: Application deployment
- ✅ **Deployments**: Rolling updates and scaling
- ✅ **Services**: Internal networking
- ✅ **Ingress**: External access and SSL
- ✅ **ConfigMaps & Secrets**: Configuration management
- ✅ **Persistent Volumes**: Data persistence
- ✅ **CronJobs**: Scheduled tasks
- ✅ **HorizontalPodAutoscaler**: Auto-scaling
- ✅ **NetworkPolicies**: Security policies
- ✅ **Helm Charts**: Package management

### Recommended Learning Path
1. **Kubernetes Basics**: Pods, Services, Deployments
2. **Storage**: Persistent Volumes and Claims
3. **Networking**: Services and Ingress
4. **Security**: NetworkPolicies, Secrets, RBAC
5. **Automation**: Helm, Operators, CI/CD
6. **Monitoring**: Logging, Metrics, Health Checks

### Useful Commands
```bash
# Cluster info
kubectl cluster-info

# Node status
kubectl get nodes

# All resources
kubectl get all -n linux-scanner

# Resource usage
kubectl top nodes
kubectl top pods -n linux-scanner

# API resources
kubectl api-resources

# Explain resources
kubectl explain deployment
kubectl explain ingress
```

---

## 🆘 Common Issues & Solutions

### Pod CrashLoopBackOff
```bash
# Check pod logs
kubectl logs scanner-webapp-12345 -n linux-scanner

# Check events
kubectl get events -n linux-scanner

# Describe pod
kubectl describe pod scanner-webapp-12345 -n linux-scanner
```

### Service Not Accessible
```bash
# Check service endpoints
kubectl get endpoints -n linux-scanner

# Test service connectivity
kubectl run test --image=busybox --rm -it -- wget scanner-webapp-service:80
```

### Ingress Not Working
```bash
# Check ingress controller
kubectl get pods -n ingress-nginx

# Check ingress status
kubectl describe ingress scanner-ingress -n linux-scanner
```

### Storage Issues
```bash
# Check PVC status
kubectl get pvc -n linux-scanner

# Check PV status
kubectl get pv

# Describe PVC
kubectl describe pvc scanner-data-pvc -n linux-scanner
```

---

**🎊 Congratulations! You've successfully deployed a production-ready application on Kubernetes!**

**The Linux Hardening & Compliance Scanner is now running in a scalable, secure, and maintainable Kubernetes environment.**

**Next steps:**
- Configure monitoring (Prometheus/Grafana)
- Set up log aggregation (ELK stack)
- Implement CI/CD for Kubernetes deployments
- Add security scanning (Falco, OPA Gatekeeper)

**Happy Kuberneting! 🚢⚓**
