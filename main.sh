#!/bin/bash
set -e
red='\033[0;31m'
green='\033[0;32m'
blue='\033[0;34m'
yellow='\033[0;33m'
plain='\033[0m'
X_Panel_last_version=$(curl -Ls "https://api.github.com/repos/xeefei/x-panel/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
baidupcs_go_last_version=$(curl -Ls "https://api.github.com/repos/qjfoidnh/BaiduPCS-Go/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
#########################################################必要软件###############################################################
# check root
[[ $EUID -ne 0 ]] && echo -e "${red}致命错误: ${plain} 请使用 root 权限运行此脚本\n" && exit 1

# Check OS and set release variable
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    release=$ID
elif [[ -f /usr/lib/os-release ]]; then
    source /usr/lib/os-release
    release=$ID
else
    echo -e "${red}检查服务器操作系统失败，请联系作者!${plain}" >&2
    exit 1
fi

echo -e "——————————————————————"
echo -e "当前服务器的操作系统为:${red} $release${plain}"
echo ""

if [[ -f /etc/os-release ]]; then
    os_version=$(grep -i version_id /etc/os-release | cut -d \" -f2 | cut -d . -f1)
else
    echo -e "${red}无法获取系统版本信息${plain}" >&2
    exit 1
fi

if [[ "${release}" == "centos" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red} 请使用 CentOS 8 或更高版本 ${plain}\n" && exit 1
    fi
elif [[ "${release}" == "ubuntu" ]]; then
    if [[ ${os_version} -lt 20 ]]; then
        echo -e "${red} 请使用 Ubuntu 20 或更高版本!${plain}\n" && exit 1
    fi
elif [[ "${release}" == "debian" ]]; then
    if [[ ${os_version} -lt 11 ]]; then
        echo -e "${red} 请使用 Debian 11 或更高版本 ${plain}\n" && exit 1
    fi
else
    echo -e "${red}此脚本不支持您的操作系统。${plain}\n"
    echo -e "${red}请确保您使用的是以下受支持的操作系统之一："
    echo "- Ubuntu 20.04+"
    echo "- Debian 11+"
    echo "- CentOS 8+"
    exit 1

fi

echo -e "${green}系统检查通过，开始安装必要的软件包... ${plain}"
# 根据系统类型安装软件包
if [[ "${release}" == "ubuntu" || "${release}" == "debian" ]]; then
    echo -e "${green}使用 apt 包管理器安装软件包... ${plain}"
    apt update -y
    apt install -y curl unzip socat  git build-essential
elif [[ "${release}" == "centos" ]]; then
    if command -v dnf &> /dev/null; then
        echo -e "${green}使用 dnf 包管理器安装软件包... ${plain}"
        dnf update -y
        dnf install -y epel-release
        dnf install -y curl unzip socat git build-essential
    else
        echo -e "${green}使用 yum 包管理器安装软件包... ${plain}"
        yum update -y
        yum install -y epel-release
        yum install -y curl unzip socat git build-essential
    fi
fi
# 检查安装结果
if [ $? -eq 0 ]; then
    echo -e "${green}软件包安装成功! ${plain}"
else
    echo -e "${red}软件包安装失败，请检查网络连接或软件源配置! ${plain}"
    exit 1
fi

echo -e "${green}所有操作已完成! ${plain} \n"
#########################################################必要软件###############################################################

###########################################################menu#################################################################
show_menu() {
    clear
    echo -e "${green}——————————————————————${plain}"
    echo -e "  ${yellow}我的自动化管理脚本${plain}"
    echo -e "${green}——————————————————————${plain}"
    echo -e "  0. 退出脚本"
    echo -e "  1. 封装 X-UI"
    echo -e "  2. 部署直播录制"
    echo -e "  3. 部署自动上传"
    echo -e "  4. 配置开机启动"
    echo -e "  5. 部署ALL"
    echo -e "  6. 删除x-ui"
    echo -e "  7. 删除直播录制"
    echo -e "  8. 删除自动上传"
    echo -e "  9. 删除ALL"
    echo -e "${green}——————————————————————${plain}"
    echo
    read -p "请输入选项 [0-9]: " choice
    case $choice in
        0)
            echo "退出脚本..."
            exit 0
            ;;
        1)
            Package_xui
            ;;
        2)
            deploy_douyin_recorder
            ;;
        3)
            deploy_autoupload
            ;;
        4)
            deploy_systemd
            ;;
        5)
            deploy_all
            ;;
        6)
            delete_xui
            ;;
        7)
            delete_douyin_recorder
            ;;
        8)
            delete_autoupload
            ;;
        9)
            delete_all
            ;;
        *)
            echo -e "${red}无效输入，请重试！${plain}"
            sleep 2
            show_menu
            ;;
    esac
}

###########################################################menu#################################################################

#########################################################x-ui部署###############################################################
Package_xui() {
    echo -e "${green}开始x-ui部署 ${plain}\n"
    cd /root
    curl -LO https://github.com/xeefei/X-Panel/archive/refs/tags/${X_Panel_last_version}.tar.gz
    tar -xvf *.tar.gz
    rm -rf *.tar.gz
    cd X-Panel*
    # 找到需要修改和新家文件的绝对路径
    web_go=$(find . -name "web.go" -exec readlink -f {} \;)
    aSidebar=$(find . -name "aSidebar.html" -exec readlink -f {} \;)
    html=$(find -name "html" -type d  -exec readlink -f {} \;)
    controller=$(find -name "controller" -type d  -exec readlink -f {} \;)
    
    ###用 awk 在web.go中插入直播监控路由注册并覆盖写回##########
    awk '
    /s\.api = controller.NewAPIController\(g\)/ {
        indent = match($0,/^[ \t]*/)?substr($0,RSTART,RLENGTH):""
    }
    /return engine, nil/ {
        print indent "//add for nick"
        print indent "controller.NewLiveControlController(g, s.settingService)"
    }
    { print }
    ' "$web_go" > "$web_go.tmp" && mv "$web_go.tmp" "$web_go"
    ##########################################################
    
    # 用 awk 在aSidebar.html中插入直播控制台路侧边栏菜单并覆盖写回
    awk '
    /panel\/inbounds/ { in_inbounds=1 }   # 进入 inbounds 块
    in_inbounds && /^[[:space:]]*},/ {
        print        # 先输出原始的 inbounds 结束行
        indent = match($0,/^[ \t]*/)?substr($0,RSTART,RLENGTH):""
        print indent "{"
        print indent "    key: '\''{{ .base_path }}panel/livecontrol'\'',"
        print indent "    icon: '\''video-camera'\'',"
        print indent "    title: '\''直播控制台'\''"
        print indent "},"
        in_inbounds=0
        next
    }
    { print }
    ' "$aSidebar" > "$aSidebar.tmp" && mv "$aSidebar.tmp" "$aSidebar"
    ##########################################################
    
    #生成直播控制台页面代码
    cat <<'EOF' > "$html/livecontrol.html"
    <!DOCTYPE html>
    <html lang="zh-CN">
    <head>
        <meta charset="UTF-8">
        <title>直播控制台</title>
        <link rel="stylesheet" href="/static/css/style.css">
        <style>
            .container {
                display: flex;
                flex-direction: column;
                height: calc(100vh - 60px);
                padding: 20px;
    	    background: #121212;   /* 🔴暗黑背景 */
                color: #eee;           /* 🔴浅色文字 */
            }
            .panel {
                padding: 20px;
                border: 1px solid #333;
                background: #1e1e1e;
                box-shadow: 0 2px 8px rgba(0,0,0,0.5);
    	    margin-bottom: 20px;
            }
            .status {
                margin: 10px 0;
                font-weight: bold;
            }
            .btn-group button {
                margin-right: 8px;
            }
            .log-header {
                cursor: pointer;
                font-weight: bold;
                padding: 8px;
                border-bottom: 1px solid #333;
                background: #2a2a2a;
                display: flex;
                align-items: center;
    	    color: #eee;
            }
            .log-header span {
                margin-left: 8px;
            }
            .arrow {
                transition: transform 0.3s;
            }
            .arrow.expanded {
                transform: rotate(90deg);
            }
            .log-content {
                display: none;
                background: #000;
                color: #0f0;
                padding: 10px;
                white-space: pre-wrap;
                height: 200px;
                overflow-y: auto;
    	    font-family: monospace;
            }
            .services-row {
                display: flex;
                gap: 20px; /* 两个卡片之间的间距 */
            }
            .service-box {
                flex: 1;
                background: #2a2a2a;
                padding: 15px;
                border-radius: 10px;
            }
            input[type="text"] {
                background: #2a2a2a;  /* ✅ 深色背景 */
                color: #eee;          /* ✅ 浅色文字 */
                border: 1px solid #444;
                padding: 6px;
                border-radius: 4px;
            }
            
            button {
                background: #444;     /* ✅ 深色按钮 */
                color: #eee;
                border: none;
                padding: 6px 12px;
                border-radius: 4px;
                cursor: pointer;
            }
            button:hover {
                background: #666;
            }
            /* 🔴 URL 删除按钮样式 */
            #url-list button {
                background-color: #e74c3c;
                color: #fff;
                border: none;
                padding: 4px 8px;
                border-radius: 4px;
                cursor: pointer;
                font-size: 12px;
            }
            #url-list button:hover {
                background-color: #c0392b;
            }
        </style>
    </head>
    <body>
        <div class="container">
    
            <!-- 服务状态与控制 -->
            <div class="panel">
                <h3>服务状态与控制</h3>
    	    <div class="services-row">
                    <div class="service-box">
                        <div class="status">
                            Douyin Recorder 状态: <span id="status-douyin">加载中...</span>
                        </div>
                        <div class="btn-group">
                            <button onclick="controlService('douyinrecorder.service','start')">启动</button>
                            <button onclick="controlService('douyinrecorder.service','stop')">停止</button>
                            <button onclick="controlService('douyinrecorder.service','restart')">重启</button>
                        </div>
    	        </div>
    
                    <div class="service-box">
                        <div class="status" style="margin-top:15px;">
                            PCS Upload 状态: <span id="status-pcs">加载中...</span>
                        </div>
                        <div class="btn-group">
                            <button onclick="controlService('baidupcs-go.service','start')">启动</button>
                            <button onclick="controlService('baidupcs-go.service','stop')">停止</button>
                            <button onclick="controlService('baidupcs-go.service','restart')">重启</button>
                        </div>
    	        </div>
                </div>
            </div>
    
            <!-- URL 配置 -->
            <div class="panel">
                <h3>URL 配置</h3>
                <form id="url-config-form" onsubmit="saveConfig(event)">
                    <label>直播间URL：</label>
                    <input type="text" id="live-url" name="live-url" placeholder="输入直播间URL" style="width:100%;">
                    <button type="submit" style="margin-top:15px;">保存配置</button>
                </form>
    
                <!-- 这里是 URL 列表 -->
                <ul id="url-list" style="margin-top:15px; padding-left:20px;"></ul>
            </div>
            <!-- 百度网盘凭证配置 -->
            <div class="panel">
                <h3>百度网盘凭证配置</h3>
                <form id="baidu-token-form" onsubmit="saveBaiduToken(event)">
                    <label>BDUSS：</label>
                    <input type="text" id="bduss" placeholder="请输入BDUSS" style="width:100%; margin-bottom:10px;">
                    <label>STOKEN：</label>
                    <input type="text" id="stoken" placeholder="请输入STOKEN" style="width:100%; margin-bottom:10px;">
                    <button type="submit">保存凭证</button>
                </form>
            <div class="panel">
                <h3>TikTok Cookie 配置</h3>
                <form id="tiktok-cookie-form" onsubmit="saveTiktokCookie(event)">
                    <label>Cookie：</label>
                    <textarea id="tiktok-cookie" 
                        placeholder="粘贴完整的 TikTok Cookie（通常以 sessionid= 开头）..." 
                        style="width:100%; height:120px; background:#2a2a2a; color:#eee; border:1px solid #444; border-radius:4px; padding:8px;"></textarea>
                    <button type="submit" style="margin-top:10px;">保存 Cookie</button>
                </form>
	    </div>
            </div>
            <!-- 日志显示 -->
            <div class="panel">
                <h3>日志</h3>
                <!-- Douyin Recorder 日志 -->
                <div class="log-header" onclick="toggleLog('douyin')">
                    <span class="arrow" id="arrow-douyin">▶</span>
                    <span>Douyin Recorder 日志</span>
    		<button onclick="clearLogs('douyinrecorder.service');event.stopPropagation();" style="margin-left:auto;">清空</button>
                </div>
                <pre id="log-douyin" class="log-content">点击展开查看日志</pre>
    
                <!-- PCS Upload 日志 -->
                <div class="log-header" style="margin-top:10px;" onclick="toggleLog('pcs')">
                    <span class="arrow" id="arrow-pcs">▶</span>
                    <span>PCS Upload 日志</span>
    		<button onclick="clearLogs('baidupcs-go.service');event.stopPropagation();" style="margin-left:auto;">清空</button>
                </div>
                <pre id="log-pcs" class="log-content">点击展开查看日志</pre>
            </div>
    
        </div>
    
        <script>
            const basePath = "{{ .base_path }}";   
            const API_PREFIX = basePath + "panel/livecontrol/api";
            let logIntervals = {};
            // 切换日志展开/收起
            function toggleLog(service) {
                const logBox = document.getElementById("log-" + service);
                const arrow = document.getElementById("arrow-" + service);
                const svcName = service === "douyin" ? "douyinrecorder.service" : "baidupcs-go.service";
    
                if (logBox.style.display === "none" || logBox.style.display === "") {
                        logBox.style.display = "block";
                        arrow.classList.add("expanded");
                        loadLogs(svcName);
                        clearInterval(logIntervals[service]);
                        // 开启定时刷新
                        logIntervals[service] = setInterval(() => {
                        loadLogs(svcName);
                    }, 10000); // 10 秒刷新一次
                } else {
                    logBox.style.display = "none";
                    arrow.classList.remove("expanded");
                    // 停止刷新
                    clearInterval(logIntervals[service]);
                    delete logIntervals[service];
                }
            }
    
            // 获取服务状态
            function loadStatus() {
                fetch(API_PREFIX + "/status")
                    .then(res => res.json())
                    .then(data => {
                        document.getElementById("status-douyin").textContent = data.status["douyinrecorder.service"];
                        document.getElementById("status-pcs").textContent = data.status["baidupcs-go.service"];
                    })
                    .catch(() => {
                        document.getElementById("status-douyin").textContent = "获取失败";
                        document.getElementById("status-pcs").textContent = "获取失败";
                    });
            }
    
            // 控制服务
            function controlService(service, action) {
                fetch(API_PREFIX + "/action", {
                    method: "POST",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify({ service: service, action: action })
                })
                .then(res => res.json())
                .then(data => {
                    alert(data.message || data.error);
                    loadStatus();
                });
            }
    
            // 加载日志
            function loadLogs(service) {
                fetch(API_PREFIX + "/logs/" + service)
                    .then(res => res.json())
                    .then(data => {
                        const target = service === "douyinrecorder.service" ? "log-douyin" : "log-pcs";
                        const targetBox = document.getElementById(target);
                        targetBox.textContent = data.logs.join("\n");
                        targetBox.scrollTop = targetBox.scrollHeight; // 自动滚动到底部
                    });
            }
    
            // 加载 URL 配置
            function loadURLConfig() {
                fetch(API_PREFIX + "/urlconfig")
                    .then(res => res.json())
                    .then(data => {
                        const listBox = document.getElementById("url-list");
                        listBox.innerHTML = ""; // 清空旧内容
                        if (!data.url_config || data.url_config.length === 0) {
                            listBox.innerHTML = "<li>暂无配置</li>";
                            return;
                        }
                        data.url_config.forEach(url => {
                            const li = document.createElement("li");
                            li.style.marginBottom = "8px";
                            li.textContent = url + " ";
    
                            const btn = document.createElement("button");
                            btn.textContent = "删除";
                            btn.style.marginLeft = "10px";
                            btn.onclick = () => deleteURL(url);
    
                            li.appendChild(btn);
                            listBox.appendChild(li);
                        });
                    });
            }
    
            // 保存 URL 配置
            function saveConfig(event) {
                event.preventDefault();
                const url = document.getElementById("live-url").value.trim();
                if (!url) {
                    alert("请输入URL");
                    return;
                }
                fetch(API_PREFIX + "/urlconfig", {
                    method: "POST",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify({ url: url })
                })
                    .then(res => res.json())
                    .then(data => {
                        alert(data.message || data.error);
                        document.getElementById("live-url").value = "";
                        loadURLConfig();   // 保存后刷新列表
                    });
            }
    
            // 删除 URL 配置
            function deleteURL(url) {
                if (!confirm("确定删除该URL吗？\n" + url)) return;
                fetch(API_PREFIX + "/urlconfig", {
                    method: "DELETE",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify({ url: url })
                })
                    .then(res => res.json())
                    .then(data => {
                        alert(data.message || data.error);
                        loadURLConfig(); // 删除后刷新列表
                    });
            }
            // 清空日志
            function clearLogs(service) {
                if (!confirm("确定要清空该日志吗？")) return;
                fetch(API_PREFIX + "/logs/clear", {
                    method: "POST",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify({ service: service })
                })
                .then(res => res.json())
                .then(data => {
                    alert(data.message || data.error);
                    if (service === "douyinrecorder.service") {
                        document.getElementById("log-douyin").textContent = "";
    		    loadLogs(service);   //清空后刷新
                    } else if (service === "baidupcs-go.service") {
                        document.getElementById("log-pcs").textContent = "";
    		    loadLogs(service);   //清空后刷新
                    }
                });
            }
            // 保存百度网盘凭证
            function saveBaiduToken(event) {
                event.preventDefault();
                const bduss = document.getElementById("bduss").value.trim();
                const stoken = document.getElementById("stoken").value.trim();
            
                if (!bduss || !stoken) {
                    alert("请完整填写 BDUSS 和 STOKEN！");
                    return;
                }
            
                fetch(API_PREFIX + "/update_baidu_token", {
                    method: "POST",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify({ bduss, stoken })
                })
                    .then(res => res.json())
                    .then(data => {
                        alert(data.message || data.error);
                    })
                    .catch(() => alert("请求失败，请检查服务端连接。"));
            }
            function loadTiktokCookie() {
                fetch(API_PREFIX + "/get_tiktok_cookie")
                    .then(res => res.json())
                    .then(data => {
                        if (data.tiktok_cookie) {
                            document.getElementById("tiktok-cookie").value = data.tiktok_cookie;
                        }
                    })
                    .catch(() => console.warn("无法加载 TikTok Cookie"));
            }
            // 保存 TikTok Cookie
            function saveTiktokCookie(event) {
                event.preventDefault();
                const cookie = document.getElementById("tiktok-cookie").value.trim();
            
                if (!cookie) {
                    alert("请输入完整的 TikTok Cookie！");
                    return;
                }
            
                fetch(API_PREFIX + "/update_tiktok_cookie", {
                    method: "POST",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify({ cookie })
                })
                    .then(res => res.json())
                    .then(data => {
                        alert(data.message || data.error);
                    })
                    .catch(() => {
                        alert("请求失败，请检查服务端连接。");
                    });
            }
            // 初始化
            loadStatus();
            loadURLConfig();
            setInterval(loadStatus, 10000); //每 10 秒刷新服务状态
        </script>
    </body>
    </html>
EOF
    
    #生成直播控制台后端路由代码
    cat <<'EOF' > "$controller/livecontrol.go"
    package controller
    
    import (
    	"fmt"
    	"net/http"
    	"os"
    	"os/exec"
    	"strings"
        "bufio"
    	"x-ui/web/service"
    	"x-ui/web/session"
    	"github.com/gin-gonic/gin"
    )
    
    // 日志和配置路径
    const (
    	DouyinLogPath = "/root/logs/douyinrecorder.log"
    	PCSLogPath    = "/root/logs/pcs_upload.log"
    	URLConfigPath = "/root/DouyinLiveRecorder/config/URL_config.ini"
    )
    
    type LiveControlController struct{
    	settingService service.SettingService
    }
    
    func NewLiveControlController(g *gin.RouterGroup, settingService service.SettingService) *LiveControlController {
    	lc := &LiveControlController{
                settingService: settingService,
            }
    
    	// 页面路由
    	g.GET("/panel/livecontrol", lc.page)
    
    	// API 路由
    	api := g.Group("/panel/livecontrol/api")
    	{
    	    api.GET("/status", lc.getStatus)     // 获取服务状态
    	    api.POST("/action", lc.serviceAction) // 启动/停止/重启
    	    api.GET("/logs/:service", lc.getLogs) // 读取日志
    	    api.GET("/urlconfig", lc.getURLConfig) // 读取 URL 配置
            api.POST("/urlconfig", lc.saveURLConfig) // 保存 URL 配置补上这一行
            api.DELETE("/urlconfig", lc.deleteURLConfig) // 删除 URL 配置
            api.POST("/logs/clear", lc.clearLogs) // 🔹新增或替换原来的日志清空接口
            api.POST("/update_baidu_token", lc.updateBaiduToken) // 🔹新增百度凭证更新接口
            api.GET("/get_tiktok_cookie", lc.GetTiktokCookie)
            api.POST("/update_tiktok_cookie", lc.UpdateTiktokCookie)
    	}
    
    	return lc
    }
    
    // 页面渲染
    func (lc *LiveControlController) page(c *gin.Context) {
            user := session.GetLoginUser(c)
            basePath, err := lc.settingService.GetBasePath()
            if err != nil {
                // 如果出错，给个默认值，避免页面打不开
                basePath = "/"
            }
            if user == nil {
                c.Redirect(http.StatusFound, basePath+"/panel/")
                c.Abort()
                return
            }
    	c.HTML(http.StatusOK, "livecontrol.html", gin.H{ 
                "base_path": basePath,
            })
    }
    
    // 获取服务状态
    func (lc *LiveControlController) getStatus(c *gin.Context) {
    	services := []string{"douyinrecorder.service", "baidupcs-go.service"}
    	status := make(map[string]string)
    
    	for _, svc := range services {
    		cmd := exec.Command("systemctl", "is-active", svc)
    		output, err := cmd.Output()
    		if err != nil {
    			status[svc] = "failed"
    		} else {
    			status[svc] = strings.TrimSpace(string(output))
    		}
    	}
    	c.JSON(http.StatusOK, gin.H{"status": status})
    }
    
    // 服务操作
    func (lc *LiveControlController) serviceAction(c *gin.Context) {
        var req struct {
            Service string `json:"service"`
            Action  string `json:"action"` // start | stop | restart
        }
        if err := c.ShouldBindJSON(&req); err != nil {
            c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误"})
            return
        }
    
        // 允许的服务
        allowedServices := map[string]bool{
            "douyinrecorder.service": true,
            "baidupcs-go.service":      true,
        }
        // 允许的操作
        allowedActions := map[string]bool{
            "start":   true,
            "stop":    true,
            "restart": true,
        }
    
        if !allowedServices[req.Service] || !allowedActions[req.Action] {
            c.JSON(http.StatusBadRequest, gin.H{"error": "非法参数"})
            return
        }
    
        cmd := exec.Command("systemctl", req.Action, req.Service)
        output, err := cmd.CombinedOutput()
        if err != nil {
            c.JSON(http.StatusInternalServerError, gin.H{
                "error":  err.Error(),
                "output": string(output),
            })
            return
        }
        // 🔹启动/停止/重启直播录制时，自动清理 URL_config.ini
        if req.Service == "douyinrecorder.service" {
            if err := cleanURLConfig(URLConfigPath); err != nil {
                fmt.Printf("清理 URL_config.ini 失败: %v\n", err)
            } else {
                fmt.Println("已自动清理 URL_config.ini 中的逗号及其后内容")
            }
        }
        c.JSON(http.StatusOK, gin.H{
            "message": fmt.Sprintf("执行成功: %s %s", req.Action, req.Service),
        })
    }
    // cleanURLConfig 纯 Go 清理 URL_config.ini
    func cleanURLConfig(path string) error {
        file, err := os.Open(path)
        if err != nil {
            return err
        }
        defer file.Close()
    
        var lines []string
        scanner := bufio.NewScanner(file)
        for scanner.Scan() {
            line := scanner.Text()
            if idx := strings.Index(line, ","); idx != -1 {
                line = line[:idx] // 截取逗号前内容
            }
            lines = append(lines, line)
        }
        if err := scanner.Err(); err != nil {
            return err
        }
    
        f, err := os.OpenFile(path, os.O_WRONLY|os.O_TRUNC, 0644)
        if err != nil {
            return err
        }
        defer f.Close()
    
        for _, line := range lines {
            _, err := f.WriteString(line + "\n")
            if err != nil {
                return err
            }
        }
    
        return nil
    }
    // 读取日志
    func (lc *LiveControlController) getLogs(c *gin.Context) {
    	service := c.Param("service")
    	var path string
    
    	if service == "douyinrecorder.service" || service == "douyin" {
    		path = DouyinLogPath
    	} else if service == "baidupcs-go.service" || service == "pcs" {
    		path = PCSLogPath
    	} else {
    		c.JSON(http.StatusBadRequest, gin.H{"error": "未知服务"})
    		return
    	}
    
    	data, err := os.ReadFile(path)
    	if err != nil {
    		c.JSON(http.StatusInternalServerError, gin.H{"error": "日志读取失败: " + err.Error()})
    		return
    	}
    
    	// 转换为行，倒序，最多 200 行
    	lines := strings.Split(strings.TrimSpace(string(data)), "\n")
    	if len(lines) > 200 {
    		lines = lines[len(lines)-200:]
    	}
    	c.JSON(http.StatusOK, gin.H{
    		"logs": lines,
    	})
    }
    
    // 清空日志
    func (lc *LiveControlController) clearLogs(c *gin.Context) {
        var req struct {
            Service string `json:"service"` // 接收要清空的服务
        }
        if err := c.ShouldBindJSON(&req); err != nil || req.Service == "" {
            c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误"})
            return
        }
    
        var path string
        switch req.Service {
        case "douyinrecorder.service", "douyin":
            path = DouyinLogPath
        case "baidupcs-go.service", "pcs":
            path = PCSLogPath
        default:
            c.JSON(http.StatusBadRequest, gin.H{"error": "未知服务"})
            return
        }
    
        cmd := exec.Command("truncate", "-s", "0", path)
        if err := cmd.Run(); err != nil {
            c.JSON(http.StatusInternalServerError, gin.H{"error": "日志清空失败: " + err.Error()})
            return
        }
    
        c.JSON(http.StatusOK, gin.H{"message": fmt.Sprintf("%s 日志已清空", req.Service)})
    }
    
    
    // 读取 URL 配置
    func (lc *LiveControlController) getURLConfig(c *gin.Context) {
    
    	data, err := os.ReadFile(URLConfigPath)
    	if err != nil {
    		c.JSON(http.StatusInternalServerError, gin.H{"error": "配置文件读取失败: " + err.Error()})
    		return
    	}
            rawLines := strings.Split(strings.TrimSpace(string(data)), "\n")
            var urls []string
            for _, line := range rawLines {
                line = strings.TrimSpace(line)
                if line != "" {
                    urls = append(urls, line)
                }
            }
    
    	c.JSON(http.StatusOK, gin.H{
    		"url_config": urls,
    	})
    }
    // 保存 URL 配置
    func (lc *LiveControlController) saveURLConfig(c *gin.Context) {
        var req struct {
            URL string `json:"url"`
        }
        if err := c.ShouldBindJSON(&req); err != nil || req.URL == "" {
            c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误"})
            return
        }
        newURL := strings.TrimSpace(req.URL)
        if newURL == "" {
            c.JSON(http.StatusBadRequest, gin.H{"error": "URL 不能为空"})
            return
        }
    
        // 读取现有内容
        data, _ := os.ReadFile(URLConfigPath)
        var lines []string
        if len(data) > 0 {
            rawLines := strings.Split(strings.TrimSpace(string(data)), "\n")
            for _, line := range rawLines {
                line = strings.TrimSpace(line)
                if line != "" {
                    lines = append(lines, line)
                }
            }
        }
    
        // 检查是否已存在
        for _, line := range lines {
            if strings.EqualFold(strings.TrimSpace(line), newURL) {
                c.JSON(http.StatusOK, gin.H{"message": "该URL已存在，无需重复保存"})
                return
            }
        }
    
        // 追加新 URL
        lines = append(lines, newURL)
    
        // 覆盖写入文件（保持顺序）
        err := os.WriteFile(URLConfigPath, []byte(strings.Join(lines, "\n")+"\n"), 0644)
        if err != nil {
            c.JSON(http.StatusInternalServerError, gin.H{"error": "保存失败: " + err.Error()})
            return
        }
    
        c.JSON(http.StatusOK, gin.H{"message": "保存成功"})
    }
    // 删除 URL 配置
    func (lc *LiveControlController) deleteURLConfig(c *gin.Context) {
        var req struct {
            URL string `json:"url"`
        }
        if err := c.ShouldBindJSON(&req); err != nil || strings.TrimSpace(req.URL) == "" {
            c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误"})
            return
        }
        target := strings.TrimSpace(req.URL)
    
        // 读取现有 URL
        data, err := os.ReadFile(URLConfigPath)
        if err != nil && !os.IsNotExist(err) {
            c.JSON(http.StatusInternalServerError, gin.H{"error": "读取配置失败: " + err.Error()})
            return
        }
    
        rawLines := strings.Split(strings.TrimSpace(string(data)), "\n")
        var newLines []string
        var found bool
    
        for _, line := range rawLines {
            line = strings.TrimSpace(line)
            if line == "" {
                continue
            }
            if strings.EqualFold(line, target) {
                found = true
                continue // 跳过要删除的
            }
            newLines = append(newLines, line)
        }
    
        // 处理写入：如果删光了就写空，否则正常拼接
        var content string
        if len(newLines) > 0 {
            content = strings.Join(newLines, "\n") + "\n"
        } else {
            content = ""
        }
    
        if !found {
            c.JSON(http.StatusNotFound, gin.H{"error": "未找到该URL"})
            return
        }
    
        // 覆盖写入
        err = os.WriteFile(URLConfigPath, []byte(content), 0644)
        if err != nil {
            c.JSON(http.StatusInternalServerError, gin.H{"error": "删除失败: " + err.Error()})
            return
        }
    
        c.JSON(http.StatusOK, gin.H{"message": "删除成功"})
    }
    // 更新百度网盘 BDUSS 和 STOKEN
    func (lc *LiveControlController) updateBaiduToken(c *gin.Context) {
        var req struct {
            BDUSS  string `json:"bduss"`
            STOKEN string `json:"stoken"`
        }
    
        if err := c.ShouldBindJSON(&req); err != nil || req.BDUSS == "" || req.STOKEN == "" {
            c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误，必须提供 BDUSS 和 STOKEN"})
            return
        }
    
        const uploadScript = "/root/autoupload"
    
        data, err := os.ReadFile(uploadScript)
        if err != nil {
            c.JSON(http.StatusInternalServerError, gin.H{"error": "读取脚本失败: " + err.Error()})
            return
        }
    
        content := string(data)
        // 使用正则替换 BaiduPCS-Go login 行
        newLine := fmt.Sprintf(`BaiduPCS-Go login -bduss=%s -stoken=%s`, req.BDUSS, req.STOKEN)
    
        found := false
        lines := strings.Split(content, "\n")
        for i, line := range lines {
            if strings.Contains(line, "BaiduPCS-Go login") {
                lines[i] = newLine
                found = true
            }
        }
    
        if !found {
            // 如果没有找到，则追加一行
            lines = append(lines, newLine)
        }
    
        // 写回文件
        err = os.WriteFile(uploadScript, []byte(strings.Join(lines, "\n")+"\n"), 0755)
        if err != nil {
            c.JSON(http.StatusInternalServerError, gin.H{"error": "写入脚本失败: " + err.Error()})
            return
        }
    
        c.JSON(http.StatusOK, gin.H{"message": "百度网盘凭证已更新成功"})
    }
    // 获取 TikTok Cookie
    func (ctl *LiveControlController) GetTiktokCookie(c *gin.Context) {
        configPath := "/root/DouyinLiveRecorder/config/config.ini"
    
        data, err := os.ReadFile(configPath)
        if err != nil {
            c.JSON(http.StatusInternalServerError, gin.H{"error": "无法读取 config.ini"})
            return
        }
    
        lines := strings.Split(string(data), "\n")
        var cookie string
        for _, line := range lines {
            if strings.HasPrefix(strings.TrimSpace(line), "tiktok_cookie=") {
                cookie = strings.TrimPrefix(strings.TrimSpace(line), "tiktok_cookie=")
                break
            }
        }
    
        c.JSON(http.StatusOK, gin.H{"tiktok_cookie": cookie})
    }
    // 更新 TikTok Cookie
    func (ctl *LiveControlController) UpdateTiktokCookie(c *gin.Context) {
        var req struct {
            Cookie string `json:"cookie"`
        }
        if err := c.BindJSON(&req); err != nil || strings.TrimSpace(req.Cookie) == "" {
            c.JSON(http.StatusBadRequest, gin.H{"error": "无效的 Cookie"})
            return
        }
    
        configPath := "/root/DouyinLiveRecorder/config/config.ini"
        data, err := os.ReadFile(configPath)
        if err != nil {
            c.JSON(http.StatusInternalServerError, gin.H{"error": "无法读取 config.ini"})
            return
        }
    
        lines := strings.Split(string(data), "\n")
        updated := false
        insertIndex := -1
    
        for i, line := range lines {
            trimmed := strings.TrimSpace(line)
    
            if strings.HasPrefix(trimmed, "tiktok_cookie") {
                // 保留左侧空格，统一格式为 "tiktok_cookie = <Cookie>"
                parts := strings.SplitN(line, "=", 2)
                left := strings.TrimRight(parts[0], " ") // 去掉左边等号前多余空格
                lines[i] = left + " = " + req.Cookie     // 始终保证等号后有一个空格
                updated = true
                break
            }
    
            if insertIndex == -1 && strings.HasPrefix(trimmed, "快手cookie") {
                insertIndex = i
            }
        }
    
        if !updated {
            newLine := "tiktok_cookie = " + req.Cookie
            if insertIndex != -1 {
                tmp := append([]string{}, lines[:insertIndex+1]...)
                tmp = append(tmp, newLine)
                tmp = append(tmp, lines[insertIndex+1:]...)
                lines = tmp
            } else {
                lines = append(lines, newLine)
            }
        }
    
        err = os.WriteFile(configPath, []byte(strings.Join(lines, "\n")), 0644)
        if err != nil {
            c.JSON(http.StatusInternalServerError, gin.H{"error": "写入失败"})
            return
        }
    
        c.JSON(http.StatusOK, gin.H{"message": "TikTok Cookie 已更新"})
    }

EOF
    
    #编译生成X-Panel面板x-ui
    git clone https://github.com/riobard/go-bloom.git
    cd go-bloom
    git checkout cdc8013cb5b3
    curl -LO https://golang.org/dl/go1.23.0.linux-amd64.tar.gz
    mkdir -p /root/packge
    tar -C /root/packge -xzf go1.23.0.linux-amd64.tar.gz
    export PATH=$PATH:/root/packge/go/bin
    export GOPATH=$HOME/go
    go mod init github.com/riobard/go-bloom
    cd -
    echo "replace github.com/riobard/go-bloom => ./go-bloom" >> go.mod
    go mod tidy
    CGO_ENABLED=1 GOOS=linux GOARCH=amd64 go build -o x-ui .
    cd -
    sudo rm -rf /root/packge/local/go
    sudo rm -rf /root/go
    echo -e "${green}x-ui封装完成 ${plain}\n"
}

#下载原xeefei中封装好的X-Panel
deploy_x-ui() {
    curl -L -o /usr/local/x-ui-linux-amd64.tar.gz https://github.com/xeefei/X-Panel/releases/download/${X_Panel_last_version}/x-ui-linux-amd64.tar.gz
    cd /usr/local 
    tar -xvf *.tar.gz
    cd /usr/local/x-ui
    rm -rf x-ui
    cp /root/X-Panel*/x-ui .
    cp /usr/local/x-ui/x-ui.sh /usr/local/bin/x-ui
    cp x-ui.service /etc/systemd/system/
    chmod +x /usr/local/x-ui/x-ui
    chmod +x /usr/local/x-ui/x-ui.sh
    chmod +x /usr/local/bin/x-ui
    chmod +x /usr/local/x-ui/bin/xray-linux-amd64
    rm -rf /usr/local/x-ui-linux-amd64.tar.gz
    echo -e "${green}x-ui部署完成 ${plain}\n"
}
#########################################################x-ui部署###############################################################



#######################################################直播录制部署##############################################################
deploy_douyin_recorder() {
    echo -e "${green}直播录制部署 ${plain}\n"
    if [[ "${release}" == "ubuntu" || "${release}" == "debian" ]]; then
        echo -e "${green}使用 apt 包管理器安装pip3&ffmpeg... ${plain}"
        apt update -y
        apt install -y python3-pip ffmpeg 
    elif [[ "${release}" == "centos" ]]; then
        if command -v dnf &> /dev/null; then
            echo -e "${green}使用 dnf 包管理器安装软件包... ${plain}"
            dnf update -y
            dnf install -y epel-release
            dnf install -y python3-pip ffmpeg 
        else
            echo -e "${green}使用 yum 包管理器安装软件包... ${plain}"
            yum update -y
            yum install -y epel-release
            yum install -y  python3-pip ffmpeg 
        fi
    fi
    # 获取可用的 pip3 命令
    find_pip() {
        for cmd in pip3 pip3.11 pip3.10 pip3.9 pip3.8 pip3.7 pip3.6; do
            if command -v "$cmd" &>/dev/null; then
                echo "$cmd"
                return 0
            fi
        done
    
        if command -v python3 &>/dev/null; then
            echo "python3 -m pip"
            return 0
        fi
    
        echo "No pip found" >&2
        return 1
    }
    # 使用方法
    PIP_CMD=$(find_pip)
    echo "Using pip: $PIP_CMD"
    mkdir -p /root/logs
    cd /root
    git clone https://github.com/ihmily/DouyinLiveRecorder.git
    cd DouyinLiveRecorder
    $PIP_CMD install -r requirements.txt
    echo "https://www.tiktok.com/@user68358021784866/live" >> config/URL_config.ini
    echo "https://www.tiktok.com/@faithe322541/live" >> config/URL_config.ini
    echo "https://www.tiktok.com/@user7528178744418/live" >> config/URL_config.ini
    echo "https://www.tiktok.com/@user2137514441812/live" >> config/URL_config.ini
    echo "https://www.tiktok.com/@user33574522621350/live" >> config/URL_config.ini
    echo "https://www.tiktok.com/@user90733361298281/live" >> config/URL_config.ini
    echo "https://www.tiktok.com/@user2110706062176/live" >> config/URL_config.ini
    sed -i "s%视频分段时间(秒) = 1800%视频分段时间(秒) = 14400%g" config/config.ini
    sed -i "s%是否跳过代理检测(是/否) = 否%是否跳过代理检测(是/否) = 是%g" config/config.ini
    echo -e "${green}直播录制部署完成 ${plain}\n"
}
#######################################################直播录制部署##############################################################

#######################################################自动上传部署##############################################################
deploy_autoupload() {
    echo -e "${green}自动上传部署 ${plain}\n"
    mkdir -p /root/logs
    cd /root
    if [[ "${release}" == "ubuntu" || "${release}" == "debian" ]]; then
        echo -e "${green}使用 apt 包管理器安装软件包... ${plain}"
        apt update -y
        apt install -y inotify-tools
    elif [[ "${release}" == "centos" ]]; then
        if command -v dnf &> /dev/null; then
            echo -e "${green}使用 dnf 包管理器安装软件包... ${plain}"
            dnf update -y
            dnf install -y epel-release
            dnf install -y inotify-tools
        else
            echo -e "${green}使用 yum 包管理器安装软件包... ${plain}"
            yum update -y
            yum install -y epel-release
            yum install -y inotify-tools
        fi
    fi
    curl -LO https://github.com/qjfoidnh/BaiduPCS-Go/releases/download/${baidupcs_go_last_version}/BaiduPCS-Go-${baidupcs_go_last_version}-linux-amd64.zip
    unzip *.zip
    rm -rf *.zip
    cd Baidu*
    mv BaiduPCS-Go /usr/local/bin
    cd /root
    rm -rf Baidu*
    
    cat << 'EOF' > /root/autoupload
    #!/bin/bash
    # 实时监控 /baby/ 及其子目录下的 mp4 文件
    # 一旦有新 mp4 出现（写入完成或移动到目录），即上传到百度网盘并删除本地文件
    # 依赖: inotify-tools, BaiduPCS-Go
    # 日志: /root/logs/pcs_upload.log
    
    SRC_DIR="/root/DouyinLiveRecorder/downloads"
    DEST_DIR="/baby"      # 目标网盘目录（可以改成你想要的）
    LOG_FILE="/root/logs/pcs_upload.log"
    MAX_RETRY=3
    SLEEP_BETWEEN_RETRY=5
    
    mkdir -p "$(dirname "$LOG_FILE")"
    
    BaiduPCS-Go login -bduss= -stoken=
    timestamp() {
        date +"%Y-%m-%d %H:%M:%S"
    }
    
    echo "$(timestamp) [INFO] 开始递归监控目录: $SRC_DIR" | tee -a "$LOG_FILE"
    
    # -m 持续监听
    # -r 递归所有子目录
    # -e close_write,moved_to 表示写入完成或移动到目录时触发
    while read -r file; do
        if [[ "$file" == *.mp4 ]]; then
            echo "$(timestamp) [INFO] 检测到新文件: $file" | tee -a "$LOG_FILE"
    
            success=0
            for ((i=1; i<=MAX_RETRY; i++)); do
                echo "$(timestamp) [INFO] 上传尝试 $i/$MAX_RETRY: $file" | tee -a "$LOG_FILE"
    
                # 上传文件
                BaiduPCS-Go upload "$file" "$DEST_DIR" >> "$LOG_FILE" 2>&1
    
                # 检查最后 10 行日志，判断是否上传失败或总大小为0
                if tail -n10 "$LOG_FILE" | grep -qE "上传文件失败|总大小: 0B"; then
                    echo "$(timestamp) [WARN] 上传失败，第 $i 次重试: $file" | tee -a "$LOG_FILE"
                    sleep $SLEEP_BETWEEN_RETRY
                else
                    echo "$(timestamp) [INFO] 上传成功，删除本地文件: $file" | tee -a "$LOG_FILE"
                    rm -f "$file"
                    success=1
                    break
                fi
            done
    
            if [[ $success -eq 0 ]]; then
                echo "$(timestamp) [ERROR] 文件上传失败，保留本地文件: $file" | tee -a "$LOG_FILE"
            fi
        fi
    done < <(inotifywait -m -r -e close_write,moved_to --format "%w%f" "$SRC_DIR")
EOF
    chmod +x /root/autoupload
    echo -e "${green}自动上传部署完成 ${plain}\n"
}
#######################################################自动上传部署##############################################################


#######################################################开机启动部署##############################################################
deploy_systemd() {
    echo -e "${green}开机启动部署 ${plain}\n"
    #自动监控和上传开机启动代码并用于网页中的路由
    cat <<'EOF' > /etc/systemd/system/baidupcs-go.service
    [Unit]
    Description=BaiduPCS Realtime Upload Service
    After=network.target
    
    [Service]
    Type=simple
    ExecStart=/bin/bash /root/autoupload
    Restart=always
    RestartSec=3
    StandardOutput=append:/root/logs/pcs_upload.log
    StandardError=append:/root/logs/pcs_upload.log
    User=root
    
    [Install]
    WantedBy=multi-user.target
EOF
    
    #直播录制启动代码并用于网页中的路由
    cat <<'EOF' > /etc/systemd/system/douyinrecorder.service
    [Unit]
    Description=Douyin Recorder Service
    After=network.target
    
    [Service]
    WorkingDirectory=/root
    ExecStart=/usr/bin/python3 /root/DouyinLiveRecorder/main.py
    Restart=always
    RestartSec=5
    StandardOutput=append:/root/logs/douyinrecorder.log
    StandardError=append:/root/logs/douyinrecorder.log
    User=root
    
    [Install]
    WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl start x-ui.service
    systemctl start douyinrecorder.service
    systemctl start baidupcs-go.service
    systemctl enable douyinrecorder.service
    systemctl enable baidupcs-go.service
    systemctl enable x-ui.service
    echo -e "${green}开机启动部署完成 ${plain}\n"
}
#######################################################开机启动部署##############################################################

deploy_all() {
    Package_xui
    deploy_x-ui
    deploy_douyin_recorder
    deploy_autoupload
    deploy_systemd
}

delete_xui() {
    systemctl stop x-ui.service
    systemctl disable x-ui.service
    rm -rf /usr/local/x-ui
    rm -rf /usr/local/bin/x-ui
    rm -rf /etc/systemd/system/x-ui.service
    rm -rf X-Panel*
}

delete_douyin_recorder() {
    systemctl stop douyinrecorder.service
    systemctl disable douyinrecorder.service
    rm -rf /root/DouyinLiveRecorder
    rm -rf /etc/systemd/system/douyinrecorder.service
    rm -rf /root/logs/douyinrecorder.log
}

delete_autoupload() {
    systemctl stop baidupcs-go.service
    systemctl disable baidupcs-go.service
    rm -rf /usr/local/bin/BaiduPCS-Go
    rm -rf /etc/systemd/system/baidupcs-go.service
    rm -rf /root/logs/pcs_upload.log
    rm -rf /root/autoupload
}

delete_all() {
    delete_xui
    delete_douyin_recorder
    delete_autoupload
    rm -rf /root/logs
}

show_menu
