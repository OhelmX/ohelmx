{{- define "minio.checkListCondition" -}}
{{- $found := false -}}
{{- range .Values.minio.extendedOperator.buckets -}}
  {{- if .public -}}
    {{- $found = true -}}
  {{- end -}}
{{- end -}}
{{- if $found -}}
  "true"
{{- end -}}
{{- end -}}

# minio:
#   enabled: true
#
#   extendedOperator:
#     # Set this to create a user for OpenedX to use for storage
#     # The secret with this name must exist and contain keys `secretKey`
#     # You can use the provided `ok3dx/kube/k3d-deploy/secrets/openedx-infra/s3-storage.json` to create such a secret
#     user:
#       name: s3-storage
#       secretName: s3-storage
#       secretKeyName: password
#
#     buckets:
#       - name: openedx
#         versioning: true
