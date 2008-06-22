-module(producer).

-export([start/4]).

start(Host,X,RoutingKey,N) ->
    Connection = lib_shovel:start_connection(Host),
    {Channel,Ticket} = lib_shovel:start_channel(Connection),
    lib_shovel:declare_exchange(Channel, Ticket, X),
    loop(Channel,Ticket,X,RoutingKey,N),
    lib_shovel:teardown(Connection,Channel),
    ok.

loop(_,_,_,_,0) -> ok;
loop(Channel,Ticket,X,RoutingKey,N) ->
    Payload = random_payload(),
    lib_shovel:publish(Channel,Ticket,X,RoutingKey,Payload),
    loop(Channel,Ticket,X,RoutingKey,N-1).
    
random_payload() ->
    {A,B,C} = now(),
    <<A:32,B:32,C:32>>.
