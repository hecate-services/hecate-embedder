%%% @doc Tests for the embed RPC handler — the procedure a Spartan mind's
%%% long-term memory reaches over the mesh (io.hecate.embed). We exercise
%%% handle_embed/1 directly (no macula, no realm) against the deterministic stub
%%% embedder, so these assert the request contract, not embedding quality:
%%%
%%%   - kind routing: query | passage | raw all yield a vector
%%%   - CBOR survival: text and kind keys arrive as atom OR binary, both parse
%%%   - batch: {texts => [...]} yields {vectors => [...]}
%%%   - a request with neither text nor texts is a clean {error, bad_request}
-module(hecate_embedder_advertiser_tests).

-include_lib("eunit/include/eunit.hrl").

embed_test_() ->
    {setup,
     fun() -> {ok, _} = application:ensure_all_started(hecate_embed), ok end,
     fun(_) -> ok end,
     [
      fun single_query/0,
      fun single_passage/0,
      fun single_raw_default/0,
      fun cbor_binary_keys/0,
      fun batch_texts/0,
      fun bad_request_without_text/0
     ]}.

single_query() ->
    {ok, #{vector := V}} =
        hecate_embedder_advertiser:handle_embed(#{text => <<"block the attacker">>,
                                                  kind => query}),
    ?assert(is_list(V)),
    ?assert(length(V) > 0).

single_passage() ->
    {ok, #{vector := V}} =
        hecate_embedder_advertiser:handle_embed(#{text => <<"rotate the credential">>,
                                                  kind => passage}),
    ?assert(is_list(V)),
    ?assert(length(V) > 0).

single_raw_default() ->
    %% No kind at all: the handler treats it as raw, still returns a vector.
    {ok, #{vector := V}} =
        hecate_embedder_advertiser:handle_embed(#{text => <<"audit the accounts">>}),
    ?assert(is_list(V)),
    ?assert(length(V) > 0).

cbor_binary_keys() ->
    %% CBOR may hand the keys back as binaries. gf/2 and norm/1 must cope, so the
    %% mesh caller's payload survives the round-trip either way.
    {ok, #{vector := V}} =
        hecate_embedder_advertiser:handle_embed(#{<<"text">> => <<"a passage">>,
                                                  <<"kind">> => <<"passage">>}),
    ?assert(is_list(V)),
    ?assert(length(V) > 0).

batch_texts() ->
    {ok, #{vectors := Vs}} =
        hecate_embedder_advertiser:handle_embed(#{texts => [<<"one">>, <<"two">>, <<"three">>]}),
    ?assertEqual(3, length(Vs)),
    ?assert(lists:all(fun(V) -> is_list(V) andalso length(V) > 0 end, Vs)).

bad_request_without_text() ->
    ?assertEqual({error, bad_request},
                 hecate_embedder_advertiser:handle_embed(#{kind => query})).
