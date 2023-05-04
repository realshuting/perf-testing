kubectl create ns test

kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: CronJob
metadata:
  name: my-cronjob
  namespace: test
spec:
  concurrencyPolicy: Allow
  jobTemplate:
    metadata:
      name: my-cronjob
    spec:
      template:
        metadata:
        spec:
          containers:
          - command:
            - /bin/sh
            - -c
            - sleep 60
            image: busybox
            imagePullPolicy: Always
            name: my-cronjob
            resources: {}
            terminationMessagePath: /dev/termination-log
            terminationMessagePolicy: File
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
          dnsPolicy: ClusterFirst
          restartPolicy: OnFailure
          schedulerName: default-scheduler
          securityContext: {}
          terminationGracePeriodSeconds: 30
  schedule: '* * * * *'
EOF