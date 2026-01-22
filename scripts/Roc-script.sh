#!/bin/bash
#===========================================
# OpenWrt 完整定制脚本（Roc 版）
#===========================================

echo "============================="
echo " OpenWrt Custom by Roc "
echo "============================="

# 构建时间变量
BUILD_DATE="$(date '+%Y-%m-%d %H:%M:%S')"
BUILD_DAY="$(date '+%Y-%m-%d')"

#===========================================
# 1️⃣ 修改默认 IP & 固件名称 & LuCI 显示编译信息
#===========================================

# 默认 IP
sed -i 's/192.168.1.1/192.168.9.3/g' package/base-files/files/bin/config_generate

# 主机名
sed -i "s/hostname='.*'/hostname='OpenWrt'/g" package/base-files/files/bin/config_generate

# LuCI 状态页显示固件版本 + 编译时间 + 署名
sed -i "s#_('Firmware Version'), (L\.isObject(boardinfo\.release) ? boardinfo\.release\.description + ' / ' : '') + (luciversion || ''),# \
            _('Firmware Version'),\n \
            E('span', {}, [\n \
                (L.isObject(boardinfo.release)\n \
                ? boardinfo.release.description + ' / '\n \
                : '') + (luciversion || '') + ' / ',\n \
            E('a', {\n \
                href: 'https://github.com/laipeng668/openwrt-ci-roc/releases',\n \
                target: '_blank',\n \
                rel: 'noopener noreferrer'\n \
                }, [ 'Built by Roc @ ${BUILD_DATE}' ])\n \
            ]),#" \
feeds/luci/modules/luci-mod-status/htdocs/luci-static/resources/view/status/include/10_system.js

# LuCI 登录页底部署名
sed -i "/<footer class='footer'>/a\\
<p style='text-align:center;'>Built by Roc</p>" \
feeds/luci/themes/luci-theme-bootstrap/htdocs/luci-static/bootstrap/view/login.htm

# 固件文件名前缀
sed -i 's/IMG_PREFIX:=openwrt/IMG_PREFIX:=OpenWrt-Roc/g' include/image.mk

# 系统版本信息（SSH / 概览页）
sed -i "s/DISTRIB_DESCRIPTION='OpenWrt '/DISTRIB_DESCRIPTION='OpenWrt-Roc | Built by Roc @ ${BUILD_DAY} '/g" \
package/base-files/files/etc/openwrt_release

# /etc/banner 自定义
cat > package/base-files/files/etc/banner <<EOF
-----------------------------------------------------
 OpenWrt-Roc
 Built by Roc
 Build Date: ${BUILD_DATE}
-----------------------------------------------------
EOF

#===========================================
# 2️⃣ 移除 lci-app-attendedsysupgrade
#===========================================
sed -i "/attendedsysupgrade/d" $(find ./feeds/luci/collections/ -type f -name "Makefile")

#===========================================
# 3️⃣ kexec 支持 aarch64
#===========================================
sed -i -e 's/@(armeb||arm||i386||x86_64||powerpc64||mipsel||mips)/@(armeb||arm||aarch64||i386||x86_64||powerpc64||mipsel||mips)/' \
    -e 's/@(i386||x86_64||arm)/@(i386||x86_64||arm||aarch64)/' package/boot/kexec-tools/Makefile

#===========================================
# 4️⃣ NSS 驱动 q6_region 内存区域预留（可自选启用）
#===========================================
# ipq6018-512m 16MB
# sed -i 's/reg = <0x0 0x4ab00000 0x0 0x[0-9a-f]\+>/reg = <0x0 0x4ab00000 0x0 0x01000000>/' target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/ipq6018-512m.dtsi
# ipq6018-512m 32MB
# sed -i 's/reg = <0x0 0x4ab00000 0x0 0x[0-9a-f]\+>/reg = <0x0 0x4ab00000 0x0 0x02000000>/' target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/ipq6018-512m.dtsi
# ipq6018-512m 64MB
# sed -i 's/reg = <0x0 0x4ab00000 0x0 0x[0-9a-f]\+>/reg = <0x0 0x4ab00000 0x0 0x04000000>/' target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/ipq6018-512m.dtsi
# ipq6018-512m 96MB
# sed -i 's/reg = <0x0 0x4ab00000 0x0 0x[0-9a-f]\+>/reg = <0x0 0x4ab00000 0x0 0x06000000>/' target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/ipq6018-512m.dtsi

#===========================================
# 5️⃣ 移除默认包（待替换）
#===========================================
rm -rf feeds/luci/applications/luci-app-argon-config
rm -rf feeds/luci/applications/luci-app-wechatpush
rm -rf feeds/luci/applications/luci-app-appfilter
rm -rf feeds/luci/applications/luci-app-frpc
rm -rf feeds/luci/applications/luci-app-frps
rm -rf feeds/luci/themes/luci-theme-argon
rm -rf feeds/packages/net/open-app-filter
rm -rf feeds/packages/net/ariang
rm -rf feeds/packages/net/frp
rm -rf feeds/packages/lang/golang

#===========================================
# 6️⃣ Git 稀疏克隆函数
#===========================================
function git_sparse_clone() {
  branch="$1" repourl="$2" && shift 2
  git clone --depth=1 -b $branch --single-branch --filter=blob:none --sparse $repourl
  repodir=$(echo $repourl | awk -F '/' '{print $(NF)}')
  cd $repodir && git sparse-checkout set $@
  mv -f $@ ../package
  cd .. && rm -rf $repodir
}

#===========================================
# 7️⃣ 拉取自定义软件包 / 主题
#===========================================
git_sparse_clone ariang https://github.com/laipeng668/packages net/ariang
git_sparse_clone frp https://github.com/laipeng668/packages net/frp
mv -f package/frp feeds/packages/net/frp
git_sparse_clone frp https://github.com/laipeng668/luci applications/luci-app-frpc applications/luci-app-frps
mv -f package/luci-app-frpc feeds/luci/applications/luci-app-frpc
mv -f package/luci-app-frps feeds/luci/applications/luci-app-frps
git_sparse_clone main https://github.com/VIKINGYFY/packages luci-app-wolplus

git clone --depth=1 https://github.com/jerrykuku/luci-theme-argon feeds/luci/themes/luci-theme-argon
git clone --depth=1 https://github.com/jerrykuku/luci-app-argon-config feeds/luci/applications/luci-app-argon-config
git clone --depth=1 https://github.com/eamonxg/luci-theme-aurora feeds/luci/themes/luci-theme-aurora
git clone --depth=1 https://github.com/eamonxg/luci-app-aurora-config feeds/luci/applications/luci-app-aurora-config
git clone --depth=1 https://github.com/sbwml/packages_lang_golang -b 25.x feeds/packages/lang/golang
git clone --depth=1 https://github.com/sbwml/luci-app-openlist2 package/openlist2
git clone --depth=1 https://github.com/gdy666/luci-app-lucky package/luci-app-lucky
git clone --depth=1 https://github.com/tty228/luci-app-wechatpush package/luci-app-wechatpush
git clone --depth=1 https://github.com/destan19/OpenAppFilter.git package/OpenAppFilter
git clone --depth=1 https://github.com/lwb1978/openwrt-gecoosac package/openwrt-gecoosac
git clone --depth=1 https://github.com/NONGFAH/luci-app-athena-led package/luci-app-athena-led
chmod +x package/luci-app-athena-led/root/etc/init.d/athena_led package/luci-app-athena-led/root/usr/sbin/athena-led

#===========================================
# 8️⃣ PassWall & OpenClash
#===========================================
# 移除 OpenWrt Feeds 自带核心库
rm -rf feeds/packages/net/{xray-core,v2ray-geodata,sing-box,chinadns-ng,dns2socks,hysteria,ipt2socks,microsocks,naiveproxy,shadowsocks-libev,shadowsocks-rust,shadowsocksr-libev,simple-obfs,tcping,trojan-plus,tuic-client,v2ray-plugin,xray-plugin,geoview,shadow-tls}

git clone --depth=1 https://github.com/Openwrt-Passwall/openwrt-passwall-packages package/passwall-packages

# 移除旧 LuCI 版本
rm -rf feeds/luci/applications/luci-app-passwall
rm -rf feeds/luci/applications/luci-app-openclash

git clone --depth=1 https://github.com/Openwrt-Passwall/openwrt-passwall package/luci-app-passwall
git clone --depth=1 https://github.com/Openwrt-Passwall/openwrt-passwall2 package/luci-app-passwall2
git clone --depth=1 https://github.com/vernesong/OpenClash package/luci-app-openclash

# 清理 PassWall 的 chnlist 规则文件
echo "baidu.com"  > package/luci-app-passwall/luci-app-passwall/root/usr/share/passwall/rules/chnlist

#===========================================
# 9️⃣ 更新 feeds 并安装
#===========================================
./scripts/feeds update -a
./scripts/feeds install -a

echo "========================================="
echo " OpenWrt 定制脚本执行完成 ✔"
echo "========================================="
