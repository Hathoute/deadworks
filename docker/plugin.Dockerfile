# syntax=docker/dockerfile:1
# =============================================================================
# Example Dockerfile for building and packaging a Deadworks plugin as an
# OCI image — WITHOUT rebuilding the deadworks server itself.
#
# The plugin is compiled against DeadworksManaged.Api.dll (and its transitive
# dependencies, e.g. Google.Protobuf.dll) taken directly from the published
# deadworks image, then stored in a lightweight busybox image under
# /opt/deadworks/plugins/. The deadworks Helm chart mounts these images in
# init containers and copies that folder into the server on start.
#
# Build (run from the plugin project directory, i.e. the dir containing the
# plugin's .csproj):
#
#   docker build \
#     -f /path/to/deadworks/docker/plugin.Dockerfile \
#     -t ghcr.io/<you>/my-deadworks-plugin:1.0.0 \
#     --build-arg DEADWORKS_IMAGE=ghcr.io/deadworks-net/deadworks:latest \
#     .
#
# DEADWORKS_IMAGE should match the server version you run, so the plugin is
# compiled against the exact API it will be loaded by.
#
# Publish and wire it into the Helm chart:
#
#   docker push ghcr.io/<you>/my-deadworks-plugin:1.0.0
#   helm install myserver charts/deadworks \
#     --set steam.user=... --set steam.password=... \
#     --set 'server.plugins[0]=ghcr.io/<you>/my-deadworks-plugin:1.0.0'
#
# The plugin .csproj must reference the API DLLs extracted into $(DeadworksApiDir)
# instead of a ProjectReference (which only works inside this repository):
#
#   <ItemGroup>
#     <Reference Include="$(DeadworksApiDir)/*.dll" Private="false" />
#   </ItemGroup>
#
# Keep EnableDynamicLoading=true and TargetFramework net10.0 as in the
# example plugins. The "DeployToGame" target from the examples is only for
# local Windows development and not needed here.
# =============================================================================

# Registry reference of the deadworks server image providing the built API.
ARG DEADWORKS_IMAGE=ghcr.io/hathoute/deadworks:sha-2465390

# -----------------------------------------------------------------------------
# Stage 1: built deadworks artifacts — source of DeadworksManaged.Api.dll
# -----------------------------------------------------------------------------
FROM ${DEADWORKS_IMAGE} AS api

# -----------------------------------------------------------------------------
# Stage 2: compile the plugin against the API from the image
# -----------------------------------------------------------------------------
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build

WORKDIR /build

# Managed layer from the published server image: DeadworksManaged.Api.dll,
# Google.Protobuf.dll, ...
COPY --from=api /opt/deadworks/game/bin/win64/managed/ /api/

# Plugin source (the build context: directory with the plugin .csproj)
COPY . /src

# Plugins from this repository reference the API via a relative ProjectReference
# that only resolves inside the full repo checkout. When such a reference is
# found, replace it with the API DLLs extracted from the deadworks image.
# Standalone plugins using the $(DeadworksApiDir) Reference are not affected.
RUN find /src -name '*.csproj' -exec sed -i \
      -e '/<ProjectReference Include="[^"]*DeadworksManaged\.Api\.csproj">/,/<\/ProjectReference>/c\<Reference Include="$(DeadworksApiDir)/*.dll" Private="false" />' \
      {} +

RUN dotnet publish /src/*.csproj \
    -c Release \
    -o /out \
    -p:DeadworksApiDir=/api

# -----------------------------------------------------------------------------
# Stage 3: storage-only image — just the plugin payload
# -----------------------------------------------------------------------------
# busybox is deliberately chosen: it is tiny AND provides /bin/sh + cp, which
# the deadworks chart's init containers use to copy the payload out.
FROM busybox:stable-musl

COPY --from=build /out/ /opt/deadworks/plugins/
