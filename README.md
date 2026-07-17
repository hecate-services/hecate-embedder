# hecate-embedder

The sovereign sentence-embedding capability, **on the Macula mesh**.

An L2 [`hecate-om`](https://codeberg.org/hecate-services/hecate-om) service that
advertises `io.hecate.embed` in the realm. Peers — for example a Spartan mind's
long-term memory — reach it with `macula:call`, and the relay finds the provider
wherever it lives. No LAN address, no subnet coupling: the mesh routes across
subnets where flat routing does not.

## Why a separate service

Embedding needs an ONNX runtime, which requires AVX2 — the beam Celerons don't
have it (the runtime SIGILLs), so one embedder runs on an AVX2 host and serves
the whole society. Reaching it over the mesh (rather than a hardcoded LAN URL)
makes its location irrelevant and its calls realm-authenticated and encrypted.

`hecate-embedder` is the thin mesh layer; the actual embedding is done by the
[`hecate-embed`](https://codeberg.org/hecate-social/hecate-embed) library's real
`fastembed` NIF (multilingual-e5-small), kept a clean, mesh-free dependency.

## The capability

```
macula:call(Pool, Realm, <<"io.hecate.embed">>,
            #{text => Text, kind => query | passage | raw}, TimeoutMs)
    -> {ok, #{vector => [float()]}}

macula:call(Pool, Realm, <<"io.hecate.embed">>,
            #{texts => [Text]}, TimeoutMs)
    -> {ok, #{vectors => [[float()]]}}
```

`kind` selects the model's asymmetric-retrieval prefix (`query:` / `passage:`),
applied service-side, so callers need not know the model's convention.

## Run

Deploy the image (`ghcr.io/hecate-services/hecate-embedder`) on an AVX2 host with:

- `HECATE_REALM` — 64-hex realm tag
- `MACULA_STATION_SEEDS` — CSV of stations to dial
- a realm-signed service cert at `/etc/hecate/secrets/service-cert.pem`

The multilingual-e5-small model is baked into the image; nothing is downloaded
at runtime.

## License

Apache-2.0.
