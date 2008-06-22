{application, shovel,
 [{description, "Shovel AMQP Relay"},
  {id, "Shovel"},
  {vsn, "0.1"},
  {modules, [
            shovel_supervisor,
            shovel_application,
            shovel,
            lib_shovel
             ]},
  {registered, [shovel,shovel_supervisor]},
  {applications, [kernel,stdlib,rabbit]},
  {mod, {shovel_application, []} }
 ]
}.