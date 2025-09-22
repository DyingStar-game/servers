# Servers Stack

This repository contains the Docker Compose configurations for the various servers used in the Dying Star project.

## Included Services

### Horizon

The Horizon server is packaged in the `horizon` directory. It includes:
- A Dockerfile for building the Horizon server image with horizon-server official repository and additional plugins from dying-star repository (https://github.com/DyingStar-game/horizonserver).

The docker image is a multi-layer image:
- The first layer pull from git the horizon-server repository and dying-star repository.
- The second stage build the horizon-server with the plugins from dying-star repository with rust.
- The third stage copy the built binary and the configuration files to a distroless image.

### SDO

### PersistInfra

## Environment Variables

In order to customize the ports used by the services, you can set the following environment variables in a `.env` file at the root of the repository.

## Local Development

To run the entire stack locally, you can use the following command:

```bash
docker-compose up -d --build
``` 

You can also use the Makefile provided in the root of the repository for convenience:

```bash
make dev
``` 

You can stop the stack with:

```bash
make stop-dev
```
