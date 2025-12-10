#!/bin/bash
# Volcano 安装脚本（MVP 版本）

set -e

echo "=========================================="
echo "开始安装 Volcano Scheduler"
echo "=========================================="

# 检查 kubectl
if ! command -v kubectl &> /dev/null; then
    echo "❌ 错误: kubectl 未安装或不在 PATH 中"
    exit 1
fi

# 检查 Helm
if ! command -v helm &> /dev/null; then
    echo "❌ 错误: Helm 未安装"
    echo "请先安装 Helm: https://helm.sh/docs/intro/install/"
    exit 1
fi

# 步骤1: 创建命名空间
echo ""
echo "步骤1: 创建命名空间..."
kubectl apply -f namespace.yaml

# 步骤2: 应用调度器配置
echo ""
echo "步骤2: 应用调度器配置..."
kubectl apply -f scheduler-config.yaml

# 步骤3: 添加 Helm 仓库
echo ""
echo "步骤3: 添加 Helm 仓库..."
helm repo add volcano https://volcano-sh.github.io/volcano
helm repo update

# 步骤4: 安装 Volcano
echo ""
echo "步骤4: 安装 Volcano..."

# 检查是否已存在本地 chart 包
# 必须提前将 volcano chart（指定版本）下载到本地，并重命名为 volcano-chart.tgz
# 示例命令（请替换成你需要的版本号）：
#   helm pull volcano/volcano --version <version> --destination .
#   mv ./volcano-<version>.tgz ./volcano-chart.tgz
LOCAL_CHART="./volcano-chart.tgz"
if [ -f "$LOCAL_CHART" ]; then
    echo "检测到本地 Helm Chart: $LOCAL_CHART"
    helm install volcano "$LOCAL_CHART" \
        --namespace volcano-system \
        --set scheduler.schedulerName=volcano \
        --set scheduler.configMapName=volcano-scheduler-configmap \
        --create-namespace
else
    echo "⚠️ 提示：如果不能访问外网，请先从有网络环境下载 volcano chart 到本地 (可用命令见下)"
    echo "    helm pull volcano/volcano --version <version> --destination ."
    echo "    # 然后将 volcano-chart.tgz 拷贝到本目录并重命名为 volcano-chart.tgz"
    echo ""
    echo "尝试从仓库安装 volcano（若内网受限可能会失败）..."
    helm install volcano volcano/volcano \
        --namespace volcano-system \
        --set scheduler.schedulerName=volcano \
        --set scheduler.configMapName=volcano-scheduler-configmap \
        --create-namespace
fi

# 步骤5: 等待组件就绪
echo ""
echo "步骤5: 等待 Volcano 组件就绪..."
echo "这可能需要几分钟时间..."
echo ""
echo "说明:"
echo "  - volcano-scheduler: 调度器，负责 Pod 调度决策"
echo "  - volcano-controllers: 控制器，负责管理 Job/JobFlow 资源"
echo ""

# 等待调度器就绪
echo "等待 volcano-scheduler..."
kubectl wait --for=condition=ready pod -l app=volcano-scheduler -n volcano-system --timeout=300s || {
    echo "⚠️  警告: volcano-scheduler 等待超时，但可能仍在启动中"
}

# 等待控制器就绪
echo ""
echo "等待 volcano-controllers..."
kubectl wait --for=condition=ready pod -l app=volcano-controllers -n volcano-system --timeout=300s || {
    echo "⚠️  警告: volcano-controllers 等待超时，但可能仍在启动中"
}

# 步骤6: 验证安装
echo ""
echo "步骤6: 验证安装..."
echo "以下输出展示 volcano-system 命名空间下的核心组件启动情况，所有 Pod 状态应为 Running 或 Completed："
kubectl get pods -n volcano-system
echo ""
echo "常见核心组件包括："
echo "  - volcano-scheduler      # Volcano 调度器"
echo "  - volcano-controllers    # Volcano 控制器"
echo ""
echo "如果所有 Pod 都已就绪，表示 Volcano 安装成功。"

echo ""
echo "=========================================="
echo "✅ Volcano 安装完成！"
echo "=========================================="
echo ""
echo "验证命令:"
echo "  kubectl get pods -n volcano-system"
echo "  kubectl get configmap -n volcano-system volcano-scheduler-configmap"
echo ""

