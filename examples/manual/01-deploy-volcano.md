# 步骤1: 部署 Volcano

## 目标

成功部署 Volcano 到 K8s 集群，并验证所有组件正常运行。

## 前置检查

### 1. 检查 kubectl 配置

```bash
kubectl cluster-info
kubectl get nodes
```

**预期结果：** 能够看到集群信息和节点列表

### 2. 检查 Helm 安装

```bash
helm version
```

**预期结果：** 显示 Helm 版本（v3.x）

**如果未安装 Helm：**
```bash
# macOS
brew install helm

# Linux
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

## 部署步骤

### 步骤 1.1: 进入 Volcano 安装目录

```bash
cd ../../manifests/volcano
pwd
# 应该显示: .../volcano_workflow/manifests/volcano
```

### 步骤 1.2: 执行安装脚本

```bash
chmod +x install.sh
./install.sh
```

**安装过程说明：**

脚本会执行以下操作：
1. 检查 kubectl 和 Helm
2. 创建 `volcano-system` 命名空间
3. 应用调度器配置
4. 添加 Helm 仓库
5. 安装 Volcano 组件
6. 等待组件就绪

**预期输出：**
```
==========================================
开始安装 Volcano Scheduler
==========================================

步骤1: 创建命名空间...
namespace/volcano-system created

步骤2: 应用调度器配置...
configmap/volcano-scheduler-configmap created

步骤3: 添加 Helm 仓库...
"volcano" has been added to your repositories

步骤4: 安装 Volcano...
NAME: volcano
...

步骤5: 等待 Volcano 组件就绪...
pod/volcano-scheduler-xxx condition met
pod/volcano-controllers-xxx condition met

步骤6: 验证安装...
NAME                                    READY   STATUS    RESTARTS   AGE
volcano-scheduler-xxx                   1/1     Running   0          2m
volcano-controllers-xxx                 1/1     Running   0          2m

==========================================
✅ Volcano 安装完成！
==========================================
```

### 步骤 1.3: 验证安装

```bash
# 查看所有组件
kubectl get pods -n volcano-system

# 查看调度器状态
kubectl get pods -n volcano-system -l app=volcano-scheduler

# 查看控制器状态
kubectl get pods -n volcano-system -l app=volcano-controllers
```

**预期结果：**

```
NAME                                    READY   STATUS    RESTARTS   AGE
volcano-scheduler-xxx                   1/1     Running   0          5m
volcano-controllers-xxx                 1/1     Running   0          5m
```

**关键检查点：**
- ✅ 所有 Pod 状态为 `Running`
- ✅ READY 为 `1/1`
- ✅ 没有 `Error` 或 `CrashLoopBackOff`

### 步骤 1.4: 检查调度器配置

```bash
kubectl get configmap -n volcano-system volcano-scheduler-configmap -o yaml
```

**预期结果：** 看到调度器配置文件内容

## 验证清单

完成以下检查，确保 Volcano 部署成功：

- [ ] `volcano-scheduler` Pod 状态为 `Running`
- [ ] `volcano-controllers` Pod 状态为 `Running`
- [ ] 调度器配置 ConfigMap 存在
- [ ] 没有错误日志

## 故障排查

### 问题1: Helm 安装失败

**症状：** `helm install` 命令失败

**排查：**
```bash
# 检查 Helm 仓库
helm repo list

# 更新仓库
helm repo update

# 检查网络连接
ping github.com
```

**解决：**
- 检查网络连接
- 确认 Helm 版本 >= 3.0
- 尝试手动添加仓库：`helm repo add volcano https://volcano-sh.github.io/volcano`

### 问题2: Pod 一直 Pending

**症状：** Pod 状态为 `Pending`

**排查：**
```bash
# 查看 Pod 详情
kubectl describe pod -n volcano-system <pod-name>

# 查看节点资源
kubectl describe nodes
```

**解决：**
- 检查节点资源是否充足
- 检查节点标签和污点
- 查看调度器日志：`kubectl logs -n volcano-system -l app=volcano-scheduler`

### 问题3: Pod CrashLoopBackOff

**症状：** Pod 状态为 `CrashLoopBackOff`

**排查：**
```bash
# 查看 Pod 日志
kubectl logs -n volcano-system <pod-name> --previous

# 查看 Pod 事件
kubectl describe pod -n volcano-system <pod-name>
```

**解决：**
- 检查镜像拉取权限
- 检查资源配置（CPU/内存）
- 查看详细错误日志

### 问题4: 组件启动超时

**症状：** 安装脚本显示"等待超时"

**排查：**
```bash
# 手动检查 Pod 状态
kubectl get pods -n volcano-system -w

# 查看 Pod 日志
kubectl logs -n volcano-system -l app=volcano-scheduler --tail=50
```

**解决：**
- 等待更长时间（首次安装可能需要 5-10 分钟）
- 检查节点资源
- 查看详细日志定位问题

## 下一步

✅ **如果所有检查都通过**，继续到 [步骤2: 测试最简 Job](02-test-simple-job.md)

❌ **如果遇到问题**，参考故障排查部分，或查看 Volcano 官方文档

## 清理（可选）

如果部署失败需要重新安装：

```bash
# 卸载 Volcano
helm uninstall volcano -n volcano-system

# 删除命名空间
kubectl delete namespace volcano-system

# 重新执行安装脚本
./install.sh
```

