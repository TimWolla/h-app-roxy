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

-- http://www.lua.org/pil/20.3.html
local function unescape(s)
	s = string.gsub(s, "+", " ")
	s = string.gsub(s, "%%(%x%x)", function (h)
		return string.char(tonumber(h, 16))
	end)
	return s
end

local function decode(s)
	local cgi = {}
	for name, value in string.gmatch(s, "([^&=]+)=([^&=]+)") do
		name = unescape(name)
		value = unescape(value)
		cgi[name] = value
	end
	
	return cgi
end

local function App(applet)
	function applet:parse_body()
		if self.headers["content-type"] == nil or #self.headers["content-type"] > 1 or self.headers["content-type"][0] ~= "application/x-www-form-urlencoded" then
			return nil
		end
		
		return decode(self:receive())
	end
	
	function applet:send_error(number)
		core.Debug("Sending error: " .. number)
		self:set_status(number)
		self:start_response()
		self:send(number)
	end
	
	function applet:send_redirect(location, code)
		code = code or 303

		core.Debug("Sending redirect: " .. code)
		applet:set_status(code)
		applet:add_header("content-type", "text/html")
		applet:add_header("location", location)
		applet:start_response()
		local response = [[
<html>
	<head>
		<meta http-equiv="refresh" content="%s">
	</head>
	<body>
		<a href="%s">%s</a>
	</body>
</html>]]
		
		self:send(response:format(location, location, location))
	end
end

local function h_app_roxy(controllers)
	return function(applet)
		App(applet)

		applet:add_header("X-Powered-By", "h-app-roxy")

		local pattern_match = false
		for i, v in ipairs(controllers) do
			if applet.path:match("^" .. v["pattern"] .. "$") then
				pattern_match = true

				if applet.method == v["method"] then
					core.Debug("Found matching controller: " .. v["method"] .. " " .. v["pattern"])
					return v["controller"](applet, applet.path:match("^" .. v["pattern"] .. "$"))
				end
			end
		end

		if pattern_match then
			applet:send_error(405)
		else
			applet:send_error(404)
		end
	end
end

return h_app_roxy
