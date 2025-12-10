# 步骤2: 测试最简 Job

## 目标

创建一个最简单的 Volcano Job，验证 Volcano 调度器能够正常工作。

## 前置条件

- ✅ 已完成 [步骤1: 部署 Volcano](01-deploy-volcano.md)
- ✅ Volcano 组件正常运行

## 测试步骤

### 步骤 2.1: 查看示例文件

```bash
cd examples/manual
cat simple-job.yaml
```

**文件内容说明：**

```yaml
apiVersion: batch.volcano.sh/v1alpha1  # Volcano Job API
kind: Job
metadata:
  name: simple-job
spec:
  schedulerName: volcano              # ⚠️ 关键：使用 Volcano 调度器
  minAvailable: 1                     # 最少需要 1 个 Pod
  tasks:
    - replicas: 1                     # 1 个 Pod
      name: hello
      template:
        spec:
          containers:
            - name: hello
              image: busybox:latest   # 最简单的镜像
              command:
                - /bin/sh
                - -c
                - echo "Hello from Volcano Job!" && sleep 10
          restartPolicy: Never
```

**关键点：**
- `schedulerName: volcano` - 必须指定使用 Volcano 调度器
- `minAvailable: 1` - 最少需要 1 个 Pod 才能开始
- 使用 `busybox` 镜像，不需要 GPU，不需要特殊权限

### 步骤 2.2: 提交 Job

```bash
kubectl apply -f simple-job.yaml
```

**预期输出：**
```
job.batch.volcano.sh/simple-job created
```

### 步骤 2.3: 查看 Job 状态

```bash
kubectl get job simple-job
```

**预期输出（初始状态）：**
```
NAME         AGE   STATE
simple-job   5s    Pending
```

**状态说明：**
- `Pending` - Job 已创建，等待调度
- `Running` - Job 正在运行
- `Completed` - Job 成功完成
- `Failed` - Job 失败

### 步骤 2.4: 查看 Pod 状态

```bash
# 查看 Pod
kubectl get pods -l job-name=simple-job

# 或者查看所有 Pod（会看到 simple-job 相关的 Pod）
kubectl get pods
```

**预期输出（调度中）：**
```
NAME                READY   STATUS    RESTARTS   AGE
simple-job-hello-0  0/1     Pending   0          10s
```

**预期输出（运行中）：**
```
NAME                READY   STATUS    RESTARTS   AGE
simple-job-hello-0  1/1     Running   0          30s
```

**预期输出（完成）：**
```
NAME                READY   STATUS      RESTARTS   AGE
simple-job-hello-0  0/1     Completed   0          1m
```

### 步骤 2.5: 查看 Pod 详情

```bash
kubectl describe pod -l job-name=simple-job
```

**关键信息：**
- **Node:** Pod 调度到哪个节点
- **Events:** 调度和启动事件
- **Conditions:** Pod 条件状态

**预期看到：**
```
Events:
  Type    Reason     Age   From               Message
  ----    ------     ----  ----               -------
  Normal  Scheduled  30s   volcano-scheduler  Successfully assigned default/simple-job-hello-0 to node-01
  Normal  Pulling    29s   kubelet            Pulling image "busybox:latest"
  Normal  Pulled     25s   kubelet            Successfully pulled image "busybox:latest"
  Normal  Created    25s   kubelet            Created container hello
  Normal  Started    24s   kubelet            Started container hello
```

**关键检查点：**
- ✅ `Scheduled` 事件显示 `volcano-scheduler` - 确认使用 Volcano 调度
- ✅ `Successfully assigned` - Pod 成功调度到节点

### 步骤 2.6: 查看日志

```bash
kubectl logs -l job-name=simple-job
```

**预期输出：**
```
Hello from Volcano Job!
```

### 步骤 2.7: 等待 Job 完成

```bash
# 持续监控 Job 状态
kubectl get job simple-job -w
```

**按 Ctrl+C 停止监控**

**或者等待完成后查看：**
```bash
kubectl get job simple-job
```

**预期输出：**
```
NAME         AGE   STATE
simple-job   2m    Completed
```

### 步骤 2.8: 验证成功

**检查清单：**

- [ ] Job 状态为 `Completed`
- [ ] Pod 状态为 `Completed`
- [ ] 日志输出 "Hello from Volcano Job!"
- [ ] Pod 事件显示由 `volcano-scheduler` 调度

## 深入理解

### 调度流程

```
1. 创建 Job
   ↓
2. volcano-controllers 创建 Pod
   ↓
3. Pod schedulerName=volcano
   ↓
4. volcano-scheduler 接收调度请求
   ↓
5. 调度 Pod 到节点
   ↓
6. Pod 运行
   ↓
7. Job 完成
```

### 与 K8s Job 的区别

**K8s Job：**
```yaml
apiVersion: batch/v1
kind: Job
spec:
  # 没有 schedulerName，使用默认调度器
  # 没有 minAvailable
```

**Volcano Job：**
```yaml
apiVersion: batch.volcano.sh/v1alpha1
kind: Job
spec:
  schedulerName: volcano  # 使用 Volcano 调度器
  minAvailable: 1         # Gang Scheduling
```

## 故障排查

### 问题1: Pod 一直 Pending

**症状：** Pod 状态一直是 `Pending`

**排查：**
```bash
# 查看 Pod 详情
kubectl describe pod -l job-name=simple-job

# 查看调度器日志
kubectl logs -n volcano-system -l app=volcano-scheduler --tail=50

# 检查节点资源
kubectl describe nodes
```

**可能原因：**
- 节点资源不足
- 调度器未正常运行
- 节点标签/污点问题

**解决：**
- 检查 Volcano 调度器是否运行
- 检查节点是否有可用资源
- 查看调度器日志了解调度失败原因

### 问题2: Job 状态一直是 Pending

**症状：** Job 状态不变化

**排查：**
```bash
# 查看 Job 详情
kubectl describe job simple-job

# 查看 Controller 日志
kubectl logs -n volcano-system -l app=volcano-controllers --tail=50
```

**可能原因：**
- Controller 未正常运行
- Job 配置错误

**解决：**
- 检查 Controller 是否运行
- 检查 YAML 文件格式
- 查看 Controller 日志

### 问题3: Pod 启动失败

**症状：** Pod 状态为 `Error` 或 `CrashLoopBackOff`

**排查：**
```bash
# 查看 Pod 日志
kubectl logs -l job-name=simple-job

# 查看 Pod 事件
kubectl describe pod -l job-name=simple-job
```

**可能原因：**
- 镜像拉取失败
- 命令执行错误
- 资源限制

**解决：**
- 检查镜像是否存在
- 检查命令是否正确
- 检查资源限制

## 清理资源

测试完成后，清理资源：

```bash
kubectl delete job simple-job
```

**验证清理：**
```bash
kubectl get job simple-job
# 应该显示: Error from server (NotFound)
```

## 下一步

✅ **如果测试成功**，继续到 [步骤3: 测试最简 JobFlow](03-test-simple-jobflow.md)

❌ **如果遇到问题**，参考故障排查部分，或重新检查 Volcano 部署

## 扩展练习（可选）

尝试修改 Job，观察变化：

1. **增加 Pod 数量：**
   ```yaml
   replicas: 3  # 改为 3 个 Pod
   ```

2. **修改 minAvailable：**
   ```yaml
   minAvailable: 2  # 需要至少 2 个 Pod 才能开始
   ```

3. **修改命令：**
   ```yaml
   command:
     - /bin/sh
     - -c
     - echo "Hello $HOSTNAME" && sleep 30
   ```

观察这些变化对调度和执行的影响。

