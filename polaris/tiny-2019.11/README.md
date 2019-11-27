# kustomized from 2019.11 yamls

1. edited postgres deployment's mountpath to /var/lib/postgresql/data
2. change eventstore replicas from 3 -> 1 and also EVENTSTORE_CLUSTER_SIZE
3. remove podDisruptionBudgets
4. remove 'rollingUpdate: null' from minio (both upload and download server)
5. do not deploy reporting
6. remove `vault-exporter` and `eventstore-exporter` containers
7. update eventstore readiness check to check on port `2113`

Use command:

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
