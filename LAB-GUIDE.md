# Participant labs: from Docker to Kubernetes

The hands-on workshop is split into **six topic-based guides**. Follow them in
order; each guide states its prerequisites and what to leave ready for the next.
The YAML samples and Helm chart remain in their original locations.

Each guide now starts with a **concept refresher**, an object/scope table,
Docker comparisons and illustrated explanations so you can revisit the theory
presented a week earlier. Spend about five minutes on the refresher before
running commands. Each picture has a caption explaining how to read it.

**Audience:** people who know Docker. **Shell:** PowerShell 7.4+.
**Starting point:** an existing AKS workload cluster, prepared by the trainer.
The Volumes lab uses the AKS (Azure) built-in storage classes `managed-csi` and
`azurefile-csi`. No image build or application coding is required.

## Lab sequence

| Order | Lab | Minutes | What you will do |
| --- | --- | ---: | --- |
| 0 | [Preparation](labs/00-preparation.md) | 15 | Refresh API objects/scopes, verify tools/context, create a namespace and generate learner-specific files |
| 1 | [Deployment / Pods / ReplicaSet](labs/01-deployment-pods-replicaset.md) | 50 | Refresh ownership/configuration, deploy, replace/scale Pods, manage ConfigMaps and Secrets |
| 2 | [Service / Ingress / Gateway API](labs/02-service-ingress-gatewayapi.md) | 50 | Refresh discovery versus routing, create a Service, repair selectors and compare HTTP routing APIs |
| 3 | [Volumes](labs/03-volumes.md) | 45 | Refresh storage lifecycles, compare emptyDir/PVC, persist data on an Azure Disk (`managed-csi`), share it with Azure Files (`azurefile-csi`) and watch the reclaim policy |
| 4 | [Jobs and CronJobs](labs/04-jobs-cronjobs.md) | 40 | Refresh run-to-completion workloads, run one-off, parallel and failing Jobs, schedule, trigger and suspend a CronJob |
| 5 | [Helm](labs/05-helm.md) | 35 | Refresh charts versus releases, assemble/render a chart, install, upgrade, roll back and package |

Allow **10 minutes for a break** and **10 minutes for debrief/cleanup** at the end
of the Helm guide: **255 minutes (about 4h15) for the core sequence**, including
the refreshers. The optional
[cert-manager operator/CRD extension](labs/05-helm.md#optional-extension-operator-and-crd-with-cert-manager-30-minutes)
adds 30 minutes (**285 minutes**). This no longer fits a strict half day: run it
as a full day with discussion time, or as two sessions, for example labs 0-3
(about 2h40) then labs 4-5 with cleanup and the optional operator extension
(about 1h30-2h).

ConfigMaps/Secrets stay with the Deployment lab. The operator, TLS, cleanup and
troubleshooting exercises are in the Helm guide. The CronJob in lab 4 writes into
the Azure Files claim created in lab 3.

## How to run the labs

- Trainer: complete [Instructor setup](docs/INSTRUCTOR-SETUP.md) first.
- Run commands from the **workshop root**, the folder containing this index,
  **not** from the `labs` folder.
- Keep the same PowerShell session and your assigned namespace throughout.
  Preparation sets the shared variables; Networking adds `$IngressIp`.
- Use a second terminal for port-forwarding. Stop tunnels with Ctrl+C.
- Follow the file-by-file instructions. **Do not apply the manifests recursively**:
  they include alternative routing paths and deployment patches.
- Keep previous labs' objects until final cleanup. Deleting a namespace also
  deletes its PVCs, and with `managed-csi`/`azurefile-csi` their Azure disks and
  file shares.
- Use synthetic content only; never put credentials or sensitive data in the
  served page or public data directory.
- Stop at unexpected failures. PowerShell does not automatically stop for a
  nonzero native-command exit code.

## Supporting material

- [Instructor setup and platform prerequisites](docs/INSTRUCTOR-SETUP.md)
- [Documentation sources and compatibility evidence](docs/SOURCES.md)
- [Raw Kubernetes manifests](manifests)
- [Reference Helm chart](charts/training-web)
- [Illustration gallery and editable sources](labs/images/README.md)

Start with **[Preparation](labs/00-preparation.md)**.
