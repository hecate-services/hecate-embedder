%%% @doc hecate_embedder OTP application entry.
%%%
%%% hecate_om:boot/1 provisions this service's realm cert (from identity_spec/0),
%%% joins the mesh, registers capabilities + the /health probe, then calls the
%%% service's start/1. This service is store-less (no store_id/0 + data_dir/0),
%%% so no reckon-db store is started.
%%%
%%% The realm tag is the one value hecate_om reads from app-env with no env
%%% fallback, so we set it from HECATE_REALM here BEFORE boot. Everything else is
%%% read directly from the environment (MACULA_STATION_SEEDS by hecate_om,
%%% HECATE_EMBED_MODEL_DIR by hecate_embed) or has a static default in
%%% config/sys.config — so there is no ${VAR} substitution and no dependency on
%%% the base image's awk (RELX_REPLACE_OS_VARS is not used).
-module(hecate_embedder_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    ok = set_realm_from_env(),
    hecate_om:boot(hecate_embedder_service).

stop(_State) ->
    ok.

set_realm_from_env() ->
    case os:getenv("HECATE_REALM") of
        Realm when is_list(Realm), Realm =/= "" ->
            application:set_env(hecate_om, realm, list_to_binary(Realm));
        _Unset ->
            ok
    end.
