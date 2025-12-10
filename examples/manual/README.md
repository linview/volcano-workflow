# 手动跑通 Volcano 流程指南

本目录包含最简化的 Volcano Job 和 JobFlow 示例，用于验证 Volcano 的基本功能。

## 📋 目录结构

```
examples/manual/
├── README.md                    # 本文档
├── 01-deploy-volcano.md        # 步骤1: 部署 Volcano
├── 02-test-simple-job.md       # 步骤2: 测试最简 Job
├── 03-test-simple-jobflow.md   # 步骤3: 测试最简 JobFlow
├── simple-job.yaml             # 最简 Job 示例
└── simple-jobflow.yaml         # 最简 JobFlow 示例
```

## 🎯 学习目标

通过本指南，你将：

1. ✅ 成功部署 Volcano 到 K8s 集群
2. ✅ 运行最简单的 Volcano Job
3. ✅ 运行最简单的 JobFlow 工作流
4. ✅ 理解 Volcano 的基本工作流程
5. ✅ 掌握基本的故障排查方法

## 📚 学习路径

按照以下顺序逐步进行：

1. **[步骤1: 部署 Volcano](01-deploy-volcano.md)** - 安装和验证 Volcano
2. **[步骤2: 测试最简 Job](02-test-simple-job.md)** - 运行最简单的 Job
3. **[步骤3: 测试最简 JobFlow](03-test-simple-jobflow.md)** - 运行最简单的工作流

## ⏱️ 预计时间

- 步骤1: 5-10 分钟
- 步骤2: 10-15 分钟
- 步骤3: 15-20 分钟
- **总计: 30-45 分钟**

## ✅ 前置要求

- ✅ Kubernetes 集群（1.20+）
- ✅ kubectl 已配置并可以访问集群
- ✅ Helm 3.x（用于安装 Volcano）
- ✅ 基本的 K8s 知识（Pod、Job 等）

## 🚀 快速开始

```bash
# 1. 进入 manual 目录
cd examples/manual

# 2. 按照步骤1开始
# 查看 01-deploy-volcano.md
```

## 📝 注意事项

1. **按顺序执行** - 每个步骤都依赖前一步的成功
2. **仔细阅读输出** - 注意命令的输出和错误信息
3. **记录问题** - 如果遇到问题，记录错误信息便于排查
4. **清理资源** - 测试完成后记得清理创建的资源

## 🆘 遇到问题？

如果遇到问题，请：

1. 查看对应步骤的故障排查部分
2. 检查 Volcano 组件日志
3. 查看 Pod 事件和状态
4. 参考 [主文档](../../README.md) 的常见问题部分

## 📖 下一步

完成本指南后，可以：

1. 阅读 [概念文档](../../docs/01-concepts.md) 深入理解原理
2. 尝试 [训练任务示例](../training-job.yaml)
3. 学习 [调度策略配置](../../configs/scheduling_strategy.md)
4. 探索更多 Volcano 功能

