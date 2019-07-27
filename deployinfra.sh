# Set up terraform provisioning
terraform init ./topology
terraform plan -out ./topology/plan.out ./topology
terraform apply "./topology/plan.out"

# Config kubectl and test k8s
echo "$(terraform output kube_config)" > ./topology/azurek8s
export KUBECONFIG=topology/azurek8s
kubectl get nodes

# Configure k8s security policy
az aks update --resource-group azure-k8stest --name k8stest --enable-pod-security-policy

# Deploy k8s pods
kubectl apply -f pod.yml

# Apply autoscale
kubectl autoscale deployment my-api --min=2 --max=5 --cpu-percent=80