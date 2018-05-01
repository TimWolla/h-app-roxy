-- The MIT License (MIT)
--
-- Copyright (c) 2018 Tim Düsterhus
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

local redis = require("redis-pool").new("172.17.0.2", 6379, 20)

function call_redis(method, ...)
	local conn = redis:get(1000)

	if conn == nil then
		error("Could not get connection")
	end

	local client = conn.client
	
	if not pcall(client.ping, client) then
		redis:renew(conn)
		return call_redis(method, ...)
	end

	local result = table.pack(pcall(client[method], client, ...))

	if not table.remove(result, 1) then
		redis:renew(conn)
		error("Dead connection")
	end

	redis:release(conn)

	return table.unpack(result)
end

function getRoot(app)
	app:set_status(200)
	app:add_header("content-type", "text/html")
	app:start_response()
	app:send([[
<html>
	<head>
		<title>Short URL service</title>
	</head>
	<body>
		<form action="." method="post">
			<input type="url" name="url" placeholder="URL" />
			<button type="submit">Submit</button>
		</form>
	</body>
</html>]])
end

function random_char(alphabet)
	alphabet = alphabet or "123456789abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ"
	local index = math.random(1, alphabet:len())

	return alphabet:sub(index,index)
end

function random_string(length, alphabet)
	if length <= 0 then
		return ""
	end

	return random_string(length - 1, alphabet) .. random_char(alphabet)
end

function postRoot(app)
	local variables = app:parse_body()
	if variables == nil then
		return app:send_error(415)
	elseif variables["url"] == nil then
		return app:send_error(400)
	end

	while true do
		local key = random_string(10)

		if call_redis("setnx", key, variables["url"]) then
			app:set_status(200)
			app:add_header("content-type", "text/html")
			app:start_response()
			local response = [[
<html>
	<head>
		<title>Short URL service</title>
	</head>
	<body>
		<a href="./%s">%s</a>
	</body>
</html>]]
			app:send(response:format(key, key))
			return
		end
	end
end

function getShortUrl(app, key)
	local value = call_redis("get", key)
	if value ~= nil then
		app:send_redirect(value)
	else
		app:send_error(404)
	end
end

core.register_service("shorturl", "http", require("h_app_roxy"){
	{ pattern="/",      method="GET",  controller=getRoot     },
	{ pattern="/",      method="POST", controller=postRoot    },
	{ pattern="/(%w+)", method="GET",  controller=getShortUrl }
})
