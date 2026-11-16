# Volumes

**Duration:** 40 minutes, including a 5-minute refresher,
plus optional RWX/static NFS exercises.
**Prerequisite:** [Service / Ingress / Gateway API](02-service-ingress-gatewayapi.md),
with a working Ingress and `$IngressIp` set.
Run commands from the workshop root in the same PowerShell session.

## Goals

- Compare Pod-scoped `emptyDir` with persistent storage.
- Request a volume through a PVC and inspect its PV and StorageClass.
- Prove data survives Pod replacement.
- Understand access modes and the consequences of deleting a claim.

## Concept refresher: where does a file actually live?

A container's writable layer is not durable application storage. Kubernetes
**volumes** give containers a mounted filesystem, but their lifetimes depend on
the volume source. An `emptyDir` belongs to one Pod; persistent storage is
requested separately through a **PersistentVolumeClaim**.

![A Pod references a PVC bound to a PV; a StorageClass and CSI driver provision backing storage, while emptyDir has only the Pod's lifetime.](images/03-volumes.png)

*Read the picture:* arrows show references and provisioning, not a chain of
network proxies that file data passes through. The Pod sees a mounted path;
the CSI driver and node arrange the mount to the actual backend.
The requested class must exist and work before this exercise.

### Objects and fields you will manipulate or inspect

| Object or field | Scope | Purpose and role in the exercise |
| --- | --- | --- |
| **Pod `volumes` / `volumeMounts`** | Fields in a namespaced Pod template | Connect a named volume source to a container path. These are not standalone API objects. |
| **`emptyDir`** | Pod-lifetime volume source | Initially backs the public `data` directory. Survives a container restart in that Pod; lost when that Pod is removed. |
| **PVC: PersistentVolumeClaim** | Namespace | An app's request for capacity, access mode and optional StorageClass. `demo-data` requests a writable 1Gi filesystem volume. |
| **PV: PersistentVolume** | Cluster | Describes a provisioned storage resource and its binding to a claim, backend reference, capacity and reclaim policy. The PV object is not the actual disk/share. |
| **StorageClass** | Cluster | Defines a provisioning policy: provisioner/parameters, reclaim policy and binding behavior. It is a recipe, not a volume or a pool of already mounted files. |
| **CSI driver / CSIDriver** | Driver software / cluster API object | CSI software implements storage operations; a CSIDriver object advertises driver capabilities. Creating that object alone does not install a working driver. |
| **Event** | Namespace for the Pod/PVC events here | Explains provisioning, attach, scheduling or mount failures. Read the reason/message rather than assuming every Pending PVC is broken. |
| **Deployment patch** | Change to an existing namespaced Deployment | Replaces the `data` volume source, sets one replica and chooses Recreate. The patch file itself is not a new Kubernetes object. |

### Dynamic versus static provisioning

**Dynamic path used first:** create a PVC that names the trainer-approved class.
The provisioner creates backing storage and a PV; Kubernetes binds the PVC/PV,
and the consuming Pod can mount it. With `WaitForFirstConsumer`, provisioning
or binding waits for scheduling information from a consuming Pod. That is why
the instructions do not wait for Bound before creating the consumer.

**Static NFS extension:** the administrator first provides a dedicated export
and creates a PV pointing at it. Its `claimRef` reserves it; the PVC's
`volumeName` selects it. `storageClassName: ""` avoids accidentally using the
default dynamic class. No new share is created merely by writing this PV YAML.

### Access mode, lifecycle and permissions are different questions

| Concept | Meaning to remember |
| --- | --- |
| `ReadWriteOnce` (RWO) | Read/write mounting by one node; not necessarily only one Pod. One replica plus Recreate avoids overlapping rollout consumers here. |
| `ReadWriteMany` (RWX) | Supports read/write mounts from multiple nodes when the backend/driver allows it. Does not make concurrent file writes safe for the application. |
| `Delete` reclaim policy | After claim release/deletion, supported provisioning normally deletes the PV and backing volume. Treat deletion as potentially destructive. |
| `Retain` reclaim policy | Leaves storage for administrator-led recovery/reclamation. It does not provide automated rebinding or backups. |
| UID/GID, ACLs and `fsGroup` | Determine whether the mounted filesystem is writable by this app (UID/GID 101). A Bound PVC does not prove filesystem permissions are correct. |

Pod deletion leaves a separately existing PVC/PV intact; namespace deletion
deletes its PVCs and can trigger backend deletion. None of these policies
replaces backup or disaster recovery.

On **Azure Local**, SAN-backed storage for VM disks and storage presented to
Pods through CSI are different layers. PowerStore/PowerScale hardware does not
tell you which StorageClass, transport or access modes are available. Use the
class and permissions validated by the trainer; do not guess Dell parameters.

**Docker bridge:** a PVC is closer to an app requesting a named volume than
binding a host path. A PV/CSI backend adds provisioning, attachment and lifecycle
management across nodes.

**Recall before typing:** can you prove persistence by restarting only a
container in the same Pod? No; replace the Pod while keeping the same claim.

## 1. First, lose data with an emptyDir

Use one replica so a request/exec cannot accidentally target a different Pod:

```powershell
kubectl -n $Namespace scale deployment/demo --replicas=1
kubectl -n $Namespace rollout status deployment/demo --timeout=180s
kubectl -n $Namespace exec deployment/demo -- sh -c 'echo "temporary data" > /usr/share/nginx/html/data/note.txt'
kubectl -n $Namespace exec deployment/demo -- cat /usr/share/nginx/html/data/note.txt
kubectl -n $Namespace rollout restart deployment/demo
kubectl -n $Namespace rollout status deployment/demo --timeout=180s
kubectl -n $Namespace exec deployment/demo -- sh -c 'if [ -f /usr/share/nginx/html/data/note.txt ]; then echo "Unexpected: file still exists" >&2; exit 1; else echo "Expected: replacement Pod has no note.txt"; fi'
```

Expected: the file is gone. `emptyDir` survives a container restart inside the
same Pod, **not** replacement of that Pod.

## 2. Request storage with a PVC

Inspect your generated claim and confirm its class with the trainer:

```powershell
kubectl get storageclass $RwoStorageClass
kubectl -n $Namespace apply -f "$LabFiles\03-storage\pvc-rwo.yaml"
kubectl -n $Namespace get pvc demo-data
kubectl -n $Namespace patch deployment demo --type strategic --patch-file "$LabFiles\03-storage\use-pvc.patch.yaml"
kubectl -n $Namespace rollout status deployment/demo --timeout=300s
kubectl -n $Namespace get pvc demo-data
kubectl -n $Namespace describe pvc demo-data
```

The patch replaces `emptyDir` with a PVC reference, sets one replica and uses
`Recreate`. It is a **patch**, not a resource for `kubectl apply`.
With `WaitForFirstConsumer`, Pending before a consuming Pod is scheduled is
normal; the order above deliberately creates the consumer before waiting.

Expected: PVC `Bound`, Deployment available, one Ready Pod. If provisioning or
mounting fails:

```powershell
kubectl -n $Namespace get pods -l app=demo
kubectl -n $Namespace describe pvc demo-data
kubectl -n $Namespace get events --sort-by=.metadata.creationTimestamp
```

Do not "fix" this by switching to hostPath, privileged containers, chmod 777 or
an arbitrary default StorageClass. Ask the trainer to identify the CSI, transport,
topology or UID/GID/ACL issue from events.

If you can read cluster-scoped storage resources (otherwise trainer demo):

```powershell
$PvName = kubectl -n $Namespace get pvc demo-data -o jsonpath='{.spec.volumeName}'
kubectl get pv $PvName
kubectl describe pv $PvName
```

Find its claim reference, storage class, access mode, reclaim policy and CSI
driver/volume handle. The PV is cluster-scoped; the PVC is namespaced.

## 3. Prove persistence across Pod replacement

```powershell
kubectl -n $Namespace exec deployment/demo -- sh -c 'echo "This file lives on my PVC" > /usr/share/nginx/html/data/note.txt'
kubectl -n $Namespace get pods -l app=demo
kubectl -n $Namespace rollout restart deployment/demo
kubectl -n $Namespace rollout status deployment/demo --timeout=300s
kubectl -n $Namespace get pods -l app=demo
kubectl -n $Namespace exec deployment/demo -- cat /usr/share/nginx/html/data/note.txt
curl.exe --fail --noproxy "*" --resolve "${LabHost}:80:${IngressIp}" "http://${LabHost}/data/note.txt"
kubectl -n $Namespace get pvc demo-data
```

Expected: new Pod, **same PVC/PV**, same file contents returned through Ingress.
Do not put secrets in this publicly served data directory.

Discuss:

- RWO means read/write by one **node**, not necessarily only one Pod.
- Single replica + Recreate avoids overlapping rollout consumers here, but is
  not high availability. Do not scale this RWO example to multiple nodes.
- RWX allows multi-node mounts if the backend/driver supports it; applications
  still need concurrency-safe file handling.
- Deleting a Pod, deleting a PVC and deleting a namespace are different actions.
- `Delete` reclaim policy can delete backend data after PVC deletion; `Retain`
  requires administrator reclamation. Neither is a backup policy.
- A new claim normally gets new storage; it does not find old data by app name.

**Do not reapply the original Deployment now**: it still declares an emptyDir.
The running Deployment was patched. In a real project, update the canonical
manifest or use a managed overlay so desired state matches the intended storage.

## Optional A: shared PowerScale/RWX storage (+10 minutes)

Only if the trainer supplied and validated an RWX class. This switches to a
**different volume**, not a data migration:

```powershell
kubectl -n $Namespace apply -f "$LabFiles\03-storage\optional-rwx\pvc-rwx.yaml"
kubectl -n $Namespace patch deployment demo --type strategic --patch-file "$LabFiles\03-storage\optional-rwx\use-rwx.patch.yaml"
kubectl -n $Namespace rollout status deployment/demo --timeout=300s
$Pods = (kubectl -n $Namespace get pods -l app=demo -o json | ConvertFrom-Json).items
kubectl -n $Namespace exec $Pods[0].metadata.name -- sh -c 'echo "shared through RWX" > /usr/share/nginx/html/data/note.txt'
kubectl -n $Namespace exec $Pods[1].metadata.name -- cat /usr/share/nginx/html/data/note.txt
kubectl -n $Namespace get pods -l app=demo -o wide
```

Expected: both Pods see the same file. They may land on the same node; that
alone does not prove multi-node behavior. A trainer can add a temporary
anti-affinity rule if there are two eligible nodes and time permits.

## Optional B: explicitly create a static NFS PV (+10-15 minutes)

Trainer-led alternative. No CSI installation is required for the in-tree NFS
PV object itself, but node NFS client support and a supported platform path are
still required. This is not a Dell CSI installer or a production recommendation.

The trainer edits your generated
`03-storage\optional-static\pv-nfs.yaml`:

- Replace **192.0.2.10** (documentation-only address) and export path with a
  dedicated, approved PowerScale/NFS export.
- Confirm `claimRef.namespace`, unique PV name and UID/GID 101 permissions.
- Confirm NFS 4.1/node prerequisites. Reserve one directory/export per learner.

Trainer applies the cluster-scoped PV; learner applies its matching claim:

```powershell
# Trainer:
kubectl apply -f "$LabFiles\03-storage\optional-static\pv-nfs.yaml"
# Learner:
kubectl -n $Namespace apply -f "$LabFiles\03-storage\optional-static\pvc-nfs.yaml"
kubectl -n $Namespace patch deployment demo --type strategic --patch-file "$LabFiles\03-storage\optional-static\use-static.patch.yaml"
kubectl -n $Namespace rollout status deployment/demo --timeout=300s
```

`storageClassName: ""` disables default-class selection, `volumeName` selects
the PV and the PV's `claimRef` reserves it for this namespace/claim.
Repeat the persistence test. NFS capacity in the PV is not an enforced quota
unless the storage system applies one. Reclaim policy is deliberately `Retain`;
the trainer owns later PV/export/data cleanup.

## Completion checkpoint

- A replacement Pod loses `emptyDir` data but retains data on the same PVC.
- The claim binds to a PV using the trainer-approved StorageClass.
- RWO/RWX and Delete/Retain policies are understood.
- Keep the app and PVC for the remaining labs; do not delete the namespace yet.

[Previous: Service / Ingress / Gateway API](02-service-ingress-gatewayapi.md) | [Lab index](../LAB-GUIDE.md) | [Next: Helm](04-helm.md)
