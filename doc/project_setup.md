## Prerequisites
1. Your app is accessed over HTTP
2. You are familiar with Docker and docker-compose

In order to setup a project for deployment using chatops_deployer, you
need to add 3 files to the root of your project:

## 1. Add a `Dockerfile`
A `Dockerfile` contains the steps for creating a docker image for your app.
This image will be used by docker-compose to create a container for the app.

Make sure that only the "setup" steps are added to Dockerfile, such as installing
prerequisites, and copying the files of the project to the image. If any
step needs to have persistent side effects, add this command inside `chatops_deployer.yml`
instead of adding it to `Dockerfile` (step 3 has more info). This is useful for cases like `bundle install`,
`npm install` or `gradle setup` where the downloaded libraries can be shared
among deployments.

Here's a sample `Dockerfile` :

```
# For faster builds, it's a good practice to push the commonly used base images
# to an on-premise docker registry, in this example it's running at my.dockerhub:5000
FROM my.dockerhub:5000/ruby:2.2
RUN apt-get update -qq && apt-get install -y build-essential libpq-dev nodejs mysql-client

# Copy the project
RUN mkdir /web
WORKDIR /web
ADD . /web/
COPY config/database.docker.yml /web/config/database.yml
```

## 2. Add `docker-compose.yml`
`docker-compose.yml` is declarative way of specifying how your app's services
will run together. Go through docker-compose docs to learn how to write
the `docker-compose.yml` file for your setup. Here's a sample `docker-compose.yml`:

```
db:
  image: my.dockerhub:5000/mysql:5.6
  environment:
    - MYSQL_ROOT_PASSWORD=secret
    - MYSQL_DATABASE=db_name

redis:
  image: vt.dockerhub:5000/redis:3.0.5

web:
  # Build the docker image using Dockerfile
  build: .
  command: bin/rails s -p 3000 -b '0.0.0.0'
  ports:
    - "3000"
  environment:
    - BUNDLE_PATH=/cache/tmp/bundler
    - REDIS_URL=redis://redis
    - DB_USER=root
    - DB_PASSWORD=secret
    - DB_HOST=db
    - DB_NAME=db_name
  volumes_from:
    - cache
  links:
    - db
    - redis
```

## 3. Add `chatops_deployer.yml`
This file tells the deployer which ports of which all services should
be exposed to the user. It also allows users to run commands on the services,
for example downloading dependent libraries or running DB migrations or seeding
DB with initial data. Here's a sample `chatops_deployer.yml` :

```
# Which ports if which service need to be exposed as
# haikunated URLs
expose:
  web: [3000]

# These commands will be run in the specified order in the containers
# In this example "bin/setup.docker" is an executable that is checked into
# source control that downloads dependent libraries and runs DB migrations.
commands:
  - [web, "bin/setup.docker"]

# Expand and copy template files.
# If the source file ends with .erb, it's treated as an ERB template and gets
# processed. You have access to a variable named `env` in ERB.
# "env" holds the exposed urls. For example:
# "<%= env['urls']['web']['3000'] %>" will be replaced with something like "http://crimson-cloud-12.<deployer_host>"
copy:
  - "./config/secrets.docker.yml.erb:config/secrets.yml"
```


## Github Webhooks

If you'd like automatic deployments when Pull requests are opened or updated,
you can configure a Github webhook by going to your project's Settings page.
Follow these instructions : https://developer.github.com/webhooks/creating/ .
Use `<host>:<port>/gh-webhook` as the payload URL, where `host:port` is where
chatops_deployer is running. Get the value of ENV variable
`GITHUB_WEBHOOK_SECRET` which was used when starting `chatops_deployer` app and
use it as the secret when configuring the webhook.

Now whenever a Pull Request is opened, updated or closed, a new deployment will be triggered
and chatops_deployer will leave a comment on the PR with the URLs to access
the services deployed for the newly deployed environment. This environment will
be destroyed when the PR is closed.
