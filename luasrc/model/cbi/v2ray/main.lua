-- Copyright 2019-2020 Xingwang Liao <kuoruan@gmail.com>
-- Licensed to the public under the MIT License.

local uci = require "luci.model.uci".cursor()
local util = require "luci.util"
local sys = require "luci.sys"
local json = require "luci.jsonc"
local xray = require "luci.model.xray"

local m, s, o

local inbound_keys, inbound_table, outbound_keys, outbound_table = {}, {}, {}, {}

uci:foreach("xray", "inbound", function(s)
	if s.alias then
		local key = s[".name"]
		util.append(inbound_keys, key)
		inbound_table[key] = s.alias
	end
end)

uci:foreach("xray", "outbound", function(s)
	if s.alias then
		local key = s[".name"]
		util.append(outbound_keys, key)
		outbound_table[key] = s.alias
	end
end)

m = Map("xray", "%s - %s" % { translate("Xray"), translate("Global Settings") },
"<p>%s</p><p>%s</p>" % {
	translate("A platform for building proxies to bypass network restrictions."),
	translatef("For more information, please visit: %s",
		"<a href=\"https://www.xray.com\" target=\"_blank\">https://www.xray.com</a>")
})
m:append(Template("xray/status_header"))

s = m:section(NamedSection, "main", "xray")
s.addremove = false
s.anonymos = true

o = s:option(Flag, "enabled", translate("Enabled"))
o.rmempty = false

o = s:option(Button, "_reload", translate("Reload Service"), translate("This will restart service when config file changes."))
o.inputstyle = "reload"
o.write = function ()
	sys.call("/etc/init.d/xray reload 2>/dev/null")
end

o = s:option(Value, "xray_file", translate("Xray file"), "<em>%s</em>" % translate("Collecting data..."))
o.datatype = "file"
o.placeholder = "/usr/bin/xray"
o.rmempty = false

o = s:option(Value, "asset_location", translate("Xray asset location"),
	translate("Directory where geoip.dat and geosite.dat files are, default: same directory as Xray file."))
o.datatype = "directory"
o.placeholder = "/usr/bin"

o = s:option(Value, "mem_percentage", translate("Memory percentage"),
	translate("The maximum percentage of memory used by Xray."))
o.datatype = "and(uinteger, max(100))"
o.placeholder = "80"

o = s:option(Value, "config_file", translate("Config file"),
	translate("Use custom config file."))
o.datatype = "file"
o:value("", translate("None"))

o = s:option(Value, "access_log", translate("Access log file"))
o:depends("config_file", "")
o:value("/dev/null")
o:value("/var/log/xray-access.log")

o = s:option(ListValue, "loglevel", translate("Log level"))
o:depends("config_file", "")
o:value("debug", translate("Debug"))
o:value("info", translate("Info"))
o:value("warning", translate("Warning"))
o:value("error", translate("Error"))
o:value("none", translate("None"))
o.default = "warning"

o = s:option(Value, "error_log", translate("Error log file"))
o:value("/dev/null")
o:value("/var/log/xray-error.log")
o:depends("loglevel", "debug")
o:depends("loglevel", "info")
o:depends("loglevel", "warning")
o:depends("loglevel", "error")

o = s:option(MultiValue, "inbounds", translate("Inbounds enabled"))
o:depends("config_file", "")
for _, v in ipairs(inbound_keys) do
	o:value(v, inbound_table[v])
end

o = s:option(MultiValue, "outbounds", translate("Outbounds enabled"))
o:depends("config_file", "")
for _, v in ipairs(outbound_keys) do
	o:value(v, outbound_table[v])
end

o = s:option(Flag, "stats_enabled", "%s - %s" % { translate("Stats"), translate("Enabled") })
o:depends("config_file", "")

o = s:option(Flag, "transport_enabled", "%s - %s" % { translate("Transport"), translate("Enabled") })
o:depends("config_file", "")

o = s:option(TextValue, "_transport", "%s - %s" % { translate("Transport"), translate("Settings") },
	translate("<code>transport</code> field in top level configuration, JSON string"))
o:depends("transport_enabled", "1")
o.wrap = "off"
o.rows = 5
o.datatype = "string"
o.filepath = "/etc/xray/transport.json"
o.validate = function(self, value, section)
	if not value or value == "" then
		return nil, translate("Transport settings is required.")
	end

	if not json.parse(value) then
		return nil, translate("Invalid JSON content.")
	end
	return value, nil
end
o.cfgvalue = xray.textarea_cfgvalue
o.write = xray.textarea_write
o.remove = xray.textarea_remove

return m
