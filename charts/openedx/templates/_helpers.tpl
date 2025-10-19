{{- define "openedx.ingressroute.tlscertificate" -}}
{{- $component := .component -}}
{{- $root := .root -}}
{{- $existingTlsSecretName := index $root.Values.openedx $component "existingTlsSecretName" -}}
{{- $host := index $root.Values.openedx $component "host" -}}
{{- $generatedTlsSecretName := $host | replace "." "-" }}
{{- $tlsIssuerName := index $root.Values.openedx $component "tlsIssuerName" -}}
{{- $tlsIssuerKind := index $root.Values.openedx $component "tlsIssuerKind" -}}
{{- if not $existingTlsSecretName }}
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: {{ $generatedTlsSecretName | quote }}
spec:
  secretName: {{ $generatedTlsSecretName | quote }}
  issuerRef:
    name: {{ $tlsIssuerName | quote }}
    {{- if $tlsIssuerKind }}
    kind: {{ $tlsIssuerKind | quote }}
    {{- end }}
  dnsNames:
    - {{ $host | quote }}
{{- end }}
{{- end -}}

{{- define "openedx.ingressroute.tlsname" -}}
{{- $component := .component -}}
{{- $root := .root -}}
{{- $existingTlsSecretName := index $root.Values.openedx $component "existingTlsSecretName" -}}
{{- $host := index $root.Values.openedx $component "host" -}}
{{- $generatedTlsSecretName := $host | replace "." "-" }}
{{- if $existingTlsSecretName }}
secretName: {{ $existingTlsSecretName | quote }}
{{- else }}
secretName: {{ $generatedTlsSecretName | quote }}
{{- end }}
{{- end -}}

{{/*
  Template: openedx.ingressroute.integratedtls
  Usage: {{ include "openedx.ingressroute.integratedtls" (dict "component" "cms" "root" .) }}
  Renders the tls object for an IngressRoute, using existingTlsSecretName if set, otherwise certResolver.
  TODO: remove if not needed
*/}}
{{- define "openedx.ingressroute.integratedtls" -}}
{{- $component := .component -}}
{{- $root := .root -}}
{{- $existingTlsSecretName := index $root.Values.openedx $component "existingTlsSecretName" -}}
{{- $certResolver := $root.Values.openedx.traefik.certResolver -}}
{{- if $existingTlsSecretName }}
secretName: {{ $existingTlsSecretName | quote }}
{{- else }}
certResolver: {{ $certResolver | quote }}
{{- end }}
{{- end -}}

{{/*
  InitContainer to wait for Argo Workflow completion using curl
  Usage: {{ include "openedx.waitForArgoWorkflowInitContainer" (dict "namespace" .Values.global.namespace) }}
  TODO: remove if not needed
*/}}
{{- define "openedx.waitForArgoWorkflowInitContainer" -}}
- name: wait-for-migrations
  image: nixery.dev/shell/curl/jq
  imagePullPolicy: IfNotPresent
  command:
    - /bin/sh
    - -c
    - |
      # This init container waits for an Argo Workflow to complete. It supports two modes:
      # 1) If WORKFLOW_NAME is provided (environment variable override), wait for that workflow.
      # 2) Otherwise, wait for the latest Workflow created from the WorkflowTemplate
      #    named WORKFLOW_TEMPLATE_NAME (default: openedx-init-workflow-template).
      TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
      CA_CERT=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
      NAMESPACE={{ .namespace }}
      # Optional overrides: you can set WORKFLOW_NAME or WORKFLOW_TEMPLATE_NAME via env when using the helper
      WORKFLOW_NAME=${WORKFLOW_NAME:-}
      WORKFLOW_TEMPLATE_NAME=${WORKFLOW_TEMPLATE_NAME:-openedx-init-workflow-template}
      API_SERVER=https://kubernetes.default.svc

      echo "Waiting for Argo Workflow (template='$WORKFLOW_TEMPLATE_NAME', name='$WORKFLOW_NAME') in namespace $NAMESPACE"
      echo "Using jq version: $(jq --version)"

      while true; do
        if [ -z "$WORKFLOW_NAME" ]; then
          # Find the most recent Workflow created from the WorkflowTemplate
          echo "$(curl -s --cacert $CA_CERT -H "Authorization: Bearer $TOKEN" "$API_SERVER/apis/argoproj.io/v1alpha1/namespaces/$NAMESPACE/workflows")"
          echo "--------------------------------"
          WORKFLOW_NAME=$(curl -s --cacert $CA_CERT -H "Authorization: Bearer $TOKEN" \
            "$API_SERVER/apis/argoproj.io/v1alpha1/namespaces/$NAMESPACE/workflows" \
            | jq -r --arg tpl "$WORKFLOW_TEMPLATE_NAME" '.items[] | select(.spec.workflowTemplateRef.name == $tpl) | .metadata.name' \
            | sort | tail -n 1)
          if [ -z "$WORKFLOW_NAME" ]; then
            echo "No workflow found for template '$WORKFLOW_TEMPLATE_NAME' yet. Waiting..."
            sleep 5
            continue
          fi
          echo "Found workflow $WORKFLOW_NAME for template $WORKFLOW_TEMPLATE_NAME"
        fi

        status=$(curl -s --cacert $CA_CERT -H "Authorization: Bearer $TOKEN" \
          "$API_SERVER/apis/argoproj.io/v1alpha1/namespaces/$NAMESPACE/workflows/$WORKFLOW_NAME" \
          | jq -r '.status.phase' 2>/dev/null)

        if [ "$status" = "Succeeded" ]; then
          echo "Argo Workflow '$WORKFLOW_NAME' completed successfully."
          break
        elif [ "$status" = "Failed" ] || [ "$status" = "Error" ]; then
          echo "Argo Workflow '$WORKFLOW_NAME' failed or errored. Exiting."
          exit 1
        elif [ -z "$status" ] || [ "$status" = "null" ]; then
          echo "Workflow $WORKFLOW_NAME not found or no status yet. Resetting name and waiting..."
          WORKFLOW_NAME=
          sleep 5
          continue
        fi

        echo "Workflow status: $status. Waiting..."
        sleep 10
      done
{{- end }}
{{/*
Expand the name of the chart.
*/}}
{{- define "openedx.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "openedx.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "openedx.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "openedx.labels" -}}
helm.sh/chart: {{ include "openedx.chart" . }}
app.kubernetes.io/name: {{ include "openedx.name" . }}
app.kubernetes.io/instance: openedx-{{ .Values.global.instanceId }}
app.kubernetes.io/version: {{ .Values.global.openedxVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: openedx
{{- with .Values.commonLabels }}
{{- toYaml . | nindent 0 }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "openedx.selectorLabels" -}}
app.kubernetes.io/name: {{ include "openedx.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Component-specific labels
*/}}
{{- define "openedx.componentLabels" -}}
{{- $component := .component }}
{{- include "openedx.labels" .root | nindent 0 }}
app.kubernetes.io/component: {{ $component }}
{{- end }}

{{/*
Component-specific selector labels
*/}}
{{- define "openedx.componentSelectorLabels" -}}
{{- $component := .component }}
app.kubernetes.io/name: {{ include "openedx.name" .root }}
app.kubernetes.io/instance: openedx-{{ .root.Values.global.instanceId }}
app.kubernetes.io/component: {{ $component }}
{{- end }}

{{/*
Common annotations that match Kustomize commonAnnotations
*/}}
{{- define "openedx.annotations" -}}
app.kubernetes.io/version: {{ .Values.global.openedxVersion | quote }}
{{- with .Values.commonAnnotations }}
{{- toYaml . | nindent 0 }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "openedx.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "openedx.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Generate image reference
*/}}
{{- define "openedx.image" -}}
{{- $comp := .component -}}
{{- if eq $comp "openedx" -}}
  {{- $img := .root.Values.openedx.image -}}
  {{- printf "%s:%s" $img.repository $img.tag -}}
{{- else if hasKey .root.Values.openedx $comp -}}
  {{- $img := (index .root.Values.openedx $comp).image -}}
  {{- printf "%s:%s" $img.repository $img.tag -}}
{{- else -}}
  {{- printf "" -}}
{{- end -}}
{{- end }}

{{/*
Pull policy for images
*/}}
{{- define "openedx.imagePullPolicy" -}}
{{- $comp := .component -}}
{{- if eq $comp "openedx" -}}
  {{- .root.Values.openedx.image.pullPolicy | default "IfNotPresent" -}}
{{- else if hasKey .root.Values.openedx $comp -}}
  {{- ((index .root.Values.openedx $comp).image.pullPolicy) | default "IfNotPresent" -}}
{{- else -}}
  {{- printf "IfNotPresent" -}}
{{- end -}}
{{- end }}

{{/*
Shared environment variables
*/}}
{{- define "openedx.common.env" -}}
# Shared settings
- name: LMS_HOST
  value: {{ .Values.openedx.lms.host | quote }}
- name: PREVIEW_HOST
  value: {{ .Values.openedx.preview.host | quote }}
- name: CMS_HOST
  value: {{ .Values.openedx.cms.host | quote }}
- name: MFE_HOST
  value: {{ .Values.openedx.mfe.host | quote }}
- name: NOTES_HOST
  value: {{ .Values.openedx.notes.host | quote }}
- name: NOTES_SERVICE_HOST
  value: {{ .Values.openedx.notes.service.name | quote }}
- name: NOTES_SERVICE_PORT
  value: {{ .Values.openedx.notes.service.port | quote }}
- name: PLATFORM_NAME
  value: {{ .Values.openedx.platformName | quote }}
# FIXME: do we need this?
# - name: CONTACT_MAILING_ADDRESS
#   value: "contact@local.openedx.io"
- name: CONTACT_EMAIL
  value: {{ .Values.openedx.contactEmail | quote }}

- name: DOCUMENTDB_DATABASE
  value: {{ .Values.openedx.documentdb.name | quote }}
- name: DOCUMENTDB_HOST
  value: {{ .Values.openedx.documentdb.host | quote }}
- name: DOCUMENTDB_PORT
  value: {{ .Values.openedx.documentdb.port | quote }}
- name: DOCUMENTDB_USERNAME
  valueFrom:
    secretKeyRef:
      name: {{ .Values.openedx.documentdb.credentials }}
      key: username
- name: DOCUMENTDB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.openedx.documentdb.credentials }}
      key: password
- name: DOCUMENTDB_USE_SSL
  value: {{ .Values.openedx.documentdb.useSSL | quote }}
- name: DOCUMENTDB_AUTH_SOURCE
  value: {{ .Values.openedx.documentdb.authSource | quote }}
- name: DOCUMENTDB_AUTH_MECHANISM
  value: {{ .Values.openedx.documentdb.authMechanism | quote }}
- name: DOCUMENTDB_REPLICA_SET
  value: {{ .Values.openedx.documentdb.replicaSet | quote }}

- name: MEILISEARCH_URL
  value: "{{ .Values.openedx.meilisearch.service.scheme }}://{{ .Values.openedx.meilisearch.service.host }}:{{ .Values.openedx.meilisearch.service.port }}"
- name: MEILISEARCH_PUBLIC_URL
  value: {{ .Values.openedx.meilisearch.publicUrl | quote }}
- name: MEILISEARCH_INDEX_PREFIX
  value: {{ .Values.openedx.meilisearch.indexPrefix | quote }}

- name: MEILISEARCH_API_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .Values.openedx.meilisearch.auth.apiKey.secretName }}
      key: {{ .Values.openedx.meilisearch.auth.apiKey.secretKey }}

- name: MEILISEARCH_MASTER_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .Values.openedx.meilisearch.auth.existingMasterKeySecret }}
      key: MEILI_MASTER_KEY

- name: KV_ENGINE
  value: {{ .Values.openedx.cache.backend.engine | quote }}
- name: KV_HOST
  value: {{ .Values.openedx.cache.backend.host | quote }}
- name: KV_PORT
  value: {{ .Values.openedx.cache.backend.port | quote }}
- name: KV_USERNAME
  valueFrom:
    secretKeyRef:
      name: {{ .Values.openedx.cache.backend.credentials }}
      key: username
- name: KV_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.openedx.cache.backend.credentials }}
      key: password
- name: OPENEDX_CACHE_KV_DB
  value: {{ .Values.openedx.cache.backend.db | quote }}

- name: SMTP_USE_SSL
  value: {{ .Values.openedx.smtp.useSSL | quote }}

- name: JWT_RSA_PRIVATE_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .Values.openedx.jwtRsaPrivateKey.secretName }}
      key: {{ .Values.openedx.jwtRsaPrivateKey.secretKey }}
- name: JWT_COMMON_ISSUER
  value: "https://{{ .Values.openedx.lms.host }}/oauth2"
- name: JWT_COMMON_AUDIENCE
  value: {{ .Values.openedx.jwtCommonAudience | quote }}
- name: JWT_COMMON_SECRET_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .Values.openedx.jwtCommonSecretKey.secretName }}
      key: {{ .Values.openedx.jwtCommonSecretKey.secretKey }}
- name: OPENEDX_SECRET_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .Values.openedx.secretKey.secretName }}
      key: {{ .Values.openedx.secretKey.secretKey }}

- name: S3_GRADE_BUCKET
  value: {{ .Values.openedx.s3.gradeBucket | quote }}
- name: S3_PROFILE_IMAGE_BUCKET
  value: {{ .Values.openedx.s3.profileImageBucket | quote }}
- name: S3_STORAGE_BUCKET
  value: {{ .Values.openedx.s3.storageBucket | quote }}
- name: S3_FILE_UPLOAD_BUCKET
  value: {{ .Values.openedx.s3.fileUploadBucket | quote }}
# FIXME: what are these? Do we need them?
# S3_CUSTOM_DOMAIN: ''
# S3_PROFILE_IMAGE_CUSTOM_DOMAIN: ''
- name: S3_SIGNATURE_VERSION
  value: {{ .Values.openedx.s3.signatureVersion | quote }}
- name: S3_REQUEST_CHECKSUM_CALCULATION
  value: {{ .Values.openedx.s3.requestChecksumCalculation | quote }}
- name: S3_HOST
  value: {{ .Values.openedx.s3.host | quote }}
- name: S3_PORT
  value: {{ .Values.openedx.s3.port | quote }}
- name: S3_USE_SSL
  value: {{ .Values.openedx.s3.useSSL | quote }}
- name: S3_DEFAULT_ACL
  value: {{ .Values.openedx.s3.defaultACL | quote }}
- name: S3_ADDRESSING_STYLE
  value: {{ .Values.openedx.s3.addressingStyle | quote }}
- name: S3_REGION
  value: {{ .Values.openedx.s3.region | quote }}
{{- end }}

{{/*
Shared CMS environment variables
*/}}
{{- define "openedx.cms.env" -}}
# CMS specific
- name: SOCIAL_AUTH_EDX_OAUTH2_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ .Values.openedx.cms.socialAuthEdxOauth2Secret.secretName }}
      key: {{ .Values.openedx.cms.socialAuthEdxOauth2Secret.secretKey }}
- name: SOCIAL_AUTH_EDX_OAUTH2_URL_ROOT
  value: "http://{{ .Values.openedx.lms.service.name }}:{{ .Values.openedx.lms.service.port }}"
{{- end }}

{{/*
Shared python settings for LMS and CMS
*/}}
{{- define "openedx.common.shared" -}}
####### Settings common to LMS and CMS
import json
import os

from xmodule.modulestore.modulestore_settings import update_module_store_settings

# Mongodb connection parameters: simply modify `mongodb_parameters` to affect all connections to MongoDb.
documentdb_base_parameters = {
    "host": os.environ["DOCUMENTDB_HOST"],
    "port": int(os.environ["DOCUMENTDB_PORT"]),
    "password": os.environ["DOCUMENTDB_PASSWORD"],
    "connect": False,
    "ssl": os.environ["DOCUMENTDB_USE_SSL"] == "True",
    "authSource": os.environ["DOCUMENTDB_AUTH_SOURCE"],
}
if os.environ.get("DOCUMENTDB_AUTH_MECHANISM"):
    documentdb_base_parameters["authMechanism"] = os.environ["DOCUMENTDB_AUTH_MECHANISM"]

if os.environ.get("DOCUMENTDB_REPLICA_SET"):
    documentdb_base_parameters["replicaSet"] = os.environ["DOCUMENTDB_REPLICA_SET"]

mongodb_parameters = documentdb_base_parameters.copy()
mongodb_parameters["db"] = os.environ["DOCUMENTDB_DATABASE"]
mongodb_parameters["user"] = os.environ["DOCUMENTDB_USERNAME"]

DOC_STORE_CONFIG = mongodb_parameters
CONTENTSTORE = {
    "ENGINE": "xmodule.contentstore.mongo.MongoContentStore",
    "ADDITIONAL_OPTIONS": {},
    "DOC_STORE_CONFIG": DOC_STORE_CONFIG
}
# Load module store settings from config files
update_module_store_settings(MODULESTORE, doc_store_settings=DOC_STORE_CONFIG)
DATA_DIR = "/openedx/data/modulestore"

for store in MODULESTORE["default"]["OPTIONS"]["stores"]:
   store["OPTIONS"]["fs_root"] = DATA_DIR

# Behave like memcache when it comes to connection errors
DJANGO_REDIS_IGNORE_EXCEPTIONS = True

# Meilisearch connection parameters
MEILISEARCH_ENABLED = True
MEILISEARCH_URL = os.environ["MEILISEARCH_URL"]
MEILISEARCH_PUBLIC_URL = os.environ["MEILISEARCH_PUBLIC_URL"]
MEILISEARCH_INDEX_PREFIX = os.environ["MEILISEARCH_INDEX_PREFIX"]
MEILISEARCH_API_KEY = os.environ["MEILISEARCH_API_KEY"]
MEILISEARCH_MASTER_KEY = os.environ["MEILISEARCH_MASTER_KEY"]
SEARCH_ENGINE = "search.meilisearch.MeilisearchEngine"

KV_USER_PASS = ""
if os.environ.get("KV_PASSWORD") and os.environ.get("KV_USERNAME"):
  KV_USER_PASS = f"{os.environ['KV_USERNAME']}:{os.environ['KV_PASSWORD']}"
KV_HOST = os.environ["KV_HOST"]
KV_PORT = os.environ["KV_PORT"]
OPENEDX_CACHE_KV_DB = os.environ["OPENEDX_CACHE_KV_DB"]

# FIXME: should be protocol independent, and at the very least handle rediss://
KV_LOCATION = f"redis://{KV_USER_PASS}@{KV_HOST}:{KV_PORT}/{OPENEDX_CACHE_KV_DB}"
KV_ENGINE = os.environ["KV_ENGINE"]

# Common cache config
CACHES = {
    "default": {
        "KEY_PREFIX": "default",
        "VERSION": "1",
        "BACKEND": KV_ENGINE,
        "LOCATION": KV_LOCATION,
    },
    "general": {
        "KEY_PREFIX": "general",
        "BACKEND": KV_ENGINE,
        "LOCATION": KV_LOCATION,
    },
    "mongo_metadata_inheritance": {
        "KEY_PREFIX": "mongo_metadata_inheritance",
        "TIMEOUT": 300,
        "BACKEND": KV_ENGINE,
        "LOCATION": KV_LOCATION,
    },
    "configuration": {
        "KEY_PREFIX": "configuration",
        "BACKEND": KV_ENGINE,
        "LOCATION": KV_LOCATION,
    },
    "celery": {
        "KEY_PREFIX": "celery",
        "TIMEOUT": 7200,
        "BACKEND": KV_ENGINE,
        "LOCATION": KV_LOCATION,
    },
    "course_structure_cache": {
        "KEY_PREFIX": "course_structure",
        "TIMEOUT": 604800, # 1 week
        "BACKEND": KV_ENGINE,
        "LOCATION": KV_LOCATION,
    },
    "ora2-storage": {
        "KEY_PREFIX": "ora2-storage",
        "BACKEND": KV_ENGINE,
        "LOCATION": KV_LOCATION,
    }
}

# The default Django contrib site is the one associated to the LMS domain name. 1 is
# usually "example.com", so it's the next available integer.
SITE_ID = int(os.environ.get("SITE_ID", "2"))

LMS_HOST = os.environ["LMS_HOST"]
CMS_HOST = os.environ["CMS_HOST"]
MFE_HOST = os.environ["MFE_HOST"]
NOTES_HOST = os.environ["NOTES_HOST"]

# Contact addresses
CONTACT_MAILING_ADDRESS = os.environ.get("CONTACT_MAILING_ADDRESS", f"{os.environ['PLATFORM_NAME']} - https://{LMS_HOST}")
DEFAULT_FROM_EMAIL = ENV_TOKENS.get("DEFAULT_FROM_EMAIL", ENV_TOKENS["CONTACT_EMAIL"])
DEFAULT_FEEDBACK_EMAIL = ENV_TOKENS.get("DEFAULT_FEEDBACK_EMAIL", ENV_TOKENS["CONTACT_EMAIL"])
SERVER_EMAIL = ENV_TOKENS.get("SERVER_EMAIL", ENV_TOKENS["CONTACT_EMAIL"])
TECH_SUPPORT_EMAIL = ENV_TOKENS.get("TECH_SUPPORT_EMAIL", ENV_TOKENS["CONTACT_EMAIL"])
CONTACT_EMAIL = ENV_TOKENS.get("CONTACT_EMAIL", ENV_TOKENS["CONTACT_EMAIL"])
BUGS_EMAIL = ENV_TOKENS.get("BUGS_EMAIL", ENV_TOKENS["CONTACT_EMAIL"])
UNIVERSITY_EMAIL = ENV_TOKENS.get("UNIVERSITY_EMAIL", ENV_TOKENS["CONTACT_EMAIL"])
PRESS_EMAIL = ENV_TOKENS.get("PRESS_EMAIL", ENV_TOKENS["CONTACT_EMAIL"])
PAYMENT_SUPPORT_EMAIL = ENV_TOKENS.get("PAYMENT_SUPPORT_EMAIL", ENV_TOKENS["CONTACT_EMAIL"])
BULK_EMAIL_DEFAULT_FROM_EMAIL = ENV_TOKENS.get("BULK_EMAIL_DEFAULT_FROM_EMAIL", ENV_TOKENS["CONTACT_EMAIL"])
API_ACCESS_MANAGER_EMAIL = ENV_TOKENS.get("API_ACCESS_MANAGER_EMAIL", ENV_TOKENS["CONTACT_EMAIL"])
API_ACCESS_FROM_EMAIL = ENV_TOKENS.get("API_ACCESS_FROM_EMAIL", ENV_TOKENS["CONTACT_EMAIL"])

# Get rid completely of coursewarehistoryextended, as we do not use the CSMH database
INSTALLED_APPS.remove("lms.djangoapps.coursewarehistoryextended")
DATABASE_ROUTERS.remove(
    "openedx.core.lib.django_courseware_routers.StudentModuleHistoryExtendedRouter"
)

# Set uploaded media file path
# FIXME: is this NOT POSSIBLE?
MEDIA_ROOT = "/openedx/media/"

# Video settings
VIDEO_IMAGE_SETTINGS["STORAGE_KWARGS"]["location"] = MEDIA_ROOT
VIDEO_TRANSCRIPTS_SETTINGS["STORAGE_KWARGS"]["location"] = MEDIA_ROOT

GRADES_DOWNLOAD = {
    "STORAGE_TYPE": "",
    "STORAGE_KWARGS": {
        "base_url": "/media/grades/",
        "location": "/openedx/media/grades",
    },
}

# ORA2 FIXME: is this right?
ORA2_FILEUPLOAD_BACKEND = "filesystem"
ORA2_FILEUPLOAD_ROOT = "/openedx/data/ora2"
FILE_UPLOAD_STORAGE_BUCKET_NAME = os.environ["S3_FILE_UPLOAD_BUCKET"]
ORA2_FILEUPLOAD_CACHE_NAME = "ora2-storage"

# Change syslog-based loggers which don't work inside docker containers
LOGGING["handlers"]["local"] = {
    "class": "logging.handlers.WatchedFileHandler",
    "filename": os.path.join(LOG_DIR, "all.log"),
    "formatter": "standard",
}
LOGGING["handlers"]["tracking"] = {
    "level": "DEBUG",
    "class": "logging.handlers.WatchedFileHandler",
    "filename": os.path.join(LOG_DIR, "tracking.log"),
    "formatter": "standard",
}
LOGGING["loggers"]["tracking"]["handlers"] = ["console", "local", "tracking"]

# Silence some loggers (note: we must attempt to get rid of these when upgrading from one release to the next)
LOGGING["loggers"]["blockstore.apps.bundles.storage"] = {"handlers": ["console"], "level": "WARNING"}

# These warnings are visible in simple commands and init tasks
import warnings

# DeprecationWarning: 'imghdr' is deprecated and slated for removal in Python 3.13
warnings.filterwarnings("ignore", category=DeprecationWarning, module="pgpy.constants")

# Email
EMAIL_USE_SSL = os.environ.get("SMTP_USE_SSL", "false").lower() == "true"
# Forward all emails from edX's Automated Communication Engine (ACE) to django.
ACE_ENABLED_CHANNELS = ["django_email"]
ACE_CHANNEL_DEFAULT_EMAIL = "django_email"
ACE_CHANNEL_TRANSACTIONAL_EMAIL = "django_email"
EMAIL_FILE_PATH = "/tmp/openedx/emails"

# Language/locales
LANGUAGE_COOKIE_NAME = "openedx-language-preference"

# Allow the platform to include itself in an iframe
X_FRAME_OPTIONS = "SAMEORIGIN"

from Cryptodome.PublicKey import RSA
from Cryptodome.PublicKey.RSA import RsaKey
import base64
import struct

JWT_RSA_PRIVATE_KEY = os.environ["JWT_RSA_PRIVATE_KEY"]
jwt_rsa_key = RSA.import_key(JWT_RSA_PRIVATE_KEY.encode())

def long_to_base64(n):
    """
    Borrowed from jwkest.__init__
    """

    def long2intarr(long_int):
        _bytes = []
        while long_int:
            long_int, r = divmod(long_int, 256)
            _bytes.insert(0, r)
        return _bytes

    bys = long2intarr(n)
    data = struct.pack(f"{len(bys)}B", *bys)
    if not data:
        data = b"\x00"
    s = base64.urlsafe_b64encode(data).rstrip(b"=")
    return s.decode("ascii")

JWT_AUTH["JWT_ISSUER"] = os.environ["JWT_COMMON_ISSUER"]
JWT_AUTH["JWT_AUDIENCE"] = os.environ["JWT_COMMON_AUDIENCE"]
JWT_AUTH["JWT_SECRET_KEY"] = os.environ["JWT_COMMON_SECRET_KEY"]

JWT_AUTH["JWT_PRIVATE_SIGNING_JWK"] = json.dumps(
    {
        "kid": "openedx",
        "kty": "RSA",
        "e": long_to_base64(jwt_rsa_key.e),
        "d": long_to_base64(jwt_rsa_key.d),
        "n": long_to_base64(jwt_rsa_key.n),
        "p": long_to_base64(jwt_rsa_key.p),
        "q": long_to_base64(jwt_rsa_key.q),
        "dq": long_to_base64(jwt_rsa_key.dq),
        "dp": long_to_base64(jwt_rsa_key.dp),
        "qi": long_to_base64(jwt_rsa_key.invq),
    }
)
JWT_AUTH["JWT_PUBLIC_SIGNING_JWK_SET"] = json.dumps(
    {
        "keys": [
            {
                "kid": "openedx",
                "kty": "RSA",
                "e": long_to_base64(jwt_rsa_key.e),
                "n": long_to_base64(jwt_rsa_key.n),
            }
        ]
    }
)
JWT_AUTH["JWT_ISSUERS"] = [
    {
        "ISSUER": os.environ["JWT_COMMON_ISSUER"],
        "AUDIENCE": os.environ["JWT_COMMON_AUDIENCE"],
        "SECRET_KEY": os.environ["OPENEDX_SECRET_KEY"]
    }
]

# Enable/Disable some features globally
FEATURES["ENABLE_DISCUSSION_SERVICE"] = False
FEATURES["PREVENT_CONCURRENT_LOGINS"] = False
FEATURES["ENABLE_CORS_HEADERS"] = True

# CORS
CORS_ALLOW_CREDENTIALS = True
CORS_ORIGIN_ALLOW_ALL = False
CORS_ALLOW_INSECURE = False
# Note: CORS_ALLOW_HEADERS is intentionally not defined here, because it should
# be consistent across deployments, and is therefore set in edx-platform.

# Add your MFE and third-party app domains here
CORS_ORIGIN_WHITELIST = []

# Disable codejail support
# explicitely configuring python is necessary to prevent unsafe calls
import codejail.jail_code
codejail.jail_code.configure("python", "nonexistingpythonbinary", user=None)
# another configuration entry is required to override prod/dev settings
CODE_JAIL = {
    "python_bin": "nonexistingpythonbinary",
    "user": None,
}

OPENEDX_LEARNING = {
    'MEDIA': {
        "BACKEND": "django.core.files.storage.FileSystemStorage",
        "OPTIONS": {
            "location": "/openedx/media-private/openedx-learning",
        }
    }
}

# Forum configuration
FORUM_SEARCH_BACKEND = "forum.search.meilisearch.MeilisearchBackend"
FEATURES["ENABLE_DISCUSSION_SERVICE"] = True

# Forum mongodb configuration, for existing platforms still running mongodb
FORUM_MONGODB_DATABASE = "cs_comments_service"
FORUM_MONGODB_CLIENT_PARAMETERS = documentdb_base_parameters.copy()
# unbeliveable but the forum db is named differently
FORUM_MONGODB_CLIENT_PARAMETERS["username"] = os.environ["DOCUMENTDB_USERNAME"]

# Student notes
FEATURES["ENABLE_EDXNOTES"] = True

# FIXME: deleted MAIN
# DEFAULT_FILE_STORAGE = "storages.backends.s3boto3.S3Boto3Storage"
# FIXME: added MAIN
STORAGES['default']['BACKEND'] = "storages.backends.s3boto3.S3Boto3Storage"
VIDEO_IMAGE_SETTINGS["STORAGE_KWARGS"]["location"] = VIDEO_IMAGE_SETTINGS["STORAGE_KWARGS"]["location"].lstrip("/")
VIDEO_TRANSCRIPTS_SETTINGS["STORAGE_KWARGS"]["location"] = VIDEO_TRANSCRIPTS_SETTINGS["STORAGE_KWARGS"]["location"].lstrip("/")
GRADES_DOWNLOAD["STORAGE_KWARGS"] = {"location": GRADES_DOWNLOAD["STORAGE_KWARGS"]["location"].lstrip("/")}
GRADES_DOWNLOAD["STORAGE_KWARGS"]["bucket_name"] = "openedx"

ORA2_FILEUPLOAD_BACKEND = "s3"
FILE_UPLOAD_STORAGE_BUCKET_NAME = os.environ["S3_FILE_UPLOAD_BUCKET"]

AWS_S3_SIGNATURE_VERSION = os.environ.get("S3_SIGNATURE_VERSION") or "s3v4"
AWS_REQUEST_CHECKSUM_CALCULATION = os.environ.get("S3_REQUEST_CHECKSUM_CALCULATION") or "when_required"

if os.environ.get("S3_HOST"):
    S3_HOST = os.environ["S3_HOST"]
    scheme = "https" if os.environ.get("S3_USE_SSL", "false").lower() == "true" else "http"
    AWS_S3_ENDPOINT_URL = f"{scheme}://{S3_HOST}:{os.environ.get('S3_PORT', '80')}"

AWS_S3_USE_SSL = os.environ.get("S3_USE_SSL", "false").lower() == "true"
AWS_S3_SECURE_URLS = os.environ.get("S3_USE_SSL", "false").lower() == "true"
AWS_DEFAULT_ACL = os.environ.get("S3_DEFAULT_ACL") or None
AWS_S3_ADDRESSING_STYLE = os.environ.get("S3_ADDRESSING_STYLE") or "auto"
AWS_AUTO_CREATE_BUCKET = False

AWS_S3_REGION_NAME = os.environ.get("S3_REGION", "")
AWS_QUERYSTRING_EXPIRE = 7 * 24 * 60 * 60  # 1 week: this is necessary to generate valid download urls

from botocore.client import Config

AWS_S3_CLIENT_CONFIG = Config(
    signature_version=AWS_S3_SIGNATURE_VERSION,
    request_checksum_calculation=AWS_REQUEST_CHECKSUM_CALCULATION,
    s3={"addressing_style": AWS_S3_ADDRESSING_STYLE}
)
######## End of settings common to LMS and CMS

{{- end -}}

{{/*
Shared notes environment variables
*/}}
{{- define "openedx.notes.env" -}}
- name: DJANGO_SETTINGS_MODULE
  value: notesserver.settings.tutor
- name: NOTES_HOST
  value: {{ .Values.openedx.notes.host | quote }}
- name: SECRET_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .Values.openedx.notes.secretKey.secretName }}
      key: {{ .Values.openedx.notes.secretKey.secretKey }}
- name: DB_ENGINE
  value: {{ .Values.openedx.notes.db.engine | quote }}
- name: DB_PORT
  value: {{ .Values.openedx.notes.db.port | quote }}
- name: DB_DATABASE
  value: {{ .Values.openedx.notes.db.name | quote }}
- name: DB_USERNAME
  valueFrom:
    secretKeyRef:
      name: {{ .Values.openedx.notes.db.credentials }}
      key: username
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.openedx.notes.db.credentials }}
      key: password
- name: DB_HOST
  value: {{ .Values.openedx.notes.db.host | quote }}
- name: DB_OPTIONS
  value: {{ toJson .Values.openedx.notes.db.options | quote }}

- name: CLIENT_ID
  value: "{{ .Values.openedx.notes.clientId }}"
- name: CLIENT_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ .Values.openedx.notes.clientSecret.secretName }}
      key: {{ .Values.openedx.notes.clientSecret.secretKey }}
- name: ES_DISABLED
  value: "True"
- name: MEILISEARCH_ENABLED
  value: "{{ if .Values.openedx.notes.meilisearch.enabled }}True{{ else }}False{{ end }}"
- name: MEILISEARCH_URL
  value: "{{ .Values.openedx.notes.meilisearch.url }}"
- name: MEILISEARCH_API_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .Values.openedx.meilisearch.auth.apiKey.secretName }}
      key: {{ .Values.openedx.meilisearch.auth.apiKey.secretKey }}
- name: MEILISEARCH_INDEX
  value: "{{ .Values.openedx.notes.meilisearch.searchIndex }}"
- name: LOGGING
  value: '{"version": 1, "disable_existing_loggers": false, "handlers": {"console": {"level": "INFO", "class": "logging.StreamHandler"}}, "loggers": {"": {"handlers": ["console"], "level": "INFO"}}}'

{{- end -}}

{{/*
Shared dev volume mounts
*/}}
{{- define "openedx.dev.volumeMounts" -}}
{{- if and .Values.openedx.isDev .Values.openedx.local.srcFrom }}
- name: edx-platform
  mountPath: /openedx/edx-platform
- name: mnt
  mountPath: /mnt
{{- end }}
{{- end -}}

{{/*
Shared dev volumes
*/}}
{{- define "openedx.dev.volumes" -}}
{{- if and .Values.openedx.isDev .Values.openedx.local.srcFrom }}
- name: edx-platform
  hostPath:
    path: /openedx/edx-platform
- name: mnt
  hostPath:
    path: /mnt
{{- end }}
{{- end -}}

{{/*
Shared common volume mounts
*/}}
{{- define "openedx.common.volumeMounts" -}}
- name: config
  mountPath: /openedx/config
  readOnly: true
- name: settings-cms
  mountPath: /openedx/edx-platform/cms/envs/tutor/
- name: settings-lms
  mountPath: /openedx/edx-platform/lms/envs/tutor/
{{- end -}}

{{/*
Shared common volumes
*/}}
{{- define "openedx.common.volumes" -}}
- name: config
  secret:
    secretName: openedx-config
- name: settings-cms
  configMap:
    name: openedx-settings-cms
- name: settings-lms
  configMap:
    name: openedx-settings-lms
{{- end -}}

{{- define "openedx.imagePullSecrets" -}}
{{ include "common.images.pullSecrets" (dict "images" (list  .Values.openedx.lms.image .Values.openedx.cms.image .Values.openedx.mfe.image .Values.openedx.notes.image) "global" .Values.global) }}
{{- end -}}
