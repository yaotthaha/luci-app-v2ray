-- Copyright 2019-2020 Xingwang Liao <kuoruan@gmail.com>
-- Licensed to the public under the MIT License.

local uci = require "luci.model.uci".cursor()
local util = require "luci.util"
local fs = require "nixio.fs"

local config_file = uci:get("xray", "main", "config_file")

if not config_file or util.trim(config_file) == "" then
	config_file = "/var/etc/xray/xray.main.json"
end

local config_content = fs.readfile(config_file) or translate("Failed to open file.")

local m

m = SimpleForm("xray", "%s - %s" % { translate("Xray"), translate("About") },
	"<p>%s</p><p>%s</p><p>%s</p><p>%s</p><p>%s</p><p>%s</p><p>%s</p><p>%s</p>" % {
		translate("LuCI support for Xray."),
		translatef("Author: %s", "Xingwang Liao"),
		translatef(
			"Source: %s",
			"<a href=\"https://github.com/kuoruan/luci-app-xray\" target=\"_blank\">https://github.com/kuoruan/luci-app-xray</a>"
		),
		translatef(
			"Latest: %s",
			"<a href=\"https://github.com/kuoruan/luci-app-xray/releases/latest\" target=\"_blank\">https://github.com/kuoruan/luci-app-xray/releases/latest</a>"
		),
		translatef(
			"Report Bugs: %s",
			"<a href=\"https://github.com/kuoruan/luci-app-xray/issues\" target=\"_blank\">https://github.com/kuoruan/luci-app-xray/issues</a>"
		),
		translatef(
			"Donate: %s",
			"<a href=\"https://blog.kuoruan.com/donate\" target=\"_blank\">https://blog.kuoruan.com/donate</a>"
		),
		translatef("Current Config File: %s", config_file),
		"<pre style=\"-moz-tab-size: 4;-o-tab-size: 4;tab-size: 4;word-break: break-all;\">%s</pre>" % config_content,
	})

m.reset = false
m.submit = false

return m
