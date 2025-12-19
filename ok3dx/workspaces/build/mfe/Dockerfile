# syntax=docker/dockerfile:1
# https://hub.docker.com/_/node/tags
FROM docker.io/node:24.12.0-bullseye-slim AS base

RUN apt update && apt install -y git \
  # required for cwebp-bin
  gcc libgl1 libxi6 make \
  # required for gifsicle, mozjpeg, and optipng (on arm)
  autoconf libtool pkg-config zlib1g-dev \
  # required for node-sass (on arm)
  python3 g++ \
  # required for image-webpack-loader (on arm)
  libpng-dev \
  # required for building node-canvas (on arm, for authoring)
  # https://www.npmjs.com/package/canvas
  libcairo2-dev libpango1.0-dev libjpeg-dev libgif-dev librsvg2-dev

RUN mkdir -p /openedx/app /openedx/env


# Install shared dependencies in /openedx/node_modules
WORKDIR /openedx/
RUN npm install @rsbuild/core @rsbuild/plugin-react @rsbuild/plugin-svgr @rsbuild/plugin-sass

# Install apps in /openedx/app
WORKDIR /openedx/app
ENV PATH=/openedx/app/node_modules/.bin:/openedx/node_modules/.bin:${PATH}

ARG MFE_BRANCH=master

####################### admin-console MFE
######## admin-console (git)
FROM base AS admin-console-git
ARG MFE_BRANCH
ADD --keep-git-dir=true https://github.com/openedx/frontend-app-admin-console.git#${MFE_BRANCH} .

######## admin-console (src)
# Empty layer with just the repo at the root, for build-time bind-mounts
FROM scratch AS admin-console-src
COPY --from=admin-console-git /openedx/app /

######## admin-console (common)
FROM base AS admin-console-common
COPY --from=admin-console-src /package.json /openedx/app/package.json
COPY --from=admin-console-src /package-lock.json /openedx/app/package-lock.json
ARG NPM_REGISTRY=https://registry.npmjs.org/


ENV CPPFLAGS=-DPNG_ARM_NEON_OPT=0
ENV PACT_SKIP_BINARY_INSTALL=true
RUN --mount=type=cache,target=/root/.npm,sharing=shared npm clean-install --no-audit --no-fund --registry=$NPM_REGISTRY


COPY --from=admin-console-src / /openedx/app

RUN make OPENEDX_ATLAS_PULL=true ATLAS_OPTIONS="--repository=openedx/openedx-translations --revision=main " pull_translations

EXPOSE 2025

# Configuration needed at build time
ENV APP_ID=admin-console
ENV PUBLIC_PATH='/admin-console/'
# We could in theory point the mfe_config API directly to the LMS. But for that we would
# have to code the LMS url into the mfe image, and this configuration is user-dependent.
# So we point to a relative url that will be a proxy for the LMS.
ENV MFE_CONFIG_API_URL=/api/mfe_config/v1
ARG ENABLE_NEW_RELIC=false
COPY env.config.jsx /openedx/app



######## admin-console (dev)
FROM admin-console-common AS admin-console-dev
ENV NODE_ENV=development
CMD ["/bin/bash", "-c", "npm run start --- --config ./webpack.dev-tutor.config.js"]

####################### authn MFE
######## authn (git)
FROM base AS authn-git
ARG MFE_BRANCH
ADD --keep-git-dir=true https://github.com/openedx/frontend-app-authn.git#${MFE_BRANCH} .

######## authn (src)
# Empty layer with just the repo at the root, for build-time bind-mounts
FROM scratch AS authn-src
COPY --from=authn-git /openedx/app /

######## authn (common)
FROM base AS authn-common
COPY --from=authn-src /package.json /openedx/app/package.json
COPY --from=authn-src /package-lock.json /openedx/app/package-lock.json
ARG NPM_REGISTRY=https://registry.npmjs.org/


ENV CPPFLAGS=-DPNG_ARM_NEON_OPT=0
ENV PACT_SKIP_BINARY_INSTALL=true
RUN --mount=type=cache,target=/root/.npm,sharing=shared npm clean-install --no-audit --no-fund --registry=$NPM_REGISTRY


COPY --from=authn-src / /openedx/app

RUN make OPENEDX_ATLAS_PULL=true ATLAS_OPTIONS="--repository=openedx/openedx-translations --revision=main " pull_translations

EXPOSE 1999

# Configuration needed at build time
ENV APP_ID=authn
ENV PUBLIC_PATH='/authn/'
# We could in theory point the mfe_config API directly to the LMS. But for that we would
# have to code the LMS url into the mfe image, and this configuration is user-dependent.
# So we point to a relative url that will be a proxy for the LMS.
ENV MFE_CONFIG_API_URL=/api/mfe_config/v1
ARG ENABLE_NEW_RELIC=false
COPY env.config.jsx /openedx/app



######## authn (dev)
FROM authn-common AS authn-dev
ENV NODE_ENV=development
CMD ["/bin/bash", "-c", "npm run start --- --config ./webpack.dev-tutor.config.js"]

####################### authoring MFE
######## authoring (git)
FROM base AS authoring-git
ARG MFE_BRANCH
ADD --keep-git-dir=true https://github.com/openedx/frontend-app-authoring.git#${MFE_BRANCH} .

######## authoring (src)
# Empty layer with just the repo at the root, for build-time bind-mounts
FROM scratch AS authoring-src
COPY --from=authoring-git /openedx/app /

######## authoring (common)
FROM base AS authoring-common
COPY --from=authoring-src /package.json /openedx/app/package.json
COPY --from=authoring-src /package-lock.json /openedx/app/package-lock.json
ARG NPM_REGISTRY=https://registry.npmjs.org/


ENV CPPFLAGS=-DPNG_ARM_NEON_OPT=0
ENV PACT_SKIP_BINARY_INSTALL=true
RUN --mount=type=cache,target=/root/.npm,sharing=shared npm clean-install --no-audit --no-fund --registry=$NPM_REGISTRY


COPY --from=authoring-src / /openedx/app

RUN make OPENEDX_ATLAS_PULL=true ATLAS_OPTIONS="--repository=openedx/openedx-translations --revision=main " pull_translations

EXPOSE 2001

# Configuration needed at build time
ENV APP_ID=authoring
ENV PUBLIC_PATH='/authoring/'
# We could in theory point the mfe_config API directly to the LMS. But for that we would
# have to code the LMS url into the mfe image, and this configuration is user-dependent.
# So we point to a relative url that will be a proxy for the LMS.
ENV MFE_CONFIG_API_URL=/api/mfe_config/v1
ARG ENABLE_NEW_RELIC=false
COPY env.config.jsx /openedx/app



######## authoring (dev)
FROM authoring-common AS authoring-dev
ENV NODE_ENV=development
CMD ["/bin/bash", "-c", "npm run start --- --config ./webpack.dev-tutor.config.js"]

####################### account MFE
######## account (git)
FROM base AS account-git
ARG MFE_BRANCH
ADD --keep-git-dir=true https://github.com/openedx/frontend-app-account.git#${MFE_BRANCH} .

######## account (src)
# Empty layer with just the repo at the root, for build-time bind-mounts
FROM scratch AS account-src
COPY --from=account-git /openedx/app /

######## account (common)
FROM base AS account-common
COPY --from=account-src /package.json /openedx/app/package.json
COPY --from=account-src /package-lock.json /openedx/app/package-lock.json
ARG NPM_REGISTRY=https://registry.npmjs.org/


ENV CPPFLAGS=-DPNG_ARM_NEON_OPT=0
ENV PACT_SKIP_BINARY_INSTALL=true
RUN --mount=type=cache,target=/root/.npm,sharing=shared npm clean-install --no-audit --no-fund --registry=$NPM_REGISTRY


COPY --from=account-src / /openedx/app

RUN make OPENEDX_ATLAS_PULL=true ATLAS_OPTIONS="--repository=openedx/openedx-translations --revision=main " pull_translations

EXPOSE 1997

# Configuration needed at build time
ENV APP_ID=account
ENV PUBLIC_PATH='/account/'
# We could in theory point the mfe_config API directly to the LMS. But for that we would
# have to code the LMS url into the mfe image, and this configuration is user-dependent.
# So we point to a relative url that will be a proxy for the LMS.
ENV MFE_CONFIG_API_URL=/api/mfe_config/v1
ARG ENABLE_NEW_RELIC=false
COPY env.config.jsx /openedx/app



######## account (dev)
FROM account-common AS account-dev
ENV NODE_ENV=development
CMD ["/bin/bash", "-c", "npm run start --- --config ./webpack.dev-tutor.config.js"]


####################### catalog MFE
######## catalog (git)
FROM base AS catalog-git
ARG MFE_BRANCH
# ADD --keep-git-dir=true https://github.com/openedx/frontend-app-catalog.git#${MFE_BRANCH} .
# FIXME: Temporary workaround for repo not having a release/XXX branch yet
ADD --keep-git-dir=true https://github.com/openedx/frontend-app-catalog.git#master .

######## catalog (src)
# Empty layer with just the repo at the root, for build-time bind-mounts
FROM scratch AS catalog-src
COPY --from=catalog-git /openedx/app /

######## catalog (common)
FROM base AS catalog-common
COPY --from=catalog-src /package.json /openedx/app/package.json
COPY --from=catalog-src /package-lock.json /openedx/app/package-lock.json
ARG NPM_REGISTRY=https://registry.npmjs.org/


ENV CPPFLAGS=-DPNG_ARM_NEON_OPT=0
ENV PACT_SKIP_BINARY_INSTALL=true
RUN --mount=type=cache,target=/root/.npm,sharing=shared npm clean-install --no-audit --no-fund --registry=$NPM_REGISTRY


COPY --from=catalog-src / /openedx/app

RUN make OPENEDX_ATLAS_PULL=true ATLAS_OPTIONS="--repository=openedx/openedx-translations --revision=main " pull_translations

EXPOSE 1998

# Configuration needed at build time
ENV APP_ID=catalog
ENV PUBLIC_PATH='/catalog/'
# We could in theory point the mfe_config API directly to the LMS. But for that we would
# have to code the LMS url into the mfe image, and this configuration is user-dependent.
# So we point to a relative url that will be a proxy for the LMS.
ENV MFE_CONFIG_API_URL=/api/mfe_config/v1
ARG ENABLE_NEW_RELIC=false
COPY env.config.jsx /openedx/app



######## catalog (dev)
FROM catalog-common AS catalog-dev
ENV NODE_ENV=development
CMD ["/bin/bash", "-c", "npm run start --- --config ./webpack.dev-tutor.config.js"]


####################### communications MFE
######## communications (git)
FROM base AS communications-git
ARG MFE_BRANCH
ADD --keep-git-dir=true https://github.com/openedx/frontend-app-communications.git#${MFE_BRANCH} .

######## communications (src)
# Empty layer with just the repo at the root, for build-time bind-mounts
FROM scratch AS communications-src
COPY --from=communications-git /openedx/app /

######## communications (common)
FROM base AS communications-common
COPY --from=communications-src /package.json /openedx/app/package.json
COPY --from=communications-src /package-lock.json /openedx/app/package-lock.json
ARG NPM_REGISTRY=https://registry.npmjs.org/


ENV CPPFLAGS=-DPNG_ARM_NEON_OPT=0
ENV PACT_SKIP_BINARY_INSTALL=true
RUN --mount=type=cache,target=/root/.npm,sharing=shared npm clean-install --no-audit --no-fund --registry=$NPM_REGISTRY


COPY --from=communications-src / /openedx/app

RUN make OPENEDX_ATLAS_PULL=true ATLAS_OPTIONS="--repository=openedx/openedx-translations --revision=main " pull_translations

EXPOSE 1984

# Configuration needed at build time
ENV APP_ID=communications
ENV PUBLIC_PATH='/communications/'
# We could in theory point the mfe_config API directly to the LMS. But for that we would
# have to code the LMS url into the mfe image, and this configuration is user-dependent.
# So we point to a relative url that will be a proxy for the LMS.
ENV MFE_CONFIG_API_URL=/api/mfe_config/v1
ARG ENABLE_NEW_RELIC=false
COPY env.config.jsx /openedx/app



######## communications (dev)
FROM communications-common AS communications-dev
ENV NODE_ENV=development
CMD ["/bin/bash", "-c", "npm run start --- --config ./webpack.dev-tutor.config.js"]

####################### discussions MFE
######## discussions (git)
FROM base AS discussions-git
ARG MFE_BRANCH
ADD --keep-git-dir=true https://github.com/openedx/frontend-app-discussions.git#${MFE_BRANCH} .

######## discussions (src)
# Empty layer with just the repo at the root, for build-time bind-mounts
FROM scratch AS discussions-src
COPY --from=discussions-git /openedx/app /

######## discussions (common)
FROM base AS discussions-common
COPY --from=discussions-src /package.json /openedx/app/package.json
COPY --from=discussions-src /package-lock.json /openedx/app/package-lock.json
ARG NPM_REGISTRY=https://registry.npmjs.org/


ENV CPPFLAGS=-DPNG_ARM_NEON_OPT=0
ENV PACT_SKIP_BINARY_INSTALL=true
RUN --mount=type=cache,target=/root/.npm,sharing=shared npm clean-install --no-audit --no-fund --registry=$NPM_REGISTRY


COPY --from=discussions-src / /openedx/app

RUN make OPENEDX_ATLAS_PULL=true ATLAS_OPTIONS="--repository=openedx/openedx-translations --revision=main " pull_translations

EXPOSE 2002

# Configuration needed at build time
ENV APP_ID=discussions
ENV PUBLIC_PATH='/discussions/'
# We could in theory point the mfe_config API directly to the LMS. But for that we would
# have to code the LMS url into the mfe image, and this configuration is user-dependent.
# So we point to a relative url that will be a proxy for the LMS.
ENV MFE_CONFIG_API_URL=/api/mfe_config/v1
ARG ENABLE_NEW_RELIC=false
COPY env.config.jsx /openedx/app



######## discussions (dev)
FROM discussions-common AS discussions-dev
ENV NODE_ENV=development
CMD ["/bin/bash", "-c", "npm run start --- --config ./webpack.dev-tutor.config.js"]

####################### gradebook MFE
######## gradebook (git)
FROM base AS gradebook-git
ARG MFE_BRANCH
ADD --keep-git-dir=true https://github.com/openedx/frontend-app-gradebook.git#${MFE_BRANCH} .

######## gradebook (src)
# Empty layer with just the repo at the root, for build-time bind-mounts
FROM scratch AS gradebook-src
COPY --from=gradebook-git /openedx/app /

######## gradebook (common)
FROM base AS gradebook-common
COPY --from=gradebook-src /package.json /openedx/app/package.json
COPY --from=gradebook-src /package-lock.json /openedx/app/package-lock.json
ARG NPM_REGISTRY=https://registry.npmjs.org/


ENV CPPFLAGS=-DPNG_ARM_NEON_OPT=0
ENV PACT_SKIP_BINARY_INSTALL=true
RUN --mount=type=cache,target=/root/.npm,sharing=shared npm clean-install --no-audit --no-fund --registry=$NPM_REGISTRY


COPY --from=gradebook-src / /openedx/app

RUN make OPENEDX_ATLAS_PULL=true ATLAS_OPTIONS="--repository=openedx/openedx-translations --revision=main " pull_translations

EXPOSE 1994

# Configuration needed at build time
ENV APP_ID=gradebook
ENV PUBLIC_PATH='/gradebook/'
# We could in theory point the mfe_config API directly to the LMS. But for that we would
# have to code the LMS url into the mfe image, and this configuration is user-dependent.
# So we point to a relative url that will be a proxy for the LMS.
ENV MFE_CONFIG_API_URL=/api/mfe_config/v1
ARG ENABLE_NEW_RELIC=false
COPY env.config.jsx /openedx/app



######## gradebook (dev)
FROM gradebook-common AS gradebook-dev
ENV NODE_ENV=development
CMD ["/bin/bash", "-c", "npm run start --- --config ./webpack.dev-tutor.config.js"]

####################### learner-dashboard MFE
######## learner-dashboard (git)
FROM base AS learner-dashboard-git
ARG MFE_BRANCH
ADD --keep-git-dir=true https://github.com/openedx/frontend-app-learner-dashboard.git#${MFE_BRANCH} .

######## learner-dashboard (src)
# Empty layer with just the repo at the root, for build-time bind-mounts
FROM scratch AS learner-dashboard-src
COPY --from=learner-dashboard-git /openedx/app /

######## learner-dashboard (common)
FROM base AS learner-dashboard-common
COPY --from=learner-dashboard-src /package.json /openedx/app/package.json
COPY --from=learner-dashboard-src /package-lock.json /openedx/app/package-lock.json
ARG NPM_REGISTRY=https://registry.npmjs.org/


ENV CPPFLAGS=-DPNG_ARM_NEON_OPT=0
ENV PACT_SKIP_BINARY_INSTALL=true
RUN --mount=type=cache,target=/root/.npm,sharing=shared npm clean-install --no-audit --no-fund --registry=$NPM_REGISTRY


COPY --from=learner-dashboard-src / /openedx/app

RUN make OPENEDX_ATLAS_PULL=true ATLAS_OPTIONS="--repository=openedx/openedx-translations --revision=main " pull_translations

EXPOSE 1996

# Configuration needed at build time
ENV APP_ID=learner-dashboard
ENV PUBLIC_PATH='/learner-dashboard/'
# We could in theory point the mfe_config API directly to the LMS. But for that we would
# have to code the LMS url into the mfe image, and this configuration is user-dependent.
# So we point to a relative url that will be a proxy for the LMS.
ENV MFE_CONFIG_API_URL=/api/mfe_config/v1
ARG ENABLE_NEW_RELIC=false
COPY env.config.jsx /openedx/app



######## learner-dashboard (dev)
FROM learner-dashboard-common AS learner-dashboard-dev
ENV NODE_ENV=development
CMD ["/bin/bash", "-c", "npm run start --- --config ./webpack.dev-tutor.config.js"]

####################### learning MFE
######## learning (git)
FROM base AS learning-git
ARG MFE_BRANCH
ADD --keep-git-dir=true https://github.com/openedx/frontend-app-learning.git#${MFE_BRANCH} .

######## learning (src)
# Empty layer with just the repo at the root, for build-time bind-mounts
FROM scratch AS learning-src
COPY --from=learning-git /openedx/app /

######## learning (common)
FROM base AS learning-common
COPY --from=learning-src /package.json /openedx/app/package.json
COPY --from=learning-src /package-lock.json /openedx/app/package-lock.json
ARG NPM_REGISTRY=https://registry.npmjs.org/


ENV CPPFLAGS=-DPNG_ARM_NEON_OPT=0
ENV PACT_SKIP_BINARY_INSTALL=true
RUN --mount=type=cache,target=/root/.npm,sharing=shared npm clean-install --no-audit --no-fund --registry=$NPM_REGISTRY


COPY --from=learning-src / /openedx/app

RUN make OPENEDX_ATLAS_PULL=true ATLAS_OPTIONS="--repository=openedx/openedx-translations --revision=main " pull_translations

EXPOSE 2000

# Configuration needed at build time
ENV APP_ID=learning
ENV PUBLIC_PATH='/learning/'
# We could in theory point the mfe_config API directly to the LMS. But for that we would
# have to code the LMS url into the mfe image, and this configuration is user-dependent.
# So we point to a relative url that will be a proxy for the LMS.
ENV MFE_CONFIG_API_URL=/api/mfe_config/v1
ARG ENABLE_NEW_RELIC=false
COPY env.config.jsx /openedx/app



######## learning (dev)
FROM learning-common AS learning-dev
ENV NODE_ENV=development
CMD ["/bin/bash", "-c", "npm run start --- --config ./webpack.dev-tutor.config.js"]

####################### ora-grading MFE
######## ora-grading (git)
FROM base AS ora-grading-git
ARG MFE_BRANCH
ADD --keep-git-dir=true https://github.com/openedx/frontend-app-ora-grading.git#${MFE_BRANCH} .

######## ora-grading (src)
# Empty layer with just the repo at the root, for build-time bind-mounts
FROM scratch AS ora-grading-src
COPY --from=ora-grading-git /openedx/app /

######## ora-grading (common)
FROM base AS ora-grading-common
COPY --from=ora-grading-src /package.json /openedx/app/package.json
COPY --from=ora-grading-src /package-lock.json /openedx/app/package-lock.json
ARG NPM_REGISTRY=https://registry.npmjs.org/


ENV CPPFLAGS=-DPNG_ARM_NEON_OPT=0
ENV PACT_SKIP_BINARY_INSTALL=true
RUN --mount=type=cache,target=/root/.npm,sharing=shared npm clean-install --no-audit --no-fund --registry=$NPM_REGISTRY


COPY --from=ora-grading-src / /openedx/app

RUN make OPENEDX_ATLAS_PULL=true ATLAS_OPTIONS="--repository=openedx/openedx-translations --revision=main " pull_translations

EXPOSE 1993

# Configuration needed at build time
ENV APP_ID=ora-grading
ENV PUBLIC_PATH='/ora-grading/'
# We could in theory point the mfe_config API directly to the LMS. But for that we would
# have to code the LMS url into the mfe image, and this configuration is user-dependent.
# So we point to a relative url that will be a proxy for the LMS.
ENV MFE_CONFIG_API_URL=/api/mfe_config/v1
ARG ENABLE_NEW_RELIC=false
COPY env.config.jsx /openedx/app



######## ora-grading (dev)
FROM ora-grading-common AS ora-grading-dev
ENV NODE_ENV=development
CMD ["/bin/bash", "-c", "npm run start --- --config ./webpack.dev-tutor.config.js"]

####################### profile MFE
######## profile (git)
FROM base AS profile-git
ARG MFE_BRANCH
ADD --keep-git-dir=true https://github.com/openedx/frontend-app-profile.git#${MFE_BRANCH} .

######## profile (src)
# Empty layer with just the repo at the root, for build-time bind-mounts
FROM scratch AS profile-src
COPY --from=profile-git /openedx/app /

######## profile (common)
FROM base AS profile-common
COPY --from=profile-src /package.json /openedx/app/package.json
COPY --from=profile-src /package-lock.json /openedx/app/package-lock.json
ARG NPM_REGISTRY=https://registry.npmjs.org/


ENV CPPFLAGS=-DPNG_ARM_NEON_OPT=0
ENV PACT_SKIP_BINARY_INSTALL=true
RUN --mount=type=cache,target=/root/.npm,sharing=shared npm clean-install --no-audit --no-fund --registry=$NPM_REGISTRY


COPY --from=profile-src / /openedx/app

RUN make OPENEDX_ATLAS_PULL=true ATLAS_OPTIONS="--repository=openedx/openedx-translations --revision=main " pull_translations

EXPOSE 1995

# Configuration needed at build time
ENV APP_ID=profile
ENV PUBLIC_PATH='/profile/'
# We could in theory point the mfe_config API directly to the LMS. But for that we would
# have to code the LMS url into the mfe image, and this configuration is user-dependent.
# So we point to a relative url that will be a proxy for the LMS.
ENV MFE_CONFIG_API_URL=/api/mfe_config/v1
ARG ENABLE_NEW_RELIC=false
COPY env.config.jsx /openedx/app



######## profile (dev)
FROM profile-common AS profile-dev
ENV NODE_ENV=development
CMD ["/bin/bash", "-c", "npm run start --- --config ./webpack.dev-tutor.config.js"]


# Production images are last to accelerate dev image building
######## admin-console (production)
FROM admin-console-common AS admin-console-prod
ENV NODE_ENV=production
COPY rsbuild.config.ts /openedx/app/rsbuild.config.ts
RUN --mount=type=cache,target=/openedx/app/node_modules/.cache,sharing=locked rsbuild build


######## authn (production)
FROM authn-common AS authn-prod
ENV NODE_ENV=production
COPY rsbuild.config.ts /openedx/app/rsbuild.config.ts
RUN --mount=type=cache,target=/openedx/app/node_modules/.cache,sharing=locked rsbuild build



######## authoring (production)
FROM authoring-common AS authoring-prod
ENV NODE_ENV=production
COPY rsbuild.config.ts /openedx/app/rsbuild.config.ts
RUN --mount=type=cache,target=/openedx/app/node_modules/.cache,sharing=locked rsbuild build



######## account (production)
FROM account-common AS account-prod
ENV NODE_ENV=production
COPY rsbuild.config.ts /openedx/app/rsbuild.config.ts
RUN --mount=type=cache,target=/openedx/app/node_modules/.cache,sharing=locked rsbuild build



# Production images are last to accelerate dev image building
######## catalog (production)
FROM catalog-common AS catalog-prod
ENV NODE_ENV=production
COPY rsbuild.config.ts /openedx/app/rsbuild.config.ts
RUN --mount=type=cache,target=/openedx/app/node_modules/.cache,sharing=locked rsbuild build



######## communications (production)
FROM communications-common AS communications-prod
ENV NODE_ENV=production
COPY rsbuild.config.ts /openedx/app/rsbuild.config.ts
RUN --mount=type=cache,target=/openedx/app/node_modules/.cache,sharing=locked rsbuild build



######## discussions (production)
FROM discussions-common AS discussions-prod
ENV NODE_ENV=production
COPY rsbuild.config.ts /openedx/app/rsbuild.config.ts
RUN --mount=type=cache,target=/openedx/app/node_modules/.cache,sharing=locked rsbuild build



######## gradebook (production)
FROM gradebook-common AS gradebook-prod
ENV NODE_ENV=production
COPY rsbuild.config.ts /openedx/app/rsbuild.config.ts
RUN --mount=type=cache,target=/openedx/app/node_modules/.cache,sharing=locked rsbuild build



######## learner-dashboard (production)
FROM learner-dashboard-common AS learner-dashboard-prod
ENV NODE_ENV=production
COPY rsbuild.config.ts /openedx/app/rsbuild.config.ts
RUN --mount=type=cache,target=/openedx/app/node_modules/.cache,sharing=locked rsbuild build



######## learning (production)
FROM learning-common AS learning-prod
ENV NODE_ENV=production
COPY rsbuild.config.ts /openedx/app/rsbuild.config.ts
RUN --mount=type=cache,target=/openedx/app/node_modules/.cache,sharing=locked rsbuild build



######## ora-grading (production)
FROM ora-grading-common AS ora-grading-prod
ENV NODE_ENV=production
COPY rsbuild.config.ts /openedx/app/rsbuild.config.ts
RUN --mount=type=cache,target=/openedx/app/node_modules/.cache,sharing=locked rsbuild build



######## profile (production)
FROM profile-common AS profile-prod
ENV NODE_ENV=production
COPY rsbuild.config.ts /openedx/app/rsbuild.config.ts
RUN --mount=type=cache,target=/openedx/app/node_modules/.cache,sharing=locked rsbuild build




####### final production image with all static assets
FROM docker.io/caddy:2.7.4 AS production

RUN mkdir -p /openedx/dist

# Copy static assets

COPY --from=admin-console-prod /openedx/app/dist /openedx/dist/admin-console

COPY --from=authn-prod /openedx/app/dist /openedx/dist/authn

COPY --from=authoring-prod /openedx/app/dist /openedx/dist/authoring

COPY --from=account-prod /openedx/app/dist /openedx/dist/account

COPY --from=catalog-prod /openedx/app/dist /openedx/dist/catalog

COPY --from=communications-prod /openedx/app/dist /openedx/dist/communications

COPY --from=discussions-prod /openedx/app/dist /openedx/dist/discussions

COPY --from=gradebook-prod /openedx/app/dist /openedx/dist/gradebook

COPY --from=learner-dashboard-prod /openedx/app/dist /openedx/dist/learner-dashboard

COPY --from=learning-prod /openedx/app/dist /openedx/dist/learning

COPY --from=ora-grading-prod /openedx/app/dist /openedx/dist/ora-grading

COPY --from=profile-prod /openedx/app/dist /openedx/dist/profile
