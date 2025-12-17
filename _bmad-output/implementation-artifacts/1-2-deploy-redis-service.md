# Story 1.2: Deploy Redis Service

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a developer,  
I want to deploy Redis in the local K8s cluster,  
so that I can test the Informer service's state synchronization functionality.

## Acceptance Criteria

1. Redis deployment is created and running
2. Redis service is accessible from other pods
3. Redis can be accessed via `redis-cli` for testing
4. Redis data persistence is configured (optional for testing)

## Tasks / Subtasks

- [ ] Task 1: Create Redis Deployment (AC: 1)
  - [ ] Review existing `manifests/redis/redis-deployment.yaml`
  - [ ] Verify Redis deployment configuration (image, resources, probes)
  - [ ] Apply Redis deployment: `kubectl apply -f manifests/redis/redis-deployment.yaml`
  - [ ] Verify deployment created: `kubectl get deployment -n redis`
  - [ ] Wait for pod to be ready: `kubectl wait --for=condition=Ready pod -l app=redis -n redis --timeout=120s`
  - [ ] Verify pod status: `kubectl get pods -n redis` (should show Running)

- [ ] Task 2: Verify Redis Service Accessibility (AC: 2)
  - [ ] Verify Redis service exists: `kubectl get svc -n redis`
  - [ ] Check service endpoints: `kubectl get endpoints -n redis redis`
  - [ ] Test connectivity from test pod: `kubectl run redis-test --image=redis:7-alpine --rm -it --restart=Never -- redis-cli -h redis.redis.svc.cluster.local ping`
  - [ ] Verify service DNS resolution works within cluster

- [ ] Task 3: Test Redis CLI Access (AC: 3)
  - [ ] Port-forward Redis service: `kubectl port-forward -n redis svc/redis 6379:6379 &`
  - [ ] Test local redis-cli connection: `redis-cli -h localhost -p 6379 ping` (should return PONG)
  - [ ] Test basic operations: SET/GET keys
  - [ ] Clean up port-forward process

- [ ] Task 4: Verify Data Persistence (AC: 4, optional)
  - [ ] Verify AOF (Append Only File) is enabled in deployment
  - [ ] Test data persistence by writing data, restarting pod, and verifying data still exists
  - [ ] Check volume mounts if persistence volume is configured

## Dev Notes

### Epic Context

**Epic 1: Local K8s Environment Setup**
- **Objective:** Set up a local Kubernetes environment on macOS for Volcano workflow validation and development
- **Business Value:** Enable local development and testing of Volcano workflows and K8s resource synchronization services without requiring a remote cluster

This story builds on Story 1.1 (Docker Desktop Kubernetes enabled) and establishes Redis as the state storage backend for the Informer service that will be developed in Epic 2. Success here enables:
- Story 1.3: Install and Verify Volcano
- Story 1.4: Volcano Workflow Smoke Test
- Epic 2: K8s Resource State Synchronization Service (depends on Redis)

### Technical Requirements

**Prerequisites:**
- Story 1.1 completed: Docker Desktop Kubernetes enabled and running
- kubectl configured and connected to local cluster
- Redis deployment YAML exists at `manifests/redis/redis-deployment.yaml`

**Redis Deployment Configuration:**
- **Image:** `redis:7-alpine` (lightweight, production-ready)
- **Namespace:** `redis` (dedicated namespace for Redis)
- **Replicas:** 1 (single instance for local development)
- **Port:** 6379 (standard Redis port)
- **Persistence:** AOF (Append Only File) enabled via `--appendonly yes`
- **Resource Limits:**
  - Requests: CPU 100m, Memory 128Mi
  - Limits: CPU 500m, Memory 256Mi

**Service Configuration:**
- **Type:** ClusterIP (internal cluster access)
- **Port:** 6379
- **Service Name:** `redis.redis.svc.cluster.local` (FQDN for DNS resolution)
- **Optional:** NodePort service available for external access (port 30379)

**Health Checks:**
- **Liveness Probe:** TCP socket check on port 6379, initial delay 30s, period 10s
- **Readiness Probe:** TCP socket check on port 6379, initial delay 5s, period 5s

**Verification Commands:**
- Deployment status: `kubectl get deployment -n redis`
- Pod status: `kubectl get pods -n redis`
- Service status: `kubectl get svc -n redis`
- Pod logs: `kubectl logs -l app=redis -n redis`
- Describe pod: `kubectl describe pod -l app=redis -n redis`

### Project Structure Notes

**Current Project Structure:**
```
volcano-workflow/
├── docs/                    # Documentation
├── manifests/              # K8s resource definitions
│   ├── redis/             # Redis deployment files
│   │   ├── redis-deployment.yaml  # Main deployment file
│   │   └── fix-redis-network.sh   # Helper script for troubleshooting
│   ├── volcano/            # Volcano installation configs
│   └── queues/             # Queue definitions
├── examples/               # Example YAML files
├── scripts/                # Utility scripts
└── _bmad-output/           # BMAD workflow artifacts
    └── implementation-artifacts/  # Story files location
```

**File Locations:**
- Redis deployment: `manifests/redis/redis-deployment.yaml`
- Helper script: `manifests/redis/fix-redis-network.sh`
- Story file: `_bmad-output/implementation-artifacts/1-2-deploy-redis-service.md`

**No code changes required** - This story uses existing deployment files. If Redis is already deployed, this story serves as verification and documentation.

### Architecture Compliance

**Kubernetes Best Practices:**
- Use dedicated namespace (`redis`) for isolation
- Configure resource requests and limits for resource management
- Use health probes (liveness/readiness) for reliability
- Enable AOF persistence for data durability
- Use ClusterIP service for internal cluster communication

**Deployment Pattern:**
- Standard Kubernetes Deployment (not StatefulSet) - sufficient for single-instance local development
- Service discovery via DNS: `redis.redis.svc.cluster.local`
- Port-forwarding for local testing access

**Security Considerations:**
- No authentication configured (acceptable for local development)
- ClusterIP service restricts access to cluster-internal only
- Consider adding password protection for production deployments

### Testing Requirements

**Manual Verification:**
- All acceptance criteria can be verified via kubectl commands
- Test pod connectivity validates service accessibility
- redis-cli tests validate basic Redis functionality

**Verification Checklist:**
- [ ] Redis deployment created and running
- [ ] Redis pod in Running state
- [ ] Redis service accessible via DNS
- [ ] Test pod can connect to Redis
- [ ] redis-cli can connect via port-forward
- [ ] Basic Redis operations work (SET/GET)
- [ ] AOF persistence enabled (optional verification)

**Troubleshooting:**
- If pod fails to start, check logs: `kubectl logs -l app=redis -n redis`
- If service not accessible, verify endpoints: `kubectl get endpoints -n redis redis`
- If image pull fails, use helper script: `manifests/redis/fix-redis-network.sh`
- Check pod events: `kubectl describe pod -l app=redis -n redis`

### References

- [Source: _bmad-output/epics.md#Epic-1] - Epic 1: Local K8s Environment Setup
- [Source: _bmad-output/epics.md#Story-1.2] - Story 1.2: Deploy Redis Service
- [Source: manifests/redis/redis-deployment.yaml] - Redis deployment configuration
- [Source: manifests/redis/fix-redis-network.sh] - Redis deployment helper script
- [Source: docs/01-concepts.md#Kubernetes-基础概念] - Kubernetes core concepts
- Redis Documentation: https://redis.io/docs/

### Previous Story Intelligence

**Story 1.1: Enable Docker Desktop Kubernetes**
- **Completed:** All acceptance criteria verified and passed
- **Environment:** Kubernetes v1.31.1 running on Docker Desktop
- **Key Learnings:**
  - Cluster is ready and accepting workloads
  - kubectl commands work correctly
  - System pods are healthy
  - Test pod creation works successfully
- **Relevant Context:**
  - Cluster is stable and ready for Redis deployment
  - No special configuration needed beyond standard kubectl commands
  - All verification commands from Story 1.1 are still valid

**Files Created/Modified in Story 1.1:**
- Story file: `_bmad-output/implementation-artifacts/1-1-enable-docker-desktop-kubernetes.md`
- No code changes (environment setup only)

### Git Intelligence

**No relevant commits** - Redis deployment files already exist in repository. This story focuses on deployment and verification rather than code creation.

### Latest Tech Information

**Redis 7-alpine:**
- Latest stable Redis version 7.x
- Alpine Linux base image (lightweight, ~30MB)
- Production-ready with AOF persistence support
- Compatible with all Redis clients and tools

**Kubernetes Service Discovery:**
- DNS-based service discovery: `<service-name>.<namespace>.svc.cluster.local`
- ClusterIP services are accessible only within cluster
- Port-forwarding enables localhost access for testing
- Service endpoints automatically update when pods change

**Redis Persistence:**
- AOF (Append Only File) logs every write operation
- More durable than RDB snapshots for development
- Can be disabled for testing if performance is priority
- Data stored in pod's filesystem (ephemeral unless PVC configured)

## Dev Agent Record

### Agent Model Used

Claude Sonnet 4.5

### Debug Log References

### Completion Notes List

### File List

