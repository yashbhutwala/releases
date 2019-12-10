# kustomized from 2019.11 yamls

This configuration is meant for developers looking for a tiny Polaris Platform only deployment.  It removes Coverity specific pods, as well as other unnecessary pods in order to run the platform, as well as other production reduntant infrastructure.

So, you can run production equivalent Polaris on your laptop.

[x] do not deploy reporting
[x] remove `pericles-swagger-ui` and `notifications-service` deployments from "CORE"
[x] remove `jobfarmautoscaler`, `jobs-controller-service` deployments and `cleanup-k8s-jobs` cronjob from "JOBFARM"
[x] remove `configs-service`, `logs-service`, and `tools-service` deployments from "ANALYSIS SUPPORT"
[x] remove `desktop-metrics` deployment
[x] remove `download-minio` deployment
[x] remove `tools-sync-job`, and `tools-deprecate-job` jobs (cannot delete `tools-minio-secret-init` job because it's used for `upload-server`)
[x] remove `vault-exporter` and `eventstore-exporter` containers
[x] remove podDisruptionBudgets
[x] remove 'rollingUpdate: null' from minio (both upload and download server)
[x] update eventstore readiness check to check on port `2113`

Not implemented ideas:
[ ] change `eventstore` statefulset replicas from 3 -> 1 and also `EVENTSTORE_CLUSTER_SIZE` (used to work, but now it doesn't because auth-server requires eventstore to be a cluster)
[ ] minimize CPU and MEM requirements (specifically MEM for all containers)

Usage:

To create cluster

```bash
kind -v 10 create cluster --image kindest/node:v1.14.9 --config ~/kind-hacks/kind-multi-worker-cluster.yml
# use rancher's local-path-storage for dynamic volume provisioning
kubectl apply -f "https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.11/deploy/local-path-storage.yaml"
kubectl patch storageclass "local-path" -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
kubectl delete storageclass standard
```

```bash
kubectl create ns $NAMESPACE
export NAMESPACE="onprem"
export POLARIS_VERSION="2019.11"
# this is for the gcp service account used for gcr images
export GCP_SERVICE_ACCOUNT_PATH="${POLARIS_APP_PREREQUISITES_DIRECTORY}/gcp-service-account-token-for-images.json"
# this is the shared coverity license being used for testing
export COVERITY_LICENSE_PATH="${POLARIS_APP_PREREQUISITES_DIRECTORY}/coverity-license.xml"
# this is the shared polaris platform license being used for testing
export POLARIS_LICENSE_PATH="${POLARIS_APP_PREREQUISITES_DIRECTORY}/polaris-platform-license.json"
# CHANGE THIS!
export ADMIN_EMAIL="bhutwala@synopsys.com"
# CHANGE THIS IF YOU WANT!
export FQDN="yashonprem.dev.polaris.synopsys.com"
# synopsysctl command
./synopsysctl -v debug create polaris \
  --namespace $NAMESPACE \
  --version $POLARIS_VERSION \
  --fqdn $FQDN \
  --gcp-service-account-path $GCP_SERVICE_ACCOUNT_PATH \
  --polaris-license-path $POLARIS_LICENSE_PATH \
  --coverity-license-path $COVERITY_LICENSE_PATH \
  --smtp-host "XXX" \
  --smtp-port "XXX" \
  --smtp-username "XXX" \
  --smtp-password "XXX" \
  --smtp-sender-email "noreply@synopsys.com" \
  --organization-admin-email $ADMIN_EMAIL \
  --organization-admin-name "Polaris Test" \
  --organization-admin-username "test123" \
  --organization-description "myorg" \
  --enable-postgres-container \
  --postgres-password "postgres" \
  --postgres-size "1Gi" \
  --eventstore-size "1Gi" \
  --mongodb-size "1Gi" \
  --uploadserver-size "1Gi" \
  --downloadserver-size "1Gi" \
  --yaml-url "https://raw.githubusercontent.com/yashbhutwala/releases/yb-custom"
```
