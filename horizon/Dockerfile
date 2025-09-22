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

# Build plugins as dynamic libraries
COPY --from=fetcher /src/plugins_repo ./plugins_src
RUN --mount=type=cache,target=/app/target/ \
    --mount=type=cache,target=/usr/local/cargo/git/db \
    --mount=type=cache,target=/usr/local/cargo/registry/ \
    mkdir -p /app/plugins && \
    echo "==> Auto-detecting plugins in plugins_src..." && \
    # Find all directories containing Cargo.toml with cdylib crate-type
    for plugin_dir in plugins_src/*/; do \
      if [ -d "$plugin_dir" ] && [ -f "$plugin_dir/Cargo.toml" ]; then \
        plugin_name=$(basename "$plugin_dir"); \
        echo "==> Checking $plugin_name for plugin markers..."; \
        # Check if this is a plugin (has cdylib crate-type)
        if grep -q 'crate-type.*=.*\["cdylib"\]' "$plugin_dir/Cargo.toml" || \
           grep -q 'crate-type.*=.*\[.*"cdylib".*\]' "$plugin_dir/Cargo.toml"; then \
          echo "==> Found plugin: $plugin_name"; \
          cd "$plugin_dir"; \
          # Fix path to horizon crates
          sed -i 's|../Horizon/crates/|../../crates/|g' Cargo.toml; \
          # Add empty workspace section to prevent workspace confusion
          if ! grep -q '^\[workspace\]' Cargo.toml; then \
            echo "" >> Cargo.toml; \
            echo "[workspace]" >> Cargo.toml; \
          fi; \
          echo "==> Modified Cargo.toml for $plugin_name:"; \
          cat Cargo.toml; \
          echo "==> Building plugin $plugin_name..."; \
          # Build the plugin as cdylib and capture any errors
          BUILD_OUTPUT=$(mktemp); \
          if [ -f Cargo.lock ]; then \
            cargo build --locked --release 2>&1 | tee "$BUILD_OUTPUT"; \
          else \
            cargo build --release 2>&1 | tee "$BUILD_OUTPUT"; \
          fi; \
          BUILD_EXIT_CODE=$?; \
          echo "==> Build exit code for $plugin_name: $BUILD_EXIT_CODE"; \
          if [ $BUILD_EXIT_CODE -ne 0 ]; then \
            echo "==> ❌ COMPILATION FAILED for $plugin_name"; \
            echo "==> Error details:"; \
            grep -E "error\[|error:|warning:" "$BUILD_OUTPUT" | head -20; \
          else \
            echo "==> ✅ COMPILATION SUCCESSFUL for $plugin_name"; \
          fi; \
          rm -f "$BUILD_OUTPUT"; \
          # Show what was built
          echo "==> Built files for $plugin_name:"; \
          echo "==> Looking for main plugin .so file:"; \
          find target/release -maxdepth 1 -name "libplugin_*.so" -type f; \
          # Copy the resulting .so file to plugins directory (only main plugin files, not deps)
          find target/release -maxdepth 1 -name "libplugin_*.so" -exec cp {} /app/plugins/ \; || true; \
          cd /app; \
        else \
          echo "==> Skipping $plugin_name (not a cdylib plugin)"; \
        fi; \
      fi; \
    done

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