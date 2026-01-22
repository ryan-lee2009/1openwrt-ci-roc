#!/bin/bash
set -e

echo "=== IPQ6000 极限压榨版：PassWall + nikki ==="

#-------------------------------------------------
# 1. 基础信息
#-------------------------------------------------
sed -i 's/192.168.1.1/192.168.2.1/g' package/base-files/files/bin/config_generate
sed -i "s/hostname='.*'/hostname='IPQ6000'/g" package/base-files/files/bin/config_generate

#-------------------------------------------------
# 2. LuCI 固件署名
#-------------------------------------------------
sed -i "s#_('Firmware Version'), (L\.isObject(boardinfo\.release) ? boardinfo\.release\.description + ' / ' : '') + (luciversion || ''),# \
            _('Firmware Version'),\n \
            E('span', {}, [\n \
                (L.isObject(boardinfo.release)\n \
                ? boardinfo.release.description + ' / '\n \
                : '') + (luciversion || '') + ' / Built for IPQ6000'\n \
            ]),#" \
feeds/luci/modules/luci-mod-status/htdocs/luci-static/resources/view/status/include/10_system.js

#-------------------------------------------------
# 3. 移除 attendedsysupgrade
#-------------------------------------------------
sed -i "/attendedsysupgrade/d" $(find feeds/luci/collections/ -name Makefile)

#-------------------------------------------------
# 4. kexec 支持 aarch64（IPQ6000 必须）
#-------------------------------------------------
sed -i -e 's/@(armeb||arm||i386||x86_64||powerpc64||mipsel||mips)/@(armeb||arm||aarch64||i386||x86_64||powerpc64||mipsel||mips)/' \
       -e 's/@(i386||x86_64||arm)/@(i386||x86_64||arm||aarch64)/' \
package/boot/kexec-tools/Makefile

#-------------------------------------------------
# 5. 删除不需要的软件
#-------------------------------------------------
rm -rf \
feeds/luci/applications/luci-app-openclash \
feeds/luci/applications/luci-app-homeproxy \
feeds/luci/applications/luci-app-attendedsysupgrade \
feeds/packages/net/open-app-filter \
feeds/packages/net/ariang \
feeds/packages/net/frp \
feeds/packages/lang/golang

#-------------------------------------------------
# 6. nikki（官方 sing-box）
#-------------------------------------------------
git clone --depth=1 https://github.com/nikkinikki-org/luci-app-nikki package/luci-app-nikki

#-------------------------------------------------
# 7. PassWall：极限精简核心
#-------------------------------------------------

# ❌ 移除 feeds 中会被 PassWall 接管或浪费内存的核心
rm -rf feeds/packages/net/{ \
xray-core,v2ray-geodata, \
chinadns-ng,dns2socks,ipt2socks,microsocks, \
naiveproxy,shadowsocks-libev,shadowsocks-rust, \
shadowsocksr-libev,simple-obfs,tcping, \
trojan-plus,tuic-client,hysteria, \
v2ray-plugin,xray-plugin,geoview,shadow-tls \
}

# ✔ 保留 feeds 官方 sing-box（给 nikki 用）

# PassWall 核心
git clone --depth=1 https://github.com/Openwrt-Passwall/openwrt-passwall-packages package/passwall-packages

# LuCI
rm -rf feeds/luci/applications/luci-app-passwall
git clone --depth=1 https://github.com/Openwrt-Passwall/openwrt-passwall package/luci-app-passwall

# ❌ 不要 passwall2（省 20MB+）
rm -rf feeds/luci/applications/luci-app-passwall2

# 精简 chnlist
echo "baidu.com" > \
package/luci-app-passwall/luci-app-passwall/root/usr/share/passwall/rules/chnlist

#-------------------------------------------------
# 8. feeds
#-------------------------------------------------
./scripts/feeds update -a
./scripts/feeds install -a

echo "=== IPQ6000 极限压榨完成 ==="
