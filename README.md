# GitLab CI/CD

This repository contains an example for emulating a CI/CD pipeline.
For demonstration purposes, GitLab will be used locally at all levels.
In ideal conditions, the pipeline should consist of the following servers:

- a server for **GitLab CE** with the project **repository** and
  container images in the **GitLab Container Registry**;
- a server for **GitLab Runner**, which monitors the repository state,
  runs various pipeline stages (linters, tests, container image builds,
  deployments to staging and production), and requires 8GB RAM, 4 CPU cores, 50GB SSD (recommended);
- a **staging** server, where the project runs during development;
- a **production** server, where the final deployed project runs.

In resource-limited environments, GitLab CE and GitLab Runner can be hosted on the same server.
For local development, this is not critical, so they are placed on separate servers here.
However, the structure is simplified by omitting the production server
and keeping only the staging server, since their setup is often similar.

## Workflow

### Launching Local Servers

First, build the image for the mock VPS:

```sh
docker build -t simple-vps .
```

Once the image is built, start the servers based on it:

```sh
docker compose up -d
```

Further configuration will be done inside the running servers.

### Installing GitLab CE

Install GitLab CE inside the `gitlab-ce-vps` container:

```sh
docker exec -it gitlab-ce-vps /bin/sh
```

Inside the container, run:

```sh
cd /opt/gitlab-ce && docker compose up -d
```

The installation may take about 5+ minutes. Once done, visit `http://host.docker.internal:801`
in your browser and log in with credentials from `.env` (`test@mail.com` / `PaSS_VV0rd`).

### Installing GitLab Runner

Connect to the GitLab Runner server terminal:

```sh
docker exec -it gitlab-runner-vps /bin/sh
```

Start the installation:

```sh
cd opt/gitlab-runner && docker compose up -d
```

Once completed, you can close the terminal of this server with the `exit` command.

### Configuring GitLab CE

From the GitLab CE home page, choose **Create a project**. Select a creation method:

- import an existing project with a `.gitlab-ci.yml`;
- or choose a template, e.g., **NodeJS Express**.

If importing, enable `Import sources` in
`Admin` → `Settings` → `General` → `Import and export settings`.

If the template lacks `.gitlab-ci.yml`, create it via
`Build` → `Pipeline editor` → `Configure Pipeline` → `Commit changes`.

Next, configure the Runner in
`Settings` → `CI/CD` → `Runners` → `Project runners` → `Create project runner`:

- enable **Run untagged jobs**;
- choose **Linux**;
- save the provided runner token for the next step.

### Configuring GitLab Runner

Register the Runner inside `gitlab-runner-vps`:

```sh
docker exec -it gitlab-runner /bin/sh
```

Run:

```sh
gitlab-runner register \
 --non-interactive \
 --url "http://host.docker.internal:801" \
 --token "YOUR_TOKEN" \
 --executor docker \
 --docker-image alpine:latest \
 --docker-network-mode host \
 --docker-volumes "/var/run/docker.sock:/var/run/docker.sock" \
 --docker-privileged
```

Comments on command options:

- `--non-interactive`: avoid prompts;
- `--url`: GitLab CE URL;
- `--token`: project runner token;
- `--executor docker`: run jobs in new Docker containers;
- `--docker-image alpine:latest`: default container image;
- `--docker-network-mode host`: use the host machine's network;
- `--docker-volumes "/var/run/docker.sock:/var/run/docker.sock"`: access to host Docker;
- `--docker-privileged`: resolve container permission issues.

### Configuring the Pipeline

We’ll set up SSH key authentication for the staging server.

From the host:

```sh
ssh vpsuser@host.docker.internal -p 222 # password: password
```

Generate SSH keys:

```sh
ssh-keygen -t rsa -b 4096 -C 'gitlab-runner' -f ~/keys-gitlab-runner
```

Add the public key:

```sh
mkdir -p ~/.ssh && cat ~/keys-gitlab-runner.pub >> ~/.ssh/authorized_keys
```

Copy the private key (e.g. by opening it with `vim ~/keys-gitlab-runner`)
and add it in GitLab CE under `Settings` → `CI/CD` → `Variables` → `Add variable`:

- key: `STAGING_SSH_KEY`;
- value: private key;
- visibility: `Visible`.

If you set a passphrase, also add `STAGING_SSH_PASSPHRASE`.

### Pipeline Example

This is a template `.gitlab-ci.yml` file for a NodeJS Express project.

```yaml
stages:
  - test
  - build
  - deploy

variables:
  DOCKER_DRIVER: overlay2
  DOCKER_TLS_CERTDIR: ""
  IMAGE_TAG: ${CI_REGISTRY}/${CI_PROJECT_PATH}/${CI_COMMIT_REF_SLUG}
  STAGING_HOST: host.docker.internal
  STAGING_SSH_PORT: 222
  STAGING_USER: vpsuser

test:
  stage: test
  image: node:lts-alpine
  script:
    - npm ci && npm run test

build:
  stage: build
  image: docker:latest
  services:
    - docker:dind
  script:
    - echo ${CI_JOB_TOKEN} | docker login -u gitlab-ci-token --password-stdin ${CI_REGISTRY}
    - docker build -t ${IMAGE_TAG} .
    - docker push ${IMAGE_TAG}

deploy:
  stage: deploy
  image: alpine:latest
  before_script:
    - "which ssh-agent || ( apk update && apk add openssh )"
    - eval $(ssh-agent -s)
    - mkdir -p ~/.ssh
    - chmod 700 ~/.ssh
    - echo 'echo $STAGING_SSH_PASSPHRASE' > ~/.ssh/tmp && chmod 700 ~/.ssh/tmp
    - echo "$STAGING_SSH_KEY" | tr -d '\r' | DISPLAY=None SSH_ASKPASS=~/.ssh/tmp ssh-add -
    - ssh-keyscan -p ${STAGING_SSH_PORT} ${STAGING_HOST} >> ~/.ssh/known_hosts
    - chmod 644 ~/.ssh/known_hosts
  script:
    - ssh -o StrictHostKeyChecking=no -p ${STAGING_SSH_PORT} ${STAGING_USER}@${STAGING_HOST} "
      echo ${CI_JOB_TOKEN} | docker login -u gitlab-ci-token --password-stdin ${CI_REGISTRY} &&
      docker pull ${IMAGE_TAG} &&
      docker rm -f myapp || true &&
      docker run -d -p 80:5000 --restart always --name myapp ${IMAGE_TAG}"
  only:
    - master
```

When pushed to `master`, this triggers the pipeline.
After completion, your app will be available at `http://host.docker.internal:802`.

## Conclusion

This guide covers the key stages of setting up and running a local GitLab CI/CD pipeline.
In a real-world project, you may need additional setup for complex project structures,
user/group management, and security policies.

If you find inaccuracies or mistakes, feel free to open an issue or pull request.
