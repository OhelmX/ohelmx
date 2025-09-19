# ok3dx

A Kubernetes `k3d` and `Helm` development environment and deployment tool for Open Edx.

## STATUS - pre-alpha

[!WARNING] 2025-10-04 - the current setup requires code (postgres support) that has not yet been merged to the official Open edX repos. As such, it requires installing container images from non-official sources (`ghcr.io/ohelmx/openedx` and `ghcr.io/ohelmx/openedx-notes`). Support is based off `master`, NOT an official release. Unless you like living on the edge, you are probably better waiting for that code to be merged and for a proper upstream release.

## Founding concepts

This project is far more opinionated than the Open edX upstream sanctioned/supported project - `tutor`. It starts from the following premises:

- `kubernetes` is suitable for production, `docker compose` wasn't designed for it and has many drawbacks
- `k3d` allows you to do everything `docker compose` does for dev, just as easily, and furthermore allows almost instantly spinning up "production-equivalent" kubernetes clusters so your dev environment can match your production environment quite closely
- Dev should mirror prod, so dev should also be TLS if prod is. Everything should be secure (TLS, etc.) that leaves your machine/cluster.
- All secrets should be stored in secure locations designed to hold secrets
- Prefer official, industrial strength mechanisms and scaffold them for beginners if required. Scaffolding should be as simple as possible and require no more than a few minutes for a reasonably skilled devops engineer to understand
- Production artifacts should be built using automation in isolated environments (so not the dev machine or production host machine), using remote source and artifact repositories to ensure build reproducibility and auditability.

And finally... `postgres` all the things!

## Features

### Dev features
- hot reloading for both python and frontend project/sub-projects
- Automated TLS locally (and on the server)
- Interaction with the sites using only port 443, whether pointing to a host-local, hot-reloaded dev version or not
- and the Deploy features

### Deploy features
- Automated S3-compatible (point-in-time) db, (point-in-time) documentdb and storage backups included
- Bootstrap/disaster recovery from S3-compatible storage

## Dev/operator workstation prerequisites

This setup has been tested on Ubuntu 24.04 and should work seamlessly on similar setups. It should also work well on recent (2025+) WSL2-Ubuntu 24.04 setups (with a couple of extra 1-2 minute setup steps). It probably works on recent MacOS, though hasn't been tested.

- `docker` - [Official instructions](https://docs.docker.com/engine/install/ubuntu/)
- `mkcert`, `git` - `sudo apt install mkcert git`
- `k3d` - [Official instructions](https://k3d.io/v5.8.3/#releases)
- `kubectl` - `sudo snap install kubectl --classic`
- `helm` - `sudo snap install helm --classic`
- `helm-diff` - `helm plugin install https://github.com/databus23/helm-diff`
- `helmfile` - [Download](https://github.com/helmfile/helmfile/releases/) the latest release, `tar xf` it and put it in your path

A full local setup including all servers (DBs, Meilisearch, etc.) will require 6GB+ of RAM and a reasonably recent/powerful processor (laptop 2020+, desktop 2018+).

## Installation

### Components

While you can (obviously!) choose to use external services, the default install will install [Kubernetes Operators](https://kubernetes.io/docs/concepts/extend-kubernetes/operator/) for:

- Minio (Minio)
- Postgres (CNPG)
- Redis (Opstree)

And (normal) Helm-based installs for the following:

- Cert-manager
- Meilisearch
- FerretDB (MongoDB-compatible, DocumentDB/CNPG underneath)
- Argo Workflows

The system also relies on the following services, currently installed with `k3d`/`k3s`

- Traefik
- Coredns

(+ related, i.e., local-path-provisioner, servicelb)

#### Key server differences with tutor

- `mysql` is replaced by `postgres`
- `mongodb` is replaced by `ferretdb` (`postgres`)
- `caddy` is retained (currently) for the MFEs but replaced by `traefik` for cluster ingress and `cert-manager`/`mkcert` for certificates
- tutor-driven docker/kubernetes jobs are replaced by `argo workflow` for initialisation

## Dev deployment

Init your workstation setup:

```
cp --update vars.sh.default vars.sh
touch kube/k3d-deploy/{overrides-local.yaml,overrides-infra-local.yaml}
```

These files are NOT managed by git and are included in the various scripts to store environment variables and then values overrides for the two main helm charts.

If your personalisation needs are more substantial, you could copy this repo's `ok3dx` (root level dir) and adapt outside of this repo. Don't hesitate to submit PRs if you think others might benefit!

### Cluster init

```
bash kube/k3d-deploy/k3d-create-cluster.sh && bash kube/k3d-deploy/kubectl-create-secret.sh
```

### Cluster operator and infra provisioning

```
bash kube/k3d-deploy/pre-install.sh
```

### Reinstall `openedx-infra`

[!NOTE] The `pre-install.sh` script above installs the openedx-infra chart, so the following is only necessary if you want to redeploy just `openedx-infra` for some reason.

```
bash kube/k3d-deploy/openedx-infra-install.sh
```

### Install openedx

```
bash kube/k3d-deploy/openedx-install.sh
```

### Init openedx dbs/resources

[!NOTE] The following can take 20+ minutes, but is only required once.

```
bash kube/k3d-deploy/openedx-init.sh
```

Show init progress - requires `argo`, see below:

```
argo logs -f @latest
```

### Admin

Create a superuser:

```
bash kube/k3d-deploy/openedx-create-user.sh USERNAME USER_EMAIL
```

## Dev development

Unless you change the default settings, if you set `openedx.isDev: true`:


```
# e.g, in overrides-local.yaml
openedx:
  isDev: true
```

Then the system has been set up to load project python files from `workspaces/apps/edx-platform`. If you want to work with a local copy then simply clone the [upstream repo](https://github.com/openedx/edx-platform) to the `apps` directory. The `apps` and `mnt` directories are .gitignored, so can be managed independently from there, and are mounted into the k3d "host" as follows.

```bash
# from `kube/k3d-deploy/k3d-create-cluster.sh`
k3d cluster create ${APPNAME} --config ${SCRIPT_DIR}/k3d-config.yml \
...
  --volume ${SCRIPT_DIR}/volumes:/opt/${APPNAME}/volumes@all \
  --volume ${SCRIPT_DIR}/../../workspaces:/workspaces@all \
  --volume ${SCRIPT_DIR}/../../workspaces/apps/edx-platform:/openedx/edx-platform@all \
  --volume ${SCRIPT_DIR}/../../workspaces/mnt:/mnt@all
```

The system was originally "inspired" by `tutor`, and `tutor` also has mounts going to a `/mnt` directory, so should be familiar to existing tutor users. The `workspaces/build` directory contains build helpers for building both `edx-platform` and `edx-notes-api` - the two main repos that needed modifying to support `postgres`. There are two build scripts to help build those. The former requires a local clone of the repo and the latter a remote git URL with a branch/tag/sha (ref). The init scripts in this repo mimick `tutor`'s init process, and if you are building locally (with `isDev: true`) then the same local install process gets run in this repo's `argo` workflow, (hopefully) resulting in near-identical results.

If you have other special needs then you should probably just copy this repo's `ok3dx` directory somewhere and make changes as you see fit. It is all standard `k3d` and/or `helm` (with a couple of useful helper scripts) - nothing more, so Google, Stackoverflow, Reddit and your usual help haunts are your friends!

## Staging/Prod deployment

A key difference in philosophy with Tutor is that DevOps engineers should be in total control of their infrastructure. This project tries to make that not only possible but required... As such, there are no "prod-deploy" scripts. There are all the tools you'll need to build your own prod deploy scripts in about 10 minutes if you know what you are doing - basically if you have some experience with Helm and know what you are deploying into.

If you are not comfortable with Helm (or at least want to be), you should probably stick with Tutor.

[!WARNING] The default dev secrets (in `kube/k3d-deploy/secrets/ok3dx*`) *ARE NOT SUITABLE FOR PRODUCTION*. They are all basically some variant of "password". This is great for dev but not great for prod. The YAML secret files contain annotations which allow them to be reliably regenerated using basically identical code to Tutor via the python script `kube/k8s-deploy/regen-secrets.py`. Basically you just run that script (which needs either python's `pycryptodome` to be available to python, or linux's command line `openssl` to be available to the CL) with the `kube/k3d-deploy/secrets` directory as the first parameter and an output directory as the second and then you will have 3 directories you *CAN* `kubectl apply -f ...` to production, then properly manage with your secrets-management system.

### Recommended extras

#### argo cli

```
ARGO_OS="linux"
curl -sLO "https://github.com/argoproj/argo-workflows/releases/download/v3.7.2/argo-$ARGO_OS-amd64.gz"
gunzip "argo-$ARGO_OS-amd64.gz"
chmod +x "argo-$ARGO_OS-amd64"
mv "./argo-$ARGO_OS-amd64" ~/bin/argo
```

#### kubectl cnpg plugin

```
wget https://github.com/cloudnative-pg/cloudnative-pg/releases/download/v1.27.0/kubectl-cnpg_1.27.0_linux_x86_64.deb
sudo apt install ./kubectl-cnpg_1.27.0_linux_x86_64.deb
rm kubectl-cnpg_1.27.0_linux_x86_64.deb
```

# TODOs
- finish trying to get local volumes working for operators/meili
- Email!
- integrate a proper secrets manager (SOPS?) for gitops
- integrate CI/CD
  - Argo?
  - add a registry (harbor? zot? maybe move to full oci when ImageVolumes goes GA?)

# Relationship to Edly Tutor

The Open edX community has decided to focus on Tutor and in many key repos (such as `openedx/edx-platform`) is no longer maintaining documentation to ensure competent developers can use the code/projects independently, instead choosing to delegate that to Tutor Just Working. If it works as a whole, you don't need documentation for the individual bits I guess is the rationale. As such, in 2025, there is no practical way to create a working Open edX platform in a tractable amount of time without reverse engineering how Tutor sets up and builds things, at least to a certain extent. So that was done. In the process a reasonable amount of code was copied, including the `indigo` theme and most of a `tutor`-produced local `build` directory. Some utility code was copied, particularly for generating passwords (see `ok3dx/kube/k8s-deploy/regen_secrets.py`).

That said, Tutor does a lot of templating so plugins can inject code not only runtime config, but also build code/config fragments. That makes it very flexible and powerful. Also very complicated to reason about and ensure the stability and security of - unless maybe you have a technical PhD. At the very least it means you need to spend significant amounts of time and resources to become familiar with it, rather than a more widely used tool, like `helm`. While Tutor relies on a standard templating language and `kustomize` for deploying to Kubernetes, it is very much "black-box" in its approach. This project takes a different approach - use parameters and (environment) variables over templating, and additional building rather than trying to monolith it. Tutor has had many years to perfect its approach, so clearly has far more rounded edges and features. Stay tuned to this repo for more, and don't hesitate to submit PRs if you create some useful addtions!
