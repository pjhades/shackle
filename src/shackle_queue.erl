-module(shackle_queue).
-include("shackle_internal.hrl").

-compile(inline).
-compile({inline_size, 512}).

%% internal
-export([
    add/4,
    clear/1,
    init/0,
    remove/2
]).

%% internal
-spec add(server_id(), external_request_id(), cast(), reference()) ->
    ok.

add(ServerId, ExtRequestId, Cast, TimerRef) ->
    Object = {{ServerId, ExtRequestId}, {Cast, TimerRef}},
    ets:insert(?ETS_TABLE_QUEUE, Object),
    ok.

-spec clear(server_id()) ->
    [{cast(), reference()}].

clear(ServerId) ->
    Match = {{ServerId, '_'}, '_'},
    case ets_match_take(?ETS_TABLE_QUEUE, Match) of
        [] ->
            [];
        Objects ->
            [{Cast, TimerRef} || {_, {Cast, TimerRef}} <- Objects]
    end.

-spec init() ->
    ok.

init() ->
    ets_new(?ETS_TABLE_QUEUE),
    ok.

-spec remove(server_id(), external_request_id()) ->
    {ok, cast(), reference()} | {error, not_found}.

remove(ServerId, ExtRequestId) ->
    case ets_take(?ETS_TABLE_QUEUE, {ServerId, ExtRequestId}) of
        [] ->
            {error, not_found};
        [{_, {Cast, TimerRef}}] ->
            {ok, Cast, TimerRef}
    end.

%% private
ets_match_take(Tid, Match) ->
    case ets:match_object(Tid, Match) of
        [] ->
            [];
        Objects ->
            ets:match_delete(Tid, Match),
            Objects
    end.

ets_new(Tid) ->
    ets:new(Tid, [
        named_table,
        public,
        {read_concurrency, true},
        {write_concurrency, true}
    ]).

-ifdef(ETS_TAKE).

ets_take(Tid, Key) ->
    ets:take(Tid, Key).

-else.

ets_take(Tid, Key) ->
    case ets:lookup(Tid, Key) of
        [] ->
            [];
        Objects ->
            ets:delete(Tid, Key),
            Objects
    end.

-endif.
