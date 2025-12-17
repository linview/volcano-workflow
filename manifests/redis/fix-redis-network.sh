#!/bin/bash
set -e

echo "🔧 修复 Redis 部署网络问题..."

# 检查 Docker 是否运行
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker Desktop 未运行，请先启动 Docker Desktop"
    exit 1
fi

# 检查镜像是否已存在
if docker images | grep -q "redis.*7-alpine"; then
    echo "✅ 本地已有 Redis 镜像"
else
    echo "📥 拉取 Redis 镜像..."
    docker pull redis:7-alpine || {
        echo "❌ 镜像拉取失败，请检查："
        echo "   1. Docker Desktop Settings → Docker Engine → 配置镜像加速器"
        echo "   2. 或配置代理"
        exit 1
    }
fi

# 如果使用 Kind，加载镜像到集群
if command -v kind &> /dev/null; then
    CLUSTER_NAME=$(kind get clusters 2>/dev/null | head -1)
    if [ ! -z "$CLUSTER_NAME" ]; then
        echo "📦 加载镜像到 Kind 集群: $CLUSTER_NAME"
        kind load docker-image redis:7-alpine --name "$CLUSTER_NAME" || {
            echo "⚠️  镜像加载失败，但继续部署..."
        }
    fi
fi

# 删除旧的部署（如果存在）
echo "🗑️  清理旧部署..."
kubectl delete deployment redis -n redis 2>/dev/null || true
sleep 2

# 重新部署
echo "🚀 重新部署 Redis..."
kubectl apply -f "$(dirname "$0")/redis-deployment.yaml"

# 等待 Pod 就绪
echo "⏳ 等待 Redis Pod 就绪..."
if kubectl wait --for=condition=Ready pod -l app=redis -n redis --timeout=120s 2>/dev/null; then
    echo "✅ Redis 部署成功！"
    echo ""
    echo "📋 验证命令："
    echo "  kubectl get pods -n redis"
    echo "  kubectl get svc -n redis"
    echo "  kubectl port-forward -n redis svc/redis 6379:6379 &"
    echo "  redis-cli -h localhost -p 6379 ping"
else
    echo "❌ Redis Pod 未就绪，查看详情："
    echo "  kubectl describe pod -l app=redis -n redis"
    echo "  kubectl logs -l app=redis -n redis"
    exit 1
fi

