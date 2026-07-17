# hecate-embedder — the sovereign embedding capability, ON THE MESH.
#
# An L2 hecate-om service that advertises `io.hecate.embed' in the realm; peers
# reach it with macula:call, location-transparently. Runs on an AVX2 host (the
# beam Celerons SIGILL on the ONNX runtime), does the embedding with the
# hecate_embed library's real fastembed NIF, and bakes the model in so nothing
# is downloaded at runtime.
#
# Debian/trixie: fastembed's ONNX Runtime needs glibc, and the runtime base must
# match the erlang:28 builder's glibc (2.38). Pushed to
# ghcr.io/hecate-services/hecate-embedder.
#
# Deploy needs, from the environment / mounts (not baked in):
#   HECATE_REALM           64-hex realm tag
#   MACULA_STATION_SEEDS   CSV of station seeds to dial
#   /etc/hecate/secrets/service-cert.pem   realm-signed service cert (mounted)

#----------------------------------------------------------------------
# Stage 1 — builder: Erlang + Rust + real-embed NIF + model + release
#----------------------------------------------------------------------
FROM docker.io/erlang:28 AS builder
WORKDIR /build

RUN apt-get update && apt-get install -y --no-install-recommends \
        git curl bash build-essential cmake \
    && rm -rf /var/lib/apt/lists/*

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
        | sh -s -- -y --default-toolchain stable --profile minimal
ENV PATH="/root/.cargo/bin:${PATH}"

RUN curl -fsSL https://s3.amazonaws.com/rebar3/rebar3 -o /usr/local/bin/rebar3 \
    && chmod +x /usr/local/bin/rebar3

COPY rebar.config ./
RUN rebar3 get-deps

COPY . .
# The genuine ONNX embedder NIF (from the hecate_embed dep; glibc).
RUN CARGO_FEATURES=real-embed bash _build/default/lib/hecate_embed/scripts/build-nif.sh
# Bake the model into the image (no runtime download).
RUN bash _build/default/lib/hecate_embed/scripts/prefetch-model.sh /models
# Production release (bundles ERTS).
RUN rebar3 as prod release

#----------------------------------------------------------------------
# Stage 2 — runtime: slim Debian (trixie) + the release + the baked model
#----------------------------------------------------------------------
FROM docker.io/debian:trixie-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
        libssl3 zlib1g libbrotli1 libzstd1 libstdc++6 libncurses6 \
        ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /build/_build/prod/rel/hecate_embedder ./
COPY --from=builder /models /models

ENV HOME=/app
# Read directly by the apps (os:getenv); no ${VAR} substitution at boot.
ENV HECATE_EMBED_MODEL_DIR=/models

# The realm cert is mounted here by the deploy; the station socket lives here.
VOLUME ["/etc/hecate/secrets", "/run/macula"]

# Loopback health (hecate_om health probe).
EXPOSE 8480
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD curl -fsS http://127.0.0.1:8480/health || exit 1

CMD ["bin/hecate_embedder", "foreground"]
