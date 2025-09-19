# OhelmX

Charts for installing Open edX and dependencies

[!WARNING] Pre-alpha software! Use at your own risk!

## Introduction

Open edX relies on a number of services, such as Redis, Meilisearch, a relational DB, a document DB, etc. The `openedx-infra` chart installs these. The `openedx` chart installs a heavily `Tutor`-inspired version of `openedx`, including the `indigo` theme.

Both charts can be installed completely independently *however*, the `openedx-infra` chart relies on the availability of serveral Kubernetes Operators, notably:

- oci://ghcr.io/cloudnative-pg/charts/cloudnative-pg
- https://operator.min.io/tenant
- https://ot-container-kit.github.io/helm-charts/redis-operator

And other services:

- oci://quay.io/jetstack/charts/cert-manager
- oci://ghcr.io/argoproj/argo-helm/argo-workflows

During the pre-alpha phase, you will need to look closely at the companion repo [`Ok3dX`](https://github.com/AntonOfTheWoods/ok3dx) for configuration examples and further documentation. `Ok3dX` is meant to provide a set of scripts and example configurations so you can get operational locally developing and deploying Open edX - all using these charts.

You should look particularly at [this helmfile.yaml](https://github.com/AntonOfTheWoods/ok3dx/blob/main/kube/k3d-deploy/helmfile.yaml), which contains all the pre-requisites required for getting both these charts running.

[!NOTE] PRs and wishlists are welcome!

# FAQ

### Why don't you support MySQL?

I don't use it but am willing to accept PRs if someone will maintain support.

### Why did you replace MongoDB with FerretDB?

FOSS, and Postgres All The Things!

### Can I migrate from an existing Tutor installation?

Not at this time, and considering the differences, it will be extremely unlikely to be possible to do so smoothly, even with a lot of work.
