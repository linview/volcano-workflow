# 第三部分：最佳实践

## 一、队列设计最佳实践

### 1.1 队列划分原则

**原则1：按任务类型划分**

```
training-queue    → 训练任务（长时间运行，高优先级）
inference-queue   → 推理任务（短时间运行，中优先级）
export-queue      → 导出任务（CPU 密集，低优先级）
```

**原则2：按资源需求划分**

```
gpu-queue         → GPU 任务
cpu-queue         → CPU 任务
io-queue          → IO 密集任务
```

**原则3：按优先级划分**

```
high-priority-queue   → 生产任务
low-priority-queue    → 开发/测试任务
```

### 1.2 资源配额设置

**原则1：capability 不要超过集群总资源**

```yaml
# ❌ 错误：超过集群总资源
capability:
  cpu: "10000"  # 集群只有 1000 核

# ✅ 正确：不超过集群总资源
capability:
  cpu: "800"    # 集群有 1000 核，留 200 核给其他队列
```

**原则2：guarantee 设置合理**

```yaml
# ✅ 正确：保证关键任务有资源
guarantee:
  cpu: "500"           # 保证 500 核
  nvidia.com/gpu: "16"  # 保证 16 个 GPU
```

**原则3：weight 设置合理**

```yaml
# ✅ 正确：训练任务优先级最高
training-queue:
  weight: 10

inference-queue:
  weight: 5

export-queue:
  weight: 2
```

### 1.3 队列状态管理

**队列状态：**

- **Open** - 开放，接受新任务
- **Closed** - 关闭，不接受新任务
- **Closing** - 关闭中，等待现有任务完成

**最佳实践：**

```bash
# 维护时关闭队列
kubectl patch queue training-queue -p '{"spec":{"state":"Closed"}}'

# 维护完成后重新开放
kubectl patch queue training-queue -p '{"spec":{"state":"Open"}}'
```

## 二、节点标签最佳实践

### 2.1 标签命名规范

**规范：**

- ✅ 使用小写字母和连字符
- ✅ 格式：`<资源类型>.<属性名>`
- ✅ 避免使用下划线

**示例：**

```yaml
# ✅ 正确
gpu.type: a100
cpu.cores: 64
disk.type: nvme

# ❌ 错误
gpu_type: a100
GPU_TYPE: A100
```

### 2.2 标签分类

**静态标签（Labels）- 硬件特征**

```yaml
# CPU 特征
cpu.arch: x86_64
cpu.cores: 64
cpu.frequency: 2.4GHz

# GPU 特征
gpu.type: a100
gpu.count: 8
gpu.memory-per-card: 80GB

# 存储特征
disk.type: nvme
disk.iops: 100000
disk.bandwidth: 3GB/s
```

**动态注解（Annotations）- 使用率**

```yaml
# CPU 使用率
metrics.cpu.utilization: 45%
metrics.cpu.available-cores: 35

# GPU 使用率
metrics.gpu.utilization: 60%
metrics.gpu.memory-used: 48GB
metrics.gpu.temperature: 75C

# 存储使用率
metrics.disk.utilization: 70%
metrics.disk.iops-used: 50000
```

### 2.3 标签更新策略

**静态标签：**
- 节点创建时设置
- 硬件变更时更新
- 很少变化

**动态注解：**
- 每 30 秒更新一次
- 通过监控 Agent 自动更新
- 频繁变化

## 三、任务配置最佳实践

### 3.1 资源请求设置

**原则1：requests 设置合理**

```yaml
# ✅ 正确：根据实际需求设置
resources:
  requests:
    cpu: "4"              # 实际需要 4 核
    memory: "16Gi"        # 实际需要 16Gi
    nvidia.com/gpu: "1"   # 实际需要 1 个 GPU
```

**原则2：limits 不要设置过高**

```yaml
# ❌ 错误：limits 过高，浪费资源
limits:
  cpu: "100"
  memory: "500Gi"

# ✅ 正确：limits 略高于 requests
limits:
  cpu: "8"              # requests 的 2 倍
  memory: "32Gi"        # requests 的 2 倍
```

**原则3：GPU 资源设置**

```yaml
# ✅ 正确：GPU 通常 requests = limits
resources:
  requests:
    nvidia.com/gpu: "1"
  limits:
    nvidia.com/gpu: "1"  # GPU 不能超量使用
```

### 3.2 调度策略配置

**原则1：required 条件要准确**

```yaml
# ✅ 正确：必须满足的条件
requiredDuringSchedulingIgnoredDuringExecution:
  nodeSelectorTerms:
    - matchExpressions:
        - key: gpu.type
          operator: In
          values: ["a100"]  # 必须使用 A100 GPU
```

**原则2：preferred 条件要合理**

```yaml
# ✅ 正确：偏好条件
preferredDuringSchedulingIgnoredDuringExecution:
  - weight: 100
    preference:
      matchExpressions:
        - key: metrics.gpu.utilization
          operator: Lt
          values: ["60%"]  # 优先选择使用率低于 60% 的节点
```

**原则3：权重设置合理**

```yaml
# ✅ 正确：重要条件权重高
- weight: 100  # GPU 使用率（重要）
- weight: 50   # 磁盘类型（次要）
```

### 3.3 重试策略配置

**原则1：区分可重试和不可重试的错误**

```yaml
# ✅ 正确：可重试的错误
policies:
  - event: PodEvicted      # Pod 被驱逐，可重试
    action: RestartJob
    maxRetry: 3

# ✅ 正确：不可重试的错误
policies:
  - event: TaskFailed
    action: AbortJobFlow   # 直接中止，不重试
```

**原则2：设置合理的重试次数**

```yaml
# ✅ 正确：根据任务特点设置
maxRetry: 3  # 训练任务可以重试 3 次
maxRetry: 1  # 导出任务只重试 1 次
```

## 四、工作流设计最佳实践

### 4.1 任务依赖设计

**原则1：避免循环依赖**

```yaml
# ❌ 错误：循环依赖
training → validation → training

# ✅ 正确：线性依赖
training → validation → export → publish
```

**原则2：依赖关系要清晰**

```yaml
# ✅ 正确：明确的依赖关系
dependsOn:
  - training
  - data-preparation
```

### 4.2 失败处理策略

**原则1：设置合理的超时时间**

```yaml
# ✅ 正确：根据任务特点设置
timeout: 3600s  # 训练任务 1 小时超时
timeout: 600s   # 验证任务 10 分钟超时
```

**原则2：区分任务级别和工作流级别失败**

```yaml
# 任务级别失败
policies:
  - event: TaskFailed
    action: RestartJob
    maxRetry: 3

# 工作流级别失败
policies:
  - event: TaskFailed
    action: AbortJobFlow  # 中止整个工作流
```

### 4.3 资源分配策略

**原则1：根据任务特点选择队列**

```yaml
# ✅ 正确：训练任务使用训练队列
queue: training-queue

# ✅ 正确：推理任务使用推理队列
queue: inference-queue
```

**原则2：设置合理的优先级**

```yaml
# ✅ 正确：生产任务优先级高
priorityClassName: high-priority

# ✅ 正确：开发任务优先级低
priorityClassName: low-priority
```

## 五、监控和告警最佳实践

### 5.1 监控指标选择

**核心指标：**

1. **队列指标**
   - 队列资源使用率
   - 队列任务数量
   - 队列等待时间

2. **任务指标**
   - 任务执行时间
   - 任务成功率
   - 任务失败率

3. **节点指标**
   - CPU/GPU/内存使用率
   - 节点可用性
   - 节点温度

### 5.2 告警规则设置

**原则1：设置合理的告警阈值**

```yaml
# ✅ 正确：根据实际情况设置
- alert: GPUHighUtilization
  expr: nvidia_gpu_utilization_gpu > 95  # GPU 使用率超过 95%
  for: 10m  # 持续 10 分钟
```

**原则2：区分警告和严重告警**

```yaml
# 警告：资源使用率高
severity: warning

# 严重：任务失败
severity: critical
```

### 5.3 日志管理

**原则1：设置合理的日志保留时间**

```yaml
# ✅ 正确：保留 30 天
retention: 30d
```

**原则2：重要日志归档**

```bash
# ✅ 正确：归档重要日志
tar -czf logs-$(date +%Y%m%d).tar.gz logs/
```

## 六、性能优化最佳实践

### 6.1 调度性能优化

**策略1：减少节点数量**

```yaml
# ✅ 正确：只标注需要的节点
nodeSelector:
  gpu.type: a100  # 只考虑 A100 节点
```

**策略2：使用缓存**

```yaml
# ✅ 正确：缓存节点信息
cacheTTL: 5m  # 缓存 5 分钟
```

### 6.2 资源利用率优化

**策略1：资源预留**

```yaml
# ✅ 正确：为关键任务预留资源
guarantee:
  cpu: "500"
  nvidia.com/gpu: "16"
```

**策略2：资源回收**

```yaml
# ✅ 正确：允许资源回收
reclaimable: true
```

### 6.3 任务执行优化

**策略1：批量处理**

```yaml
# ✅ 正确：批量处理任务
batchSize: 10
```

**策略2：并行执行**

```yaml
# ✅ 正确：并行执行独立任务
parallelism: 5
```

## 七、故障排查最佳实践

### 7.1 任务无法调度

**排查步骤：**

1. 检查队列状态
   ```bash
   kubectl get queue
   ```

2. 检查节点标签
   ```bash
   kubectl get nodes --show-labels
   ```

3. 检查资源使用率
   ```bash
   kubectl describe node <node-name>
   ```

4. 查看调度器日志
   ```bash
   kubectl logs -n volcano-system -l app=volcano-scheduler
   ```

### 7.2 任务执行失败

**排查步骤：**

1. 查看 Pod 日志
   ```bash
   kubectl logs <pod-name>
   ```

2. 查看 Pod 事件
   ```bash
   kubectl describe pod <pod-name>
   ```

3. 检查资源限制
   ```bash
   kubectl describe pod <pod-name> | grep Limits
   ```

### 7.3 工作流失败

**排查步骤：**

1. 查看工作流状态
   ```bash
   kubectl get jobflow <jobflow-name>
   ```

2. 查看各个任务状态
   ```bash
   kubectl get jobs -l version=<version>
   ```

3. 查看工作流事件
   ```bash
   kubectl describe jobflow <jobflow-name>
   ```

## 参考

- [Volcano 最佳实践](https://volcano.sh/docs/best-practices/)
- [Kubernetes 最佳实践](https://kubernetes.io/docs/concepts/cluster-administration/)

