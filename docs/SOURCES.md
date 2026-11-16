# Sources and applicability

Checked **2026-10-23**, using first-party Microsoft, Kubernetes, Traefik,
cert-manager and Dell documentation; AKS storage and Jobs/CronJobs sources
checked **2026-11-16**. Dell rows apply only when running on AKS on Azure Local.
These links are for trainers to recheck before a session; a documentation
statement is not a live-cluster test.

| Source | What it establishes / limit |
| --- | --- |
| [AKS on Azure Local overview](https://learn.microsoft.com/en-us/azure/aks-hybrid-edge/local/aks-local-overview) | Azure-managed/Arc-connected on-premises workload clusters; distinguish workload cluster from Resource Bridge. |
| [Disaggregated Azure Local overview](https://learn.microsoft.com/en-us/azure/azure-local/overview/disaggregated-overview) | Disaggregated deployments, external SAN, Azure Local VMs and AKS services. Does not certify every CSI/ingress combination. |
| [External storage support](https://learn.microsoft.com/en-us/azure/azure-local/concepts/external-storage-support) | Host-level FC/iSCSI SAN and CSV integration. Not proof that Pods automatically get a Dell CSI class. |
| [AKS on Azure Local release notes](https://learn.microsoft.com/en-us/azure/aks-hybrid-edge/local/aks-whats-new-local) | Retrieved 2607 section says unchanged from 2602, whose listed Kubernetes versions reach 1.33.5. No retrieved evidence confirming this platform's reported 1.36; obtain exact release support confirmation. |
| [MetalLB overview for AKS on Azure Local](https://learn.microsoft.com/en-us/azure/aks-hybrid-edge/local/hyperconverged/load-balancer-overview) | L4 address allocation/advertisement, L2 versus BGP, per-cluster extension. Path is hyperconverged: verify applicability to disaggregated release. |
| [MetalLB Arc CLI installation](https://learn.microsoft.com/en-us/azure/aks-hybrid-edge/local/hyperconverged/deploy-load-balancer-cli) | `k8s-runtime`, extension enablement, permissions, pools, ARP/BGP. Same disaggregated applicability caveat. |
| [MetalLB Arc portal installation](https://learn.microsoft.com/en-us/azure/aks-hybrid-edge/local/hyperconverged/deploy-load-balancer-portal) | Install extension/pool through Networking; address conflicts must be checked by the operator. |
| [AKS Local storage concepts](https://learn.microsoft.com/en-us/azure/aks-hybrid-edge/local/hyperconverged/concepts-storage) | Volumes/PV/PVC/StorageClass and platform storage concepts; not a Dell support matrix. |
| [Kubernetes version skew](https://kubernetes.io/releases/version-skew-policy/) | `kubectl` within one minor of API server; old 1.23 client is inappropriate for 1.36. |
| [Ingress NGINX retirement](https://kubernetes.io/blog/2025/11/11/ingress-nginx-retirement/) | Community ingress-nginx maintenance ended March 2026; not retirement of Ingress API or every NGINX controller. |
| [Traefik Kubernetes setup](https://doc.traefik.io/traefik/setup/kubernetes/) | Helm install and routing concepts. This lab intentionally does not copy its full HTTPS/redirect setup. |
| [Traefik Gateway API provider](https://doc.traefik.io/traefik/reference/install-configuration/providers/kubernetes/kubernetes-gateway/) | v3.7 documentation names Standard Gateway API v1.6.3, CRDs and RBAC requirements, recent Kubernetes support policy. |
| [Pinned Traefik chart metadata](https://github.com/traefik/traefik-helm-chart/blob/v42.1.3/traefik/Chart.yaml) and [values](https://github.com/traefik/traefik-helm-chart/blob/v42.1.3/traefik/values.yaml) | Chart 42.1.3, app v3.7.16, kube >=1.30, listener defaults and provider/class switches. |
| [Gateway API project](https://gateway-api.sigs.k8s.io/) and [v1.6.3 release](https://github.com/kubernetes-sigs/gateway-api/releases/tag/v1.6.3) | Standard CRDs and Gateway/HTTPRoute API model. CRDs alone do not implement a data plane. |
| [cert-manager Helm installation](https://cert-manager.io/docs/installation/helm/) | OCI chart, CRD installation, install only once and not as learner subcharts. |
| [cert-manager supported releases](https://cert-manager.io/docs/releases/) | v1.21 supports/tests Kubernetes 1.33-1.36; retrieved install guide uses v1.21.2. |
| [SelfSigned issuer](https://cert-manager.io/docs/configuration/selfsigned/) | Simple namespaced issuer; Subject and trust caveats. Suitable for demo, not production trust design. |
| [Dell CSM documentation notice](https://dell.github.io/csm-docs/) | CSM 1.17+ documentation moved to Dell.com. Do not use archived compatibility data as current certification. |
| [Dell CSM current documentation](https://www.dell.com/support/product-details/en-us/product/container-storage-modules/resources/manuals) | Consult version-specific installation/support matrices and array/OS prerequisites. Exact site compatibility remains to be checked. |
| [Dell PowerStore CSI](https://github.com/dell/csi-powerstore) | Driver purpose, transport dependencies and supported-protocol prerequisites; exact release matrix still required. |
| [Dell PowerScale CSI](https://github.com/dell/csi-powerscale) | Driver purpose and node-to-array connectivity requirement; historical Isilon naming remains visible. |
| [Kubernetes persistent volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/) | RWO/RWX, binding, reclaim policy and lifecycle. RWO is single-node, not necessarily single-Pod. |
| [AKS storage concepts](https://learn.microsoft.com/en-us/azure/aks/concepts-storage) | Built-in AKS classes: `managed-csi` (Standard SSD managed disk, LRS or ZRS on multi-zone clusters, expandable, `Delete`) and `azurefile-csi` (Standard Azure Files share, `Delete`). Azure Disk is single-node; use Azure Files for multi-node access. Used by the Volumes lab. |
| [AKS CSI storage drivers](https://learn.microsoft.com/en-us/azure/aks/csi-storage-drivers) | Azure Disk/Files CSI drivers, enabling them with `az aks update --enable-disk-driver/--enable-file-driver`, per-node data-disk limits. |
| [Azure Files CSI driver parameters](https://github.com/kubernetes-sigs/azurefile-csi-driver/blob/master/docs/driver-parameters.md) | Dynamic provisioning creates/reuses a storage account in the cluster resource group (tag `k8s-azure-created-by: azure`); SMB parameters and permissions. |
| [Kubernetes Jobs](https://kubernetes.io/docs/concepts/workloads/controllers/job/) | Completions, parallelism, Indexed completion mode, `backoffLimit`, `activeDeadlineSeconds`, `ttlSecondsAfterFinished`, restart policies. Used by the Jobs lab. |
| [Kubernetes CronJobs](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/) | Schedule syntax, `timeZone` (stable since 1.27), concurrency policy, starting deadline, history limits, suspension, idempotency caveat. |
| [ConfigMap](https://kubernetes.io/docs/concepts/configuration/configmap/) and [Secret](https://kubernetes.io/docs/concepts/configuration/secret/) | Environment refresh versus mounted projection; subPath caveat; base64 is not encryption. |
| [Helm chart guide](https://helm.sh/docs/chart_template_guide/getting_started/) | Templates, values and release workflow for the learner-created chart. |
| [Application image tag](https://hub.docker.com/r/nginxinc/nginx-unprivileged/tags?name=1.31.7-alpine) | Registry API confirmed the tag, 2026-10-19 update and Linux amd64/arm64 images; run behavior still needs the cluster rehearsal. |

The reference PowerPoint was not modified. Local extraction failed because its
container is an encrypted/protected Office package; slide contents were not
used to assert alignment. The labs follow the requested topic list.

## Concept refreshers and illustration provenance

Each guide includes a refresher for learners returning one week after the
theory session. The [illustrations](../labs/images/README.md) are original,
locally generated diagrams of the lab's behavior, not extracted slides or
vendor certification diagrams. They distinguish API configuration from data
paths and show simplified ownership/provisioning relationships.

Further reading for the refresher terminology:

- [Kubernetes objects](https://kubernetes.io/docs/concepts/overview/working-with-objects/)
  and [namespaces](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/)
- [Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/),
  [ReplicaSets](https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/)
  and [Pods](https://kubernetes.io/docs/concepts/workloads/pods/)
- [Services](https://kubernetes.io/docs/concepts/services-networking/service/)
  and [EndpointSlices](https://kubernetes.io/docs/concepts/services-networking/endpoint-slices/)
- [StorageClasses](https://kubernetes.io/docs/concepts/storage/storage-classes/)
  and [volumes](https://kubernetes.io/docs/concepts/storage/volumes/)
- [Jobs](https://kubernetes.io/docs/concepts/workloads/controllers/job/)
  and [CronJobs](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/)
- [Custom resources and controllers](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/)
- [Helm release storage](https://helm.sh/docs/topics/advanced/#storage-backends)
  and [cert-manager Certificate resources](https://cert-manager.io/docs/usage/certificate/)
