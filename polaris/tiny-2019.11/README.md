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

Make sure all dependencies are installed

```bash
$ docker --version
Docker version 19.03.5, build 633a0ea
#
$ kind version
kind v0.7.0 go1.13.6 darwin/amd64
#
$ kubectl version
Client Version: version.Info{Major:"1", Minor:"17", GitVersion:"v1.17.3", GitCommit:"06ad960bfd03b39c8310aaf92d1e7c12ce618213", GitTreeState:"clean", BuildDate:"2020-02-13T18:06:54Z", GoVersion:"go1.13.8", Compiler:"gc", Platform:"darwin/amd64"}
Server Version: version.Info{Major:"1", Minor:"17", GitVersion:"v1.17.0", GitCommit:"70132b0f130acc0bed193d9ba59dd186f0e634cf", GitTreeState:"clean", BuildDate:"2020-01-14T00:09:19Z", GoVersion:"go1.13.4", Compiler:"gc", Platform:"linux/amd64"}
#
$ synopsysctl --version
synopsysctl version 2019.11.1
```

```bash
# Create kind cluster config file
# For more examples of kind configurations, see here: https://github.com/yashbhutwala/kind-hacks
#
$ cat <<EOF > kind-multi-worker-with-ingress.yaml
# a cluster with 1 master and three worker nodes
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
#
$ kind -v 3 create cluster --image kindest/node:v1.14.10 --config kind-multi-worker-with-ingress.yaml
#
# install ingress-nginx controller
#
$ kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/nginx-0.29.0/deploy/static/mandatory.yaml; kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/nginx-0.29.0/deploy/static/provider/baremetal/service-nodeport.yaml; kubectl patch deployments -n ingress-nginx nginx-ingress-controller -p '{"spec":{"template":{"spec":{"containers":[{"name":"nginx-ingress-controller","ports":[{"containerPort":80,"hostPort":80},{"containerPort":443,"hostPort":443}]}],"nodeSelector":{"ingress-ready":"true"},"tolerations":[{"key":"node-role.kubernetes.io/master","operator":"Equal","effect":"NoSchedule"}]}}}}'
```

**Here is an example of synopsysctl command to use.  You will need the `GCP_SERVICE_ACCOUNT_PATH` and `POLARIS_LICENSE_PATH`. `COVERITY_LICENSE_PATH` is not needed, but to get synopsysctl to pass, simply pass an empty file (`touch coverity-license.xml`).  Also, an actual SMTP server is not needed (unless you are testing the email parts, which I highly doubt you are), just pass synopsysctl valid fields. You can read more details about synopsysctl and on-prem polaris here**

- [Synopsysctl command line parameters list; you can also use `synopsysctl create polaris --help`](https://sig-confluence.internal.synopsys.com/display/DD/Installing+with+synopsysctl+CLI)

```bash
$ cat synopsysctl-command-to-run.sh
#!/bin/bash

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
synopsysctl -v debug create polaris \
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

Give it ~5-10 mins, and all pods should be running and you can use `kubectl port-forward` for forwarding any of the pods to a localhost port.

## Post Install Steps

Update your host's dns to map localhost to the above inputted FQDN

```bash
# Edit /etc/hosts
$ sudo echo "127.0.0.1 ${FQDN}" >> /etc/hosts
```

Now you can go to your FQDN and access your local instance of Polaris.  Happy Hacking!

Here is a script that you can use to get the default super user admin credentials:

```bash
$ cat owner_credentials.sh

#!/bin/bash

# [USAGE]: ./owner_credentials.sh [NAMESPACE]

POD_NAME=$(kubectl get pods -n $1 -o name | grep -m 1 polaris-db-vault | cut -d'/' -f2)
kubectl exec -it -n $1 $POD_NAME sh << EOF
export VAULT_TOKEN=$(kubectl get secret -n $1 vault-init-secret -o json | jq -r '.data["root_token"]' | base64 --decode)
vault kv get secret/auth/private/admin
EOF

```
