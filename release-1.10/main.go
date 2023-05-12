package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"strconv"

	v1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	k8s_io_client_go_kubernetes "k8s.io/client-go/kubernetes"
	clientcmd "k8s.io/client-go/tools/clientcmd"
)

var (
	kubeconfig           string
	namespace            string
	clientRateLimitBurst int
	clientRateLimitQPS   float64
	replicas             int
	count                int
)

func main() {
	var burst int = 100
	var qps float64 = 100
	flagset := flag.NewFlagSet("perf-testing", flag.ExitOnError)
	flagset.StringVar(&kubeconfig, "kubeconfig", "/root/.kube/config", "Path to a kubeconfig. Only required if out-of-cluster.")
	flagset.StringVar(&namespace, "namespace", "test", "Namespace to create the resource")
	flagset.Float64Var(&clientRateLimitQPS, "clientRateLimitQPS", qps, "Configure the maximum QPS to the Kubernetes API server from Kyverno. Uses the client default if zero.")
	flagset.IntVar(&clientRateLimitBurst, "clientRateLimitBurst", burst, "Configure the maximum burst for throttle. Uses the client default if zero.")
	flagset.IntVar(&replicas, "replicas", 50, "Configure the replica number of the replicaset")
	flagset.IntVar(&count, "count", 50, "Configure the total number of the replicaset")

	flagset.VisitAll(func(f *flag.Flag) {
		flag.CommandLine.Var(f.Value, f.Name, f.Usage)
	})
	flag.Parse()

	clientConfig, err := clientcmd.BuildConfigFromFlags("", kubeconfig)
	if err != nil {
		fmt.Println("error creating client config: ", err)
		os.Exit(1)
	}

	clientConfig.Burst = clientRateLimitBurst
	clientConfig.QPS = float32(clientRateLimitQPS)

	client, err := k8s_io_client_go_kubernetes.NewForConfig(clientConfig)
	if err != nil {
		fmt.Println("error creating client set: ", err)
		os.Exit(1)
	}

	for i := 0; i < count; i++ {
		num := strconv.Itoa(i)
		rs := newReplicaset(num)
		_, err = client.AppsV1().ReplicaSets(namespace).Create(context.TODO(), rs, metav1.CreateOptions{})
		if err != nil {
			fmt.Println("failed to create the replicaset: ", err)
			os.Exit(1)
		}
		fmt.Printf("created replicaset perf-testing-%v\n", num)
	}

}

func newReplicaset(i string) *v1.ReplicaSet {
	r := int32(replicas)
	boolTrue := true
	boolFalse := false

	return &v1.ReplicaSet{
		ObjectMeta: metav1.ObjectMeta{
			Name:      "perf-testing-" + i,
			Namespace: "test",
			Labels: map[string]string{
				"app.kubernetes.io/name": "perf-testing",
			},
		},
		Spec: v1.ReplicaSetSpec{
			Replicas: &r,
			Selector: &metav1.LabelSelector{
				MatchLabels: map[string]string{
					"app.kubernetes.io/name": "perf-testing",
				},
			},
			Template: corev1.PodTemplateSpec{
				ObjectMeta: metav1.ObjectMeta{
					Labels: map[string]string{
						"app.kubernetes.io/name": "perf-testing",
					},
				},
				Spec: corev1.PodSpec{
					Containers: []corev1.Container{
						{
							Name:  "nginx",
							Image: "nginx",
							SecurityContext: &corev1.SecurityContext{
								AllowPrivilegeEscalation: &boolFalse,
								RunAsNonRoot:             &boolTrue,
								SeccompProfile: &corev1.SeccompProfile{
									Type: corev1.SeccompProfileTypeRuntimeDefault,
								},
								Capabilities: &corev1.Capabilities{
									Drop: []corev1.Capability{"ALL"},
								},
							},
						},
					},
					Tolerations: []corev1.Toleration{
						{
							Key:      "kwok.x-k8s.io/node",
							Operator: corev1.TolerationOpExists,
							Effect:   corev1.TaintEffectNoSchedule,
						},
					},
					Affinity: &corev1.Affinity{
						NodeAffinity: &corev1.NodeAffinity{
							RequiredDuringSchedulingIgnoredDuringExecution: &corev1.NodeSelector{
								NodeSelectorTerms: []corev1.NodeSelectorTerm{
									{
										MatchExpressions: []corev1.NodeSelectorRequirement{
											{
												Key:      "type",
												Operator: corev1.NodeSelectorOpIn,
												Values:   []string{"kwok"},
											},
										},
									},
								},
							},
						},
					},
				},
			},
		},
	}
}
