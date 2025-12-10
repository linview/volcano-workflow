# 步骤3: 测试最简 JobFlow

## 目标

创建一个最简单的 JobFlow 工作流，验证任务依赖关系和工作流执行顺序。

## 前置条件

- ✅ 已完成 [步骤1: 部署 Volcano](01-deploy-volcano.md)
- ✅ 已完成 [步骤2: 测试最简 Job](02-test-simple-job.md)
- ✅ 理解 Volcano Job 的基本概念

## 测试步骤

### 步骤 3.1: 理解 JobFlow 概念

**JobFlow 是什么？**

JobFlow 是 Volcano 的工作流功能，支持：
- ✅ 多个任务（Job）
- ✅ 任务依赖关系（DAG）
- ✅ 顺序执行

**本示例包含：**
- **step1** - 第一个任务，输出 "Step 1: Hello"
- **step2** - 第二个任务，依赖 step1，输出 "Step 2: World"

**执行顺序：**
```
step1 执行 → step1 完成 → step2 开始执行 → step2 完成 → JobFlow 完成
```

### 步骤 3.2: 查看示例文件

```bash
cd examples/manual
cat simple-jobflow.yaml
```

**文件结构说明：**

```yaml
apiVersion: flow.volcano.sh/v1alpha1  # JobFlow API
kind: JobFlow
metadata:
  name: simple-jobflow
spec:
  flow:
    steps:
      - name: step1              # 步骤1
        template: hello-job       # 使用 hello-job 模板
        dependsOn: []             # 无依赖
        
      - name: step2              # 步骤2
        template: world-job       # 使用 world-job 模板
        dependsOn:
          - step1                # ⚠️ 依赖 step1
  
  templates:                     # 任务模板定义
    - name: hello-job
      jobTemplate: ...
    - name: world-job
      jobTemplate: ...
```

**关键点：**
- `dependsOn: [step1]` - step2 依赖 step1
- `templates` - 定义可复用的 Job 模板
- 每个模板对应一个 Volcano Job

### 步骤 3.3: 提交 JobFlow

```bash
kubectl apply -f simple-jobflow.yaml
```

**预期输出：**
```
jobflow.flow.volcano.sh/simple-jobflow created
```

### 步骤 3.4: 查看 JobFlow 状态

```bash
kubectl get jobflow simple-jobflow
```

**预期输出（初始状态）：**
```
NAME              AGE   STATE
simple-jobflow    5s    Running
```

**状态说明：**
- `Running` - JobFlow 正在执行
- `Completed` - JobFlow 成功完成
- `Failed` - JobFlow 失败
- `Aborted` - JobFlow 被中止

**持续监控：**
```bash
kubectl get jobflow simple-jobflow -w
```

### 步骤 3.5: 查看各个 Job 状态

```bash
# 查看所有 Job
kubectl get jobs

# 或者只查看 JobFlow 相关的 Job
kubectl get jobs -l jobflow=simple-jobflow
```

**预期输出（step1 执行中）：**
```
NAME         AGE   STATE
hello-job    10s   Running
```

**预期输出（step1 完成，step2 执行中）：**
```
NAME         AGE   STATE
hello-job    1m    Completed
world-job    5s    Running
```

**预期输出（全部完成）：**
```
NAME         AGE   STATE
hello-job    2m    Completed
world-job    1m    Completed
```

**关键观察点：**
- ✅ step1（hello-job）先执行
- ✅ step1 完成后，step2（world-job）才开始
- ✅ 两个 Job 都成功完成

### 步骤 3.6: 查看 Pod 状态

```bash
# 查看所有 Pod
kubectl get pods

# 或者按 Job 查看
kubectl get pods -l job-name=hello-job
kubectl get pods -l job-name=world-job
```

**预期输出（step1 执行中）：**
```
NAME                READY   STATUS    RESTARTS   AGE
hello-job-hello-0   1/1     Running   0          15s
```

**预期输出（step1 完成，step2 执行中）：**
```
NAME                READY   STATUS      RESTARTS   AGE
hello-job-hello-0   0/1     Completed   0          1m
world-job-world-0   1/1     Running     0          10s
```

**关键观察点：**
- ✅ hello-job 的 Pod 先运行
- ✅ hello-job 完成后，world-job 的 Pod 才开始运行

### 步骤 3.7: 查看日志（验证执行顺序）

```bash
# 查看 step1 日志
kubectl logs -l job-name=hello-job

# 查看 step2 日志
kubectl logs -l job-name=world-job
```

**预期输出（step1）：**
```
Step 1: Hello
```

**预期输出（step2）：**
```
Step 2: World
```

**验证执行顺序：**
```bash
# 查看 Pod 创建时间
kubectl get pods -o wide --sort-by=.metadata.creationTimestamp
```

应该看到：
- hello-job Pod 创建时间早于 world-job Pod
- hello-job Pod 完成时间早于 world-job Pod 创建时间

### 步骤 3.8: 查看 JobFlow 详情

```bash
kubectl describe jobflow simple-jobflow
```

**关键信息：**
- **State:** JobFlow 当前状态
- **Phase:** 各个步骤的状态
- **Events:** JobFlow 事件

**预期看到：**
```
Events:
  Type    Reason      Age   From                    Message
  ----    ------      ----  ----                    -------
  Normal  JobCreated  2m    volcano-jobflow-controller  Created job hello-job
  Normal  JobCompleted 1m  volcano-jobflow-controller  Job hello-job completed
  Normal  JobCreated  1m    volcano-jobflow-controller  Created job world-job
  Normal  JobCompleted 30s volcano-jobflow-controller  Job world-job completed
  Normal  Completed   30s   volcano-jobflow-controller  JobFlow completed
```

### 步骤 3.9: 等待 JobFlow 完成

```bash
# 持续监控
kubectl get jobflow simple-jobflow -w
```

**按 Ctrl+C 停止监控**

**或者等待完成后查看：**
```bash
kubectl get jobflow simple-jobflow
```

**预期输出：**
```
NAME              AGE   STATE
simple-jobflow    3m    Completed
```

### 步骤 3.10: 验证成功

**检查清单：**

- [ ] JobFlow 状态为 `Completed`
- [ ] hello-job 先执行并完成
- [ ] world-job 在 hello-job 完成后执行
- [ ] 两个 Job 都成功完成
- [ ] 日志输出正确（"Step 1: Hello" 和 "Step 2: World"）

## 深入理解

### 工作流执行流程

```
1. 创建 JobFlow
   ↓
2. volcano-controllers 解析依赖关系
   ↓
3. 创建 step1 (hello-job)
   ↓
4. hello-job 执行
   ↓
5. hello-job 完成
   ↓
6. 触发 step2 (world-job) 创建
   ↓
7. world-job 执行
   ↓
8. world-job 完成
   ↓
9. JobFlow 完成
```

### DAG（有向无环图）

```
step1 ──→ step2
```

**依赖关系：**
- step2 依赖 step1
- step1 不依赖任何任务
- 没有循环依赖（这是 DAG 的要求）

### 与单独 Job 的区别

**单独提交两个 Job：**
```bash
kubectl apply -f hello-job.yaml
kubectl apply -f world-job.yaml
# 问题：两个 Job 可能同时执行，无法保证顺序
```

**使用 JobFlow：**
```bash
kubectl apply -f simple-jobflow.yaml
# 优势：保证 step2 在 step1 完成后执行
```

## 故障排查

### 问题1: JobFlow 一直 Running

**症状：** JobFlow 状态一直是 `Running`

**排查：**
```bash
# 查看 JobFlow 详情
kubectl describe jobflow simple-jobflow

# 查看各个 Job 状态
kubectl get jobs

# 查看 Controller 日志
kubectl logs -n volcano-system -l app=volcano-controllers --tail=50
```

**可能原因：**
- step1 未完成
- step2 无法启动
- Controller 未正确处理依赖

**解决：**
- 检查 step1 的 Job 状态
- 查看 Controller 日志
- 检查依赖关系配置

### 问题2: step2 不等待 step1

**症状：** step2 在 step1 完成前就开始执行

**排查：**
```bash
# 查看 Pod 创建时间
kubectl get pods -o wide --sort-by=.metadata.creationTimestamp

# 查看 JobFlow 配置
kubectl get jobflow simple-jobflow -o yaml
```

**可能原因：**
- `dependsOn` 配置错误
- Controller 未正确处理依赖

**解决：**
- 检查 YAML 文件中的 `dependsOn` 配置
- 确认 Controller 正常运行

### 问题3: step1 失败，step2 仍执行

**症状：** step1 失败，但 step2 仍然执行

**排查：**
```bash
# 查看 JobFlow 配置中的 policies
kubectl get jobflow simple-jobflow -o yaml | grep -A 10 policies
```

**说明：**
- 默认情况下，如果 step1 失败，step2 可能仍会执行
- 需要配置 `policies` 来控制失败行为

**解决：**
- 添加失败策略：
  ```yaml
  policies:
    - event: TaskFailed
      action: AbortJobFlow
  ```

### 问题4: JobFlow 状态为 Failed

**症状：** JobFlow 状态为 `Failed`

**排查：**
```bash
# 查看 JobFlow 详情
kubectl describe jobflow simple-jobflow

# 查看各个 Job 状态
kubectl get jobs

# 查看失败的 Pod 日志
kubectl logs <failed-pod-name>
```

**可能原因：**
- 某个 Job 执行失败
- 达到最大重试次数
- 资源不足

**解决：**
- 查看失败的 Job 和 Pod
- 检查日志了解失败原因
- 调整资源配置或重试策略

## 清理资源

测试完成后，清理资源：

```bash
# 删除 JobFlow（会自动删除相关的 Job）
kubectl delete jobflow simple-jobflow

# 验证清理
kubectl get jobflow simple-jobflow
kubectl get jobs
```

**预期结果：**
- JobFlow 被删除
- 相关的 Job 也被删除
- Pod 被清理

## 下一步

✅ **恭喜！** 你已经成功跑通了 Volcano 的基本流程：

1. ✅ 部署了 Volcano
2. ✅ 运行了最简单的 Job
3. ✅ 运行了最简单的工作流

**接下来可以：**

1. **深入学习** - 阅读 [概念文档](../../docs/01-concepts.md)
2. **尝试复杂场景** - 运行 [训练任务示例](../training-job.yaml)
3. **学习调度策略** - 查看 [调度策略配置](../../configs/scheduling_strategy.md)
4. **探索更多功能** - 队列管理、资源配额、优先级等

## 扩展练习（可选）

### 练习1: 添加第三个步骤

修改 `simple-jobflow.yaml`，添加 step3：

```yaml
steps:
  - name: step1
    template: hello-job
  - name: step2
    template: world-job
    dependsOn:
      - step1
  - name: step3              # 新增
    template: done-job       # 新增
    dependsOn:
      - step2                # 依赖 step2
```

### 练习2: 并行执行

创建两个无依赖的步骤，观察并行执行：

```yaml
steps:
  - name: step1
    template: hello-job
  - name: step2
    template: world-job
    # 没有 dependsOn，两个步骤并行执行
```

### 练习3: 失败重试

添加失败重试策略：

```yaml
steps:
  - name: step1
    template: hello-job
    policies:
      - event: TaskFailed
        action: RestartJob
        maxRetry: 3
```

观察失败时的重试行为。

