%%% @doc Advertises the embed capability on the mesh and serves it.
%%%
%%% Once the macula client and realm are up, this advertises the procedure
%%% (io.hecate.embed by default). A caller invokes it with:
%%%
%%%   macula:call(Pool, Realm, <<"io.hecate.embed">>,
%%%               #{text => Text, kind => query | passage | raw}, TimeoutMs)
%%%     -> {ok, #{vector => [float()]}}
%%%
%%%   macula:call(Pool, Realm, <<"io.hecate.embed">>,
%%%               #{texts => [Text]}, TimeoutMs)
%%%     -> {ok, #{vectors => [[float()]]}}
%%%
%%% The `kind' selects the model's asymmetric-retrieval prefix, so the caller
%%% does not need to know the model's convention — the service applies it. Keys
%%% are read defensively (atom or binary) so the payload survives CBOR either
%%% way. Re-advertises if the mesh link drops.
-module(hecate_embedder_advertiser).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).
-export([handle_embed/1]).   %% the RPC handler; external fun for macula to call

-define(RETRY_MS, 5000).

-record(st, {ref :: reference() | undefined}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    self() ! advertise,
    {ok, #st{}}.

handle_call(_Req, _From, St) -> {reply, ok, St}.
handle_cast(_Msg, St)        -> {noreply, St}.

handle_info(advertise, St) ->
    {noreply, do_advertise(St)};
handle_info({macula_event_gone, _Ref, _Reason}, St) ->
    self() ! advertise,
    {noreply, St#st{ref = undefined}};
handle_info(_Info, St) ->
    {noreply, St}.

terminate(_Reason, _St) -> ok.

%% --- advertising (same client-retry shape the subscribers use) ---

do_advertise(St) ->
    advertise_with(hecate_om:macula_client(), hecate_om_identity:realm(), St).

advertise_with({ok, Pool}, {ok, Realm}, St) ->
    on_advertised(catch macula:advertise(Pool, Realm, procedure(),
                                         fun ?MODULE:handle_embed/1, #{}), St);
advertise_with(_Client, _Realm, St) ->
    retry(St).

on_advertised({ok, Ref}, St) ->
    logger:info("[hecate_embedder] advertising ~ts", [procedure()]),
    St#st{ref = Ref};
on_advertised(Other, St) ->
    logger:notice("[hecate_embedder] advertise failed (~p); retrying", [Other]),
    retry(St).

retry(St) ->
    erlang:send_after(?RETRY_MS, self(), advertise),
    St#st{ref = undefined}.

procedure() ->
    application:get_env(hecate_embedder, procedure, <<"io.hecate.embed">>).

%% --- the RPC handler: embed text(s) -> vector(s) ---

-spec handle_embed(map()) -> {ok, map()} | {error, term()}.
handle_embed(Payload) ->
    dispatch(gf(text, Payload), gf(texts, Payload), norm(gf(kind, Payload))).

dispatch(Text, _Texts, Kind) when is_binary(Text) ->
    one(Kind, Text);
dispatch(_Text, Texts, _Kind) when is_list(Texts) ->
    many(Texts);
dispatch(_Text, _Texts, _Kind) ->
    {error, bad_request}.

one(Kind, Text) ->
    {ok, Model} = hecate_embed:default_model(),
    vec(embed_by_kind(Kind, Model, Text)).

embed_by_kind(<<"query">>, Model, Text)   -> hecate_embed:embed_query(Model, Text);
embed_by_kind(<<"passage">>, Model, Text) -> hecate_embed:embed_passage(Model, Text);
embed_by_kind(_Raw, Model, Text)          -> hecate_embed:embed(Model, Text).

vec({ok, V})           -> {ok, #{vector => V}};
vec({error, _} = Err)  -> Err.

many(Texts) ->
    {ok, Model} = hecate_embed:default_model(),
    vecs(hecate_embed:embed_many(Model, Texts)).

vecs({ok, Vs})          -> {ok, #{vectors => Vs}};
vecs({error, _} = Err)  -> Err.

%% CBOR may round-trip a map key as an atom or a binary; try atom then binary.
gf(Key, Map) ->
    maps:get(Key, Map, maps:get(atom_to_binary(Key, utf8), Map, undefined)).

norm(K) when is_atom(K)   -> atom_to_binary(K, utf8);
norm(K) when is_binary(K) -> K;
norm(_Other)              -> <<"raw">>.
