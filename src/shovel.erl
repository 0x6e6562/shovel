% ---------------------------------------------------------------------------
%   Copyright (C) 2008 0x6e6562
%
%   Licensed under the Apache License, Version 2.0 (the "License");
%   you may not use this file except in compliance with the License.
%   You may obtain a copy of the License at
%
%       http://www.apache.org/licenses/LICENSE-2.0
%
%   Unless required by applicable law or agreed to in writing, software
%   distributed under the License is distributed on an "AS IS" BASIS,
%   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%   See the License for the specific language governing permissions and
%   limitations under the License.
% ---------------------------------------------------------------------------

-module(shovel).

-include("shovel.hrl").
-include_lib("rabbitmq_server/include/rabbit_framing.hrl").
-include_lib("rabbitmq_server/include/rabbit.hrl").

-behaviour(gen_server).

-export([start/0,stop/0]).
-export([start_link/0]).
-export([init/1, terminate/2, code_change/3, handle_call/3, handle_cast/2, handle_info/2]).

%---------------------------------------------------------------------------
% Exported API
%---------------------------------------------------------------------------

start() ->
    application:start(shovel).
stop() ->
    application:stop(shovel).

start_link() -> 
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).
    
%---------------------------------------------------------------------------
% gen_server callbacks
%---------------------------------------------------------------------------

init(Args) ->
    RemoteHost = "1.2.3.4",
    LocalX = <<"shovel_exchange">>,
    RemoteX = <<"shovel_foreign_exchange">>,
    RoutingKey = <<"k">>,
    BindKey = <<"shovel">>,
    Realm = <<"/data">>,
    Q = <<"shovel_queue">>,

    LocalConnection = lib_petstore:start_connection(),
    {LocalChannel,LocalTicket} = lib_petstore:start_channel(LocalConnection),
    lib_petstore:bind_queue(LocalChannel, LocalTicket, Q, LocalX, BindKey),
    lib_petstore:subscribe(LocalChannel,LocalTicket,Q,self()),

    RemoteConnection = lib_petstore:start_connection(RemoteHost),
    {RemoteChannel,RemoteTicket} = lib_petstore:start_channel(RemoteConnection),
    lib_petstore:declare_exchange(RemoteChannel, RemoteTicket, RemoteX),

    LocalState = #broker_state{connection = LocalConnection,
                               channel = LocalChannel,
                               ticket = LocalTicket},
    RemoteState = #broker_state{connection = RemoteConnection,
                                channel = RemoteChannel,
                                ticket = RemoteTicket},
    State = #shovel_state{local = LocalState,
                          remote = RemoteState,
                          exchange = RemoteX,
                          routing_key = RoutingKey},
    {ok, State}.

terminate(Reason, State) ->
    ok.

handle_call(Msg,From,State) ->
    {noreply,State}.

handle_cast(Msg, State) ->
    {noreply, State}.

handle_info(#'basic.consume_ok'{consumer_tag = ConsumerTag}, State) ->
    {noreply, State};

handle_info(#'basic.cancel_ok'{consumer_tag = ConsumerTag}, State) ->
    {noreply, State};

handle_info({#'basic.deliver'{consumer_tag = ConsumerTag},
             #content{class_id = ClassId,
                      properties_bin = Properties, 
                      payload_fragments_rev = [Payload]}},
             State = #shovel_state{remote = #broker_state{channel = Channel, 
                                                          ticket = Ticket},
                                   exchange = X,
                                   routing_key = RoutingKey}) ->
    
    lib_shovel:forward(Channel,Ticket,X,RoutingKey,Payload),
    {noreply, State}.

code_change(_OldVsn, State, _Extra) ->
    State.
    