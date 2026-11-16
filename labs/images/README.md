# Lab concept illustrations

These **original workshop diagrams** refresh the concepts before each exercise.
They are not extracted slides or official Microsoft/Dell product architecture
diagrams. The reference PowerPoint was protected and could not be extracted.
The pictures are deliberately simplified and describe this lab's configuration.

The guides embed PNGs so the pictures work offline in ordinary Markdown
previews. Each picture also has a vector SVG and editable Excalidraw source.

| Picture | What to remember | Vector | Editable source |
| --- | --- | --- | --- |
| [Preparation](00-preparation.png) | API management path; namespace versus cluster scope | [SVG](00-preparation.svg) | [Excalidraw](00-preparation.excalidraw) |
| [Deployment ownership](01-deployment.png) | Deployment -> ReplicaSet -> Pods; controllers replace missing Pods | [SVG](01-deployment.svg) | [Excalidraw](01-deployment.excalidraw) |
| [Configuration injection](01-configuration.png) | Same image, separate ConfigMap/Secret; refresh behavior differs | [SVG](01-configuration.svg) | [Excalidraw](01-configuration.excalidraw) |
| [Networking](02-networking.png) | Logical HTTP path versus configuration; L4 versus L7 | [SVG](02-networking.svg) | [Excalidraw](02-networking.excalidraw) |
| [Volumes](03-volumes.png) | Pod -> PVC -> PV; provisioning and backend are separate from API records | [SVG](03-volumes.svg) | [Excalidraw](03-volumes.excalidraw) |
| [Helm](04-helm.png) | Chart/values -> rendered manifests -> release revisions | [SVG](04-helm.svg) | [Excalidraw](04-helm.excalidraw) |
| [Operator](04-operator.png) | CRDs register types; a controller maintains TLS output consumed by Traefik | [SVG](04-operator.svg) | [Excalidraw](04-operator.excalidraw) |

## Regeneration

The canonical layout/text definitions are in
[Export-LabDiagrams.ps1](../../scripts/Export-LabDiagrams.ps1). From the workshop
root on **Windows with PowerShell 7**, run:

```powershell
.\scripts\Export-LabDiagrams.ps1
```

The script uses the Windows drawing APIs to regenerate all seven PNG/SVG/
Excalidraw triplets locally, without installing packages or uploading content.
It checks text measurements before rendering and overwrites only its seven
named triplets in this folder. Other workshop commands are cross-platform
PowerShell examples; this optional image exporter is Windows-specific.

Edit the script to keep all three formats synchronized. Alternatively, open an
Excalidraw source in the approved [Microsoft Excalidraw instance](https://aka.ms/excalidraw)
and export a revised image, then update the canonical definitions if regenerating
later.

Colors distinguish object roles. Solid/dashed arrows have the meaning stated
in each diagram's caption; arrows do not always represent network traffic.
Detailed descriptions and applicability caveats remain in the lab text.
