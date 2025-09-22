ARG RUST_VERSION=1.88.0
ARG HORIZON_TAG=v0.39.0
ARG DS_PLUGIN_TAG=main

#############################
# Stage 1: fetch sources
#############################
FROM alpine/git AS fetcher

# Re-declare args for this stage
ARG HORIZON_TAG
ARG DS_PLUGIN_TAG

WORKDIR /src

# Clone Horizon core
RUN git clone --depth 1 --branch "$HORIZON_TAG" https://github.com/Far-Beyond-Dev/Horizon.git horizon

# Clone plugins repo
RUN git clone --depth 1 --branch "$DS_PLUGIN_TAG" https://github.com/DyingStar-game/horizonserver plugins_repo

#############################################
# Stage 2: build Rust (app + plugins)
#############################################
FROM rust:${RUST_VERSION}-slim AS build

WORKDIR /app

# Install build dependencies (glibc environment provides statx symbols required by monoio)
RUN apt-get update && \
	DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
		build-essential \
		clang \
		lld \
		git \
		pkg-config \
		ca-certificates \
		libssl-dev \
		openssl && \
	rm -rf /var/lib/apt/lists/*

# Copy workspace configuration first for better caching
COPY --from=fetcher /src/horizon/Cargo.toml ./
# Copy all crate directories  
COPY --from=fetcher /src/horizon/crates ./crates

# Fix relative paths in Cargo.toml (normalize crates path)
RUN grep -RIl "../Horizon/crates/" crates | xargs -r sed -i 's|../Horizon/crates/|../|g'
# Remove any 'path = "examples/..."' lines in crate Cargo.toml files
RUN grep -RIl 'path = "examples/' crates | xargs -r sed -i '/path = "examples\//d' || true
# Clean root Cargo.toml workspace members: drop entries under examples/
RUN sed -i '/^[[:space:]]*"examples\//d' Cargo.toml && \
	# Remove trailing comma if last item removed (comments may remain)
	sed -i -r ':a;N;$!ba;s/,(\n([[:space:]]*#.*\n)*)]/\1]/g' Cargo.toml && \
	# Simple case: comma directly before ]
	sed -i ':a;N;$!ba;s/,\n]/\n]/' Cargo.toml

# Build the horizon crate (main application)
RUN --mount=type=cache,target=/app/target/ \
    --mount=type=cache,target=/usr/local/cargo/git/db \
    --mount=type=cache,target=/usr/local/cargo/registry/ \
    if [ -f Cargo.lock ]; then \
      cargo build --locked --release --package horizon; \
    else \
      cargo build --release --package horizon; \
    fi && \
    cp ./target/release/horizon /app/server

# Build plugins as dynamic libraries (sortie réduite)
COPY --from=fetcher /src/plugins_repo ./plugins_src
RUN --mount=type=cache,target=/app/target/ \
    --mount=type=cache,target=/usr/local/cargo/git/db \
    --mount=type=cache,target=/usr/local/cargo/registry/ \
    bash -euxc 'mkdir -p /app/plugins; \
    plugins_built=""; \
    for cargo_file in plugins_src/*/Cargo.toml; do \
      [ -f "${cargo_file}" ] || continue; \
      plugin_dir=$(dirname "${cargo_file}"); \
      plugin_name=$(basename "${plugin_dir}"); \
      if grep -q "crate-type.*cdylib" "${cargo_file}"; then \
        echo "[plugin] ${plugin_name}"; \
        cd "${plugin_dir}"; \
        sed -i "s|../Horizon/crates/|../../crates/|g" Cargo.toml; \
        if ! grep -q "^\\[workspace\\]" Cargo.toml; then echo "" >> Cargo.toml; echo "[workspace]" >> Cargo.toml; fi; \
        if [ -f Cargo.lock ]; then cargo build --locked --release -q || cargo build --locked --release; else cargo build --release -q || cargo build --release; fi; \
        find target/release -maxdepth 1 -name "libplugin_*.so" -exec cp {} /app/plugins/ \; 2>/dev/null || true; \
        plugins_built="${plugins_built} ${plugin_name}"; \
        cd /app; \
      fi; \
    done; \
    echo "Plugins: ${plugins_built:-aucun}"'

#############################################
# Stage 3: distroless runtime (final)
#############################################
FROM gcr.io/distroless/cc-debian12 AS final

WORKDIR /app

COPY --from=build /app/server /app/server
COPY --from=build /app/plugins /app/plugins
COPY ./config.toml /app/config.toml

EXPOSE 8080
ENTRYPOINT ["/app/server"]