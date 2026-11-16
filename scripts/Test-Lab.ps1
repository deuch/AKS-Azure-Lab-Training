[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$chart = Join-Path $root 'charts\training-web'
Get-Command helm -ErrorAction Stop | Out-Null

& helm lint $chart --strict --kube-version 1.36.0
if ($LASTEXITCODE -ne 0) {
    throw 'Helm lint failed.'
}

function Get-RenderedChart {
    param([string[]]$Overrides = @())
    $rendered = & helm template helm-web $chart --namespace lab01 --kube-version 1.36.0 @Overrides
    if ($LASTEXITCODE -ne 0) {
        throw 'Helm rendering failed.'
    }
    return $rendered -join "`n"
}

function Assert-Contains {
    param([string]$Content, [string]$Pattern, [string]$Message)
    if ($Content -notmatch $Pattern) {
        throw $Message
    }
}

$baseline = Get-RenderedChart
foreach ($kind in @('Deployment', 'Service', 'ConfigMap', 'Ingress')) {
    Assert-Contains $baseline "(?m)^kind: $kind$" "Default render is missing $kind."
}
Assert-Contains $baseline 'replicas: 2' 'Default replica count is incorrect.'
Assert-Contains $baseline 'helm.lab01.lab.test' 'Default hostname is incorrect.'

$noIngress = Get-RenderedChart -Overrides @('--set', 'ingress.enabled=false')
if ($noIngress -match '(?m)^kind: Ingress$') {
    throw 'Ingress is still rendered when disabled.'
}

$changed = Get-RenderedChart -Overrides @('--set', 'replicaCount=3', '--set-string', 'message=Hello from Helm - version 2')
Assert-Contains $changed 'replicas: 3' 'Replica override was ignored.'
Assert-Contains $changed 'Hello from Helm - version 2' 'Message override was ignored.'
$originalChecksum = [regex]::Match($baseline, 'checksum/config: ([a-f0-9]{64})').Groups[1].Value
$changedChecksum = [regex]::Match($changed, 'checksum/config: ([a-f0-9]{64})').Groups[1].Value
if (-not $originalChecksum -or -not $changedChecksum -or $originalChecksum -eq $changedChecksum) {
    throw 'Config changes do not change the Pod-template checksum.'
}

$tls = Get-RenderedChart -Overrides @('--set', 'ingress.tls.enabled=true', '--set', 'ingress.tls.secretName=helm-web-tls')
Assert-Contains $tls 'secretName: "helm-web-tls"' 'TLS Secret reference was not rendered.'

$invalidTls = & helm template helm-web $chart --set ingress.tls.enabled=true 2>&1
if ($LASTEXITCODE -eq 0) {
    throw 'TLS without a Secret name should fail rendering.'
}
if (($invalidTls -join "`n") -notmatch 'Set ingress.tls.secretName') {
    throw "Unexpected TLS validation error: $invalidTls"
}

Write-Output 'PASS: lint, default render, ingress switch, replicas/message, config checksum, TLS and invalid-TLS validation.'
Write-Output 'These are local chart checks, not a live-cluster or storage/network acceptance test.'
