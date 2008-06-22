-module(consumer).

-include_lib("rabbitmq_server/include/rabbit.hrl").
-include_lib("rabbitmq_server/include/rabbit_framing.hrl").

-export([start/4]).
-export([stop/2]).
-export([consumer_loop/4]).

start(Host,X,Q,BindKey) ->
    Connection = lib_shovel:start_connection(Host),
    {Channel,Ticket} = lib_shovel:start_channel(Connection),
    lib_shovel:bind_queue(Channel,Ticket,Q,X,BindKey),
    Consumer = spawn(?MODULE, consumer_loop,[Connection,Channel,Ticket,Q]),
    lib_shovel:subscribe(Channel,Ticket,Q, Consumer),
    Channel.

stop(Channel,ConsumerTag) ->
    lib_shovel:unsubscribe(Channel,ConsumerTag).

consumer_loop(Con,Channel,Ticket,Q) ->
    receive
        #'basic.consume_ok'{consumer_tag = ConsumerTag} ->
            io:format("Subscribed: ~p~n",[ConsumerTag]), 
            consumer_loop(Con, Channel,Ticket,Q);
        #'basic.cancel_ok'{consumer_tag = ConsumerTag} ->
            io:format("Rec'd Cancel: ~p~n",[ConsumerTag]),
            lib_shovel:delete_queue(Channel,Ticket,Q),
            lib_shovel:teardown(Con,Channel),
            ok;
        {#'basic.deliver'{consumer_tag = ConsumerTag},
        {content, ClassId, Properties, PropertiesBin, Payload}} ->
            io:format("Rec'd msg: ~p~n",[Payload]),            
            consumer_loop(Con,Channel,Ticket,Q)
    end.