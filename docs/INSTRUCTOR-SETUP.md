# Instructor setup: do this before participants arrive

Research checked on **2026-10-23**. See [sources](SOURCES.md) for the evidence and
its applicability limits. These are instructions to review and run deliberately,
not an automatic cluster bootstrap script.

## 1. Establish the actual platform and ownership

Record:

- Azure Local release/build, disaggregated deployment type, AKS distribution,
  API-server version and Linux node OS.
- Who owns the cluster, load-balancer controller, IP pools, ingress controllers,
  CRDs and storage classes. Reuse suitable existing installations.
- Microsoft support confirmation for the exact release and reported Kubernetes
  1.36 version. The retrieved release notes list versions through 1.33 for the
  releases shown; they do not verify 1.36 on this platform.
- Storage: on AKS in Azure, the built-in `managed-csi`/`azurefile-csi` classes
  (section 4). On Azure Local only: the Dell CSM/CSI release, its supported
  Kubernetes/OS matrix, PowerStore OS and PowerScale OneFS versions, transport
  and storage-network reachability.

Use the **workload cluster**, not the Arc Resource Bridge management cluster.
Check context before every administrator operation:

```powershell
kubectl config current-context
kubectl version -o yaml
kubectl get nodes -o wide
kubectl get nodes -L kubernetes.io/os
kubectl get service -A
kubectl get ingressclass
kubectl get storageclass
kubectl get csidriver
helm list -A
kubectl api-resources --api-group=gateway.networking.k8s.io
kubectl api-resources --api-group=cert-manager.io
```

Missing custom API groups before installation are expected. A connectivity or
authorization error is not evidence that a controller is absent.

The `kubectl` found on the author's workstation was **1.23**. Do not use that
client against 1.36. Prefer 1.36, and obey the upstream +/- one-minor skew rule
(1.35-1.37 for a uniformly 1.36 API server). Upgrade through your approved
software distribution process. Use Helm 3.16+ and PowerShell 7.4+.

### Permissions and shared-cluster safety

The trainer needs cluster-scoped Kubernetes permissions for CRDs, classes and
controllers. MetalLB extension deployment also needs appropriate Azure/Arc
permissions, documented separately in the Microsoft how-to.

Learners need namespace-scoped CRUD for Deployments, Services, ConfigMaps,
Secrets, Ingresses, PVCs, Jobs, CronJobs and the exercise's Gateway API/cert-manager
resources; Pod logs, exec and port-forward; and read access to relevant events.
The trainer can show cluster-scoped PV/VolumeAttachment/StorageClass/CRD
inventory if learners cannot list it.
Have the trainer pre-create namespaces if learners cannot create them.
Use a training cluster or dedicated namespaces with quotas; never grant every
learner cluster-admin merely to run this workshop.

One namespace and hostname per learner/pair, for example:

| Learner | Namespace | Raw application host | Helm host |
| --- | --- | --- | --- |
| 1 | lab01 | lab01.lab.test | helm.lab01.lab.test |
| 2 | lab02 | lab02.lab.test | helm.lab02.lab.test |

Namespace separation is not a security boundary by itself. Discuss RBAC,
NetworkPolicy and tenant isolation without expanding the workshop into their
installation/configuration.

## 2. Decide the L4 exposure path

**Preferred:** reuse the site's working load-balancer implementation. Check its
Service selection/class conventions before creating Traefik's Service.

**If none exists:** Microsoft's AKS-on-Azure-Local documentation describes the
MetalLB Arc extension. Because the linked implementation pages are categorized
under hyperconverged, obtain approval for the exact disaggregated platform
release. Do not install a second upstream MetalLB over an Arc-managed instance.

For a simple training LAN, ARP/L2 is usually easier than BGP, but only if:

- The network owner reserves unused addresses in the Kubernetes node subnet.
- The pool excludes node, control-plane, DHCP, logical-network and other VIPs.
- VLAN/L2 adjacency, ARP announcements and the virtual network's anti-spoofing
  behavior allow the VIP to work; clients can reach it.
- Ports 80/443 and any required node-to-node speaker traffic are allowed.
- Routing and firewalls are validated from the **learner workstation**.

An IP from a different subnet requires an appropriate routed/BGP design; do not
copy an arbitrary example range. BGP also requires router peering, ASNs and
network-team configuration. Do not change the CNI or kube-proxy just for this lab.

### MetalLB Arc extension: documented installation route

Review the Microsoft [CLI guide](https://learn.microsoft.com/en-us/azure/aks-hybrid-edge/local/hyperconverged/deploy-load-balancer-cli)
or [portal guide](https://learn.microsoft.com/en-us/azure/aks-hybrid-edge/local/hyperconverged/deploy-load-balancer-portal).
The portal route is: workload AKS resource -> Networking -> install extension ->
add approved pool. It is not the public-cloud AKS application-routing add-on.

Illustrative PowerShell CLI sequence, **administrator only**, after filling in
site-owned values and confirming the correct Arc connected-cluster resource:

```powershell
$ResourceGroup = '<workload-cluster-resource-group>'
$ArcClusterName = '<Arc-connected-cluster-name>'
$ApprovedRange = '<network-team-approved-first-ip>-<last-ip>'
$PoolName = 'training-pool'

az connectedk8s show -g $ResourceGroup -n $ArcClusterName --query id -o tsv
# Verify this ID matches the intended workload cluster before proceeding.
$ArcClusterId = az connectedk8s show -g $ResourceGroup -n $ArcClusterName --query id -o tsv
if ($LASTEXITCODE -ne 0 -or -not $ArcClusterId) { throw 'Cannot resolve workload cluster.' }

az extension add --name k8s-runtime --upgrade
if ($LASTEXITCODE -ne 0) { throw 'Azure CLI extension installation failed.' }
az k8s-runtime load-balancer enable --resource-uri $ArcClusterId
if ($LASTEXITCODE -ne 0) { throw 'MetalLB Arc extension enablement failed.' }
az k8s-runtime load-balancer create --load-balancer-name $PoolName `
  --resource-uri $ArcClusterId --addresses $ApprovedRange --advertise-mode ARP
if ($LASTEXITCODE -ne 0) { throw 'Load-balancer pool creation failed.' }
```

The enable operation has documented Microsoft Graph permission requirements;
the Microsoft guide provides an alternative extension-creation route. Use the
current guide rather than inventing service-principal IDs or elevating learners.
The CLI creates the relevant IPAddressPool and advertisement CRs. Do not also
apply unmanaged MetalLB pool YAML to the same addresses.

If site policy requires `loadBalancerClass` or pool annotations on Services,
extend the Traefik values using the site's approved settings and re-render it.

## 3. Install shared HTTP routing

### Version set used for this pack

| Component | Pin | Basis |
| --- | --- | --- |
| Traefik Helm chart | 42.1.3 | Chart appVersion v3.7.16; kubeVersion >=1.30 |
| Gateway API CRDs | v1.6.3, Standard channel | Traefik v3.7 provider documentation |
| cert-manager Helm chart | v1.21.2 | v1.21 supports/tests Kubernetes 1.33-1.36 |
| Application image | nginxinc/nginx-unprivileged:1.31.7-alpine | Existing multi-architecture Linux tag, updated 2026-10-19, UID 101/port 8080 |

These are reproducibility pins, not a vulnerability assessment or perpetual
recommendation. Before a new session, review advisories and compatible patches,
mirror approved images/charts if required, then rerun the checks and rehearsal.
Never upgrade existing shared CRDs/controllers just to match these pins without
their owner's approval. CRD schemas existing in a cluster must be compatible;
their mere presence is not sufficient.

If Gateway API is already managed by the platform, ask its owner to validate the
needed version. Otherwise install it once, before enabling Traefik's provider:

```powershell
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.3/standard-install.yaml
kubectl wait --for=condition=Established crd/gatewayclasses.gateway.networking.k8s.io --timeout=120s
kubectl wait --for=condition=Established crd/gateways.gateway.networking.k8s.io --timeout=120s
kubectl wait --for=condition=Established crd/httproutes.gateway.networking.k8s.io --timeout=120s

helm repo add traefik https://traefik.github.io/charts
helm repo update traefik
helm upgrade --install traefik traefik/traefik --version 42.1.3 `
  --namespace traefik --create-namespace --skip-crds `
  --values .\instructor\traefik-values.yaml --wait --timeout 5m
kubectl apply -f .\instructor\gatewayclass.yaml
kubectl wait --for=condition=Accepted gatewayclass/traefik --timeout=120s
kubectl -n traefik get deployment,service
kubectl get ingressclass traefik
```

Stop on any failure; PowerShell does not automatically stop for a nonzero native
command exit. Check `$LASTEXITCODE` when executing these blocks.

The values explicitly enable both standard providers, disable proprietary
Traefik CRD routing/dashboard exposure and disable chart-created Gateways/classes.
`--skip-crds` avoids installing unused Traefik-specific CRDs. The separately
installed Standard Gateway API CRDs are still required. We manually create one
shared GatewayClass; learners create namespaced Gateways.

For this Traefik configuration, Gateway listener port **8000** matches the
controller's `web` entry point. Clients connect to **80** on the Service VIP.
HTTPS similarly uses controller port **8443** and Service port **443**.
This mapping is controller-specific, not a general Gateway API requirement.
Each learner's Gateway must have a distinct hostname; `allowedRoutes: Same`
prevents accidental cross-namespace route attachment in this exercise.

Wait for the `traefik` LoadBalancer Service to have an address:

```powershell
kubectl -n traefik get service traefik -w
```

Use Ctrl+C when allocated. Record the actual address and test it after the
application is deployed. A `Pending` VIP is an L4/pool issue, not an Ingress YAML
issue. Creating several learner Gateways in this setup reuses Traefik's shared
Service; it does not allocate a separate VIP for each Gateway.

Provide wildcard DNS for `*.lab.test`, including the Helm hostnames, or use the
lab's `curl.exe --resolve` commands (no DNS/hosts file edits required).
The `.test` suffix is intentional; no public DNS or ACME Internet access is needed.

### No-VIP contingency

For routing concepts only, the trainer can use:

```powershell
kubectl -n traefik port-forward service/traefik 8088:80 8443:443
```

In another terminal, learners on that workstation can use:

```powershell
curl.exe --fail --noproxy "*" --resolve "lab01.lab.test:8088:127.0.0.1" http://lab01.lab.test:8088/
```

Each learner with port-forward permission can start their own tunnel. This tests
Traefik routing but **does not validate MetalLB, LAN reachability or external
load balancing**. The core networking acceptance check must use the real VIP.

## 4. Check the storage classes used by the Volumes lab

The [Volumes lab](../labs/03-volumes.md) uses the storage classes that **AKS in
Azure** creates automatically when its Azure Disk and Azure Files CSI drivers are
enabled (the default):

| Class | Driver | Backend | Access | Binding | Reclaim |
| --- | --- | --- | --- | --- | --- |
| `managed-csi` | `disk.csi.azure.com` | Azure managed disk, Standard SSD | RWO | `WaitForFirstConsumer` | `Delete` |
| `azurefile-csi` | `file.csi.azure.com` | Azure Files SMB share, Standard storage account | RWX | `Immediate` | `Delete` |

Check them on the training cluster:

```powershell
kubectl get storageclass managed-csi azurefile-csi
kubectl get storageclass managed-csi -o yaml
kubectl get storageclass azurefile-csi -o yaml
kubectl get csidriver disk.csi.azure.com file.csi.azure.com
```

If a class or driver is missing, the cluster administrator can check and enable
the drivers. Replace the placeholders with the training cluster's values:

```powershell
az aks show --resource-group '<resource-group>' --name '<cluster-name>' --query storageProfile
az aks update --resource-group '<resource-group>' --name '<cluster-name>' --enable-disk-driver --enable-file-driver
```

Do not change the cluster's default StorageClass for the workshop.

What the lab creates in Azure, per learner:

- One **4 GiB Standard SSD managed disk** (`demo-data`), deleted again in Volumes
  section 5 by the `Delete` reclaim policy.
- One **5 GiB Azure Files share** (`demo-shared-data`), deleted when the
  learner's namespace is deleted at the end of the workshop.
- The Azure Files driver creates or reuses a **storage account** in the node
  resource group (`MC_...`), tagged `k8s-azure-created-by: azure`. It is shared by
  all shares and is **not** deleted with the claims; review it after the session.

Requirements and rehearsal points:

- The cluster identity can create disks and storage accounts in the node
  resource group (the AKS default). Azure Policy or locked resource groups can
  block this; check events if claims stay `Pending`.
- Nodes can reach Azure Files over SMB (TCP 445). Restricted egress through a
  firewall or a storage account firewall/private endpoint needs an explicit rule.
- Each node VM size has a maximum number of data disks; one small disk per
  learner is usually far below it.
- The app runs as UID/GID 101. Azure Disk honors the Pod's `fsGroup: 101`;
  the built-in Azure Files class mounts SMB shares with permissive file and
  directory modes. Confirm writes work during the rehearsal.

Rehearse the [Volumes lab](../labs/03-volumes.md) and verify:

- `demo-data` stays `Pending` until the Pod exists (`WaitForFirstConsumer`), then
  binds; the disk attaches and the file survives Pod replacement.
- `demo-shared-data` binds immediately; both replicas read and write the same
  file, ideally on two different nodes.
- Deleting `demo-data` removes its PV and the managed disk.
- Describe/events do not show quota, attach, zone, mount or permission failures.

### Running the workshop on AKS on Azure Local instead

AKS on Azure Local does **not** provide `managed-csi` or `azurefile-csi`. Choose
validated equivalent classes with the platform/storage team, then have learners
pass them to the workspace helper in the Preparation lab, for example:

```powershell
.\scripts\New-LabWorkspace.ps1 -Namespace $Namespace -RwoStorageClass '<validated-rwo-class>' -RwxStorageClass '<validated-rwx-class>'
```

The helper rewrites `storageClassName` in the generated files; the lab commands
stay the same, but class-specific explanations (Azure disk IDs, storage account,
binding mode) will differ. Points to validate on Azure Local:

- SAN storage behind Azure Local CSVs and VM disks is a different layer from
  Pod storage provisioned through CSI; PowerStore/PowerScale hardware does not
  by itself provide a Kubernetes StorageClass.
- For array-backed provisioning, follow the Dell CSI for PowerStore/PowerScale
  documentation and support matrix (moved to Dell.com for CSM 1.17+). Confirm
  supported transports from the VM workers and NFS export permissions,
  root-squash and `fsGroup` behavior for UID/GID 101.
- An RWX class is needed for Volumes section 4 and the CronJob in the Jobs lab.

## 5. Install the shared operator once

If cert-manager exists, reuse a supported installation. Do not install a second
release or package it as a dependency of each learner's chart.

```powershell
helm upgrade --install cert-manager oci://quay.io/jetstack/charts/cert-manager `
  --version v1.21.2 --namespace cert-manager --create-namespace `
  --set crds.enabled=true --wait --timeout 5m
kubectl wait --for=condition=Established crd/certificates.cert-manager.io --timeout=120s
kubectl -n cert-manager rollout status deployment/cert-manager --timeout=120s
kubectl -n cert-manager rollout status deployment/cert-manager-webhook --timeout=120s
kubectl -n cert-manager rollout status deployment/cert-manager-cainjector --timeout=120s
```

Show the Helm install to learners, then let each create their own **namespaced**
Issuer and Certificate. SelfSigned avoids public DNS, Internet-facing challenges,
external credentials and ClusterIssuer permissions. It is a demo, **not** a
production PKI design. Certificate trust is deliberately not established.

## 6. Internet-restricted sites

Pre-stage the chart packages, Gateway API manifest and all controller, webhook,
startup-check and app images, including chart hook images. Inspect them with:

```powershell
helm template traefik traefik/traefik --version 42.1.3 `
  --values .\instructor\traefik-values.yaml --kube-version 1.36.0 `
  --api-versions gateway.networking.k8s.io/v1/GatewayClass `
  --api-versions gateway.networking.k8s.io/v1/HTTPRoute
helm template cert-manager oci://quay.io/jetstack/charts/cert-manager `
  --version v1.21.2 --set crds.enabled=true --kube-version 1.36.0
```

Mirror into an approved reachable registry, set the charts' documented image
overrides and pull secrets, replace the app image in raw YAML and Helm values,
and rehearse on the actual nodes. Workstation Internet access does not prove
node image-pull access. Shared-controller setup may also require Arc connectivity.

## 7. Go/no-go and acceptance checks

- [ ] Exact AKS/Azure Local version and disaggregated support confirmed.
- [ ] Supported `kubectl`; correct workload kubeconfig/context; Helm and PowerShell work.
- [ ] Healthy Linux nodes with spare resources; images pull from worker nodes.
- [ ] Learner namespace permissions, exec, port-forward and events access work.
- [ ] Gateway CRDs established, shared class Accepted, Traefik and cert-manager Ready.
- [ ] No second controller/pool competing for the same Service addresses.
- [ ] Real VIP reachable from learner PCs on 80 and 443.
- [ ] Per-learner raw/Helm hostnames distinct; curl hostname resolution works.
- [ ] App replicas become Ready; Service has endpoints; deletion recreates a Pod.
- [ ] Config change appears after rollout; Secret isn't printed or served.
- [ ] Ingress works, then Gateway/HTTPRoute conditions become Accepted/ResolvedRefs
      and routing works after switching.
- [ ] `managed-csi` disk claim binds after the Pod exists, is writable and survives
      Pod recreation; deleting it removes the PV and Azure disk.
- [ ] `azurefile-csi` claim binds immediately; two replicas share the same file.
- [ ] Jobs complete (`hello`, `parallel-batch` 6/6), `fail-demo` fails with
      `BackoffLimitExceeded`, the CronJob creates a Job every minute and its
      report is served through Ingress; suspending stops new Jobs.
- [ ] Helm upgrade changes content and replica count; rollback restores both.
- [ ] Certificate Ready, TLS Secret generated, deleting only that demo Secret
      causes the controller to recreate it; HTTPS routes successfully.
- [ ] Cleanup reviewed: learner deletion does not remove shared controllers/CRDs;
      after the session, review the storage account created by the Azure Files driver.

Budget per learner: up to five small app Pods during rollouts, short-lived Job
Pods (two at a time for the parallel Job, one per minute for the CronJob), one
4 GiB Azure disk (deleted during the Volumes lab), one 5 GiB Azure Files share
and small API objects. The two-replica Traefik and cert-manager installation are
shared overhead. Rehearse capacity with the expected group size, rather than
treating resource requests as actual usage.
