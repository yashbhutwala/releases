# kustomized from 2019.11 yamls

This configuration is meant for developers looking for a tiny Polaris Platform only deployment.  It removes Coverity specific pods, as well as other unnecessary pods in order to run the platform, as well as other production reduntant infrastructure.

So, you can run production equivalent Polaris on your laptop.

- [x] do not deploy reporting
- [x] remove `pericles-swagger-ui` and `notifications-service` deployments from "CORE"
- [x] remove `jobfarmautoscaler`, `jobs-controller-service`, `jobs-service` deployments and `cleanup-k8s-jobs` cronjob from "JOBFARM"
- [x] remove `configs-service`, `logs-service`, and `tools-service` deployments from "ANALYSIS SUPPORT"
- [x] remove `desktop-metrics` deployment (only needed for CodeSight)
- [x] remove `download-minio` deployment and `tools-sync-job`, `tools-deprecate-job` jobs (cannot delete `tools-minio-secret-init` job because it's used for `upload-server`)
- [x] remove `tds-code-analysis` (TODO: replace with `csv-tds`)
- [x] remove `vault-exporter` and `eventstore-exporter` containers
- [x] remove podDisruptionBudgets
- [x] remove 'rollingUpdate: null' from minio (both upload and download server)
- [x] update eventstore readiness check to check on port `2113`

Not implemented ideas:

- [ ] change `eventstore` statefulset replicas from 3 -> 1 and also `EVENTSTORE_CLUSTER_SIZE` (used to work, but now it doesn't because `auth-server` requires `eventstore` to be setup as more than 1 node cluster; Scott says this should be configurable)
  - **Won't do** because it requires the java `config.yaml` to be made as a `configMap` and be overwritten to `/opt/auth-service/config.yaml` in all containers which use `eventstore`, specifically with this:

  ```yaml
    eventStoreConfiguration:
      connection:
        # replace the line below with COMMENTED line for clients to treate Eventstore as a single node
        class: "com.synopsys.pericles.eventstore.configuration.EventStoreConfiguration$ClusterUsingDnsConnection"
        # class: "com.synopsys.pericles.eventstore.configuration.EventStoreConfiguration$SingleNodeConnection"
    ```

- [ ] replace `tds-code-analysis` with a minimal `csv-tds`
- [ ] minimize CPU and MEM requirements (specifically MEM for all containers)
- [ ] Right now, `tools-sync-job` is actually tools-download-job and `tools-deprecate-job` is actually tools-delete-job, they can be made into one

## Prerequisites

- [Docker](https://docs.docker.com/install/)
- [KinD](https://kind.sigs.k8s.io/docs/user/quick-start)
  - MacOS users (most cases): `brew install kind`
- [synopsysctl >= 2019.11.0](https://github.com/blackducksoftware/synopsys-operator/releases/tag/2019.11.1)
  - MacOS user (most cases): `wget https://github.com/blackducksoftware/synopsys-operator/releases/download/2019.11.1/synopsysctl-darwin-amd64.zip && tar -xvf synopsysctl-darwin-amd64.zip -C /usr/local/bin`

## Usage

To create cluster

```bash
# Make sure all dependencies are installed
docker --version
kind version
kubectl version
synopsysctl --version

# Create kind cluster config file
# For more examples of kind configuration, see here: https://github.com/yashbhutwala/kind-hacks
cat <<EOF > kind-multi-worker-cluster.yml
# a cluster with 1 master and three worker nodes
kind: Cluster
apiVersion: kind.sigs.k8s.io/v1alpha3
nodes:
  - role: control-plane
  - role: worker
  - role: worker
  - role: worker
EOF

kind create cluster --image kindest/node:v1.14.9 --config kind-multi-worker-cluster.yml

# use rancher's local-path-storage for dynamic volume provisioning (note: this will no longer be needed in k8s>=1.16 as it is the default for kind)
kubectl apply -f "https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.11/deploy/local-path-storage.yaml" && kubectl patch storageclass "local-path" -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}' && kubectl delete storageclass standard
```

**Here is an example of synopsysctl command to use.  You will need the `GCP_SERVICE_ACCOUNT_PATH`, `COVERITY_LICENSE_PATH` and `POLARIS_LICENSE_PATH`.  You can read more details about synopsysctl and on-prem polaris here**

- [Synopsysctl command line parameters list; you can also use `synopsysctl create polaris --help`](https://sig-confluence.internal.synopsys.com/display/DD/Installing+with+synopsysctl+CLI)

```bash
export NAMESPACE="onprem"
export POLARIS_VERSION="tiny-2019.11"

# this is for the gcp service account used for gcr images
export GCP_SERVICE_ACCOUNT_PATH="${POLARIS_APP_PREREQUISITES_DIRECTORY}/gcp-service-account-token-for-images.json"
# this is the shared coverity license being used for testing
export COVERITY_LICENSE_PATH="${POLARIS_APP_PREREQUISITES_DIRECTORY}/coverity-license.xml"
# this is the shared polaris platform license being used for testing
export POLARIS_LICENSE_PATH="${POLARIS_APP_PREREQUISITES_DIRECTORY}/polaris-platform-license.json"

# CHANGE THIS!
export ADMIN_EMAIL="bhutwala@synopsys.com"
# CHANGE THIS!
export FQDN="yashonprem.dev.polaris.synopsys.com"

kubectl create ns $NAMESPACE

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
