%%% @doc Top supervisor for hecate_embedder.
%%%
%%% One child: the advertiser, which joins the mesh and advertises the embed
%%% procedure. The embedding model itself is loaded lazily by hecate_embed's own
%%% model supervisor (started via the hecate_embed application) on first use.
-module(hecate_embedder_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 5, period => 10},
    Children = [
        #{id       => hecate_embedder_advertiser,
          start    => {hecate_embedder_advertiser, start_link, []},
          restart  => permanent,
          shutdown => 5000,
          type     => worker,
          modules  => [hecate_embedder_advertiser]}
    ],
    {ok, {SupFlags, Children}}.
