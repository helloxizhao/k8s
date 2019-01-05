1、首先创建账号
aws configure
输入用户名密码以及区域之后，创建一个IAM用户kops
aws iam create-group --group-name kops
aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess --group-name kops
aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonRoute53FullAccess --group-name kops
aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess --group-name kops
aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/IAMFullAccess --group-name kops
aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonVPCFullAccess --group-name kops
aws iam create-user --user-name kops
aws iam add-user-to-group --user-name kops --group-name kops
2、创建好了账号之后，为kops创建AccessKeyID和SecretAccessKey
创建好了之后，利用aws configure重新登录
同时还需要将kops用户的密钥导出到命令行的环境变量：
export AWS_ACCESS_KEY_ID=$(aws configure get aws_access_key_id)
export AWS_SECRET_ACCESS_KEY=$(aws configure get aws_secret_access_key)
export AWS_REGION=$(aws configure get region)
最后生成ssh秘钥
ssh-keygen -t rsa
这个秘钥是创建好集群之后用来登录创建好的集群服务器用的
3、后面的步骤参考
https://github.com/helloxizhao/k8s.git
k8s/kops-cn
4、里面的搭建步骤，按照里面的步骤搭建好之后，我们来创建ingress，其中ingress的搭建步骤参照
https://github.com/helloxizhao/k8s.git
k8s/ingress-controller/deploy
我们只需要apply  mandatory.yml这个文件就好了
5、ingress 搭建好之后创建一个应用并且和其进行关联，参照
https://github.com/helloxizhao/k8s.git
对k8s/app/nginx-deploy.yml 和nginx-svc这两个文件进行应用，创建好之后然后创建ingress对service进行暴露
6、之后进行hpa的搭建，在k8s1.8之后默认的使用metric-server代替了原来heapster进行节点信息的统计，下面开始deploy metric-server
具体的方式参照
https://github.com/helloxizhao/k8s.git
k8s/metric-server/1.8+
直接apply  -f ./ 即可，里面的配置已经改好了
如果metric-server搭建好了，可以使用下面的命令进行安装情况的检查
[root@ip-172-31-58-198 k8s]# kubectl api-versions
admissionregistration.k8s.io/v1beta1
apiextensions.k8s.io/v1beta1
apiregistration.k8s.io/v1
apiregistration.k8s.io/v1beta1
apps/v1
apps/v1beta1
apps/v1beta2
authentication.k8s.io/v1
authentication.k8s.io/v1beta1
authorization.k8s.io/v1
authorization.k8s.io/v1beta1
autoscaling/v1
autoscaling/v2beta1
batch/v1
batch/v1beta1
certificates.k8s.io/v1beta1
events.k8s.io/v1beta1
extensions/v1beta1
metrics.k8s.io/v1beta1
networking.k8s.io/v1
policy/v1beta1
rbac.authorization.k8s.io/v1
rbac.authorization.k8s.io/v1beta1
storage.k8s.io/v1
storage.k8s.io/v1beta1
v1
api versions里面一定要有metrics.k8s.io/v1beta1这个API组
然后执行
[root@ip-172-31-58-198 k8s]# kubectl  top node
NAME                                           CPU(cores)   CPU%      MEMORY(bytes)   MEMORY%   
ip-172-31-48-63.cn-north-1.compute.internal    65m          3%        1287Mi          37%       
ip-172-31-58-198.cn-north-1.compute.internal   147m         7%        1910Mi          55%       
如果能显示资源的利用率就可以了
7、创建hpa和deploy进行关联
参照k8s/app  hpa.yml
刚刚创建的knginx这个deploy就和hpa关联起来了
[root@ip-172-31-58-198 k8s]# kubectl get hpa
NAME         REFERENCE           TARGETS   MINPODS   MAXPODS   REPLICAS   AGE
knginx-hpa   Deployment/knginx   0%/3%     1         20        1          6h
执行上面的命令也能看见hpa的利用率
8、CA（cluster-autoscaler）实现的是当出现hpa对应的deploy的pod有pending的状态，就会根据aws的auto scaling组进行扩展节点的操作，节点扩展几个要看我们对应的aws asg默认的策略。
下面来部署autoscaler
参照
https://github.com/helloxizhao/k8s.git
k8s/autoscaler/aws/examples
里面有四个文件
其中分别为
cluster-autoscaler-autodiscover.yaml
cluster-autoscaler-multi-asg.yaml
cluster-autoscaler-one-asg.yaml
cluster-autoscaler-run-on-master.yaml
其中第一个文件为，这时候我们更改command中的- --node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/<YOUR CLUSTER NAME>
这个集群的名字，我们集群中的所有创建的autoscaling组建成asg都会被添加进来。
cluster-autoscaler-multi-asg.yaml
这个文件
command:
            - ./cluster-autoscaler
            - --v=4
            - --stderrthreshold=info
            - --cloud-provider=aws
            - --skip-nodes-with-local-storage=false
            - --expander=least-waste
            - --nodes=1:10:k8s-worker-asg-1
            - --nodes=1:3:k8s-worker-asg-2
这块我们可以添加多个asg,这个nodes的数量建议和awsconsole里面设置的一致，然后后面的就是asg的名称，名称要根据自己的实际情况填写。
cluster-autoscaler-one-asg.yaml
这个文件的话就是我们只想让某一个asg关联到autoscaler,比如在此处，我们只是想让node节点进行扩张，但是mater节点不用进行扩张，在此处我们就只需要进行一个asg的填写就好。
cluster-autoscaler-run-on-master.yaml
是不是希望pod运行在master上面，这个时候需要添加nodeselector来实现
另外在创建的过程中有可能会出现image的pull问题，除了科学上网之外，我们需要将imagePullPolicy改为IfNotPresent，
此处我们直接使用cluster-autoscaler-one-asg.yaml即可
创建好之后，我们就可以对暴露出来的Nginx服务进行压测了
while true:
do
ab -n 100000 -c 1000 http://knginx.gagogroup.cn/index.html
done
然后在master终端节点kubectl get pod -w
查看pod的创建情况，如果pending的话，一会后面就会有新的node添加进来了



