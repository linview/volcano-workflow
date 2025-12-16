#!/bin/bash

# 按状态筛选 Job 的脚本
# 用法: ./filter-jobs.sh [namespace] [pending|running|complete|failed|all]

NAMESPACE=${1:-default}
STATUS=${2:-all}

echo "=== Job 状态筛选工具 ==="
echo "命名空间: $NAMESPACE"
echo "状态筛选: $STATUS"
echo ""

case $STATUS in
  pending)
    echo "--- Pending 状态的 Job ---"
    kubectl get jobs -n $NAMESPACE -o wide | grep -E "NAME|Pending" || echo "没有找到 Pending 状态的 Job"
    ;;
  running|active)
    echo "--- Running/Active 状态的 Job ---"
    kubectl get jobs -n $NAMESPACE -o wide | grep -E "NAME|Running|Active" || echo "没有找到 Running/Active 状态的 Job"
    ;;
  complete|completed|succeeded)
    echo "--- Complete 状态的 Job ---"
    kubectl get jobs -n $NAMESPACE -o wide | grep -E "NAME|Complete|Completed" || echo "没有找到 Complete 状态的 Job"
    ;;
  failed)
    echo "--- Failed 状态的 Job ---"
    kubectl get jobs -n $NAMESPACE -o wide | grep -E "NAME|Failed" || echo "没有找到 Failed 状态的 Job"
    ;;
  all)
    echo "--- 所有 Job ---"
    kubectl get jobs -n $NAMESPACE -o wide
    ;;
  *)
    echo "用法: $0 [namespace] [pending|running|complete|failed|all]"
    echo ""
    echo "示例:"
    echo "  $0 default all          # 查看 default 命名空间的所有 Job"
    echo "  $0 default pending      # 查看 default 命名空间的 Pending Job"
    echo "  $0 default failed       # 查看 default 命名空间的 Failed Job"
    exit 1
    ;;
esac

echo ""
echo "--- 关联的 Pod 状态 ---"
kubectl get pods -n $NAMESPACE -l job-name --sort-by=.metadata.creationTimestamp 2>/dev/null || echo "没有找到关联的 Pod"
