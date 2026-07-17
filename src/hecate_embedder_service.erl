%%% @doc hecate-embedder — implements the hecate_om_service behaviour.
%%%
%%% A store-less mesh service: it holds no reckon-db state, it just advertises
%%% one capability, `io.hecate.embed', in the realm. A caller (e.g. a Spartan
%%% mind's long-term memory) reaches it with macula:call, and the relay finds
%%% this provider wherever it lives — no LAN address, no subnet coupling.
-module(hecate_embedder_service).
-behaviour(hecate_om_service).

-export([info/0, start/1, stop/1, health/0, capabilities/0, identity_spec/0]).

info() ->
    #{
        name        => <<"hecate-embedder">>,
        version     => <<"0.1.0">>,
        description => <<"Sovereign sentence-embedding capability on the mesh">>
    }.

start(_Opts) ->
    hecate_embedder_sup:start_link().

stop(_State) ->
    ok.

%% Boots green once the supervision tree is up. The advertiser refines liveness
%% (the procedure is only truly usable once advertised), but a plain ok here
%% keeps /health simple; the model warms lazily on the first call.
health() ->
    ok.

%% Announced on the realm's capability channel so peers can discover that an
%% embedding capability exists (and its version) without hard-coding a provider.
capabilities() ->
    [#{name => <<"embed">>, version => 1}].

%% The UCAN this service asks hecate-realm to mint: authority to advertise and
%% serve the embed procedure in the realm.
identity_spec() ->
    #{
        scope     => <<"embed">>,
        actions   => [<<"advertise">>, <<"call">>],
        resources => [<<"io.hecate.embed">>, <<"embed/*">>],
        ttl_days  => 30
    }.
