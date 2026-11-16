{{- define "training-web.name" -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "training-web.selectorLabels" -}}
app.kubernetes.io/name: training-web
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "training-web.labels" -}}
{{ include "training-web.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | quote }}
{{- end -}}
