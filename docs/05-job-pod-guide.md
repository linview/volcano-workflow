# Kubernetes Job 和 Pod 实战指南

本文档详细解答关于 Kubernetes Job 和 Pod 的常见问题，包含具体的 YAML 配置和 kubectl 操作示例。

## 一、K8s Job 和 Pod 的关系

### 1.1 核心关系

**Job 和 Pod 的关系：**
- **Job** 是一个控制器（Controller），用于管理 Pod 的生命周期
- **Pod** 是实际执行任务的容器组
- **一个 Job 可以创建一个或多个 Pod**（通过 `replicas` 配置）
- Job 负责确保 Pod 成功完成，如果 Pod 失败，Job 会创建新的 Pod 重试

**关系图：**
```
Job (控制器)
  ├── Pod 1 (实际执行任务的容器)
  ├── Pod 2 (如果 replicas > 1)
  └── Pod N
```

### 1.2 K8s Job vs Volcano Job

**Kubernetes 原生 Job：**
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: my-k8s-job
spec:
  completions: 1        # 需要完成的任务数
  parallelism: 1        # 同时运行的 Pod 数
  template:
    spec:
      containers:
      - name: worker
        image: busybox:latest
        command: ["echo", "Hello K8s Job"]
      restartPolicy: Never
```

**Volcano Job（增强版）：**
```yaml
apiVersion: batch.volcano.sh/v1alpha1
kind: Job
metadata:
  name: my-volcano-job
spec:
  schedulerName: volcano    # 使用 Volcano 调度器
  queue: training-queue     # 指定资源队列
  minAvailable: 1           # Gang Scheduling：最少需要 1 个 Pod
  tasks:
    - replicas: 1           # 创建 1 个 Pod
      name: worker
      template:
        spec:
          containers:
          - name: worker
            image: busybox:latest
            command: ["echo", "Hello Volcano Job"]
          restartPolicy: Never
```

### 1.3 完整示例：创建和操作 Job

#### 步骤 1: 创建 K8s Job

**文件：`examples/k8s-job-example.yaml`**
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: k8s-job-example
  namespace: default
spec:
  # 需要完成 1 个任务
  completions: 1
  # 同时运行 1 个 Pod
  parallelism: 1
  # 如果任务失败，最多重试 3 次
  backoffLimit: 3
  # Pod 模板
  template:
    metadata:
      labels:
        app: k8s-job-example
    spec:
      containers:
      - name: worker
        image: busybox:latest
        command:
          - /bin/sh
          - -c
          - |
            echo "Job 开始执行..."
            echo "Pod 名称: $HOSTNAME"
            echo "当前时间: $(date)"
            sleep 30
            echo "Job 执行完成"
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
          limits:
            cpu: "500m"
            memory: "512Mi"
      restartPolicy: Never
```

**创建 Job：**
```bash
kubectl apply -f examples/k8s-job-example.yaml
```

**查看 Job 状态：**
```bash
# 查看 Job
kubectl get job k8s-job-example

# 输出示例：
# NAME              COMPLETIONS   DURATION   AGE
# k8s-job-example   0/1           10s        10s
```

#### 步骤 2: 查看 Pod

**Job 创建后，会自动创建 Pod：**
```bash
# 查看 Pod（Job 会自动添加 job-name 标签）
kubectl get pods -l job-name=k8s-job-example

# 输出示例：
# NAME                    READY   STATUS    RESTARTS   AGE
# k8s-job-example-xxxxx   1/1     Running   0          5s
```

**查看 Pod 详情：**
```bash
# 查看 Pod 详细信息
kubectl describe pod -l job-name=k8s-job-example

# 查看 Pod 日志
kubectl logs -l job-name=k8s-job-example
```

#### 步骤 3: 观察 Job 和 Pod 的关系

**同时查看 Job 和 Pod：**
```bash
# 在一个终端窗口执行
watch -n 1 'kubectl get job k8s-job-example && echo "---" && kubectl get pods -l job-name=k8s-job-example'
```

**执行流程：**
1. 创建 Job → Job 状态为 `Active`
2. Job 创建 Pod → Pod 状态为 `Pending`（等待调度）
3. Pod 被调度到节点 → Pod 状态为 `Running`
4. Pod 执行完成 → Pod 状态为 `Completed`
5. Job 检测到 Pod 完成 → Job 状态为 `Complete`

#### 步骤 4: 清理资源

```bash
# 删除 Job（会自动删除关联的 Pod）
kubectl delete job k8s-job-example

# 验证删除
kubectl get pods -l job-name=k8s-job-example
```

### 1.4 关键操作命令总结

```bash
# 创建 Job
kubectl apply -f job.yaml

# 查看 Job 列表
kubectl get jobs

# 查看 Job 详情
kubectl describe job <job-name>

# 查看 Job 关联的 Pod
kubectl get pods -l job-name=<job-name>

# 查看 Pod 日志
kubectl logs -l job-name=<job-name>

# 删除 Job（会自动删除 Pod）
kubectl delete job <job-name>

# 强制删除 Job（如果正常删除失败）
kubectl delete job <job-name> --force --grace-period=0
```

---

## 二、Job 中挂载 NAS 数据并输出结果

### 2.1 使用 PersistentVolume (PV) 和 PersistentVolumeClaim (PVC)

**这是推荐的方式，适合生产环境。**

#### 步骤 1: 创建 PersistentVolume（管理员操作）

**文件：`manifests/storage/nas-pv.yaml`**
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nas-pv
spec:
  capacity:
    storage: 1Ti                    # NAS 存储容量
  accessModes:
    - ReadWriteMany                 # 支持多 Pod 同时读写
  persistentVolumeReclaimPolicy: Retain  # 保留数据，不自动删除
  storageClassName: nas-storage
  # NFS 配置（根据你的 NAS 实际配置修改）
  nfs:
    server: 192.168.1.100           # NAS 服务器地址
    path: /data/training            # NAS 挂载路径
```

**创建 PV：**
```bash
kubectl apply -f manifests/storage/nas-pv.yaml
kubectl get pv nas-pv
```

#### 步骤 2: 创建 PersistentVolumeClaim

**文件：`manifests/storage/nas-pvc.yaml`**
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nas-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: nas-storage
  resources:
    requests:
      storage: 500Gi                # 请求的存储大小
```

**创建 PVC：**
```bash
kubectl apply -f manifests/storage/nas-pvc.yaml
kubectl get pvc nas-pvc
```

#### 步骤 3: 在 Job 中使用 PVC

**文件：`examples/job-with-nas.yaml`**
```yaml
apiVersion: batch.volcano.sh/v1alpha1
kind: Job
metadata:
  name: training-job-with-nas
  namespace: default
spec:
  schedulerName: volcano
  queue: training-queue
  minAvailable: 1
  
  tasks:
    - replicas: 1
      name: trainer
      template:
        spec:
          containers:
          - name: trainer
            image: nvidia/cuda:11.8.0-base-ubuntu22.04
            command:
              - /bin/bash
              - -c
              - |
                echo "=== 训练任务开始 ==="
                
                # 1. 检查 NAS 数据挂载
                echo "检查数据目录..."
                ls -lh /data/input
                
                # 2. 执行训练脚本
                echo "开始训练..."
                # python /workspace/train.py --data-dir=/data/input --output-dir=/data/output
                
                # 3. 模拟训练过程
                echo "训练中..." > /data/output/training.log
                sleep 60
                
                # 4. 保存结果到 NAS
                echo "保存训练结果..."
                echo "训练完成时间: $(date)" >> /data/output/training.log
                echo "模型已保存到: /data/output/model.pth" >> /data/output/training.log
                
                # 5. 验证结果已保存
                ls -lh /data/output/
                echo "=== 训练任务完成 ==="
            
            # 挂载 NAS 存储
            volumeMounts:
            - name: nas-storage
              mountPath: /data/input          # 输入数据目录
              subPath: input                  # 使用子路径
            - name: nas-storage
              mountPath: /data/output         # 输出结果目录
              subPath: output                 # 使用子路径
            - name: scripts
              mountPath: /workspace/scripts    # 脚本目录（可选）
            
            resources:
              requests:
                cpu: "4"
                memory: "16Gi"
                nvidia.com/gpu: "1"
              limits:
                cpu: "8"
                memory: "32Gi"
                nvidia.com/gpu: "1"
          
          # 定义卷
          volumes:
          - name: nas-storage
            persistentVolumeClaim:
              claimName: nas-pvc              # 使用之前创建的 PVC
          - name: scripts
            configMap:
              name: training-scripts          # 从 ConfigMap 挂载脚本（见下方）
          
          restartPolicy: Never
```

#### 步骤 4: 使用 ConfigMap 挂载脚本

**文件：`manifests/configmaps/training-scripts.yaml`**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: training-scripts
  namespace: default
data:
  train.py: |
    #!/usr/bin/env python3
    import os
    import time
    
    print("开始训练...")
    print(f"数据目录: {os.environ.get('DATA_DIR', '/data/input')}")
    print(f"输出目录: {os.environ.get('OUTPUT_DIR', '/data/output')}")
    
    # 模拟训练
    time.sleep(60)
    
    # 保存结果
    with open('/data/output/model.pth', 'w') as f:
        f.write('model weights')
    
    print("训练完成！")
  
  run.sh: |
    #!/bin/bash
    set -e
    
    DATA_DIR=${DATA_DIR:-/data/input}
    OUTPUT_DIR=${OUTPUT_DIR:-/data/output}
    
    echo "数据目录: $DATA_DIR"
    echo "输出目录: $OUTPUT_DIR"
    
    # 执行训练
    python3 /workspace/scripts/train.py
    
    echo "训练完成，结果保存在: $OUTPUT_DIR"
```

**创建 ConfigMap：**
```bash
kubectl apply -f manifests/configmaps/training-scripts.yaml
```

### 2.2 使用 hostPath（仅用于开发测试）

**⚠️ 注意：hostPath 只在单节点或特定节点可用，不适合生产环境。**

```yaml
apiVersion: batch.volcano.sh/v1alpha1
kind: Job
metadata:
  name: training-job-hostpath
spec:
  schedulerName: volcano
  queue: training-queue
  minAvailable: 1
  
  tasks:
    - replicas: 1
      name: trainer
      template:
        spec:
          containers:
          - name: trainer
            image: nvidia/cuda:11.8.0-base-ubuntu22.04
            command:
              - /bin/bash
              - -c
              - |
                echo "从本地读取数据..."
                ls -lh /host-data/input
                
                echo "执行训练..."
                sleep 60
                
                echo "保存结果到本地..."
                echo "结果" > /host-data/output/result.txt
                ls -lh /host-data/output
            
            volumeMounts:
            - name: host-data
              mountPath: /host-data
          
          volumes:
          - name: host-data
            hostPath:
              path: /mnt/nas/training    # 节点上的路径
              type: DirectoryOrCreate
          
          restartPolicy: Never
```

### 2.3 完整操作流程

```bash
# 1. 创建存储资源
kubectl apply -f manifests/storage/nas-pv.yaml
kubectl apply -f manifests/storage/nas-pvc.yaml

# 2. 创建脚本 ConfigMap
kubectl apply -f manifests/configmaps/training-scripts.yaml

# 3. 提交训练任务
kubectl apply -f examples/job-with-nas.yaml

# 4. 查看任务状态
kubectl get job training-job-with-nas
kubectl get pods -l job-name=training-job-with-nas

# 5. 查看日志
kubectl logs -l job-name=training-job-with-nas

# 6. 验证结果（在 NAS 上或通过 Pod 访问）
kubectl exec -it <pod-name> -- ls -lh /data/output

# 7. 清理
kubectl delete job training-job-with-nas
```

---

## 三、设置 Job 使用的资源（GPU、CPU、内存、IO）

### 3.1 资源请求（requests）和限制（limits）

**核心概念：**
- **requests（请求）**：Pod 需要的最小资源，调度器必须满足才能调度
- **limits（限制）**：Pod 可以使用的最大资源，超过会被限制或终止

### 3.2 CPU 和内存配置

**完整示例：**
```yaml
apiVersion: batch.volcano.sh/v1alpha1
kind: Job
metadata:
  name: training-job-resources
spec:
  schedulerName: volcano
  queue: training-queue
  minAvailable: 1
  
  tasks:
    - replicas: 1
      name: trainer
      template:
        spec:
          containers:
          - name: trainer
            image: nvidia/cuda:11.8.0-base-ubuntu22.04
            command:
              - /bin/bash
              - -c
              - |
                echo "CPU 核心数: $(nproc)"
                echo "内存大小: $(free -h | grep Mem | awk '{print $2}')"
                sleep 60
            
            resources:
              # 资源请求（最低标准）
              requests:
                cpu: "4"                    # 请求 4 核 CPU（可以是小数，如 "0.5"）
                memory: "16Gi"              # 请求 16Gi 内存
              
              # 资源限制（上限）
              limits:
                cpu: "8"                    # 最多使用 8 核 CPU
                memory: "32Gi"              # 最多使用 32Gi 内存
            
            restartPolicy: Never
```

**CPU 单位说明：**
- `"1"` = 1 核 CPU
- `"0.5"` = 0.5 核 CPU（500m）
- `"1000m"` = 1000 毫核 = 1 核

**内存单位说明：**
- `"1Gi"` = 1 Gibibyte (1024^3 bytes)
- `"1G"` = 1 Gigabyte (1000^3 bytes)
- `"512Mi"` = 512 Mebibytes
- `"512M"` = 512 Megabytes

### 3.3 GPU 配置

**GPU 资源请求和限制：**
```yaml
resources:
  requests:
    nvidia.com/gpu: "1"             # 请求 1 个 GPU
  limits:
    nvidia.com/gpu: "1"             # 最多使用 1 个 GPU（通常等于 requests）
```

**指定 GPU 类型（使用 nodeSelector）：**
```yaml
apiVersion: batch.volcano.sh/v1alpha1
kind: Job
metadata:
  name: training-job-gpu
spec:
  schedulerName: volcano
  queue: training-queue
  minAvailable: 1
  
  tasks:
    - replicas: 1
      name: trainer
      template:
        spec:
          # 节点选择器：指定 GPU 类型
          nodeSelector:
            gpu.type: a100           # 必须调度到有 a100 GPU 的节点
          
          containers:
          - name: trainer
            image: nvidia/cuda:11.8.0-base-ubuntu22.04
            command:
              - /bin/bash
              - -c
              - |
                nvidia-smi
                sleep 60
            
            resources:
              requests:
                cpu: "8"
                memory: "32Gi"
                nvidia.com/gpu: "1"  # 请求 1 个 GPU
              limits:
                cpu: "16"
                memory: "64Gi"
                nvidia.com/gpu: "1"  # 最多 1 个 GPU
            
            restartPolicy: Never
```

**多 GPU 配置：**
```yaml
resources:
  requests:
    nvidia.com/gpu: "4"             # 请求 4 个 GPU
  limits:
    nvidia.com/gpu: "4"             # 最多 4 个 GPU
```

### 3.4 IO 资源限制（存储 IOPS）

**Kubernetes 原生不支持 IOPS 限制，但可以通过以下方式实现：**

#### 方式 1: 使用 StorageClass 的 IOPS 限制

**创建 StorageClass（需要存储插件支持）：**
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: example.com/nfs
parameters:
  iops: "10000"                     # IOPS 限制
  throughput: "500MB/s"             # 吞吐量限制
```

#### 方式 2: 使用 nodeAffinity 选择高 IOPS 节点

```yaml
apiVersion: batch.volcano.sh/v1alpha1
kind: Job
metadata:
  name: training-job-high-io
spec:
  schedulerName: volcano
  queue: training-queue
  minAvailable: 1
  
  tasks:
    - replicas: 1
      name: trainer
      template:
        spec:
          # 使用 nodeAffinity 选择 SSD/NVMe 节点
          affinity:
            nodeAffinity:
              requiredDuringSchedulingIgnoredDuringExecution:
                nodeSelectorTerms:
                - matchExpressions:
                  - key: disk.type
                    operator: In
                    values: ["nvme", "ssd"]
              preferredDuringSchedulingIgnoredDuringExecution:
              - weight: 100
                preference:
                  matchExpressions:
                  - key: metrics.disk.iops-available
                    operator: Gt
                    values: ["50000"]
          
          containers:
          - name: trainer
            image: nvidia/cuda:11.8.0-base-ubuntu22.04
            command:
              - /bin/bash
              - -c
              - |
                echo "使用高 IOPS 存储进行训练..."
                sleep 60
            
            resources:
              requests:
                cpu: "4"
                memory: "16Gi"
                nvidia.com/gpu: "1"
              limits:
                cpu: "8"
                memory: "32Gi"
                nvidia.com/gpu: "1"
            
            restartPolicy: Never
```

### 3.5 完整资源配置示例

**文件：`examples/job-full-resources.yaml`**
```yaml
apiVersion: batch.volcano.sh/v1alpha1
kind: Job
metadata:
  name: training-job-full-resources
  namespace: default
spec:
  schedulerName: volcano
  queue: training-queue
  minAvailable: 1
  
  tasks:
    - replicas: 1
      name: trainer
      template:
        spec:
          # 节点选择：GPU 类型
          nodeSelector:
            gpu.type: a100
          
          # 节点亲和性：优先选择低使用率的节点
          affinity:
            nodeAffinity:
              requiredDuringSchedulingIgnoredDuringExecution:
                nodeSelectorTerms:
                - matchExpressions:
                  - key: gpu.type
                    operator: In
                    values: ["a100"]
                  - key: disk.type
                    operator: In
                    values: ["nvme"]
              
              preferredDuringSchedulingIgnoredDuringExecution:
              - weight: 100
                preference:
                  matchExpressions:
                  - key: metrics.gpu.utilization
                    operator: Lt
                    values: ["50%"]
              - weight: 80
                preference:
                  matchExpressions:
                  - key: metrics.cpu.utilization
                    operator: Lt
                    values: ["60%"]
              - weight: 60
                preference:
                  matchExpressions:
                  - key: metrics.disk.iops-available
                    operator: Gt
                    values: ["50000"]
          
          containers:
          - name: trainer
            image: nvidia/cuda:11.8.0-base-ubuntu22.04
            command:
              - /bin/bash
              - -c
              - |
                echo "=== 资源信息 ==="
                echo "CPU: $(nproc) cores"
                echo "Memory: $(free -h | grep Mem | awk '{print $2}')"
                nvidia-smi --query-gpu=name,memory.total --format=csv
                echo "================"
                sleep 60
            
            resources:
              # 资源请求（最低标准）
              requests:
                cpu: "8"                    # 最低 8 核 CPU
                memory: "32Gi"              # 最低 32Gi 内存
                nvidia.com/gpu: "1"         # 最低 1 个 GPU
              
              # 资源限制（上限）
              limits:
                cpu: "16"                   # 最多 16 核 CPU
                memory: "64Gi"              # 最多 64Gi 内存
                nvidia.com/gpu: "1"         # 最多 1 个 GPU
            
            restartPolicy: Never
```

### 3.6 验证资源分配

```bash
# 查看 Pod 的资源请求和限制
kubectl describe pod <pod-name> | grep -A 10 "Limits\|Requests"

# 查看节点资源使用情况
kubectl describe node <node-name> | grep -A 10 "Allocated resources"

# 在 Pod 内查看实际资源
kubectl exec -it <pod-name> -- nproc                    # CPU 核心数
kubectl exec -it <pod-name> -- free -h                  # 内存
kubectl exec -it <pod-name> -- nvidia-smi              # GPU 信息
```

---

## 四、按状态筛选 Job 和状态说明

### 4.1 Job 状态类型

**Kubernetes Job 状态：**
- `Pending` - Job 已创建，等待调度
- `Active` - Job 正在运行（有 Pod 在运行）
- `Complete` - Job 成功完成（所有 Pod 成功完成）
- `Failed` - Job 失败（达到重试次数上限）
- `Suspended` - Job 被暂停（某些情况下）

**Volcano Job 状态（扩展）：**
- `Pending` - 等待调度
- `Running` - 正在运行
- `Completed` - 成功完成
- `Failed` - 失败
- `Aborted` - 被中止
- `Terminating` - 正在终止

### 4.2 Pod 状态类型

**Pod 状态：**
- `Pending` - 等待调度
- `Running` - 正在运行
- `Succeeded` - 成功完成
- `Failed` - 执行失败
- `Unknown` - 状态未知（节点通信问题）
- `CrashLoopBackOff` - 容器反复崩溃
- `ImagePullBackOff` - 镜像拉取失败
- `ErrImagePull` - 镜像拉取错误

### 4.3 按状态筛选 Job

#### 筛选命令

```bash
# 1. 查看所有 Job
kubectl get jobs

# 2. 查看特定状态的 Job（使用 grep）
kubectl get jobs | grep Pending
kubectl get jobs | grep Running
kubectl get jobs | grep Complete
kubectl get jobs | grep Failed

# 3. 使用 JSON 路径筛选（K8s Job）
kubectl get jobs -o jsonpath='{range .items[?(@.status.conditions[0].type=="Complete")]}{.metadata.name}{"\n"}{end}'

# 4. 使用 JSON 路径筛选（Volcano Job）
kubectl get vj -o jsonpath='{range .items[?(@.status.state=="Running")]}{.metadata.name}{"\n"}{end}'

# 5. 查看失败的 Job
kubectl get jobs --field-selector status.successful!=1

# 6. 查看特定命名空间的 Job
kubectl get jobs -n <namespace>

# 7. 使用标签筛选
kubectl get jobs -l app=training
kubectl get jobs -l status=failed
```

#### 筛选脚本示例

**文件：`scripts/filter-jobs.sh`**
```bash
#!/bin/bash

# 按状态筛选 Job 的脚本

NAMESPACE=${1:-default}
STATUS=${2:-all}

echo "=== Job 状态筛选工具 ==="
echo "命名空间: $NAMESPACE"
echo "状态筛选: $STATUS"
echo ""

case $STATUS in
  pending)
    echo "--- Pending 状态的 Job ---"
    kubectl get jobs -n $NAMESPACE -o wide | grep -E "NAME|Pending"
    ;;
  running|active)
    echo "--- Running/Active 状态的 Job ---"
    kubectl get jobs -n $NAMESPACE -o wide | grep -E "NAME|Running|Active"
    ;;
  complete|completed|succeeded)
    echo "--- Complete 状态的 Job ---"
    kubectl get jobs -n $NAMESPACE -o wide | grep -E "NAME|Complete|Completed"
    ;;
  failed)
    echo "--- Failed 状态的 Job ---"
    kubectl get jobs -n $NAMESPACE -o wide | grep -E "NAME|Failed"
    ;;
  all)
    echo "--- 所有 Job ---"
    kubectl get jobs -n $NAMESPACE -o wide
    ;;
  *)
    echo "用法: $0 [namespace] [pending|running|complete|failed|all]"
    exit 1
    ;;
esac

echo ""
echo "--- 关联的 Pod 状态 ---"
kubectl get pods -n $NAMESPACE -l job-name --sort-by=.metadata.creationTimestamp
```

**使用脚本：**
```bash
chmod +x scripts/filter-jobs.sh

# 查看所有 Job
./scripts/filter-jobs.sh default all

# 查看 Pending 状态的 Job
./scripts/filter-jobs.sh default pending

# 查看 Failed 状态的 Job
./scripts/filter-jobs.sh default failed
```

### 4.4 状态详细说明和排查

#### Pending 状态

**含义：** Job 已创建，但 Pod 还未被调度或正在等待资源。

**可能原因：**
1. 集群资源不足（CPU/内存/GPU）
2. 节点选择器（nodeSelector）不匹配
3. 节点亲和性（nodeAffinity）条件不满足
4. 节点污点（Taints）导致无法调度
5. PVC 未绑定（如果使用了存储）

**排查命令：**
```bash
# 查看 Job 详情
kubectl describe job <job-name>

# 查看 Pod 详情
kubectl describe pod -l job-name=<job-name>

# 查看事件
kubectl get events --sort-by=.metadata.creationTimestamp | grep <job-name>

# 检查节点资源
kubectl describe nodes | grep -A 5 "Allocated resources"

# 检查调度器日志（Volcano）
kubectl logs -n volcano-system -l app=volcano-scheduler --tail=100
```

#### Running/Active 状态

**含义：** Job 正在运行，Pod 已成功调度并正在执行任务。

**正常情况：**
- Pod 状态为 `Running`
- 容器正常运行
- 日志正常输出

**检查命令：**
```bash
# 查看 Pod 状态
kubectl get pods -l job-name=<job-name>

# 查看实时日志
kubectl logs -f -l job-name=<job-name>

# 查看 Pod 资源使用
kubectl top pod -l job-name=<job-name>
```

#### Complete/Completed 状态

**含义：** Job 成功完成，所有 Pod 都成功执行完毕。

**特征：**
- Job 的 `COMPLETIONS` 显示为 `1/1` 或 `N/N`
- Pod 状态为 `Succeeded`
- 退出码为 0

**验证命令：**
```bash
# 查看 Job 状态
kubectl get job <job-name>

# 查看 Pod 退出码
kubectl get pod -l job-name=<job-name> -o jsonpath='{.items[0].status.containerStatuses[0].state.terminated.exitCode}'

# 查看最终日志
kubectl logs -l job-name=<job-name> --tail=50
```

#### Failed 状态

**含义：** Job 执行失败，已达到最大重试次数。

**可能原因：**
1. 容器执行错误（退出码非 0）
2. 镜像拉取失败
3. 资源不足导致 OOMKilled
4. 存储挂载失败
5. 命令执行超时

**排查命令：**
```bash
# 查看 Job 详情和失败原因
kubectl describe job <job-name>

# 查看失败的 Pod
kubectl get pods -l job-name=<job-name>

# 查看 Pod 日志
kubectl logs -l job-name=<job-name> --previous  # 查看上一个容器的日志

# 查看 Pod 事件
kubectl describe pod -l job-name=<job-name> | grep -A 10 "Events"

# 查看退出码
kubectl get pod -l job-name=<job-name> -o jsonpath='{.items[0].status.containerStatuses[0].state.terminated.exitCode}'
```

**常见错误：**
- `ExitCode: 1` - 命令执行失败
- `OOMKilled` - 内存不足
- `ImagePullBackOff` - 镜像拉取失败
- `CrashLoopBackOff` - 容器反复崩溃

### 4.5 状态转换图

```
创建 Job
  ↓
Pending (等待调度)
  ↓
Running/Active (Pod 运行中)
  ↓
  ├─→ Complete (成功完成)
  │
  └─→ Failed (执行失败)
      ├─→ 重试 (如果 backoffLimit > 0)
      │   └─→ Running → Complete/Failed
      │
      └─→ 最终失败 (达到重试上限)
```

### 4.6 实用查询命令集合

```bash
# === Job 查询 ===

# 查看所有 Job 及其状态
kubectl get jobs -A -o wide

# 查看 Job 的详细信息
kubectl get job <job-name> -o yaml

# 查看 Job 的完成情况
kubectl get job <job-name> -o jsonpath='{.status}'

# === Pod 查询 ===

# 查看 Job 关联的所有 Pod
kubectl get pods -l job-name=<job-name>

# 查看 Pod 的详细状态
kubectl get pod <pod-name> -o yaml

# 查看 Pod 的当前状态和事件
kubectl describe pod <pod-name>

# === 日志查询 ===

# 查看 Pod 日志
kubectl logs <pod-name>

# 查看所有相关 Pod 的日志
kubectl logs -l job-name=<job-name>

# 查看上一个容器的日志（如果 Pod 重启过）
kubectl logs <pod-name> --previous

# === 事件查询 ===

# 查看 Job 相关事件
kubectl get events --field-selector involvedObject.name=<job-name>

# 查看 Pod 相关事件
kubectl get events --field-selector involvedObject.name=<pod-name>

# 按时间排序查看所有事件
kubectl get events --all-namespaces --sort-by=.metadata.creationTimestamp

# === 资源使用查询 ===

# 查看 Pod 资源使用
kubectl top pod <pod-name>

# 查看节点资源使用
kubectl top node

# === 清理命令 ===

# 删除 Job（会自动删除 Pod）
kubectl delete job <job-name>

# 强制删除 Job
kubectl delete job <job-name> --force --grace-period=0

# 删除失败的 Pod
kubectl delete pod <pod-name>
```

---

## 五、完整实战示例

### 5.1 创建完整的训练 Job

**文件：`examples/complete-training-job.yaml`**
```yaml
apiVersion: batch.volcano.sh/v1alpha1
kind: Job
metadata:
  name: complete-training-job
  namespace: default
  labels:
    app: training
    task-type: model-training
spec:
  schedulerName: volcano
  queue: training-queue
  minAvailable: 1
  
  # 失败重试策略
  policies:
  - event: PodFailed
    action: RestartJob
    maxRetry: 3
  
  tasks:
    - replicas: 1
      name: trainer
      template:
        metadata:
          labels:
            app: training
            task: trainer
        spec:
          # 节点选择：A100 GPU
          nodeSelector:
            gpu.type: a100
          
          # 节点亲和性：优先选择低使用率节点
          affinity:
            nodeAffinity:
              requiredDuringSchedulingIgnoredDuringExecution:
                nodeSelectorTerms:
                - matchExpressions:
                  - key: gpu.type
                    operator: In
                    values: ["a100"]
              
              preferredDuringSchedulingIgnoredDuringExecution:
              - weight: 100
                preference:
                  matchExpressions:
                  - key: metrics.gpu.utilization
                    operator: Lt
                    values: ["50%"]
          
          containers:
          - name: trainer
            image: nvidia/cuda:11.8.0-base-ubuntu22.04
            command:
              - /bin/bash
              - -c
              - |
                set -e
                
                echo "=== 训练任务开始 ==="
                echo "时间: $(date)"
                echo "Pod: $HOSTNAME"
                echo "节点: $(hostname)"
                
                # 检查资源
                echo "=== 资源信息 ==="
                echo "CPU: $(nproc) cores"
                echo "内存: $(free -h | grep Mem | awk '{print $2}')"
                nvidia-smi --query-gpu=name,memory.total --format=csv
                
                # 检查数据
                echo "=== 数据检查 ==="
                ls -lh /data/input || echo "数据目录不存在"
                
                # 执行训练（示例）
                echo "=== 开始训练 ==="
                sleep 60
                
                # 保存结果
                echo "=== 保存结果 ==="
                mkdir -p /data/output
                echo "训练完成时间: $(date)" > /data/output/training.log
                echo "模型已保存" >> /data/output/training.log
                
                echo "=== 训练任务完成 ==="
            
            # 挂载存储
            volumeMounts:
            - name: nas-storage
              mountPath: /data/input
              subPath: input
            - name: nas-storage
              mountPath: /data/output
              subPath: output
            
            # 资源限制
            resources:
              requests:
                cpu: "8"
                memory: "32Gi"
                nvidia.com/gpu: "1"
              limits:
                cpu: "16"
                memory: "64Gi"
                nvidia.com/gpu: "1"
          
          volumes:
          - name: nas-storage
            persistentVolumeClaim:
              claimName: nas-pvc
          
          restartPolicy: Never
```

### 5.2 操作流程

```bash
# 1. 创建存储（如果还没有）
kubectl apply -f manifests/storage/nas-pvc.yaml

# 2. 提交训练任务
kubectl apply -f examples/complete-training-job.yaml

# 3. 监控任务状态
watch -n 2 'kubectl get job complete-training-job && echo "---" && kubectl get pods -l job-name=complete-training-job'

# 4. 查看日志
kubectl logs -f -l job-name=complete-training-job

# 5. 检查结果
kubectl exec -it $(kubectl get pod -l job-name=complete-training-job -o jsonpath='{.items[0].metadata.name}') -- ls -lh /data/output

# 6. 清理
kubectl delete job complete-training-job
```

---

## 六、总结

### 6.1 关键要点

1. **Job 和 Pod 关系**：Job 是控制器，管理 Pod 的生命周期；一个 Job 可以创建多个 Pod
2. **NAS 挂载**：使用 PVC/PV 挂载 NAS，在容器内通过 volumeMounts 访问
3. **资源设置**：使用 `requests` 设置最低标准，`limits` 设置上限
4. **状态筛选**：使用 `kubectl get` 配合 `grep` 或 JSON 路径筛选

### 6.2 常用命令速查

```bash
# Job 操作
kubectl apply -f job.yaml              # 创建 Job
kubectl get jobs                       # 查看 Job
kubectl describe job <name>            # 查看详情
kubectl delete job <name>              # 删除 Job

# Pod 操作
kubectl get pods -l job-name=<name>    # 查看 Pod
kubectl logs -l job-name=<name>        # 查看日志
kubectl describe pod <name>            # 查看详情

# 状态筛选
kubectl get jobs | grep Pending        # 筛选 Pending
kubectl get jobs | grep Running        # 筛选 Running
kubectl get jobs | grep Failed         # 筛选 Failed
```

### 6.3 下一步学习

- 学习 [Volcano JobFlow 工作流](docs/02-principles.md)
- 了解 [调度策略配置](docs/03-best-practices.md)
- 实践 [多 Pod 并行训练](examples/)

---

**参考资源：**
- [Kubernetes Job 文档](https://kubernetes.io/docs/concepts/workloads/controllers/job/)
- [Volcano Job 文档](https://volcano.sh/docs/)
- [K8s 资源管理](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
