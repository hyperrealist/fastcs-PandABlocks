# The devcontainer should use the developer target and run as root with podman
# or docker with user namespaces.
FROM ghcr.io/diamondlightsource/ubuntu-devcontainer:noble AS developer

# Add any system dependencies for the developer/build environment here
RUN apt-get update -y && apt-get install -y --no-install-recommends \
    graphviz \
    && apt-get dist-clean

# The build stage installs the context into the venv
FROM developer AS build

# Change the working directory to the `app` directory
# and copy in the project
WORKDIR /app
COPY . /app
RUN chmod o+wrX .

# Tell uv sync to install python in a known location so we can copy it out later
ENV UV_PYTHON_INSTALL_DIR=/python

# Sync the project without its dev dependencies
# ----------------------------------------------------------------------------------------------------- debugpy
RUN uv add debugpy
# ----------------------------------------------------------------------------------------------------- /debugpy
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked --no-editable --no-dev


# The runtime stage copies the built venv into a runtime container
FROM ubuntu:noble AS runtime

# Add apt-get system dependecies for runtime here if needed
# RUN apt-get update -y && apt-get install -y --no-install-recommends \
#     some-library \
#     && apt-get dist-clean
# ----------------------------------------------------------------------------------------------------- gdb
RUN apt-get update -y && apt-get install -y --no-install-recommends \
    gdb libnss-wrapper \
    && apt-get dist-clean
# ----------------------------------------------------------------------------------------------------- /gdb

# Copy the python installation from the build stage
COPY --from=build /python /python

# Copy the environment, but not the source code
# COPY --from=build /app/.venv /app/.venv
# ENV PATH=/app/.venv/bin:$PATH
# ----------------------------------------------------------------------------------------------------- venv
COPY --chown=1000:1000 --from=build /app/.venv /app/.venv
RUN chmod o+wrX /app/.venv
ENV PATH=/app/.venv/bin:$PATH
# ----------------------------------------------------------------------------------------------------- /venv



# ----------------------------------------------------------------------------------------------------- symlink
WORKDIR /app/.venv/lib
RUN ln -s python* python
# ----------------------------------------------------------------------------------------------------- /symlink



# ----------------------------------------------------------------------------------------------------- source code
WORKDIR /workspaces
COPY --chown=1000:1000 . fastcs-PandABlocks
# ----------------------------------------------------------------------------------------------------- /source code




# ----------------------------------------------------------------------------------------------------- uv
COPY --from=ghcr.io/astral-sh/uv:0.10 /uv /uvx /bin/
# ----------------------------------------------------------------------------------------------------- /uv



# ----------------------------------------------------------------------------------------------------- user
RUN echo "user:x:37149:37149:Dynamic User:/home/user:/bin/bash" >> /etc/passwd
# ----------------------------------------------------------------------------------------------------- /user
# change this entrypoint if it is not the same as the repo
ENTRYPOINT ["fastcs-pandablocks"]
CMD ["--version"]
