# 设计分析笔记

## PV/PVC
使用PV/PVC的动机:
- 可在StorageClass中定义IOPS, throughput等精细化管理参数,避免直接存储移动导致本地盘僵死

## Job
Job层面可做的任务调度设定
- nodeAffinity: 设置节点亲和性,选择SSD/NVMe节点执行IO密集任务
e.g. 
nodeSelectorTerms[0].matchExpressions[0].key=disk.type
nodeSelectorTerms[0].matchExpressions[0].operator=In
nodeSelectorTerms[0].matchExpressions[0].values= ["nvme", "ssd"]


