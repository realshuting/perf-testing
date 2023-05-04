kubectl create ns test

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  labels:
    app.kubernetes.io/component: perf-testing
    app.kubernetes.io/instance: perf-testing
    app.kubernetes.io/name: perf-testing
  name: perf-testing-1
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
EOF