# luci-app-xray

Luci support for Xray

[![Release Version](https://img.shields.io/github/release/kuoruan/luci-app-xray.svg)](https://github.com/kuoruan/luci-app-xray/releases/latest) [![Latest Release Download](https://img.shields.io/github/downloads/kuoruan/luci-app-xray/latest/total.svg)](https://github.com/kuoruan/luci-app-xray/releases/latest) [![Total Download](https://img.shields.io/github/downloads/kuoruan/luci-app-xray/total.svg)](https://github.com/kuoruan/luci-app-xray/releases)

## Install

### Install via OPKG (recommend)

1. Add new opkg key:

```sh
wget -O kuoruan-public.key http://openwrt.kuoruan.net/packages/public.key
opkg-key add kuoruan-public.key
```

2. Add opkg repository from kuoruan:

```sh
echo "src/gz kuoruan_universal http://openwrt.kuoruan.net/packages/releases/all" \
  >> /etc/opkg/customfeeds.conf
opkg update
```

3. Install package:

```sh
opkg install luci-app-xray
opkg install luci-i18n-xray-zh-cn
```

We also support HTTPS protocol.

4. Upgrade package:

```sh
opkg update
opkg upgrade luci-app-xray
opkg upgrade luci-i18n-xray-zh-cn
```

### Manual install

1. Download ipk files from [release](https://github.com/kuoruan/luci-app-xray/releases) page

2. Upload files to your router

3. Install package with opkg:

```sh
opkg install luci-app-xray_*.ipk
```

Depends:

- jshn
- luci-lib-jsonc
- ip (ip-tiny or ip-full)
- ipset
- iptables
- iptables-mod-tproxy
- resolveip
- dnsmasq-full (dnsmasq ipset is required)
- luci-compat (for OpenWrt 19.07 and later)

For translations, please install ```luci-i18n-xray-*```.

> You may need to remove ```dnsmasq``` before installing this package.

## Configure

1. Download Xray file from Xray release [link](https://github.com/xray/xray-core/releases) or Xray ipk release [link](https://github.com/kuoruan/openwrt-xray/releases).

2. Upload Xray file to your router, or install the ipk file.

3. Config Xray file path in LuCI page.

4. Add your inbound and outbound rules.

5. Enable the service via LuCI.
