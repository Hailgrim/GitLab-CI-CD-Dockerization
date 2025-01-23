# GitLab CI/CD

## Setup

In the `./.env` file, you can configure the initial project parameters,
including the _root_ user data and a link to access the project.

## Installation

Run the command:

```sh
docker compose -f docker-compose.yml up -d
```

Wait for GitLab to start processing the login page for your personal account.
This process may take several minutes.
At the same time, an error will appear in the console of the `CI-CD.gitlab-runner` container
with the text that the `/etc/gitlab-runner/config.toml` file is missing.
At this stage, there is nothing to worry about, everything is going according to plan.
Next, you need to log in to your profile, create or connect an existing project,
create a **Runner** in `Settings` > `CI/CD` > `Runners`.
You can also create a global **Runner** in `Admin` > `CI/CD` > `Runners`.
Once created, a page with a command to register **Runner** will be displayed.
Next, you need to connect to the container terminal using the command:

```sh
docker exec -it CI-CD.gitlab-runner bash
```

Now you need to enter the following command in the container console,
where the `url` and `token` elements must match those parameters
in the command from the **Runner** registration page.

```sh
gitlab-runner register \
 --non-interactive \
 --url 'YOUR_URL' \
 --token 'YOUR_TOKEN' \
 --executor docker \
 --docker-image alpine:latest \
 --docker-network-mode host \
 --docker-volumes "$CACHE_VOLUME:/cache" \
 --docker-volumes "$BUILDS_VOLUME:/builds"
```

After successful registration, the error in the `CI-CD.gitlab-runner` container console should stop appearing.
Now you can set up build, test, and deploy pipelines for projects, as well as access rights for programmers.
