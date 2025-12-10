# 智驾模型发布版本流水线 - MVP 版本

基于 Kubernetes + Volcano 的智驾模型训练推理发布版本流水线系统（MVP 最简实现）。

## 🎯 MVP 版本特点

- ✅ **最简实现** - 只包含核心功能，易于理解
- ✅ **概念讲解** - 详细的概念、原理、最佳实践讲解
- ✅ **快速上手** - 5 步快速开始
- ✅ **完整文档** - 从概念到实践的完整指南

## 📚 学习路径

### 第一步：理解概念（推荐先看）

阅读概念讲解文档，理解 K8s 和 Volcano 的核心概念：

1. **[核心概念](docs/01-concepts.md)** - K8s 基础、Volcano 核心概念、调度原理
2. **[原理详解](docs/02-principles.md)** - Volcano 调度原理、资源 Locality Affinity、工作流执行
3. **[最佳实践](docs/03-best-practices.md)** - 队列设计、节点标签、任务配置、故障排查

### 第二步：快速实践

**推荐路径：** 先手动跑通最简流程，建立信心！

**[手动跑通流程指南](examples/manual/README.md)** - 最简化的学习路径
- 步骤1: 部署 Volcano
- 步骤2: 测试最简 Job
- 步骤3: 测试最简 JobFlow

**或者按照快速开始指南：**

**[快速开始指南](QUICKSTART.md)** - 5 步快速上手

## 🚀 快速开始（5 步）

### 步骤 1: 安装 Volcano（2 分钟）

```bash
cd manifests/volcano
chmod +x install.sh
./install.sh
```

验证安装：
```bash
kubectl get pods -n volcano-system
```

### 步骤 2: 创建训练队列（30 秒）

```bash
kubectl apply -f manifests/queues/training-queue.yaml
kubectl get queue
```

### 步骤 3: 标注 GPU 节点（30 秒）

```bash
# 查看节点列表
kubectl get nodes

# 标注一个 GPU 节点（替换 <node-name> 为实际节点名）
chmod +x scripts/label-nodes.sh
./scripts/label-nodes.sh <node-name> a100

# 验证标签
kubectl get node <node-name> --show-labels | grep gpu.type
```

### 步骤 4: 准备训练镜像（可选）

如果你还没有训练镜像，可以：
- 使用测试镜像：`nvidia/cuda:11.8.0-base-ubuntu22.04`
- 修改 `examples/training-job.yaml` 中的镜像名称

### 步骤 5: 提交训练任务（30 秒）

```bash
# 修改 examples/training-job.yaml
# 1. 修改镜像名称（如果需要）
# 2. 修改训练命令（如果需要）

# 提交任务
kubectl apply -f examples/training-job.yaml

# 查看任务状态
kubectl get job training-job-mvp
kubectl get pods -l app=training
```

## 📁 项目结构

```
volcano_workflow/
├── docs/                          # 📚 文档目录
│   ├── 01-concepts.md            # 核心概念讲解
│   ├── 02-principles.md          # 原理详解
│   ├── 03-best-practices.md      # 最佳实践
│   └── 04-components.md          # 组件详解
├── manifests/                     # K8s 资源定义
│   ├── volcano/                  # Volcano 安装配置
│   │   ├── namespace.yaml
│   │   ├── scheduler-config.yaml
│   │   └── install.sh
│   └── queues/                   # 队列定义
│       └── training-queue.yaml
├── examples/                      # 示例文件
│   ├── manual/                   # ⭐ 手动跑通流程指南
│   │   ├── README.md
│   │   ├── 01-deploy-volcano.md
│   │   ├── 02-test-simple-job.md
│   │   ├── 03-test-simple-jobflow.md
│   │   ├── simple-job.yaml
│   │   └── simple-jobflow.yaml
│   ├── training-job.yaml         # 基础训练任务
│   └── training-job-with-affinity.yaml  # 带调度策略的训练任务
├── scripts/                       # 工具脚本
│   └── label-nodes.sh            # 节点标签标注脚本
├── README.md                      # 本文档
└── QUICKSTART.md                  # 快速开始指南
```

## 🔍 验证结果

### 检查任务状态

```bash
# 查看 Job 状态
kubectl get job training-job-mvp

# 查看 Pod 状态
kubectl get pods -l app=training

# 查看 Pod 详情
kubectl describe pod <pod-name>
```

### 查看日志

```bash
# 查看训练日志
kubectl logs -l app=training

# 查看调度器日志（如果任务无法调度）
kubectl logs -n volcano-system -l app=volcano-scheduler --tail=100
```

### 检查调度结果

```bash
# 查看 Pod 调度到哪个节点
kubectl get pod -l app=training -o wide

# 应该看到 Pod 调度到了标注了 gpu.type=a100 的节点
```

## ❓ 常见问题

### Q1: Pod 一直 Pending？

**排查步骤：**

1. **检查队列是否存在**
   ```bash
   kubectl get queue training-queue
   ```

2. **检查节点标签是否正确**
   ```bash
   kubectl get nodes --show-labels | grep gpu.type
   ```

3. **检查 GPU 资源是否足够**
   ```bash
   kubectl describe node <node-name> | grep -A 5 "Allocated resources"
   ```

4. **查看事件了解原因**
   ```bash
   kubectl describe job training-job-mvp
   kubectl describe pod <pod-name>
   ```

### Q2: Volcano 调度器未运行？

```bash
# 检查调度器状态
kubectl get pods -n volcano-system

# 查看调度器日志
kubectl logs -n volcano-system -l app=volcano-scheduler

# 重新安装
cd manifests/volcano
./install.sh
```

### Q3: 任务执行失败？

```bash
# 查看 Pod 日志
kubectl logs <pod-name>

# 查看 Pod 事件
kubectl describe pod <pod-name>
```

## 📖 文档说明

### 核心文档

- **[01-concepts.md](docs/01-concepts.md)** - 核心概念讲解
  - K8s 基础概念
  - Volcano 核心概念
  - 调度原理
  - MVP 范围说明

- **[02-principles.md](docs/02-principles.md)** - 原理详解
  - Volcano 调度器架构
  - Gang Scheduling 原理
  - 资源 Locality Affinity 调度原理
  - 工作流执行原理

- **[03-best-practices.md](docs/03-best-practices.md)** - 最佳实践
  - 队列设计最佳实践
  - 节点标签最佳实践
  - 任务配置最佳实践
  - 故障排查最佳实践

## 🎓 学习建议

1. **先理解概念** - 阅读 `docs/01-concepts.md`
2. **理解原理** - 阅读 `docs/02-principles.md`
3. **实践 MVP** - 按照 `QUICKSTART.md` 操作
4. **学习最佳实践** - 阅读 `docs/03-best-practices.md`
5. **扩展功能** - 根据需要添加更多功能

## 📚 参考资源

- [Kubernetes 官方文档](https://kubernetes.io/docs/)
- [Volcano 官方文档](https://volcano.sh/docs/)
- [K8s 调度器扩展](https://kubernetes.io/docs/concepts/scheduling-eviction/scheduling-framework/)

## 📝 许可证

MIT License
