1、首先创建账号</br>
aws configure</br>
输入用户名密码以及区域之后，创建一个IAM用户kops</br>
aws iam create-group --group-name kops</br>
aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess --group-name kops</br>
aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonRoute53FullAccess --group-name kops</br>
aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess --group-name kops</br>
aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/IAMFullAccess --group-name kops</br>
aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonVPCFullAccess --group-name kops</br>
aws iam create-user --user-name kops</br>
aws iam add-user-to-group --user-name kops --group-name kops</br>
2、创建好了账号之后，为kops创建AccessKeyID和SecretAccessKey</br>
创建好了之后，利用aws configure重新登录</br>
同时还需要将kops用户的密钥导出到命令行的环境变量：</br>
export AWS_ACCESS_KEY_ID=$(aws configure get aws_access_key_id)</br>
export AWS_SECRET_ACCESS_KEY=$(aws configure get aws_secret_access_key)</br>
export AWS_REGION=$(aws configure get region)</br>
最后生成ssh秘钥</br>
ssh-keygen -t rsa</br>
这个秘钥是创建好集群之后用来登录创建好的集群服务器用的</br>
3、后面的步骤参考</br>
https://github.com/helloxizhao/k8s.git</br>
k8s/kops-cn</br>
4、里面的搭建步骤，按照里面的步骤搭建好之后，我们来创建ingress，其中ingress的搭建步骤参照</br>
https://github.com/helloxizhao/k8s.git</br>
k8s/ingress-controller/deploy</br>
我们只需要apply mandatory.yml这个文件就好了</br>
5、ingress 搭建好之后创建一个应用并且和其进行关联，参照</br>
https://github.com/helloxizhao/k8s.git</br>
对k8s/app/nginx-deploy.yml 和nginx-svc这两个文件进行应用，创建好之后然后创建ingress对service进行暴露</br>
6、之后进行hpa的搭建，在k8s1.8之后默认的使用metric-server代替了原来heapster进行节点信息的统计，下面开始deploy metric-server</br>
具体的方式参照</br>
https://github.com/helloxizhao/k8s.git</br>
k8s/metric-server/1.8+</br>
直接apply -f ./ 即可，里面的配置已经改好了</br>
如果metric-server搭建好了，可以使用下面的命令进行安装情况的检查</br>
[root@ip-172-31-58-198 k8s]# kubectl api-versions</br>
admissionregistration.k8s.io/v1beta1</br>
apiextensions.k8s.io/v1beta1</br>
apiregistration.k8s.io/v1</br>
apiregistration.k8s.io/v1beta1</br>
apps/v1</br>
apps/v1beta1</br>
apps/v1beta2</br>
authentication.k8s.io/v1</br>
authentication.k8s.io/v1beta1</br>
authorization.k8s.io/v1</br>
authorization.k8s.io/v1beta1</br>
autoscaling/v1</br>
autoscaling/v2beta1</br>
batch/v1</br>
batch/v1beta1</br>
certificates.k8s.io/v1beta1</br>
events.k8s.io/v1beta1</br>
extensions/v1beta1</br>
metrics.k8s.io/v1beta1</br>
networking.k8s.io/v1</br>
policy/v1beta1</br>
rbac.authorization.k8s.io/v1</br>
rbac.authorization.k8s.io/v1beta1</br>
storage.k8s.io/v1</br>
storage.k8s.io/v1beta1</br>
v1</br>
api versions里面一定要有metrics.k8s.io/v1beta1这个API组</br>
然后执行</br>
[root@ip-172-31-58-198 k8s]# kubectl top node</br>
NAME CPU(cores) CPU% MEMORY(bytes) MEMORY%</br>
ip-172-31-48-63.cn-north-1.compute.internal 65m 3% 1287Mi 37%</br>
ip-172-31-58-198.cn-north-1.compute.internal 147m 7% 1910Mi 55%</br>
如果能显示资源的利用率就可以了</br>
7、创建hpa和deploy进行关联</br>
参照k8s/app hpa.yml</br>
刚刚创建的knginx这个deploy就和hpa关联起来了</br>
[root@ip-172-31-58-198 k8s]# kubectl get hpa</br>
NAME REFERENCE TARGETS MINPODS MAXPODS REPLICAS AGE</br>
knginx-hpa Deployment/knginx 0%/3% 1 20 1 6h</br>
执行上面的命令也能看见hpa的利用率</br>
8、CA（cluster-autoscaler）实现的是当出现hpa对应的deploy的pod有pending的状态，就会根据aws的auto scaling组进行扩展节点的操作，节点扩展几个要看我们对应的aws asg默认的策略。</br>
下面来部署autoscaler</br>
参照</br>
https://github.com/helloxizhao/k8s.git</br>
k8s/autoscaler/aws/examples</br>
里面有四个文件</br>
其中分别为</br>
cluster-autoscaler-autodiscover.yaml</br>
cluster-autoscaler-multi-asg.yaml</br>
cluster-autoscaler-one-asg.yaml</br>
cluster-autoscaler-run-on-master.yaml</br>
其中第一个文件为，这时候我们更改command中的- --node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/<YOUR CLUSTER NAME></br>
这个集群的名字，我们集群中的所有创建的autoscaling组建成asg都会被添加进来。</br>
cluster-autoscaler-multi-asg.yaml</br>
这个文件</br>
command:</br>
- ./cluster-autoscaler</br>
- --v=4</br>
- --stderrthreshold=info</br>
- --cloud-provider=aws</br>
- --skip-nodes-with-local-storage=false</br>
- --expander=least-waste</br>
- --nodes=1:10:k8s-worker-asg-1</br>
- --nodes=1:3:k8s-worker-asg-2</br>
这块我们可以添加多个asg,这个nodes的数量建议和awsconsole里面设置的一致，然后后面的就是asg的名称，名称要根据自己的实际情况填写。</br>
cluster-autoscaler-one-asg.yaml</br>
这个文件的话就是我们只想让某一个asg关联到autoscaler,比如在此处，我们只是想让node节点进行扩张，但是mater节点不用进行扩张，在此处我们就只需要进行一个asg的填写就好。</br>
cluster-autoscaler-run-on-master.yaml</br>
是不是希望pod运行在master上面，这个时候需要添加nodeselector来实现</br>
另外在创建的过程中有可能会出现image的pull问题，除了科学上网之外，我们需要将imagePullPolicy改为IfNotPresent，</br>
此处我们直接使用cluster-autoscaler-one-asg.yaml即可</br>
创建好之后，我们就可以对暴露出来的Nginx服务进行压测了</br>
while true:</br>
do</br>
ab -n 100000 -c 1000 http://knginx.gagogroup.cn/index.html</br>
done</br>
然后在master终端节点kubectl get pod -w</br>
查看pod的创建情况，如果pending的话，一会后面就会有新的node添加进来了</br>
