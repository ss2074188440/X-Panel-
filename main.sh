#!/bin/bash
set -e
url1=$1
url2=$2
url3=$3
######必要软件
apt update -y && apt install -y curl && apt install -y unzip && apt install -y socat
######必要软件
mkdir -p /root/logs
#########################################################x-ui部署###############################################################
cd /root
curl -OL $url1
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
	"x-ui/web/service"
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
	}

	return lc
}

// 页面渲染
func (lc *LiveControlController) page(c *gin.Context) {
        basePath, err := lc.settingService.GetBasePath()
        if err != nil {
            // 如果出错，给个默认值，避免页面打不开
            basePath = "/"
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

    c.JSON(http.StatusOK, gin.H{
        "message": fmt.Sprintf("执行成功: %s %s", req.Action, req.Service),
    })
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
EOF

#编译生成X-Panel面板x-ui
git clone https://github.com/riobard/go-bloom.git
cd go-bloom
git checkout cdc8013cb5b3
curl -OL https://golang.org/dl/go1.23.0.linux-amd64.tar.gz
tar -C /usr/local -xzf go1.23.0.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin
export GOPATH=$HOME/go
go mod init github.com/riobard/go-bloom
cd -
echo "replace github.com/riobard/go-bloom => ./go-bloom" >> $web_go
go mod tidy
CGO_ENABLED=1 GOOS=linux GOARCH=amd64 go build -o x-ui .
cd -
sudo rm -rf /usr/local/go

#下载原xeefei中封装好的X-Panel
curl -L -o /usr/local/x-ui-linux-amd64.tar.gz $url2
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
#########################################################x-ui部署###############################################################



#######################################################直播录制部署##############################################################
cd /root
git clone https://github.com/ihmily/DouyinLiveRecorder.git
cd DouyinLiveRecorder
apt install python3-pip
pip3 install -r requirements.txt
apt update 
apt install -y ffmpeg
echo "https://www.tiktok.com/@user68358021784866/live" >> config/URL_config.ini
echo "https://www.tiktok.com/@faithe322541/live" >> config/URL_config.ini
echo "https://www.tiktok.com/@user7528178744418/live" >> config/URL_config.ini
echo "https://www.tiktok.com/@user2137514441812/live" >> config/URL_config.ini
echo "https://www.tiktok.com/@user33574522621350/live" >> config/URL_config.ini
echo "https://www.tiktok.com/@user90733361298281/live" >> config/URL_config.ini
echo "https://www.tiktok.com/@user2110706062176/live" >> config/URL_config.ini
#######################################################直播录制部署##############################################################

########下载BaiduPcs-go#######
cd /root
curl -OL $url3
unzip *.zip
rm -rf *.zip
cd Baidu*
mv BaiduPCS-Go /usr/local/bin
cd /root
rm -rf Baidu*
apt install -y inotify-tools

cat << 'EOF' > /root/autoupload
#!/bin/bash
# 实时监控 /baby/ 及其子目录下的 mp4 文件
# 一旦有新 mp4 出现（写入完成或移动到目录），即上传到百度网盘并删除本地文件
# 依赖: inotify-tools, BaiduPCS-Go
# 日志: /root/logs/pcs_upload.log

SRC_DIR="/root/DouyinLiveRecorder/downloads"
DEST_DIR="/baby"      # 目标网盘目录（可以改成你想要的）
LOG_FILE="/root/logs/pcs_upload.log"

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

        if BaiduPCS-Go upload "$file" "$DEST_DIR" >> "$LOG_FILE" 2>&1; then
            echo "$(timestamp) [INFO] 上传成功，删除本地文件: $file" | tee -a "$LOG_FILE"
            rm -f "$file"
        else
            echo "$(timestamp) [ERROR] 上传失败，保留文件: $file" | tee -a "$LOG_FILE"
        fi
    fi
done < <(inotifywait -m -r -e close_write,moved_to --format "%w%f" "$SRC_DIR")
EOF
chmod +x /root/autoupload
########下载BaiduPcs-go#######



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
