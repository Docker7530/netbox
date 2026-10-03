#!/usr/bin/env bash

# ==============================================================================
# Reality SNI 目标域名一键批量智能测速与筛选脚本
# 特性：
# 1. 一次性全量并发测试所有精选知名大厂域名（支持 TLS 1.3）
# 2. 修复原脚本在 Ubuntu 24/26/Debian/macOS 上因 date +%s%3N 导致的语法与计算错误
# 3. 强制验证 TLS 1.3 握手成功率与真实网络往返延迟 (RTT)
# 4. 自动按延迟由低到高排序，输出 Top 10 最优目标域名
# ==============================================================================

set -o pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
PLAIN='\033[0m'

# 检查基础依赖
check_dependencies() {
    if ! command -v openssl >/dev/null 2>&1; then
        echo -e "${RED}[!] 错误: 系统未安装 openssl，请先安装：${PLAIN}"
        echo "    Ubuntu/Debian: apt update && apt install -y openssl"
        echo "    CentOS/AlmaLinux: yum install -y openssl"
        exit 1
    fi
}

# 跨平台高精度毫秒计时器（彻底解决 date +%s%3N 在 Ubuntu 24/26 及 BSD/macOS 上的计算 Bug）
get_time_ms() {
    if [ -n "$EPOCHREALTIME" ]; then
        # Bash 5.0+ 内置变量（微秒级高精度，0 子进程开销）
        local s="${EPOCHREALTIME%.*}"
        local us="${EPOCHREALTIME#*.}"
        local ms="${us:0:3}"
        while [ ${#ms} -lt 3 ]; do ms="${ms}0"; done
        echo "${s}${ms}"
    elif command -v python3 >/dev/null 2>&1; then
        python3 -c "import time; print(int(time.time() * 1000))"
    else
        local n
        n=$(date +%s%N 2>/dev/null)
        if [[ "$n" =~ ^[0-9]{19}$ ]]; then
            echo "${n:0:13}"
        else
            echo "$(($(date +%s) * 1000))"
        fi
    fi
}

# 超时命令封装
run_with_timeout() {
    local sec="$1"
    shift
    if command -v timeout >/dev/null 2>&1; then
        timeout "${sec}" "$@"
    elif command -v gtimeout >/dev/null 2>&1; then
        gtimeout "${sec}" "$@"
    else
        "$@"
    fi
}

# 单个域名测试函数
test_single_domain() {
    local domain="$1"
    local timeout_sec="${2:-2}"
    local t1 t2 elapsed out ret

    t1=$(get_time_ms)

    # 强制指定 -tls1_3 并携带 SNI 握手
    out=$(run_with_timeout "${timeout_sec}" openssl s_client -connect "${domain}:443" -servername "${domain}" -tls1_3 </dev/null 2>&1)
    ret=$?

    # 校验握手返回码及是否包含 TLSv1.3 协商结果
    if [ $ret -eq 0 ] && echo "$out" | grep -q "TLSv1.3"; then
        t2=$(get_time_ms)
        elapsed=$((t2 - t1))
        if [ "$elapsed" -ge 0 ] 2>/dev/null; then
            printf "%d %s\n" "$elapsed" "$domain"
        fi
    fi
}

# 导出函数供子 shell / 并发进程调用
export -f get_time_ms run_with_timeout test_single_domain

# 候选大厂域名池（全量 107 个主流合规跨国大厂域名）
DOMAINS=(
  "amd.com" "aws.com" "c.6sc.co" "j.6sc.co" "b.6sc.co" "intel.com" "r.bing.com" "th.bing.com"
  "www.amd.com" "www.aws.com" "www.xbox.com" "www.sony.com" "rum.hlx.page" "www.bing.com"
  "www.wowt.com" "www.intel.com" "www.tesla.com" "www.xilinx.com" "www.oracle.com" "c.marsflag.com"
  "www.nvidia.com" "snap.licdn.com" "aws.amazon.com" "drivers.amd.com" "cdn.bizibly.com"
  "s.go-mpulse.net" "tags.tiqcdn.com" "cdn.bizible.com" "cdn.userway.org" "download.amd.com"
  "d1.awsstatic.com" "s0.awsstatic.com" "mscom.demdex.net" "a0.awsstatic.com" "apps.mzstatic.com"
  "sisu.xboxlive.com" "s.mp.marsflag.com" "images.nvidia.com" "vs.aws.amazon.com" "c.s-microsoft.com"
  "beacon.gtv-pub.com" "ts4.tc.mm.bing.net" "ts3.tc.mm.bing.net" "d2c.aws.amazon.com" "ts1.tc.mm.bing.net"
  "ce.mf.marsflag.com" "d0.m.awsstatic.com" "t0.m.awsstatic.com" "ts2.tc.mm.bing.net" "tag.demandbase.com"
  "assets-www.xbox.com" "logx.optimizely.com" "azure.microsoft.com" "aadcdn.msftauth.net" "d.oracleinfinity.io"
  "assets.adobedtm.com" "lpcdn.lpsnmedia.net" "res-1.cdn.office.net" "is1-ssl.mzstatic.com" "electronics.sony.com"
  "acctcdn.msftauth.net" "cdnssl.clicktale.net" "catalog.gamepass.com" "consent.trustarc.com" "gsp-ssl.ls.apple.com"
  "munchkin.marketo.net" "s.company-target.com" "cdn77.api.userway.org" "cua-chat-ui.tesla.com" "assets-xbxweb.xbox.com"
  "ds-aksb-a.akamaihd.net" "static.cloud.coveo.com" "api.company-target.com" "devblogs.microsoft.com" "s7mbrstream.scene7.com"
  "fpinit.itunes.apple.com" "digitalassets.tesla.com" "d.impactradius-event.com" "downloadmirror.intel.com"
  "iosapps.itunes.apple.com" "se-edge.itunes.apple.com" "publisher.liveperson.net" "tag-logger.demandbase.com"
  "services.digitaleast.mobi" "configuration.ls.apple.com" "gray-wowt-prod.gtv-cdn.com" "visualstudio.microsoft.com"
  "prod.log.shortbread.aws.dev" "amp-api-edge.apps.apple.com" "store-images.s-microsoft.com" "cdn-dynmedia-1.microsoft.com"
  "github.gallerycdn.vsassets.io" "prod.pa.cdn.uis.awsstatic.com" "a.b.cdn.console.awsstatic.com" "d3agakyjgjv5i8.cloudfront.net"
  "vscjava.gallerycdn.vsassets.io" "location-services-prd.tesla.com" "ms-vscode.gallerycdn.vsassets.io"
  "ms-python.gallerycdn.vsassets.io" "gray-config-prod.api.arc-cdn.net" "i7158c100-ds-aksb-a.akamaihd.net"
  "downloaddispatch.itunes.apple.com" "res.public.onecdn.static.microsoft" "gray.video-player.arcpublishing.com"
  "gray-config-prod.api.cdn.arcpublishing.com" "img-prod-cms-rt-microsoft-com.akamaized.net" "prod.us-east-1.ui.gcr-chat.marketing.aws.dev"
)

main() {
    check_dependencies

    local total=${#DOMAINS[@]}
    local parallel=16

    echo -e "${CYAN}================================================================${PLAIN}"
    echo -e "${BOLD}${GREEN}        🚀 Reality 目标域名（SNI）全量并发测速筛选工具        ${PLAIN}"
    echo -e "${CYAN}================================================================${PLAIN}"
    echo -e "${BLUE}[*] 待测试候选域名数:${PLAIN} ${BOLD}${total}${PLAIN} 个精选知名大厂域名"
    echo -e "${BLUE}[*] 并发测试线程数  :${PLAIN} ${BOLD}${parallel}${PLAIN} 线程"
    echo -e "${BLUE}[*] 协议硬性验证要求:${PLAIN} ${BOLD}TLS 1.3${PLAIN}（不符即淘汰）"
    echo -e "${YELLOW}[*] 正在全量测速中，请稍候约 2~4 秒...${PLAIN}"
    echo ""

    local tmp_dir
    tmp_dir=$(mktemp -d 2>/dev/null || mktemp -d -t 'reality')
    local result_file="${tmp_dir}/results.txt"
    trap 'command rm -r "$tmp_dir" 2>/dev/null' EXIT

    # 并发测试所有域名
    printf "%s\n" "${DOMAINS[@]}" | xargs -n 1 -P "${parallel}" -I {} bash -c 'test_single_domain "{}" 2' >> "${result_file}" 2>/dev/null

    local valid_count
    valid_count=$(wc -l < "${result_file}" | tr -d ' ')

    if [ "${valid_count}" -eq 0 ]; then
        echo -e "${RED}[!] 错误: 未检测到任何可用的 TLS 1.3 目标域名，请检查当前网络出站连接！${PLAIN}"
        exit 1
    fi

    # 排序并提取最快的前 10 个
    echo -e "${CYAN}================================================================${PLAIN}"
    echo -e "${BOLD}${GREEN}        🏆 最快的前 10 个 Reality 目标域名（按握手延迟排序）   ${PLAIN}"
    echo -e "${CYAN}================================================================${PLAIN}"
    printf "${BOLD}%-6s %-14s %-40s${PLAIN}\n" "排名" "握手延迟" "目标域名 (SNI / Dest)"
    echo -e "----------------------------------------------------------------"

    local rank=1
    sort -n "${result_file}" | head -n 10 | while read -r latency domain; do
        if [ "$rank" -eq 1 ]; then
            printf "${GREEN}%-6s %-14s %-40s${PLAIN}\n" "🥇 01" "${latency} ms" "${domain}"
        elif [ "$rank" -eq 2 ]; then
            printf "${YELLOW}%-6s %-14s %-40s${PLAIN}\n" "🥈 02" "${latency} ms" "${domain}"
        elif [ "$rank" -eq 3 ]; then
            printf "${CYAN}%-6s %-14s %-40s${PLAIN}\n" "🥉 03" "${latency} ms" "${domain}"
        else
            printf "%-6s %-14s %-40s\n" "   0${rank}" "${latency} ms" "${domain}"
        fi
        rank=$((rank + 1))
    done

    local best_domain
    best_domain=$(sort -n "${result_file}" | head -n 1 | awk '{print $2}')

    echo -e "----------------------------------------------------------------"
    echo -e "${BLUE}[i] 共完成测速:${PLAIN} ${total} 个域名 | ${GREEN}有效连通 TLS 1.3:${PLAIN} ${valid_count} 个"
    echo ""
    echo -e "${BOLD}${YELLOW}💡 面板配置推荐（直接复制填入 s-ui / Xray / sing-box）：${PLAIN}"
    echo -e "   • ${BOLD}目标网站 (Dest):${PLAIN}             ${GREEN}${best_domain}:443${PLAIN}"
    echo -e "   • ${BOLD}服务器名称 (serverNames/SNI):${PLAIN} ${GREEN}${best_domain}${PLAIN}"
    echo -e "${CYAN}================================================================${PLAIN}"
}

main "$@"
