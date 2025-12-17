# Epics and User Stories

## Epic 1: Local K8s Environment Setup

**Objective:** Set up a local Kubernetes environment on macOS for Volcano workflow validation and development.

**Business Value:** Enable local development and testing of Volcano workflows and K8s resource synchronization services without requiring a remote cluster.

### Story 1.1: Enable Docker Desktop Kubernetes

**As a** developer,  
**I want** to enable Kubernetes in Docker Desktop,  
**so that** I can run a local K8s cluster for testing.

**Acceptance Criteria:**
1. Docker Desktop Kubernetes is enabled and running
2. `kubectl` can connect to the local cluster
3. All system pods are in Running state
4. Cluster is ready to accept workloads

**Technical Requirements:**
- Docker Desktop installed on macOS
- Kubernetes version 1.20+ required
- Verify cluster health with `kubectl cluster-info`

### Story 1.2: Deploy Redis Service

**As a** developer,  
**I want** to deploy Redis in the local K8s cluster,  
**so that** I can test the Informer service's state synchronization functionality.

**Acceptance Criteria:**
1. Redis deployment is created and running
2. Redis service is accessible from other pods
3. Redis can be accessed via `redis-cli` for testing
4. Redis data persistence is configured (optional for testing)

**Technical Requirements:**
- Use Deployment or StatefulSet for Redis
- Expose Redis service on port 6379
- Configure appropriate resource limits
- Test connectivity from a test pod

### Story 1.3: Install and Verify Volcano

**As a** developer,  
**I want** to install Volcano scheduler in the local K8s cluster,  
**so that** I can test Volcano workflow deployment and scheduling.

**Acceptance Criteria:**
1. Volcano components are installed in `volcano-system` namespace
2. All Volcano pods are in Running state
3. Volcano scheduler is active and can schedule jobs
4. Simple Volcano Job can be submitted and scheduled successfully

**Technical Requirements:**
- Use existing `manifests/volcano/install.sh` script
- Verify scheduler with `kubectl get pods -n volcano-system`
- Test with a simple Volcano Job

### Story 1.4: Volcano Workflow Smoke Test

**As a** developer,  
**I want** to run a smoke test for Volcano workflow,  
**so that** I can verify basic Volcano functionality works correctly.

**Acceptance Criteria:**
1. Simple Volcano Job can be created and submitted
2. Job is scheduled by Volcano scheduler
3. Pods are created and run successfully
4. Job completes successfully
5. Job status can be queried via kubectl

**Technical Requirements:**
- Use existing simple job examples from `examples/manual/simple-job.yaml`
- Verify Gang Scheduling works (if applicable)
- Check job logs for successful execution

## Epic 2: K8s Resource State Synchronization Service

**Objective:** Develop a Go service using Kubernetes Informer to watch and synchronize resource states to Redis.

**Business Value:** Provide real-time visibility into K8s resource states (Volcano Jobs, Pods, etc.) for monitoring and integration purposes.

### Story 2.1: Go Client Informer Setup

**As a** developer,  
**I want** to set up a Go project with Kubernetes client-go Informer,  
**so that** I can watch K8s resources for changes.

**Acceptance Criteria:**
1. Go project initialized with proper module structure
2. Kubernetes client-go dependencies installed
3. Informer can connect to local K8s cluster
4. Informer successfully watches Volcano Job resources
5. Resource events (Add, Update, Delete) are captured

**Technical Requirements:**
- Use `k8s.io/client-go` library
- Support local kubeconfig (`~/.kube/config`)
- Implement proper error handling and reconnection logic
- Log all events for debugging

### Story 2.2: Redis Integration

**As a** developer,  
**I want** to integrate Redis client into the Informer service,  
**so that** I can store resource states in Redis.

**Acceptance Criteria:**
1. Redis client connection pool is configured
2. Connection to Redis service is established
3. Resource states can be written to Redis
4. Redis connection errors are handled gracefully
5. Connection retry logic is implemented

**Technical Requirements:**
- Use `github.com/redis/go-redis/v9` or similar
- Configure connection pool with appropriate timeouts
- Implement retry logic for connection failures
- Support both local and K8s-deployed Redis

### Story 2.3: State Synchronization Logic

**As a** developer,  
**I want** to implement state synchronization from Informer events to Redis,  
**so that** Redis always reflects the current state of K8s resources.

**Acceptance Criteria:**
1. Resource Add events write state to Redis
2. Resource Update events update state in Redis
3. Resource Delete events remove state from Redis
4. State is serialized in JSON format
5. Redis keys follow a consistent naming pattern (e.g., `k8s:job:{namespace}:{name}`)

**Technical Requirements:**
- Serialize K8s resources to JSON
- Use consistent key naming convention
- Handle concurrent updates safely
- Implement idempotent operations

### Story 2.4: Error Handling and Resilience

**As a** developer,  
**I want** to implement robust error handling and resilience features,  
**so that** the service can recover from failures and maintain data consistency.

**Acceptance Criteria:**
1. K8s API connection failures trigger reconnection
2. Redis connection failures trigger reconnection
3. Temporary failures don't cause data loss
4. Service logs all errors for debugging
5. Health check endpoint is available

**Technical Requirements:**
- Implement exponential backoff for reconnections
- Use local queue/cache for events during Redis outages
- Add health check endpoint (HTTP or gRPC)
- Implement graceful shutdown

### Story 2.5: Testing and Validation

**As a** developer,  
**I want** to test the Informer service end-to-end,  
**so that** I can verify it correctly synchronizes states to Redis.

**Acceptance Criteria:**
1. Unit tests for Informer event handlers
2. Integration tests with local K8s cluster
3. Redis state matches actual K8s resource state
4. Service handles edge cases (rapid updates, network failures)
5. Performance is acceptable (low latency for state updates)

**Technical Requirements:**
- Write unit tests for core logic
- Create integration test environment
- Test with real Volcano Jobs
- Verify Redis state consistency
- Measure and log performance metrics

