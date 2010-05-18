%% Riak EnterpriseDS
%% Copyright (c) 2007-2010 Basho Technologies, Inc.  All Rights Reserved.
-module(riak_repl_leader).
-author('Andy Gross <andy@basho.com>').
-behaviour(gen_leader).
-export([start_link/0,init/1,elected/3,surrendered/3,handle_leader_call/4, 
         handle_leader_cast/3, from_leader/3, handle_call/4,
         handle_cast/3, handle_DOWN/3, handle_info/2, terminate/2,
         code_change/4]).
-export([get_state/0, 
         add_receiver_pid/1,
         postcommit/1,
         leader_node/0]).

-define(LEADER_OPTS, [{vardir, VarDir}, {bcast_type, all}]).

-record(state, {
          is_leader :: boolean(),
          receivers=[] :: list(),
          leader_node=undefined :: atom()}).

start_link() ->
    process_flag(trap_exit, true),
    {ok, Ring} = riak_core_ring_manager:get_my_ring(),
    Candidates = riak_core_ring:all_members(Ring),
    {ok, DataRootDir} = application:get_env(riak_repl, data_root),
    VarDir = filename:join(DataRootDir, "leader"),
    ok = filelib:ensure_dir(filename:join(VarDir, ".empty")),
    [net_adm:ping(C) || C <- Candidates],
    gen_leader:start_link(?MODULE, Candidates,?LEADER_OPTS,?MODULE, [], []).

init([]) ->
    riak_repl:install_hook(),
    {ok, #state{is_leader=false}}.

leader_node() ->
    gen_leader:call(?MODULE, leader_node).

postcommit(Object) ->
    gen_leader:leader_cast(?MODULE, {repl, Object}).

get_state() ->
    gen_leader:call(?MODULE, get_state).

add_receiver_pid(Pid) when is_pid(Pid) ->
    gen_leader:leader_call(?MODULE, {add_receiver_pid, Pid}).

elected(State, _NewElection, _Node) ->
    error_logger:info_msg("Elected as replication leader~n"),
    {ok, {i_am_leader, node()}, State#state{is_leader=true, 
                                            leader_node=node()}}.

surrendered(State, {i_am_leader, Node}, _NewElection) ->
    error_logger:info_msg("Replication leadership surrendered to ~p~n", [Node]),
    {ok, State#state{is_leader=false, leader_node=Node}}.

handle_leader_call({add_receiver_pid, Pid}, _From, 
                   State=#state{receivers=R}, _E) ->
    case lists:member(Pid, R) of
        true ->
            {reply, ok, State};
        false ->
            {reply, ok, State#state{receivers=[Pid|R]}}
    end.

handle_leader_cast({repl, Msg}, State, _Election) ->
    [P ! {repl, Msg} || P <- State#state.receivers],
    {noreply, State}.

from_leader({i_am_leader, Node}, State, _NewElection) ->
    {ok, State#state{leader_node=Node}};
from_leader(Command, State, _NewElection) ->
    error_logger:info_msg("from_leader: ~p~n", [Command]),
    {ok, State}.

handle_call(get_state, _From, State, _E) -> {reply, State, State};
handle_call(leader_node, _From, State, _E) ->
    {reply, State#state.leader_node, State}.
handle_cast(_Message, State, _E) -> {noreply, State}.

handle_DOWN(_Node, State, _Election) ->
    {ok, State}.
handle_info(_Info, State) ->
    io:format("got other info: ~p~n", [_Info]),
    {noreply, State}.

terminate(_Reason, _State) -> ok.
code_change(_OldVsn, State, _Election, _Extra) -> {ok, State}.

  