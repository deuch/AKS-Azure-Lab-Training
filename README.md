# From Docker to Kubernetes: AKS on Azure Local

A hands-on workshop of about 4h15 (core labs) for people who already know Docker.
The AKS workload cluster already exists. All participant commands use **PowerShell 7**.
Examples target Linux containers and the reported Kubernetes **1.36** environment.
The Volumes lab uses the AKS (Azure) built-in storage classes `managed-csi` and
`azurefile-csi` to keep storage simple.

## Start here

1. Trainer: complete [Instructor setup](docs/INSTRUCTOR-SETUP.md) before the session.
2. Participants: use the [Lab index](LAB-GUIDE.md) to follow the six topic-based guides in order.
3. Reference: [Documentation and version evidence](docs/SOURCES.md).

**Do not run `kubectl apply -R` on this repository.** It includes mutually
exclusive routing alternatives, deployment patches and Jobs that are meant to
be run one at a time.

## Recommended platform additions

| Layer | Recommendation | Installed by |
| --- | --- | --- |
| Service exposure, L4 | Reuse the existing load balancer. If absent, evaluate the Microsoft-documented MetalLB Arc extension with the platform/network team. | Trainer/platform admin, once |
| HTTP routing, L7 | Traefik, with both standard Kubernetes Ingress and Gateway API providers | Trainer, once |
| Gateway API types | Standard-channel CRDs and a shared `GatewayClass` | Trainer, once |
| Persistent storage | AKS built-in classes `managed-csi` (Azure Disk, RWO) and `azurefile-csi` (Azure Files, RWX); on AKS on Azure Local, validated equivalent classes | Built in on AKS in Azure; storage/platform admin on Azure Local |
| Operator example | cert-manager: `Issuer` + `Certificate` -> generated TLS `Secret` | Trainer installs controller; learners create CRs |

Traffic path:

```text
Client -> reachable MetalLB/existing VIP -> Traefik LoadBalancer Service
       -> Traefik routing (Ingress OR Gateway + HTTPRoute)
       -> demo ClusterIP Service -> Ready application Pods

Pod -> PVC -> PV -> CSI driver/storage backend
```

MetalLB and Traefik solve different problems. Installing Ingress or Gateway YAML
alone does not install a controller, allocate a reachable VIP, or configure DNS.
An on-premises `EXTERNAL-IP` is not necessarily an Internet/public IP.

### Important compatibility boundaries

- **Azure Local is not public-cloud AKS.** Do not assume `az aks` application
  routing, Azure Standard Load Balancer or Application Gateway for Containers
  are present or appropriate there.
- **Storage classes:** the Volumes lab simplifies storage by using the classes
  that AKS in Azure creates automatically, `managed-csi` and `azurefile-csi`.
  AKS on Azure Local does not provide them; there, pass validated equivalent
  classes to the workspace helper (see [Instructor setup](docs/INSTRUCTOR-SETUP.md)).
- Microsoft documents MetalLB for AKS on Azure Local, but the retrieved how-to
  pages live under **hyperconverged** documentation. Confirm the extension,
  networking and support route for the exact **disaggregated** release before
  installing. This pack does not assert that every hyperconverged feature is
  supported unchanged on disaggregated deployments.
- The retrieved Microsoft AKS-on-Azure-Local release notes do **not** establish
  support for Kubernetes 1.36. Confirm the actual API-server version, Azure Local
  release and Microsoft support matrix. Upstream controller compatibility is
  not the same as Microsoft platform certification.
- On Azure Local, PowerStore/PowerScale hardware alone does not create a
  Kubernetes StorageClass. Host SAN storage for Azure Local VM disks and
  CSI-provisioned application volumes are separate layers.
- Do not start a new lab with community **ingress-nginx**: it was retired in
  March 2026. This is not a retirement of the Kubernetes Ingress API or all
  products that use NGINX.

## Timetable

| Activity | Minutes | Main objects |
| --- | ---: | --- |
| [Preparation](labs/00-preparation.md) | 15 | Namespace, declarative desired state |
| [Deployment / Pods / ReplicaSet](labs/01-deployment-pods-replicaset.md) | 50 | Deployment, ReplicaSet, Pod, ConfigMap, Secret |
| [Service / Ingress / Gateway API](labs/02-service-ingress-gatewayapi.md) | 50 | Service, EndpointSlice, IngressClass, Ingress, GatewayClass, Gateway, HTTPRoute |
| [Volumes](labs/03-volumes.md) | 45 | StorageClass (`managed-csi`, `azurefile-csi`), PVC, PV, VolumeAttachment |
| [Jobs and CronJobs](labs/04-jobs-cronjobs.md) | 40 | Job, Indexed Job, CronJob |
| Break | 10 | |
| [Helm](labs/05-helm.md) | 35 | Chart, values, release, upgrade, rollback |
| Debrief and cleanup | 10 | Reclaim policy and shared-resource ownership |
| **Core total** | **255** | Six guides with refreshers, break and cleanup |
| [Optional operator extension in Helm](labs/05-helm.md#optional-extension-operator-and-crd-with-cert-manager-30-minutes) | 30 | CRD, controller, Issuer, Certificate, TLS Secret |
| **With operator extension** | **285** | Plan a full day, or two sessions |

Each lab includes a five-minute illustrated refresher for learners who attended
the theory presentation a week earlier. The core sequence no longer fits a strict
half day: run labs 0-3 in a first session and labs 4-5 in a second one, or plan a
full day with discussion time.

## Docker-to-Kubernetes translation

| Docker concept | Kubernetes equivalent or important difference |
| --- | --- |
| `docker run` | Usually a Deployment managing Pods, not a long-lived manually managed Pod |
| Container | Runs inside a Pod; a Pod can contain more than one container |
| Compose replicas | Deployment replicas + reconciliation + readiness |
| Published port | Service for L4; Ingress/Gateway controller for HTTP routing |
| Container IP | Ephemeral Pod IP; use a Service and DNS instead |
| Environment / bind-mounted config | ConfigMap or Secret referenced by a Pod |
| Named volume | PVC requesting a PV through a StorageClass |
| `docker run --rm` one-off task | Job: Pods run to completion, with retries |
| Host `crontab` running containers | CronJob: creates a Job on a schedule |
| Compose file | Not a direct equivalent: manifests describe API objects; Helm packages/templates them |

## Contents

- [Participant guides](labs): Preparation; Deployment/Pods/ReplicaSet;
  Service/Ingress/Gateway API; Volumes; Jobs and CronJobs; Helm.
- [Concept illustrations](labs/images/README.md): eight embedded PNG diagrams
  with SVG and editable Excalidraw sources, plus a local export script.
- [Raw manifests](manifests): readable, individually applicable YAML.
- [Helm chart](charts/training-web): Deployment, Service, Ingress, ConfigMap,
  probes, resource limits, configurable replicas and config-triggered rollout.
- [Trainer configuration](instructor): shared Traefik values and GatewayClass.
- [Workspace helper](scripts/New-LabWorkspace.ps1): copies examples, substitutes
  learner-specific hostnames and chosen storage classes; **does not contact the cluster**.
- [Chart tests](scripts/Test-Lab.ps1): local lint/render/regression checks.

## Validation and limitations

Local validation is distinct from a cluster rehearsal. Run:

```powershell
.\scripts\Test-Lab.ps1
```

Delivery checks passed: duplicate-key-aware YAML parsing, **75** built-in
Kubernetes resources with strict schemas, **5** custom resources against the
pinned CRD schemas, both pinned controller chart renders, four app chart
configurations, learner substitutions and **51** PowerShell documentation blocks.
The schema checks do not execute server-side admission or CEL rules.
The refresher update also preserves all original exercise command blocks,
validates local image/navigation links and checks the PNG/SVG/Excalidraw
diagram triplets. The PNGs were visually checked for readability and overlap.
The storage and Jobs update (2026-11-16) adds strict Kubernetes 1.36 schema
checks of the Job, CronJob and both AKS-class PVCs, a local simulation of the
disk then file-share Deployment patches, workspace-helper tests with default and
overridden classes, and parsing of all **68** PowerShell documentation blocks
and **105** local links/anchors.
No target-cluster access or changes are performed while creating this pack.
The trainer must still rehearse image pulls, Azure Disk/Azure Files provisioning
and permissions, VIP reachability, controller reconciliation, Job/CronJob runs
and TLS on the real cluster.
Version choices and the explicit go/no-go checklist are in
[Instructor setup](docs/INSTRUCTOR-SETUP.md).
