#!/bin/bash
set -o errexit

# USAGE:
#
# KIND_CLUSTER_NAME="kind";
# KIND_NODE_IMAGE="kindest/node:v1.14.10";
# ./kind-with-ingress.sh

# REQUIREMENTS:
# 1. kind
# 2. kubectl

# LATEST TIME:
# ./kind-with-ingress.sh  5.21s user 2.94s system 7% cpu 1:43.72 total

# parameters
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-"kind"}"
KIND_NODE_IMAGE="${KIND_NODE_IMAGE:-"kindest/node:v1.14.10"}"

# create a ingress-ready cluster
cat <<EOF | kind -v 3 create cluster --name "${KIND_CLUSTER_NAME}" --image=${KIND_NODE_IMAGE} --config=-
# 1 control-plane, 3 workers
# control-plane node ingress-ready and with ports 80,443 exposed
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
        authorization-mode: "AlwaysAllow"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
- role: worker
- role: worker
- role: worker
EOF

echo "waiting for all nodes to be 'Ready' ..."
kubectl wait --for=condition="Ready" nodes --all --timeout="5m"
echo "all nodes are ready"
kubectl get nodes -owide

# install ingress-nginx controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/nginx-0.30.0/deploy/static/mandatory.yaml;

kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/nginx-0.30.0/deploy/static/provider/baremetal/service-nodeport.yaml;

kubectl patch deployments -n ingress-nginx nginx-ingress-controller -p '{"spec":{"template":{"spec":{"containers":[{"name":"nginx-ingress-controller","ports":[{"containerPort":80,"hostPort":80},{"containerPort":443,"hostPort":443}]}],"nodeSelector":{"ingress-ready":"true"},"tolerations":[{"key":"node-role.kubernetes.io/master","operator":"Equal","effect":"NoSchedule"}]}}}}'

echo "waiting for nginx-ingress-controller to be 'Available' ..."
kubectl wait --for=condition="Available" -n ingress-nginx deployment/nginx-ingress-controller --timeout="5m"
echo "nginx-ingress-controller is 'Available'"

echo "cluster is ready!!!"
