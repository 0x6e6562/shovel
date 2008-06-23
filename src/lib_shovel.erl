-module(lib_shovel).

-include_lib("rabbitmq_server/include/rabbit.hrl").
-include_lib("rabbitmq_server/include/rabbit_framing.hrl").

-compile(export_all).

start_connection() ->
    amqp_connection:start("guest", "guest").

start_connection(Host) ->
    amqp_connection:start("guest", "guest", Host).    

start_channel(Connection) ->
    Realm = <<"/data">>,
    Channel = amqp_connection:open_channel(Connection),
    Access = #'access.request'{realm = Realm,
                               exclusive = false,
                               passive = true,
                               active = true,
                               write = true,
                               read = true},
    #'access.request_ok'{ticket = Ticket} = amqp_channel:call(Channel, Access),
    {Channel,Ticket}.    

bind_queue(Channel, Ticket, Q, X, BindKey) ->
    QueueDeclare = #'queue.declare'{ticket = Ticket, queue = Q,
                                    passive = false, durable = false,
                                    exclusive = false, auto_delete = false,
                                    nowait = false, arguments = []},
    amqp_channel:call(Channel, QueueDeclare),
    declare_exchange(Channel,Ticket,X),
    QueueBind = #'queue.bind'{ticket = Ticket, queue = Q, exchange = X,
                              routing_key = BindKey, nowait = false, arguments = []},
    amqp_channel:call(Channel, QueueBind),
    ok.
    
delete_queue(Channel,Ticket,Q) ->
    QueueDelete = #'queue.delete'{ticket = Ticket, queue = Q,
                                  if_unused = false,
                                  if_empty = false,
                                  nowait = true},
    #'queue.delete_ok'{} = amqp_channel:call(Channel, QueueDelete).    
    
declare_exchange(Channel,Ticket,X) ->
    ExchangeDeclare = #'exchange.declare'{ticket = Ticket, exchange = X,
                                          type = <<"direct">>,
                                          passive = false, durable = false, 
                                          auto_delete = false, internal = false,
                                          nowait = false, arguments = []},
    amqp_channel:call(Channel, ExchangeDeclare).

subscribe(Channel,Ticket,Q,Consumer) ->
    BasicConsume = #'basic.consume'{ticket = Ticket, queue = Q,
                                    no_local = false, no_ack = true,
                                    exclusive = false, nowait = false},
    amqp_channel:call(Channel,BasicConsume, Consumer).

unsubscribe(Channel,Tag) ->
    BasicCancel = #'basic.cancel'{consumer_tag = Tag, nowait = false},
    #'basic.cancel_ok'{consumer_tag = ConsumerTag} = amqp_channel:call(Channel,BasicCancel),
    ok.    

publish(Channel,Ticket,X,RoutingKey,Payload) ->
    BasicPublish = #'basic.publish'{ticket = Ticket,
                                    exchange = X,
                                    routing_key = RoutingKey,
                                    mandatory = false,immediate = false},
    %ReplyProps = #'P_basic'{correlation_id = CorrelationId},
    Content = #content{class_id = 60, %% TODO HARDCODED VALUE
                       properties = amqp_util:basic_properties(), 
                       properties_bin = none,
                       payload_fragments_rev = [Payload]},
    amqp_channel:cast(Channel, BasicPublish, Content).

teardown(Connection,Channel) ->
    ChannelClose = #'channel.close'{reply_code = 200, reply_text = <<"Goodbye">>,
                                    class_id = 0, method_id = 0},
    amqp_channel:call(Channel, ChannelClose),
    ConnectionClose = #'connection.close'{reply_code = 200, reply_text = <<"Goodbye">>,
                                              class_id = 0, method_id = 0},
    amqp_connection:close(Connection, ConnectionClose).
