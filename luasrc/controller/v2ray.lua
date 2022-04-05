-- Copyright 2019-2020 Xingwang Liao <kuoruan@gmail.com>
-- Licensed to the public under the MIT License.

local http = require "luci.http"
local uci = require "luci.model.uci".cursor()
local sys = require "luci.sys"
local fs = require "nixio.fs"
local xray = require "luci.model.xray"
local i18n = require "luci.i18n"
local util = require "luci.util"

module("luci.controller.xray", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/xray") then
		return
	end

	entry({"admin", "services", "xray"},
		firstchild(), _("Xray")).dependent = false

	entry({"admin", "services", "xray", "global"},
		cbi("xray/main"), _("Global Settings"), 1)

	entry({"admin", "services", "xray", "inbounds"},
		arcombine(cbi("xray/inbound-list"), cbi("xray/inbound-detail")),
		_("Inbound"), 2).leaf = true

	entry({"admin", "services", "xray", "outbounds"},
		arcombine(cbi("xray/outbound-list"), cbi("xray/outbound-detail")),
		_("Outbound"), 3).leaf = true

	entry({"admin", "services", "xray", "dns"},
		cbi("xray/dns"), _("DNS"), 4)

	entry({"admin", "services", "xray", "routing"},
		arcombine(cbi("xray/routing"), cbi("xray/routing-rule-detail")),
		_("Routing"), 5)

	entry({"admin", "services", "xray", "policy"},
		arcombine(cbi("xray/policy"), cbi("xray/policy-level-detail")),
		_("Policy"), 6)

	entry({"admin", "services", "xray", "reverse"},
		cbi("xray/reverse"), _("Reverse"), 7)

	entry({"admin", "services", "xray", "transparent-proxy"},
		cbi("xray/transparent-proxy"), _("Transparent Proxy"), 8)

	entry({"admin", "services", "xray", "about"},
		form("xray/about"), _("About"), 9)

	entry({"admin", "services", "xray", "routing", "rules"},
		cbi("xray/routing-rule-detail")).leaf = true

	entry({"admin", "services", "xray", "policy", "levels"},
		cbi("xray/policy-level-detail")).leaf = true

	entry({"admin", "services", "xray", "status"}, call("action_status"))

	entry({"admin", "services", "xray", "version"}, call("action_version"))

	entry({"admin", "services", "xray", "list-status"},
		call("list_status")).leaf = true

	entry({"admin", "services", "xray", "list-update"}, call("list_update"))

	entry({"admin", "services", "xray", "import-outbound"}, call("import_outbound"))
end

function action_status()
	local running = false

	local pid = util.trim(fs.readfile("/var/run/xray.main.pid") or "")

	if pid ~= "" then
		local file = uci:get("xray", "main", "xray_file") or ""
		if file ~= "" then
			local file_name = fs.basename(file)
			running = sys.call("pidof %s 2>/dev/null | grep -q %s" % { file_name, pid }) == 0
		end
	end

	http.prepare_content("application/json")
	http.write_json({
		running = running
	})
end

function action_version()
	local file = uci:get("xray", "main", "xray_file") or ""

	local info

	if file == "" or not fs.stat(file) then
		info = {
			valid = false,
			message = i18n.translate("Invalid Xray file")
		}
	else
		if not fs.access(file, "rwx", "rx", "rx") then
			fs.chmod(file, 755)
		end

		local version = util.trim(sys.exec("%s --version 2>/dev/null | head -n1" % file))

		if version ~= "" then
			info = {
				valid = true,
				version = version
			}
		else
			info = {
				valid = false,
				message = i18n.translate("Can't get Xray version")
			}
		end
	end

	http.prepare_content("application/json")
	http.write_json(info)
end

function list_status(type)
	if type == "chnroute" then
		http.prepare_content("application/json")
		http.write_json(xray.get_routelist_status())
	elseif type == "gfwlist" then
		http.prepare_content("application/json")
		http.write_json(xray.get_gfwlist_status())
	else
		http.status(500, "Bad address")
	end
end

function list_update()
	local type = http.formvalue("type")

	if type == "chnroute" then
		local chnroute_result, chnroute6_result = xray.generate_routelist()
		http.prepare_content("application/json")
		http.write_json({
			chnroute = chnroute_result,
			chnroute6 = chnroute6_result
		})
	elseif type == "gfwlist" then
		local result = xray.generate_gfwlist()
		http.prepare_content("application/json")
		http.write_json({
			gfwlist = result
		})
	else
		http.status(500, "Bad address")
	end
end

function import_outbound()
	local link = http.formvalue("link")

	local objs = xray.parse_vmess_links(link or "")

	if not objs or #objs == 0 then
		http.prepare_content("application/json")
		http.write_json({
			success = false,
			message = i18n.translate("Invalid link")
		})
		return
	end

	for i=1, #objs do
		local obj = objs[i]

		if not obj or not next(obj) then
			http.prepare_content("application/json")
			http.write_json({
				success = false,
				message = i18n.translate("Invalid link")
			})
			return
		end

		local ver = obj["v"]
		if ver ~= "2" then
			http.prepare_content("application/json")
			http.write_json({
				success = false,
				message = i18n.translate("Unsupported link version")
			})
			return
		end
	end

	for i=1, #objs do
		local obj = objs[i]
		local section_name = uci:add("xray", "outbound")

		if not section_name then
			http.prepare_content("application/json")
			http.write_json({
				success = false,
				message = i18n.translate("Failed to create new section")
			})
			return
		end

		local address = obj["add"] or "0.0.0.0"
		local port = obj["port"] or "0"
		local tls = obj["tls"] or ""

		local alias = obj["ps"] or string.format("%s:%s", address, port)

		uci:set("xray", section_name, "alias", alias)
		uci:set("xray", section_name, "protocol", "vmess")
		uci:set("xray", section_name, "s_vmess_address", address)
		uci:set("xray", section_name, "s_vmess_port", port)
		uci:set("xray", section_name, "s_vmess_user_id", obj["id"] or "")
		uci:set("xray", section_name, "s_vmess_user_alter_id", obj["aid"] or "")
		uci:set("xray", section_name, "ss_security", tls)

		local network = obj["net"] or ""
		local header_type = obj["type"] or ""
		local path = obj["path"] or ""

		local hosts = { }

		for h in string.gmatch(obj["host"] or "", "([^,%s]+),?") do
			hosts[#hosts+1] = h
		end

		if network == "tcp" then
			uci:set("xray", section_name, "ss_network", "tcp")

			uci:set("xray", section_name, "ss_tcp_header_type", header_type)

			if header_type == "http" and next(hosts) then
				local host_header = string.format("Host=%s", hosts[1])
				uci:set_list("xray", section_name, "ss_tcp_header_request_headers", host_header)

				if tls == "tls" then
					uci:set("xray", section_name, "ss_tls_server_name", hosts[1])
				end
			end
		elseif network == "kcp" or network == "mkcp" then
			uci:set("xray", section_name, "ss_network", "kcp")
			uci:set("xray", section_name, "ss_kcp_header_type", header_type)
		elseif network == "ws" then
			uci:set("xray", section_name, "ss_network", "ws")
			uci:set("xray", section_name, "ss_websocket_path", path)

			if next(hosts) then
				local host_header = string.format("Host=%s", hosts[1])
				uci:set_list("xray", section_name, "ss_websocket_headers", host_header)

				if tls == "tls" then
					uci:set("xray", section_name, "ss_tls_server_name", hosts[1])
				end
			end
		elseif network == "http" or network == "h2" then
			uci:set("xray", section_name, "ss_network", "http")
			uci:set("xray", section_name, "ss_http_path", path)

			if next(hosts) then
				uci:set_list("xray", section_name, "ss_http_host", hosts)
				uci:set("xray", section_name, "ss_tls_server_name", hosts[1])
			end
		elseif network == "quic" then
			uci:set("xray", section_name, "ss_network", "quic")
			uci:set("xray", section_name, "ss_quic_header_type", header_type)
			uci:set("xray", section_name, "ss_quic_key", path)

			if next(hosts) then
				uci:set("xray", section_name, "ss_quic_security", hosts[1])

				if tls == "tls" then
					uci:set("xray", section_name, "ss_tls_server_name", hosts[1])
				end
			end
		end
	end

	local success = uci:save("xray")

	if not success then
		http.prepare_content("application/json")
		http.write_json({
			success = false,
			message = i18n.translate("Failed to save section")
		})
		return
	end

	http.prepare_content("application/json")
	http.write_json({
		success = true
	})
end
