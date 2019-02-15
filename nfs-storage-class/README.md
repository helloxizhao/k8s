nfs 实现storageclass</br>
nfs的storageclass需要使用外部的provisioner,下面介绍下实现方式</br>
1、应用deployment.yaml</br>
apiVersion: v1</br>
kind: ServiceAccount</br>
metadata:</br>
name: nfs-client-provisioner</br>
---</br>
kind: Deployment</br>
apiVersion: extensions/v1beta1</br>
metadata:</br>
name: nfs-client-provisioner</br>
spec:</br>
replicas: 1</br>
strategy:</br>
type: Recreate</br>
template:</br>
metadata:</br>
labels:</br>
app: nfs-client-provisioner</br>
spec:</br>
serviceAccountName: nfs-client-provisioner</br>
containers:</br>
- name: nfs-client-provisioner</br>
image: harbor.gagogroup.cn/kops/nfs-client-provisioner</br>
imagePullPolicy: IfNotPresent</br>
volumeMounts:</br>
- name: nfs-client-root</br>
mountPath: /persistentvolumes</br>
env:</br>
- name: PROVISIONER_NAME</br>
value: fuseim.pri/ifs</br>
- name: NFS_SERVER</br>
value: 192.168.8.29</br>
- name: NFS_PATH</br>
value: /nfsdata</br>
volumes:</br>
- name: nfs-client-root</br>
nfs:</br>
server: 192.168.8.29</br>
path: /nfsdata</br>
其中nfs_server地址和数据目录的位置根据自己的需求更改即可。</br>
2、创建SC</br>
apiVersion: storage.k8s.io/v1</br>
kind: StorageClass</br>
metadata:</br>
name: managed-nfs-storage</br>
provisioner: fuseim.pri/ifs # or choose another name, must match deployment's env PROVISIONER_NAME'</br>
parameters:</br>
archiveOnDelete: "false"</br>
3、创建rbac</br>
kind: ServiceAccount</br>
apiVersion: v1</br>
metadata:</br>
name: nfs-client-provisioner</br>
---</br>
kind: ClusterRole</br>
apiVersion: rbac.authorization.k8s.io/v1</br>
metadata:</br>
name: nfs-client-provisioner-runner</br>
rules:</br>
- apiGroups: [""]</br>
resources: ["persistentvolumes"]</br>
verbs: ["get", "list", "watch", "create", "delete"]</br>
- apiGroups: [""]</br>
resources: ["persistentvolumeclaims"]</br>
verbs: ["get", "list", "watch", "update"]</br>
- apiGroups: ["storage.k8s.io"]</br>
resources: ["storageclasses"]</br>
verbs: ["get", "list", "watch"]</br>
- apiGroups: [""]</br>
resources: ["events"]</br>
verbs: ["create", "update", "patch"]</br>
---</br>
kind: ClusterRoleBinding</br>
apiVersion: rbac.authorization.k8s.io/v1</br>
metadata:</br>
name: run-nfs-client-provisioner</br>
subjects:</br>
- kind: ServiceAccount</br>
name: nfs-client-provisioner</br>
namespace: default</br>
roleRef:</br>
kind: ClusterRole</br>
name: nfs-client-provisioner-runner</br>
apiGroup: rbac.authorization.k8s.io</br>
---</br>
kind: Role</br>
apiVersion: rbac.authorization.k8s.io/v1</br>
metadata:</br>
name: leader-locking-nfs-client-provisioner</br>
rules:</br>
- apiGroups: [""]</br>
resources: ["endpoints"]</br>
verbs: ["get", "list", "watch", "create", "update", "patch"]</br>
---</br>
kind: RoleBinding</br>
apiVersion: rbac.authorization.k8s.io/v1</br>
metadata:</br>
name: leader-locking-nfs-client-provisioner</br>
subjects:</br>
- kind: ServiceAccount</br>
name: nfs-client-provisioner</br>
# replace with namespace where provisioner is deployed</br>
namespace: default</br>
roleRef:</br>
kind: Role</br>
name: leader-locking-nfs-client-provisioner</br>
apiGroup: rbac.authorization.k8s.io</br>
4、创建pvc</br>
apiVersion: v1</br>
metadata:</br>
name: test-claim</br>
annotations:</br>
volume.beta.kubernetes.io/storage-class: "managed-nfs-storage"</br>
spec:</br>
accessModes:</br>
- ReadWriteMany</br>
resources:</br>
requests:</br>
storage: 10Mi</br>
5、创建pod，挂载PVC</br>
kind: Pod</br>
apiVersion: v1</br>
metadata:</br>
name: test-pod</br>
spec:</br>
containers:</br>
- name: test-pod</br>
image: gcr.io/google_containers/busybox:1.24</br>
command:</br>
- "/bin/sh"</br>
args:</br>
- "-c"</br>
- "touch /mnt/SUCCESS && exit 0 || exit 1"</br>
volumeMounts:</br>
- name: nfs-pvc</br>
mountPath: "/mnt"</br>
restartPolicy: "Never"</br>
volumes:</br>
- name: nfs-pvc</br>
persistentVolumeClaim:</br>
claimName: test-claim</br>
pv的回收策略：</br>
retain：保留）——手动回收</br>
recycle：（回收）——基本擦除（rm -rf /thevolume/*）</br>
delete：删除）——关联的存储资产（例如 AWS EBS、GCE PD、Azure Disk 和 OpenStack Cinder 卷）将被删除</br>
当前，只有 NFS 和 HostPath 支持回收策略。AWS EBS、GCE PD、Azure Disk 和 Cinder 卷支持删除策略。</br>
默认的策略是delete，如果数据重要的话需要讲策略改为retain，这样子就算是pvc删除了，数据还是能够进行下次绑定，在此恢复的。</br>
</br>
</br>
</br>
