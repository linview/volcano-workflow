#!/bin/bash
# MVP 版本 - 节点标签标注脚本
# 用于标注节点的资源特征（静态标签）

set -e

# 参数检查
NODE_NAME=${1:-""}
GPU_TYPE=${2:-"a100"}

if [ -z "$NODE_NAME" ]; then
    echo "用法: $0 <node-name> [gpu-type]"
    echo ""
    echo "示例:"
    echo "  $0 node-01 a100"
    echo "  $0 node-02 v100"
    echo ""
    echo "参数说明:"
    echo "  node-name: 节点名称（必需）"
    echo "  gpu-type:  GPU 类型（可选，默认: a100）"
    exit 1
fi

echo "=========================================="
echo "为节点 $NODE_NAME 添加资源特征标签"
echo "=========================================="

# 检查节点是否存在
if ! kubectl get node $NODE_NAME &>/dev/null; then
    echo "❌ 错误: 节点 $NODE_NAME 不存在"
    exit 1
fi

# GPU 标签（最核心的标签）
echo ""
echo "步骤1: 添加 GPU 标签..."
kubectl label nodes $NODE_NAME gpu.type=$GPU_TYPE --overwrite
echo "  ✅ gpu.type=$GPU_TYPE"

# CPU 标签（可选，如果节点有这些信息）
echo ""
echo "步骤2: 添加 CPU 标签..."
kubectl label nodes $NODE_NAME cpu.cores=64 --overwrite 2>/dev/null || echo "  ⚠️  cpu.cores 标签添加失败（可忽略）"
kubectl label nodes $NODE_NAME cpu.frequency=2.4GHz --overwrite 2>/dev/null || echo "  ⚠️  cpu.frequency 标签添加失败（可忽略）"

# 存储标签（可选）
echo ""
echo "步骤3: 添加存储标签..."
kubectl label nodes $NODE_NAME disk.type=ssd --overwrite 2>/dev/null || echo "  ⚠️  disk.type 标签添加失败（可忽略）"

echo ""
echo "=========================================="
echo "✅ 节点标签添加完成！"
echo "=========================================="
echo ""
echo "查看节点标签:"
echo "  kubectl get node $NODE_NAME --show-labels"
echo ""
echo "查看节点详情:"
echo "  kubectl describe node $NODE_NAME"
echo ""

