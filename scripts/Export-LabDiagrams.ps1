[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$output = Join-Path (Split-Path -Parent $PSScriptRoot) 'labs\images'
New-Item -ItemType Directory -Path $output -Force | Out-Null
$palette = @{
    Blue   = @('#0078D4', '#CFE4FA')
    Green  = @('#107C10', '#DFF6DD')
    Purple = @('#5C2D91', '#E8DAEF')
    Orange = @('#F7630C', '#FFF4CE')
    Gray   = @('#495057', '#F3F2F1')
}

function ConvertTo-XmlText([string]$Text) {
    [System.Security.SecurityElement]::Escape($Text)
}

function New-Element([string]$Type, [double]$X, [double]$Y, [double]$Width, [double]$Height) {
    @{
        id = "element-$($script:elements.Count)"
        type = $Type
        x = $X; y = $Y; width = $Width; height = $Height
        angle = 0; strokeColor = '#495057'; backgroundColor = 'transparent'
        fillStyle = 'solid'; strokeWidth = 2; strokeStyle = 'solid'
        roughness = 0; opacity = 100; groupIds = @(); frameId = $null
        index = $null; roundness = $null; seed = 1; version = 1
        versionNonce = 1; isDeleted = $false; boundElements = @()
        updated = 1; link = $null; locked = $false
    }
}

function Add-Label {
    param(
        [double]$X, [double]$Y, [double]$Width, [string]$Text,
        [int]$Size = 20, [switch]$Bold
    )
    $style = if ($Bold) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }
    $font = [System.Drawing.Font]::new('Segoe UI', $Size, $style, [System.Drawing.GraphicsUnit]::Pixel)
    $format = [System.Drawing.StringFormat]::GenericTypographic.Clone()
    try {
        $extent = $script:graphics.MeasureString($Text, $font, [int]::MaxValue, $format)
        if ($extent.Width -gt $Width -or $X -lt 0 -or ($X + $Width) -gt 1280 -or ($Y + $Size * 1.5) -gt 720) {
            throw "Diagram label does not fit: '$Text' (measured $($extent.Width), available $Width)."
        }
        $script:graphics.DrawString($Text, $font, [System.Drawing.Brushes]::Black, [single]$X, [single]$Y, $format)
        $weight = if ($Bold) { '600' } else { '400' }
        $escaped = ConvertTo-XmlText $Text
        $script:svg.Add("<text x='$X' y='$($Y + $Size)' font-size='$Size' font-weight='$weight'>$escaped</text>")
        $element = New-Element 'text' $X $Y $Width ($Size * 2.5)
        $element.strokeColor = '#000000'
        $element.fontSize = $Size
        $element.fontFamily = 2
        $element.text = $Text
        $element.originalText = $Text
        $element.textAlign = 'left'
        $element.verticalAlign = 'top'
        $element.containerId = $null
        $element.autoResize = $true
        $element.lineHeight = 1.25
        $script:elements.Add($element)
    }
    finally {
        $format.Dispose()
        $font.Dispose()
    }
}

function Add-Card {
    param(
        [double]$X, [double]$Y, [double]$Width, [double]$Height,
        [string]$Title, [string[]]$Lines, [string]$Tone = 'Blue'
    )
    if (($Y + $Height) -gt 640 -or (62 + $Lines.Count * 30) -gt $Height) {
        throw "Diagram card does not fit: $Title"
    }
    $colors = $palette[$Tone]
    $brush = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml($colors[1]))
    $pen = [System.Drawing.Pen]::new([System.Drawing.ColorTranslator]::FromHtml($colors[0]), 2)
    try {
        $script:graphics.FillRectangle($brush, [single]$X, [single]$Y, [single]$Width, [single]$Height)
        $script:graphics.DrawRectangle($pen, [single]$X, [single]$Y, [single]$Width, [single]$Height)
        $script:svg.Add("<rect x='$X' y='$Y' width='$Width' height='$Height' fill='$($colors[1])' stroke='$($colors[0])' stroke-width='2'/>")
        $element = New-Element 'rectangle' $X $Y $Width $Height
        $element.strokeColor = $colors[0]
        $element.backgroundColor = $colors[1]
        $script:elements.Add($element)
        Add-Label ($X + 18) ($Y + 15) ($Width - 36) $Title 24 -Bold
        for ($i = 0; $i -lt $Lines.Count; $i++) {
            Add-Label ($X + 18) ($Y + 57 + $i * 30) ($Width - 36) $Lines[$i]
        }
    }
    finally {
        $pen.Dispose()
        $brush.Dispose()
    }
}

function Add-Arrow {
    param([double]$X1, [double]$Y1, [double]$X2, [double]$Y2, [switch]$Dashed)
    $pen = [System.Drawing.Pen]::new([System.Drawing.ColorTranslator]::FromHtml('#495057'), 2)
    $cap = [System.Drawing.Drawing2D.AdjustableArrowCap]::new(5, 6, $true)
    try {
        $pen.CustomEndCap = $cap
        if ($Dashed) { $pen.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash }
        $script:graphics.DrawLine($pen, [single]$X1, [single]$Y1, [single]$X2, [single]$Y2)
        $dash = if ($Dashed) { " stroke-dasharray='8 6'" } else { '' }
        $script:svg.Add("<line x1='$X1' y1='$Y1' x2='$X2' y2='$Y2' stroke='#495057' stroke-width='2'$dash marker-end='url(#arrow)'/>")
        $element = New-Element 'arrow' $X1 $Y1 ([Math]::Abs($X2 - $X1)) ([Math]::Abs($Y2 - $Y1))
        $element.points = @(@(0, 0), @(($X2 - $X1), ($Y2 - $Y1)))
        $element.startBinding = $null
        $element.endBinding = $null
        $element.startArrowhead = $null
        $element.endArrowhead = 'arrow'
        $element.elbowed = $false
        if ($Dashed) { $element.strokeStyle = 'dashed' }
        $script:elements.Add($element)
    }
    finally {
        $pen.Dispose()
        $cap.Dispose()
    }
}

function Export-Diagram {
    param([string]$Name, [string]$Title, [string]$Subtitle, [scriptblock]$Content, [string]$Note)
    $script:elements = [System.Collections.Generic.List[object]]::new()
    $script:svg = [System.Collections.Generic.List[string]]::new()
    $bitmap = [System.Drawing.Bitmap]::new(1920, 1080)
    $script:graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $script:graphics.Clear([System.Drawing.Color]::White)
        $script:graphics.ScaleTransform(1.5, 1.5)
        $script:graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $script:graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
        $escapedTitle = ConvertTo-XmlText $Title
        $script:svg.Add("<svg xmlns='http://www.w3.org/2000/svg' width='1280' height='720' viewBox='0 0 1280 720' role='img' aria-labelledby='title'><title id='title'>$escapedTitle</title><defs><marker id='arrow' viewBox='0 0 10 10' refX='10' refY='5' markerWidth='8' markerHeight='8' orient='auto-start-reverse'><path d='M 0 0 L 10 5 L 0 10 z' fill='#495057'/></marker></defs><rect width='1280' height='720' fill='white'/><g font-family='Segoe UI, Arial, sans-serif' fill='black'>")
        Add-Label 40 26 1200 $Title 32 -Bold
        Add-Label 40 82 1200 $Subtitle
        & $Content
        Add-Label 40 665 1200 $Note
        $script:svg.Add('</g></svg>')
        [System.IO.File]::WriteAllLines((Join-Path $output "$Name.svg"), $script:svg, [System.Text.UTF8Encoding]::new($false))
        $scene = @{
            type = 'excalidraw'; version = 2; source = 'AKS-Training'
            elements = @($script:elements.ToArray())
            appState = @{ viewBackgroundColor = '#ffffff'; gridSize = $null }
            files = @{}
        }
        $scene | ConvertTo-Json -Depth 20 | Set-Content -Encoding utf8 (Join-Path $output "$Name.excalidraw")
        $bitmap.Save((Join-Path $output "$Name.png"), [System.Drawing.Imaging.ImageFormat]::Png)
        Write-Output "Exported $Name as PNG, SVG and editable Excalidraw."
    }
    finally {
        $script:graphics.Dispose()
        $bitmap.Dispose()
    }
}

Export-Diagram '00-preparation' 'Preparation: the API is your control surface' `
    'Declare objects through the API; the cluster continues the work after kubectl exits.' {
    Add-Card 40 155 275 155 'Your workstation' @('kubectl + kubeconfig', 'Manifest: desired state') 'Blue'
    Add-Card 420 155 335 155 'Kubernetes API' @('Validate + store objects', 'Expose spec and status') 'Purple'
    Add-Card 860 155 380 155 'Controllers + nodes' @('Observe and reconcile', 'Schedule and run Pods') 'Green'
    Add-Arrow 315 230 420 230
    Add-Arrow 755 230 860 230
    Add-Label 45 350 350 'Separate API scopes' 24 -Bold
    Add-Card 40 415 550 185 'Namespace: lab01' @('Deployment, Pod, Service, ConfigMap', 'Secret, PVC, Ingress, Gateway, HTTPRoute', 'Naming scope, not dedicated worker nodes') 'Blue'
    Add-Card 690 415 550 185 'Cluster-scoped resources' @('Nodes, PVs, StorageClasses, CRDs', 'IngressClass and GatewayClass', 'Shared; usually trainer-managed') 'Gray'
    Add-Arrow 520 310 315 415 -Dashed
    Add-Arrow 650 310 965 415 -Dashed
} 'Remember: correct cluster context first; a namespace alone does not provide tenant security.'

Export-Diagram '01-deployment' 'Deployment -> ReplicaSet -> Pods' `
    'Management relationships: the API objects describe state; running controllers take action.' {
    Add-Card 40 180 325 155 'Deployment: demo' @('Pod template + replicas: 2', 'Owns template rollouts') 'Blue'
    Add-Card 475 180 325 155 'ReplicaSet' @('One template revision', 'Maintains the Pod count') 'Purple'
    Add-Card 910 130 330 125 'Pod A' @('NGINX container :8080') 'Green'
    Add-Card 910 300 330 125 'Pod B' @('NGINX container :8080') 'Green'
    Add-Arrow 365 255 475 255
    Add-Arrow 800 225 910 195
    Add-Arrow 800 290 910 360
    Add-Card 40 470 1200 155 'Reconciliation when one Pod is deleted' @('Declared: 2 Pods   |   Observed: 1 Pod   |   ReplicaSet controller creates a replacement', 'New Pod identity/IP; scheduler chooses a node; kubelet starts the container') 'Orange'
} 'Scaling changes the count; changing the Pod template creates a new ReplicaSet revision.'

Export-Diagram '01-configuration' 'Same image, separate configuration' `
    'ConfigMaps and Secrets are namespaced API objects referenced by the Pod template.' {
    Add-Card 40 155 400 155 'ConfigMap: demo-config' @('APP_MODE: training', 'index.html: web content') 'Blue'
    Add-Card 40 365 400 155 'Secret: demo-secret' @('Dummy TRAINING_TOKEN', 'Not a browser login feature') 'Orange'
    Add-Card 680 155 560 215 'Each application Pod' @('Environment values read at startup', 'index.html: ConfigMap subPath mount', '/run/training: read-only Secret files', 'Web data directory: initially emptyDir') 'Green'
    Add-Arrow 440 230 680 230
    Add-Arrow 440 440 680 330
    Add-Card 680 435 560 185 'Update behavior in this lab' @('Environment: restart needed', 'subPath file: restart needed', 'Normal projected files: eventual refresh') 'Purple'
} 'Secret files stay outside the web root. Base64 encoding is not encryption or safe Git storage.'

Export-Diagram '02-networking' 'Traffic flow is not the same as configuration' `
    'Solid arrows: logical HTTP path. Dashed arrows: API configuration or endpoint discovery.' {
    Add-Card 40 155 510 155 'Ingress option' @('IngressClass -> Traefik implementation', 'Ingress: hostname/path -> Service') 'Blue'
    Add-Card 650 155 590 155 'Gateway API option' @('GatewayClass -> Gateway listener', 'HTTPRoute: attachment + Service backend') 'Purple'
    Add-Card 40 435 190 155 'Client' @('Host header', 'VIP :80/443') 'Gray'
    Add-Card 305 435 265 155 'Traefik' @('Shared LB Service', 'HTTP reverse proxy') 'Green'
    Add-Card 645 435 250 155 'App Service' @('demo :80', 'Selector: app=demo') 'Blue'
    Add-Card 970 435 270 155 'Ready Pods' @('Container :8080', 'Replaceable IPs') 'Green'
    Add-Arrow 230 510 305 510
    Add-Arrow 570 510 645 510
    Add-Arrow 895 510 970 510
    Add-Arrow 350 310 420 435 -Dashed
    Add-Arrow 865 310 505 435 -Dashed
    Add-Label 760 375 460 'EndpointSlices = IPs + readiness'
} 'MetalLB/existing L4 exposes the VIP; Traefik implements L7 rules. App Service is a logical backend.'

Export-Diagram '03-volumes' 'Volumes: a claim outlives a replacement Pod' `
    'Arrows show references and provisioning, not file data passing through API objects.' {
    Add-Card 40 155 300 155 'Pod volume mount' @('Path inside the container', 'References claim demo-data') 'Green'
    Add-Card 450 155 330 155 'PVC: demo-data' @('Namespaced storage request', 'Capacity + access mode') 'Blue'
    Add-Card 890 155 350 155 'PV' @('Cluster-scoped volume record', 'Bound to one claim') 'Purple'
    Add-Arrow 340 230 450 230
    Add-Arrow 780 230 890 230
    Add-Card 40 420 350 185 'emptyDir comparison' @('Belongs to one Pod', 'Container restart: data stays', 'Pod replacement: data lost') 'Orange'
    Add-Card 470 420 350 185 'StorageClass + CSI' @('Provisioning policy + driver', 'Arrange create/attach/mount', 'Trainer validates the class') 'Blue'
    Add-Card 900 420 340 185 'Actual storage' @('Approved disk or NFS share', 'Pod mounts the backend', 'Delete/Retain needs care') 'Green'
    Add-Arrow 615 310 645 420 -Dashed
    Add-Arrow 820 510 900 510 -Dashed
    Add-Arrow 1065 310 1070 420 -Dashed
} 'RWO = one node, not necessarily one Pod. Keep the same PVC to prove persistence across Pod replacement.'

Export-Diagram '04-helm' 'Helm: package -> render -> install a release' `
    'Helm generates ordinary Kubernetes objects; it does not replace their controllers.' {
    Add-Card 40 155 325 185 'Chart + values' @('Templates and defaults', 'Message, replicas, hostname', 'Local inputs, not API types') 'Blue'
    Add-Card 475 155 325 185 'Rendered manifests' @('Deployment + ConfigMap', 'Service + Ingress', 'Inspect YAML before install') 'Purple'
    Add-Card 910 155 330 185 'Release: helm-web' @('One install in a namespace', 'Creates/updates resources', 'Helm records revisions') 'Green'
    Add-Arrow 365 245 475 245
    Add-Arrow 800 245 910 245
    Add-Card 40 450 1200 155 'Revision history in this exercise' @('Revision 1: version 1, two replicas   ->   Revision 2: version 2, three replicas', 'Rollback to 1 records revision 3: version 1, two replicas; it does not rewind application data') 'Gray'
} 'A ConfigMap checksum changes the Pod template on upgrade. Release history can contain sensitive values.'

Export-Diagram '04-operator' 'Operator example: declare a certificate, get a Secret' `
    'CRDs register types; a running controller performs and maintains the domain work.' {
    Add-Card 40 150 350 185 'CRDs + your resources' @('CRDs: register Issuer/Certificate', 'Issuer: how to sign', 'Certificate: desired DNS + key') 'Blue'
    Add-Card 485 150 350 185 'cert-manager' @('Controller reconciles resources', 'CertificateRequest: issuance', 'Renews/repairs the output') 'Purple'
    Add-Card 930 150 310 185 'TLS Secret' @('Certificate + private key', 'tls.crt / tls.key', 'Never print the key') 'Orange'
    Add-Arrow 390 245 485 245
    Add-Arrow 835 245 930 245
    Add-Card 40 450 690 155 'What Helm did versus what the operator does' @('Helm installed the shared controller once.', 'cert-manager keeps reconciling after Helm exits.') 'Gray'
    Add-Card 850 450 390 155 'Traefik + Ingress' @('Reference the local TLS Secret', 'Terminate incoming HTTPS') 'Green'
    Add-Arrow 1085 335 1045 450
} 'SelfSigned is a demo: successful issuance is not trusted TLS. The controller is not in the HTTP traffic path.'
