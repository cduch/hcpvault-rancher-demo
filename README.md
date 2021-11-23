# Integrate Vault HCP with Rancher #

## Requirements:
1. Vault HCP Cluster with public access or peering configured
2. Rancher Deployed with at least one RKE cluster (in this example the Rancher Quickstart AWS is used see: https://github.com/rancher/quickstart)


## Configure Rancher Cluster
1. Open the Rancher UI, click on the menu on the top left corner and click on _Cluster Management_.
2. Select _Edit Config_ from the three dots menu on the right in the row for the cluster "quickstart-aws-custom".
3. Scroll down to _Authorized Endpoint_ and set _Authorized Cluster Endpoint_ to _Enabled_.
4. Click on _save_ and on the next page on _done_ to return to the _Cluster Management_ overview.
5. Click on the three dot menu in the row for the cluster "quickstart-aws-custom" and select _Download KubeConfig_ and save the file as _˜/.kube/config_ in your home directory.


## Prepare your Shell Environment

### 1. Get list of contexts:
```
kubectl config get-contexts

CURRENT   NAME                                     CLUSTER                                  AUTHINFO                NAMESPACE
*         quickstart-aws-custom                    quickstart-aws-custom                    quickstart-aws-custom
          quickstart-aws-custom-ip-172-31-13-222   quickstart-aws-custom-ip-172-31-13-222   quickstart-aws-custom
```

### 2. Activate the second context:
```
kubectl config use-context quickstart-aws-custom-ip-172-31-13-222
Switched to context "quickstart-aws-custom-ip-172-31-13-222".
```

### 3. Set some exports for your shell:
The URL of your k8s auth endpoint from the .kube/config file:
```
export KUBE_HOST="https://1.2.3.4:6443"
```
The HCP Vault URL:
```
export EXTERNAL_VAULT_ADDRESS='https://vault-cluster.vault.XXX.aws.hashicorp.cloud:8200'
export VAULT_ADDR='https://vault-cluster.vault.XXX.aws.hashicorp.cloud:8200'
```

## Create Namespace and Serviceaccount in Kubernetes

### 1. Create a Kubernetes Namespace for Testing
```
kubectl create ns vault-test
```

### 2. Create a Serviceaccount
```
kubectl apply -f sa.yaml
```

## Enable Kubernetes Authentication in Vault

### 1. Enable Authentication Method
```
vault auth enable kubernetes
```

### 2. Export Token and secret from Kubernetes to configure the Authentication Method
```

export TOKEN_REVIEW_JWT="$(kubectl get secret vault-auth -n vault-test -o go-template='{{ .data.token }}' | base64 --decode)"
kubectl get secret vault-auth -n vault-test -o go-template='{{ index .data "ca.crt" }}' | base64 --decode > vault-ca.crt
vault write auth/kubernetes/config \
         token_reviewer_jwt="$TOKEN_REVIEW_JWT" \
         kubernetes_host="$KUBE_HOST" \
         kubernetes_ca_cert=@vault-ca.crt
```

### 3. Create an App policy in Vault and bind it to the serviceaccount
```
vault policy write internal-app-pol internal-app-policy.hcl

vault write auth/kubernetes/role/vault-app \
         bound_service_account_names=internal-app \
         bound_service_account_namespaces=vault-test \
         policies=internal-app-pol \
         ttl=24h

```

## Install the Vault Sidecar Injector via Helm

```

helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update
helm upgrade --install vault hashicorp/vault \
  -n vault-test \
  --version 0.9.1 \
  --set "injector.externalVaultAddr=${EXTERNAL_VAULT_ADDRESS}" \
  --set "injector.authPath=auth/kubernetes"\
  --set "server.serviceAccount.name=vault-auth" \
  --set "server.serviceAccount.create=false" \
  --wait
```

## Create a test Secret for the Deployment
vault kv put secret/hello foo=world


## Install a Test Deployment which injects the previously created secret from Vault into the Container
### 1. Deploy the Container
```
kubectl apply -f deploy.yaml -n vault-test
```

### 2. Check if it's running:
```
kubectl get pods -n vault-test
```

### 3. Check if the secret was created:
```
kubectl exec -it nginx-58dddb9876-f2kgp cat /vault/secrets/hello -n vault-test
```
