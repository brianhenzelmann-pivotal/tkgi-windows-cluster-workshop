# TKGI Windows Workloads
These instructions walk through setting up TKGI Kubernetes clusters for Windows worker nodes on vSphere. It is assumed that you have a basic understanding of BOSH, configuring the TKGI tile for Linux worker nodes, and interacting with Kubernetes through the `kubectl` CLI.

## Setup and Installation
- Install and configure TKGI 1.6+ in OpsManager 2.6+ with Flannel CNI networking
  (Note: NSX-T 3.0.1 and NCP 3.0.0 are in beta support starting in 1.8)
- Configure Plans 11+ for Windows Kubernetes clusters
  - Name (example: small.windows, large.windows)
  - Description
  - Master / ETCD Node Instances (1, 3, or 5)
  - Master VM Type (at least 4GB RAM, 2 CPUs)
  - Master Persistent Disk (at least 10GB)
  - Master AZs
  - Worker Node Instances (example: 1, 5)
  - Worker VM Type (recommended at least 8GB-16GB RAM and 4 CPUs)
- Upload Windows 2019.7+ stemcell and apply to TKGI
- Apply changes

## Create Cluster

### View Plans
After applying changes for TKGI and its Windows-based plans, you should now be able to create Windows-based clusters.
``` bash
tkgi plans
```
Confirm you can see the newly configured Windows-based plan(s).

### Create Cluster

Using the following as a template:
``` bash
tkgi create-cluster <cluster-name> -p <plan-name> -e <external-hostname>
```
Create a new cluster. Give the cluster a name, use a Windows-based plan, and provide an available external hostname.
Here is an example:
``` bash
tkgi create-cluster windows-test -p small.windows -e windows-k8s.my.domain
```
Optionally, you can create a cluster using the `--wait` flag to follow the provisioning process

Depending on your sizing, creating a cluster make take several minutes.

### Setting Hostname
Check the progress of provisioning with the following:
``` bash
tkgi cluster <cluster-name>
```

After the cluster has created successfully, the output of the above command will show you the IPs of your master nodes. Update your DNS settings to point to the master IP. If you have a mult-master cluster, you will want to load balance across the IPs. 

### Get Cluster Credentials
After you have setup the hostname for the cluster, you can grab the credentials to start using the Kubernets CLI.
``` bash
tkgi get-credentials <cluster-name>
```
This will update your `kubectl` context to point to the newly created cluster.

### Check Kubernetes Nodes
After changing context to your newly created cluster, check that the worker nodes are running Windows.
``` bash
kubectl get nodes -o wide
```
Under `OS-IMAGE`, you should see `Windows Server 2019 Datacenter` for each worker node you've configured in your plan.

### Check for Node Taints
A Kubernetes Taint will restrict scheduling resources on a specific node unless a toleration for the taint is specified. 

After listing available nodes in the above step, pick the `NAME` of one the Windows nodes and run the following command:
``` bash
kubectl get nodes <node-name> -o jsonpath='{.spec.taints[0]}'
```
Note that there should a taint similar to below:
```
map[effect:NoSchedule key:windows value:2019]
```
You will need a toleration to ensure .NET Framework workloads will successfully schedule to one of these nodes.

### Deploying a HelloWorld .NET Framework App
Now that you've confirmed you're running a Windows-based cluster, you can deploy a .NET Framework container.

You can build your own app and publish to your own registry or start from the Dockerfile found in the `hello-world` directory.

The following command will scaffold a Kubernetes Deployment with 3 replicas. You will need to make some alterations.
``` bash
kubectl run hello-world --image harbor.homelab.brianhenzelmann.com/windows/hello-world:1.0.0 --replicas 3  --dry-run -o yaml > ./hello-world-deployment.yaml
```
The output should look similar to below:
``` yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  creationTimestamp: null
  labels:
    run: hello-world
  name: hello-world
spec:
  replicas: 3
  selector:
    matchLabels:
      run: hello-world
  strategy: {}
  template:
    metadata:
      creationTimestamp: null
      labels:
        run: hello-world
    spec:
      containers:
      - image: harbor.homelab.brianhenzelmann.com/windows/hello-world
        name: hello-world
        resources: {}
status: {}

```

Before applying this, a toleration needs to be added to the container spec (found at .spec.template.spec)
``` yaml
...
spec:
  ...
  template:
    ...
    spec:
      ...
      tolerations:
        - key: windows
          value: "2019"
          effect: NoSchedule
```
Note that the values should match the taint from the node in the above step.
Also note that `2019` should be surrounded by quotes.

Optionally, a `nodeSelector` can be added for additional confidence that the workload will schedule on the Windows node.

Now that the deployment has been updated, you can apply changes.

``` bash
kubectl apply -f ./hello-world-deployment.yaml
```

### View Deployment Status
#### Deployment Status
After applying changes above, you should be able to see the new deployment

``` bash
kubectl get deploy
```

```
NAME         READY   UP-TO-DATE   AVAILABLE   AGE
hello-world   0/3     3            0           3s
```

#### Pod Status
You should also be able to see the status of each pod from the deployment's replica set.
``` bash
kubectl get po
```

```
NAME                          READY   STATUS              RESTARTS   AGE
hello-world-57768b5484-fxq7j   0/1     ContainerCreating   0          3s
hello-world-57768b5484-wh4zd   0/1     ContainerCreating   0          3s
hello-world-57768b5484-wtqd8   0/1     ContainerCreating   0          3s
```

#### Pod Events
While the container is creating, you can view its events.
``` bash
kubectl describe po <pod-name>
```
At the bottom, you will find a series of events.
```
Events:
  Type    Reason     Age   From                                           Message
  ----    ------     ----  ----                                           -------
  Normal  Scheduled  35s   default-scheduler                              Successfully assigned default/hello-world-57768b5484-fxq7j to 96f208b5-c21b-418b-b106-5423c3dd7cef
  Normal  Pulling    19s   kubelet, 96f208b5-c21b-418b-b106-5423c3dd7cef  Pulling image "harbor.homelab.brianhenzelmann.com/windows/hello-world"
  Normal  Pulled     19s   kubelet, 96f208b5-c21b-418b-b106-5423c3dd7cef  Successfully pulled image "harbor.homelab.brianhenzelmann.com/windows/hello-world"
  Normal  Created    18s   kubelet, 96f208b5-c21b-418b-b106-5423c3dd7cef  Created container hello-world
  Normal  Started    6s    kubelet, 96f208b5-c21b-418b-b106-5423c3dd7cef  Started container hello-world
```

#### Pod Node Placement
After the pods are running, you should be able to find the `IP` address and `NODE` for each pod.
``` bash
kubectl get po -o wide
```
```
NAME                          READY   STATUS    RESTARTS   AGE     IP           NODE                                   NOMINATED NODE   READINESS GATES
hello-world-57768b5484-fxq7j   1/1     Running   0          2m57s   10.200.4.7   96f208b5-c21b-418b-b106-5423c3dd7cef   <none>           <none>
hello-world-57768b5484-wh4zd   1/1     Running   0          2m57s   10.200.4.8   96f208b5-c21b-418b-b106-5423c3dd7cef   <none>           <none>
hello-world-57768b5484-wtqd8   1/1     Running   0          2m57s   10.200.4.6   96f208b5-c21b-418b-b106-5423c3dd7cef   <none>           <none>
```

The pod IP addresses should be inaccessible outside of the cluster.

## Expose Application with Service
Now that the application is deployed, you can expose the application through a Kubernetes Service. This service can be through ClusterIP, NodePort, or LoadBalancer. For this demo, the preferred option is LoadBalancer, but you can try other options.

Note: the application listens on port 80

### ClusterIP (Default)
The ClusterIP service will expose the deployment internal to the cluster with a single cluster IP from within the configured CIDR range.
``` bash
kubectl expose deployment hello-world --port 80
```

The created service can be seen here:
``` bash
kubectl get svc
```

```
NAME         TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
hello-world   ClusterIP   10.100.200.100   <none>        80/TCP    9s
```

Since the goal is to access this deployment from outside the cluster, you can delete this service.
``` bash
kubectl delete svc hello-world
```

### NodePort
The NodePort service will expose the deployment on a specific port through any of the cluster node IPs.

```
kubectl expose deployment hello-world --port 80 --type NodePort
```

The created service can be seen here:
``` bash
kubectl get svc
```

```
NAME         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
hello-world   NodePort    10.100.200.30   <none>        80:30679/TCP   46s
```

Notice the port that was mapped to an open port. In the above example, `30679`.

You should now be able to grab the IP of any of your nodes
``` bash
kubectl get node -o wide
```
And use the port from the service to route to one of the running pods.
```
NAME                                   STATUS   ROLES    AGE     VERSION   INTERNAL-IP     EXTERNAL-IP     OS-IMAGE                         KERNEL-VERSION      CONTAINER-RUNTIME
6700e61a-4e76-451f-90e7-0cc89cb20b03   Ready    <none>   4h3m    v1.15.5   192.168.89.17   192.168.89.17   Ubuntu 16.04.6 LTS               4.15.0-66-generic   docker://18.9.9
96f208b5-c21b-418b-b106-5423c3dd7cef   Ready    <none>   3h59m   v1.15.4   192.168.89.18   192.168.89.18   Windows Server 2019 Datacenter   10.0.17763.557      docker://18.9.9
```

`http://192.168.89.18:30679`

You may notice a warming period with this particular application.

From here, a load balancer could be setup to point to all worker nodes for the exposed port, but a LoadBalancer service will be preferred, so you can delete this service.

``` bash
kubectl delete svc hello-world
```

#### LoadBalancer
Since the Container Networking Interface used was Flannel, your Kubernetes cluster won't know how to create a load balancer within vSphere.

Note: For the demo purposes, you can install MetalLB. However, MetalLB requires access to host networking, which the Windows nodes do not support. You will see an IP address assigned for the load balancer, but traffic will not route.

##### MetalLB Installation
Following the instructions in https://metallb.universe.tf/installation/, install MetalLB. The versions will change over time, but the installation is currently as follows:
```
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.3/manifests/namespace.yaml
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.3/manifests/metallb.yaml
# On first install only
kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
```
This will create the necessary resources to implement services of type LoadBalancer except for your specific configuration. You will need to create a configmap to specify the IP ranges to use.

Create the following `metallb-config.yaml` file updating the addresses based on the network you are using:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - 192.168.1.240-192.168.1.250
```
Apply the configmap:
``` bash
kubectl apply -f ./metallb-config.yaml
```

##### Create LoadBalancer Service
Now that MetalLB is setup, your Kubernetes cluster knows how to provision a load balancer.

``` bash
kubectl expose deployment hello-world --port 80 --type LoadBalancer
```

Now when you list services,
``` bash
kubectl get svc
```
You should be able to see an `EXTERNAL-IP` that can be better used for load balancing.
```
NAME         TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)        AGE
hello-world   LoadBalancer   10.100.200.14   192.168.200.1   80:30984/TCP   4s
```

This IP address will not successfully route because the Windows nodes do not support host networking; however, MetalLB can still be useful for Layer 7 load balancing with Contour.

## Expose Application with Ingress
Services are great ways to expose applications, but IP addresses and ports are not typically appropriate to send end users. Typically, you will want to provide a fully qualified domain name (FQDN). It's certainly possible to manage DNS entries with the IP addresses, but there's a better way - an ingress controller.

An ingress controller acts as a Layer 7 load balancer to translate human readable FQDN web addresses into running services and pods. This gives you easy dynamic routing abilities. 

One great OSS ingress controller is [Project Contour](https://projectcontour.io/). 

### Install Project Contour
The easiest way to setup Project Contour is to run the below command, found from https://projectcontour.io/getting-started/:
```bash
kubectl apply -f https://projectcontour.io/quickstart/contour.yaml
```

This will create a new `projectcontour` namespace containing a Contour deployment, which acts as the ingress controller implementation, and an Envoy daemonset, which handles the routing to pods via services, as defined by an `Ingress`.

```bash
kubectl get all -n projectcontour
```

You should be able to see a service of type LoadBalancer created for the Envoy daemonset. In order to route traffic to an application, you must define an Ingress route. 

```yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: hello-world-ingress
spec:
  rules:
  - host: helloworld.windows-cluster.homelab.brianhenzelmann.com
    http:
      paths:
      - backend:
          serviceName: hello-world-svc
          servicePort: 80
```

```bash
kubectl apply -f ./ingress.yaml
```

Contour is setup to listen to these definitions and will route traffic accordingly. HTTP requests made to the LoadBalancer IP with the `host` header set will route to the specified service.

Because ingress routes are typically dynamically defined, a wildcard DNS A record pointing to the LoadBalancer IP will ensure newly defined ingress routes will not require DNS changes.

```bash
curl -H 'Host: helloworld.windows-cluster.homelab.brianhenzelmann.com' 192.168.101.200
```

## Stateful Services
Stateful services are the backbone of most applications. Databases, queues, or apps with persistent disk. These key building blocks that accelerate custom applications, but locating and consuming these services is like living in the wild west. Docker Hub has many services to choose from, but that comes with the uncertainty of where the bits come from. 

Registries like Bitnami provide a curated list of stateful services that are scanned, tested, and validated to work. Once a list is curated, a provisioner is the next step.  Enter [Kubeapps](https://kubeapps.com/).

Kubeapps will connect to registries to allow you to deploy stateful data services, like Postgres, Redis, and the ELK stack. 

### Install Kubeapps
The following command will install the Kubeapps system in a new namespace.
```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
kubectl create namespace kubeapps
helm install kubeapps --namespace kubeapps bitnami/kubeapps --set useHelm3=true
```

### Expose Kubeapps
```bash
---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: kubeapps-ingress
  namespace: kubeapps
spec:
  rules:
  - host: kubeapps.windows-cluster.homelab.brianhenzelmann.com
    http:
      paths:
      - backend:
          serviceName: kubeapps
          servicePort: 80
```

```bash
kubectl apply -f ./ingress.yaml
```

You should now be able to navigate to https://kubeapps.windows-cluster.homelab.brianhenzelmann.com.

### Access Kubeapps

Notice when accessing Kubeapps, it asks for an API token. This is the Kubernetes token used to access namespaces, deploy apps, set secrets, etc.

Review the instructions found [here](https://github.com/kubeapps/kubeapps/blob/master/docs/user/getting-started.md) to determine the roles you want to expose. 

For this demo, we will use `clusteradmin` privileges. 

```bash
kubectl create serviceaccount kubeapps-operator
kubectl create clusterrolebinding kubeapps-operator --clusterrole=cluster-admin --serviceaccount=default:kubeapps-operator

kubectl get secret $(kubectl get serviceaccount kubeapps-operator -o jsonpath='{range .secrets[*]}{.name}{"\n"}{end}' | grep kubeapps-operator-token) -o jsonpath='{.data.token}' -o go-template='{{.data.token | base64decode}}' && echo
```

Paste the resulting token in Kubeapps.

### Provision a Stateful Service - MS SQL

Take a look at the catalog. The services are made available from various registries that are all publicly managed. Tanzu Application Catalog allows you to currate your own list, ensure proof of provenance, functionally test, and provide your own base image.

For this demo, locate the `mssql` service and provision an instance with the `sapassword` variable set to `password`.

Once the MSSQL instance is created, expose the service using the `mssql` service name. 

```bash
kubectl expose deploy <mssql-deployment-name> --name mssql --port 1433
```
### Define Storage Class
Since this service is a stateful service, it requires a persistent volume attached. Run the below command to check on the `PersistentVolumeClaims`

```bash
kubectl get pvc
```

Notice that they're all in a pending status.

In order to attach persistent storage to this claim, a storage class must be defined. 

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: thin-disk
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: kubernetes.io/vsphere-volume
parameters:
  diskformat: thin
  datastore: <datastore-name>
```
```bash
kubectl apply -f ./thin-storage-class.yaml
```
Now when you view PVCs
```bash
kubectl get pvc
```
You should see bound persistent volumes.


