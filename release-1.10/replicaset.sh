#!/bin/bash

# read user input for count
echo "Enter the count:"
read count

# iterate $count number of times
for (( i=1; i<=$count; i++ ))
do
  # generate YAML configuration using heredoc with COUNT variable substitution
  yaml=$(cat <<-END
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  labels:
    app.kubernetes.io/component: perf-testing
    app.kubernetes.io/instance: perf-testing
    app.kubernetes.io/name: perf-testing
  name: perf-testing-$i
  namespace: test
spec:
  replicas: 1000
  selector:
    matchLabels:
      app.kubernetes.io/component: perf-testing
      app.kubernetes.io/instance: perf-testing
      app.kubernetes.io/name: perf-testing
  template:
    metadata:
      labels:
        app.kubernetes.io/component: perf-testing
        app.kubernetes.io/instance: perf-testing
        app.kubernetes.io/name: perf-testing
    spec:
      containers:
      - name: nginx
        image: nginx
        securityContext:
          allowPrivilegeEscalation: false
          runAsNonRoot: true
          seccompProfile:
            type: RuntimeDefault
          capabilities:
            drop:
            - ALL
      tolerations:
      - key: "kwok.x-k8s.io/node"
        operator: "Exists"
        effect: "NoSchedule"
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
                - key: type
                  operator: In
                  values:
                    - kwok
END
)

  # apply the generated configuration to Kubernetes cluster
  echo "$yaml" | kubectl apply -f -
done