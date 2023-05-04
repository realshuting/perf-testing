kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  labels:
    app.kubernetes.io/component: perf-testing
    app.kubernetes.io/instance: perf-testing
    app.kubernetes.io/name: perf-testing
  name: perf-testing-1
  namespace: test
spec:
  containers:
  - name: busybox
    image: busybox:1.35
    args:
    - sleep 
    - 1d
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