h-app-roxy
==========

Installing the dependencies
---------------------------

- Save Thierry Fournier’s `fifo.lua` into your Lua search path. You can
  find the source on his blog: http://blog.arpalert.org/2018/02/haproxy-lua-fifo-and-asynchronous.html
- Save Thierry Fournier’s `redis-pool.lua` into your Lua Search path. You
  can find the source on his blog: http://blog.arpalert.org/2018/02/haproxy-lua-redis-connection-pool.html
- Replace `r.release(conn)` with `r:release(conn)` in `redis-pool.lua`.
- Install `lua-redis`. On Ubuntu Xenial I had to symlink the script manually
  in the Lua 5.3 library path, it was installed for Lua 5.1 / 5.2 only. Bug report
  is here: https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=898013

Installing h-app-roxy
---------------------

- Put the `h_app_roxy.lua` script into your Lua search path.

Using h-app-roxy
----------------

```
core.register_service("shorturl", "http", require("h_app_roxy"){
	# Routes go here
})
```

Check out `shorturl.lua` for an example application.

Disclaimer
----------

This project is intended as a joke to explore the abilities of haproxy’s
Lua API. It is slippery when wet, do not use this at home. Definitely
do not use this at work. If it breaks you get to keep both pieces.
