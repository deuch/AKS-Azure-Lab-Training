[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-z]([-a-z0-9]{0,38}[a-z0-9])?$')]
    [string]$Namespace,

    # Defaults are the built-in AKS (Azure) classes; override them on platforms without these classes.
    [ValidatePattern('^[a-z0-9]([-a-z0-9.]*[a-z0-9])?$')]
    [string]$RwoStorageClass = 'managed-csi',

    [ValidatePattern('^[a-z0-9]([-a-z0-9.]*[a-z0-9])?$')]
    [string]$RwxStorageClass = 'azurefile-csi'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$source = Join-Path $root 'manifests'
$destination = Join-Path $root ".work\$Namespace"
if (Test-Path -LiteralPath $destination) {
    throw "Workspace already exists: $destination. Use another namespace or deliberately remove only that generated directory."
}

$files = Get-ChildItem -LiteralPath $source -File -Recurse -Filter '*.yaml'
foreach ($file in $files) {
    $relative = $file.FullName.Substring($source.Length + 1)
    $target = Join-Path $destination $relative
    New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
    $content = [System.IO.File]::ReadAllText($file.FullName).
        Replace('lab01.lab.test', "$Namespace.lab.test").
        Replace('storageClassName: managed-csi', "storageClassName: $RwoStorageClass").
        Replace('storageClassName: azurefile-csi', "storageClassName: $RwxStorageClass")
    [System.IO.File]::WriteAllText($target, $content, [System.Text.UTF8Encoding]::new($false))
}

Write-Output "Prepared $($files.Count) YAML files in $destination"
Write-Output "Hostname: $Namespace.lab.test"
Write-Output "Storage classes: RWO=$RwoStorageClass, RWX=$RwxStorageClass"
Write-Output 'No cluster resources were created. Follow LAB-GUIDE.md in order; do not apply this directory recursively.'
