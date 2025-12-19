# CephFS + Rook + CSI 快速部署指南

## 概述

本指南帮助您在私有IDC的K8s环境中快速部署CephFS + Rook + CSI，实现高性能共享存储和审计功能。

## 前置要求

- Kubernetes集群（1.19+）
- 至少3个节点（用于Ceph集群）
- 每个节点至少50GB可用磁盘空间
- 网络连通性良好

## 快速开始（5步部署）

### 步骤1：安装Rook Operator（5分钟）

```bash
# 创建Rook命名空间
kubectl create namespace rook-ceph

# 安装Rook Operator
kubectl apply -f https://raw.githubusercontent.com/rook/rook/release-1.12/cluster/examples/kubernetes/ceph/common.yaml
kubectl apply -f https://raw.githubusercontent.com/rook/rook/release-1.12/cluster/examples/kubernetes/ceph/operator.yaml

# 等待Operator就绪
kubectl wait --for=condition=ready pod -l app=rook-ceph-operator -n rook-ceph --timeout=300s
```

### 步骤2：创建Ceph集群（10分钟）

创建 `ceph-cluster.yaml`：

```yaml
apiVersion: ceph.rook.io/v1
kind: CephCluster
metadata:
  name: rook-ceph
  namespace: rook-ceph
spec:
  cephVersion:
    image: quay.io/ceph/ceph:v18.2.0
  dataDirHostPath: /var/lib/rook
  mon:
    count: 3
    allowMultiplePerNode: false
  storage:
    useAllNodes: true
    useAllDevices: true
    config:
      databaseSizeMB: "1024"
      journalSizeMB: "1024"
  mgr:
    count: 1
  dashboard:
    enabled: true
```

部署：

```bash
kubectl apply -f ceph-cluster.yaml

# 等待集群就绪（约5-10分钟）
kubectl wait --for=condition=ready cephcluster rook-ceph -n rook-ceph --timeout=600s
```

### 步骤3：创建CephFS文件系统（5分钟）

创建 `cephfs.yaml`：

```yaml
apiVersion: ceph.rook.io/v1
kind: CephFilesystem
metadata:
  name: myfs
  namespace: rook-ceph
spec:
  metadataPool:
    replicated:
      size: 3
  dataPools:
    - replicated:
        size: 3
  metadataServer:
    activeCount: 1
    activeStandby: true
```

部署：

```bash
kubectl apply -f cephfs.yaml

# 等待MDS就绪
kubectl wait --for=condition=ready cephfilesystem myfs -n rook-ceph --timeout=300s
```

### 步骤4：配置CSI StorageClass（5分钟）

创建 `storageclass.yaml`：

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: rook-cephfs
provisioner: rook-ceph.cephfs.csi.ceph.com
parameters:
  clusterID: rook-ceph
  fsName: myfs
  pool: myfs-data0
  csi.storage.k8s.io/provisioner-secret-name: rook-csi-cephfs-provisioner
  csi.storage.k8s.io/provisioner-secret-namespace: rook-ceph
  csi.storage.k8s.io/controller-expand-secret-name: rook-csi-cephfs-provisioner
  csi.storage.k8s.io/controller-expand-secret-namespace: rook-ceph
  csi.storage.k8s.io/node-stage-secret-name: rook-csi-cephfs-node
  csi.storage.k8s.io/node-stage-secret-namespace: rook-ceph
allowVolumeExpansion: true
reclaimPolicy: Retain
```

部署：

```bash
kubectl apply -f storageclass.yaml

# 设置为默认StorageClass（可选）
kubectl patch storageclass rook-cephfs -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

### 步骤5：测试PVC创建和使用（5分钟）

创建测试PVC `test-pvc.yaml`：

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: cephfs-pvc
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: rook-cephfs
  resources:
    requests:
      storage: 10Gi
```

创建测试Pod `test-pod.yaml`：

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: cephfs-test-pod
spec:
  containers:
    - name: test
      image: busybox
      command: ["sleep", "3600"]
      volumeMounts:
        - name: cephfs-vol
          mountPath: /mnt/cephfs
  volumes:
    - name: cephfs-vol
      persistentVolumeClaim:
        claimName: cephfs-pvc
```

测试：

```bash
# 创建PVC
kubectl apply -f test-pvc.yaml

# 创建测试Pod
kubectl apply -f test-pod.yaml

# 验证挂载
kubectl exec -it cephfs-test-pod -- ls -la /mnt/cephfs

# 写入测试
kubectl exec -it cephfs-test-pod -- sh -c "echo 'Hello CephFS' > /mnt/cephfs/test.txt"

# 读取测试
kubectl exec -it cephfs-test-pod -- cat /mnt/cephfs/test.txt
```

## 审计功能配置

### 1. 访问Ceph Dashboard

```bash
# 获取Dashboard访问信息
kubectl get svc -n rook-ceph rook-ceph-mgr-dashboard

# 获取admin密码
kubectl -n rook-ceph get secret rook-ceph-dashboard-password -o jsonpath="{['data']['password']}" | base64 --decode && echo

# 端口转发（本地访问）
kubectl port-forward -n rook-ceph svc/rook-ceph-mgr-dashboard 8443:8443
```

访问：https://localhost:8443

### 2. 启用审计日志

在Ceph Dashboard中：
1. 进入 **Configuration** → **MDS**
2. 启用 `mds_audit_logging = true`
3. 配置日志级别和输出位置

### 3. 查看审计日志

```bash
# 查看MDS Pod日志
kubectl logs -n rook-ceph -l app=rook-ceph-mds --tail=100

# 导出审计日志到文件
kubectl logs -n rook-ceph -l app=rook-ceph-mds > ceph-audit.log
```

### 4. 集成到ELK/EFK（可选）

创建 `audit-log-forwarder.yaml`：

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: ceph-audit-config
  namespace: rook-ceph
data:
  fluent.conf: |
    <source>
      @type tail
      path /var/log/ceph/audit.log
      pos_file /var/log/ceph/audit.log.pos
      tag ceph.audit
      <parse>
        @type json
      </parse>
    </source>
    <match ceph.audit>
      @type elasticsearch
      host elasticsearch.logging.svc.cluster.local
      port 9200
      index_name ceph-audit
      type_name _doc
    </match>
```

## 性能优化建议

### 1. 存储后端优化

```yaml
# 在ceph-cluster.yaml中添加
spec:
  storage:
    config:
      # 使用SSD时优化
      osd_pool_default_pg_num: "128"
      osd_pool_default_pgp_num: "128"
      # 启用压缩（如果CPU充足）
      bluestore_compression_algorithm: snappy
```

### 2. 网络优化

```yaml
# 配置专用存储网络（如果有多网卡）
spec:
  network:
    provider: host
    selectors:
      public: "public-network"
      cluster: "cluster-network"
```

### 3. MDS性能调优

```yaml
# 在CephFilesystem中添加
spec:
  metadataServer:
    activeCount: 2  # 增加MDS数量
    resources:
      limits:
        cpu: "2"
        memory: "4Gi"
      requests:
        cpu: "1"
        memory: "2Gi"
```

## 在Volcano训练任务中使用

更新 `training-job.yaml`：

```yaml
apiVersion: batch.volcano.sh/v1alpha1
kind: Job
metadata:
  name: training-job-with-cephfs
spec:
  schedulerName: volcano
  queue: training-queue
  minAvailable: 1
  tasks:
    - replicas: 1
      name: trainer
      template:
        spec:
          containers:
            - image: nvidia/cuda:11.8.0-base-ubuntu22.04
              name: trainer
              volumeMounts:
                - name: training-data
                  mountPath: /data
              command:
                - /bin/bash
                - -c
                - |
                  # 训练代码访问 /data 目录
                  python train.py --data-dir=/data
          volumes:
            - name: training-data
              persistentVolumeClaim:
                claimName: training-data-pvc
          restartPolicy: Never
```

创建训练数据PVC：

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: training-data-pvc
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: rook-cephfs
  resources:
    requests:
      storage: 500Gi
```

## 故障排查

### 问题1：PVC一直Pending

```bash
# 检查CSI驱动
kubectl get pods -n rook-ceph | grep csi

# 查看PVC事件
kubectl describe pvc cephfs-pvc

# 检查StorageClass
kubectl get storageclass rook-cephfs -o yaml
```

### 问题2：Pod无法挂载

```bash
# 检查CSI Node插件
kubectl logs -n rook-ceph -l app=csi-cephfsplugin --tail=100

# 检查节点上的挂载
kubectl debug node/<node-name> -it --image=busybox
# 在debug容器中：mount | grep ceph
```

### 问题3：性能不佳

```bash
# 检查Ceph集群状态
kubectl exec -n rook-ceph -it rook-ceph-tools -- ceph -s

# 检查OSD状态
kubectl exec -n rook-ceph -it rook-ceph-tools -- ceph osd df

# 检查网络延迟
kubectl exec -n rook-ceph -it rook-ceph-tools -- ceph osd perf
```

## 监控和告警

### 1. 安装Prometheus监控

Rook自动暴露Prometheus指标：

```bash
# 查看ServiceMonitor
kubectl get servicemonitor -n rook-ceph

# 配置Prometheus抓取（如果使用Prometheus Operator）
# Rook会自动创建ServiceMonitor
```

### 2. 关键指标

- `ceph_cluster_total_bytes`: 集群总容量
- `ceph_cluster_total_used_bytes`: 已使用容量
- `ceph_mds_client_requests`: MDS请求数
- `ceph_osd_op_r_latency`: 读操作延迟
- `ceph_osd_op_w_latency`: 写操作延迟

## 参考资源

- **Ceph官方文档**: https://docs.ceph.com/
- **Rook官方文档**: https://rook.io/docs/rook/latest/
- **ceph-csi GitHub**: https://github.com/ceph/ceph-csi
- **Ceph Dashboard**: https://docs.ceph.com/en/latest/mgr/dashboard/

## 下一步

1. ✅ 完成POC部署
2. 📊 进行性能基准测试
3. 🔍 验证审计功能
4. 🚀 小规模试点
5. 📈 生产部署

