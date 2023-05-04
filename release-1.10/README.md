This document outlines the instructions for performance testing using [Kwok](https://kwok.sigs.k8s.io/) for the Kyverno 1.10 release.

# Create a base cluster using K3d

Download k3d on Linux machine:
```sh
wget -q -O - https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
```

Create the k3d cluster with 3 workers:
```sh
k3d cluster create --agents 3
```

More details for installation can be found [here](https://k3d.io/v5.4.9/#install-script):

# Deploy Kwok in a cluster

## Variables preparation
```sh
KWOK_WORK_DIR=$(mktemp -d)
KWOK_REPO=kubernetes-sigs/kwok
KWOK_LATEST_RELEASE=$(curl "https://api.github.com/repos/${KWOK_REPO}/releases/latest" | jq -r '.tag_name')
```

## Render kustomization yaml
```sh
cat <<EOF > "${KWOK_WORK_DIR}/kustomization.yaml"
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
images:
  - name: registry.k8s.io/kwok/kwok
    newTag: "${KWOK_LATEST_RELEASE}"
resources:
  - "https://github.com/${KWOK_REPO}/kustomize/kwok?ref=${KWOK_LATEST_RELEASE}"
EOF
```

```sh
kubectl kustomize "${KWOK_WORK_DIR}" > "${KWOK_WORK_DIR}/kwok.yaml"
```

## `kwok` deployment 
```sh
kubectl apply -f "${KWOK_WORK_DIR}/kwok.yaml"
```

## Create `Kwok` nodes

Run the following script with the desired number of Kowk nodes:

```sh
#!/bin/bash

# read user input for count
echo "Enter the desired number of Kowk node:"
read count

# iterate $count number of times
for (( i=1; i<=$count; i++ ))
do
  # generate YAML configuration using heredoc with COUNT variable substitution
  yaml=$(cat <<-END
    apiVersion: v1
    kind: Node
    metadata:
      annotations:
        node.alpha.kubernetes.io/ttl: "0"
        kwok.x-k8s.io/node: fake
      labels:
        beta.kubernetes.io/arch: amd64
        beta.kubernetes.io/os: linux
        kubernetes.io/arch: amd64
        kubernetes.io/hostname: kwok-node-$i
        kubernetes.io/os: linux
        kubernetes.io/role: agent
        node-role.kubernetes.io/agent: ""
        type: kwok
      name: kwok-node-$i
    spec:
      taints:
        - effect: NoSchedule
          key: kwok.x-k8s.io/node
          value: fake
    status:
      allocatable:
        cpu: 32
        memory: 256Gi
        pods: 110
      capacity:
        cpu: 32
        memory: 256Gi
        pods: 110
      nodeInfo:
        architecture: amd64
        bootID: ""
        containerRuntimeVersion: ""
        kernelVersion: ""
        kubeProxyVersion: fake
        kubeletVersion: fake
        machineID: ""
        operatingSystem: linux
        osImage: ""
        systemUUID: ""
      phase: Running
END
)

  # apply the generated configuration to Kubernetes cluster
  echo "$yaml" | kubectl apply -f -
done
```

More about Kowk on this [page](https://kwok.sigs.k8s.io/docs/user/kwok-in-cluster/).

## Install Prometheus stack

```sh
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm upgrade --install prometheus prometheus-community/prometheus --values ./value.yaml
helm install kube-state-metrics prometheus-community/kube-state-metrics
```

# Install Kyverno

```sh
kubectl apply -f ./servicemonitor.yaml
```

```sh
helm upgrade --install kyverno kyverno/kyverno -n kyverno \
  --create-namespace \
  --devel \
  --set admissionController.serviceMonitor.enabled=true \
  --set reportsController.serviceMonitor.enabled=true
```

```sh
helm upgrade --install kyverno kyverno/kyverno-policies --set=podSecurityStandard=restricted --set=background=true --set=validationFailureAction=Enforce --devel
```

# Create workloads

This script creates a single ReplicaSet with 1000 pods:
```sh
./replicaset.sh
```


# Prometheus Queries

## Admission Request Rate

```
sum(rate(kyverno_admission_requests_total{job="kyverno"}[3m]))
```