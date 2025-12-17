# Story 1.1: Enable Docker Desktop Kubernetes

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a developer,  
I want to enable Kubernetes in Docker Desktop,  
so that I can run a local K8s cluster for testing.

## Acceptance Criteria

1. Docker Desktop Kubernetes is enabled and running
2. `kubectl` can connect to the local cluster
3. All system pods are in Running state
4. Cluster is ready to accept workloads

## Tasks / Subtasks

- [ ] Task 1: Enable Kubernetes in Docker Desktop (AC: 1)
  - [ ] Open Docker Desktop application
  - [ ] Navigate to Settings → Kubernetes
  - [ ] Enable Kubernetes checkbox
  - [ ] Wait for Kubernetes to start (typically 2-3 minutes)
  - [ ] Verify Kubernetes is running (green indicator)

- [ ] Task 2: Verify kubectl connectivity (AC: 2)
  - [ ] Check kubectl is installed: `kubectl version --client`
  - [ ] Verify kubectl context points to Docker Desktop: `kubectl config current-context`
  - [ ] Test cluster connection: `kubectl cluster-info`
  - [ ] Verify cluster access: `kubectl get nodes`

- [ ] Task 3: Verify system pods status (AC: 3)
  - [ ] Check all namespaces: `kubectl get pods --all-namespaces`
  - [ ] Verify kube-system pods are Running: `kubectl get pods -n kube-system`
  - [ ] Check for any Pending or Error pods
  - [ ] Verify core services (kube-dns, kube-proxy) are running

- [ ] Task 4: Verify cluster readiness (AC: 4)
  - [ ] Check node status: `kubectl get nodes` (should show Ready)
  - [ ] Verify node resources: `kubectl describe node`
  - [ ] Test pod creation: `kubectl run test-pod --image=busybox --rm -it --restart=Never -- echo "Hello"`
  - [ ] Clean up test pod if needed

## Dev Notes

### Epic Context

**Epic 1: Local K8s Environment Setup**
- **Objective:** Set up a local Kubernetes environment on macOS for Volcano workflow validation and development
- **Business Value:** Enable local development and testing of Volcano workflows and K8s resource synchronization services without requiring a remote cluster

This is the first story in Epic 1, establishing the foundation for all subsequent local development work. Success here enables:
- Story 1.2: Deploy Redis Service
- Story 1.3: Install and Verify Volcano
- Story 1.4: Volcano Workflow Smoke Test

### Technical Requirements

**Prerequisites:**
- Docker Desktop installed on macOS (MBP Pro)
- Docker Desktop version that supports Kubernetes (typically 4.0+)
- Sufficient system resources (recommended: 4GB+ RAM allocated to Docker)

**Kubernetes Version Requirements:**
- Kubernetes version 1.20+ required (Docker Desktop typically provides latest stable)
- Verify with: `kubectl version`

**Verification Commands:**
- Cluster info: `kubectl cluster-info`
- Node status: `kubectl get nodes`
- System pods: `kubectl get pods --all-namespaces`
- Cluster version: `kubectl version`

### Project Structure Notes

**Current Project Structure:**
```
volcano-workflow/
├── docs/                    # Documentation
├── manifests/              # K8s resource definitions
│   ├── volcano/            # Volcano installation configs
│   └── queues/             # Queue definitions
├── examples/               # Example YAML files
├── scripts/                # Utility scripts
└── _bmad-output/           # BMAD workflow artifacts
    └── implementation-artifacts/  # Story files location
```

**No code changes required** - This story is about environment setup, not code implementation.

**Documentation Updates:**
- Consider adding a note to `README.md` or `QUICKSTART.md` about Docker Desktop Kubernetes requirement
- Update any setup documentation to include Docker Desktop Kubernetes enablement steps

### Architecture Compliance

**No architecture constraints** - This is infrastructure setup, not application code.

**Environment Setup Pattern:**
- Follow standard Docker Desktop Kubernetes setup process
- Use standard kubectl commands for verification
- No custom scripts or automation required for this story

### Testing Requirements

**Manual Verification Only:**
- This story requires manual verification of Docker Desktop settings
- All acceptance criteria can be verified via kubectl commands
- No automated tests needed for this infrastructure setup story

**Verification Checklist:**
- [ ] Docker Desktop Kubernetes enabled
- [ ] kubectl connects successfully
- [ ] All system pods Running
- [ ] Test pod can be created and runs successfully

### References

- [Source: _bmad-output/epics.md#Epic-1] - Epic 1: Local K8s Environment Setup
- [Source: _bmad-output/epics.md#Story-1.1] - Story 1.1: Enable Docker Desktop Kubernetes
- [Source: docs/01-concepts.md#Kubernetes-基础概念] - Kubernetes core concepts
- Docker Desktop Kubernetes Documentation: https://docs.docker.com/desktop/kubernetes/

### Previous Story Intelligence

**N/A** - This is the first story in Epic 1, no previous stories to reference.

### Git Intelligence

**No relevant commits** - This is a new setup task, no existing code patterns to follow.

### Latest Tech Information

**Docker Desktop Kubernetes:**
- Docker Desktop includes a single-node Kubernetes cluster
- Kubernetes version matches Docker Desktop version
- No additional installation required beyond enabling the feature
- Uses containerd as the container runtime (not Docker Engine)

**kubectl:**
- kubectl is included with Docker Desktop Kubernetes
- Can also be installed separately via Homebrew: `brew install kubectl`
- Version should match Kubernetes cluster version (within one minor version)

## Dev Agent Record

### Agent Model Used

Claude Sonnet 4.5

### Debug Log References

### Completion Notes List

### File List

