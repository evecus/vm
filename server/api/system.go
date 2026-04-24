package api

import (
	"bytes"
	"net/http"
	"os/exec"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/shirou/gopsutil/v3/cpu"
	"github.com/shirou/gopsutil/v3/disk"
	"github.com/shirou/gopsutil/v3/host"
	"github.com/shirou/gopsutil/v3/load"
	"github.com/shirou/gopsutil/v3/mem"
	"github.com/shirou/gopsutil/v3/net"
	"github.com/shirou/gopsutil/v3/process"
)

// getPublicIP returns the primary outbound IP by checking the default route.
func getPublicIP() string {
	out, err := exec.Command("ip", "route", "get", "1.1.1.1").Output()
	if err != nil {
		return ""
	}
	// Output like: "1.1.1.1 via 1.2.3.1 dev eth0 src 1.2.3.4 uid 0"
	for _, field := range strings.Fields(string(out)) {
		if field != "src" {
			continue
		}
		// next token is the IP
		break
	}
	fields := strings.Fields(string(out))
	for i, f := range fields {
		if f == "src" && i+1 < len(fields) {
			return fields[i+1]
		}
	}
	return ""
}

type ufwStatus struct {
	Installed bool `json:"installed"`
	Enabled   bool `json:"enabled"`
	RuleCount int  `json:"ruleCount"`
}

func getUFWStatus() ufwStatus {
	// Check if ufw is installed
	if _, err := exec.LookPath("ufw"); err != nil {
		return ufwStatus{Installed: false}
	}
	out, err := exec.Command("ufw", "status", "numbered").Output()
	if err != nil {
		return ufwStatus{Installed: true, Enabled: false}
	}
	body := string(out)
	enabled := strings.Contains(body, "Status: active")
	// Count rule lines: lines starting with "[ "
	count := 0
	for _, line := range strings.Split(body, "\n") {
		if strings.HasPrefix(strings.TrimSpace(line), "[") {
			count++
		}
	}
	return ufwStatus{Installed: true, Enabled: enabled, RuleCount: count}
}

func GetSystemInfo(c *gin.Context) {
	cpuPercent, _ := cpu.Percent(0, false)
	cpuInfo, _ := cpu.Info()
	memInfo, _ := mem.VirtualMemory()
	diskInfo, _ := disk.Usage("/")
	hostInfo, _ := host.Info()
	loadInfo, _ := load.Avg()
	netIO, _ := net.IOCounters(false)

	cpuModel := ""
	cpuCores := 0
	if len(cpuInfo) > 0 {
		cpuModel = cpuInfo[0].ModelName
		cpuCores = int(cpuInfo[0].Cores)
	}

	var netSent, netRecv uint64
	if len(netIO) > 0 {
		netSent = netIO[0].BytesSent
		netRecv = netIO[0].BytesRecv
	}

	c.JSON(http.StatusOK, gin.H{
		"cpu": gin.H{
			"percent": cpuPercent,
			"model":   cpuModel,
			"cores":   cpuCores,
		},
		"memory": gin.H{
			"total":   memInfo.Total,
			"used":    memInfo.Used,
			"free":    memInfo.Free,
			"percent": memInfo.UsedPercent,
		},
		"disk": gin.H{
			"total":   diskInfo.Total,
			"used":    diskInfo.Used,
			"free":    diskInfo.Free,
			"percent": diskInfo.UsedPercent,
		},
		"host": gin.H{
			"hostname":        hostInfo.Hostname,
			"os":              hostInfo.OS,
			"platform":        hostInfo.Platform,
			"platformVersion": hostInfo.PlatformVersion,
			"kernelVersion":   hostInfo.KernelVersion,
			"uptime":          hostInfo.Uptime,
		},
		"load": gin.H{
			"load1":  loadInfo.Load1,
			"load5":  loadInfo.Load5,
			"load15": loadInfo.Load15,
		},
		"network": gin.H{
			"bytesSent": netSent,
			"bytesRecv": netRecv,
		},
		"publicIp": getPublicIP(),
		"ufw":      getUFWStatus(),
	})
}

func GetProcesses(c *gin.Context) {
	procs, err := process.Processes()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	type ProcessInfo struct {
		PID     int32   `json:"pid"`
		Name    string  `json:"name"`
		CPU     float64 `json:"cpu"`
		Memory  float32 `json:"memory"`
		Status  string  `json:"status"`
		User    string  `json:"user"`
		CmdLine string  `json:"cmdline"`
	}

	result := make([]ProcessInfo, 0, len(procs))
	for _, p := range procs {
		name, _ := p.Name()
		cpuPct, _ := p.CPUPercent()
		memPct, _ := p.MemoryPercent()
		status, _ := p.Status()
		user, _ := p.Username()
		cmd, _ := p.Cmdline()

		statusStr := ""
		if len(status) > 0 {
			statusStr = status[0]
		}

		result = append(result, ProcessInfo{
			PID:     p.Pid,
			Name:    name,
			CPU:     cpuPct,
			Memory:  memPct,
			Status:  statusStr,
			User:    user,
			CmdLine: cmd,
		})
	}

	c.JSON(http.StatusOK, gin.H{"processes": result})
}

func KillProcess(c *gin.Context) {
	pidStr := c.Param("pid")
	pid, err := strconv.Atoi(pidStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid pid"})
		return
	}

	p, err := process.NewProcess(int32(pid))
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "process not found"})
		return
	}

	if err := p.Kill(); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true})
}

// runCmd runs a command and returns stdout, ignoring errors gracefully.
func runCmd(name string, args ...string) string {
	var buf bytes.Buffer
	cmd := exec.Command(name, args...)
	cmd.Stdout = &buf
	_ = cmd.Run()
	return strings.TrimSpace(buf.String())
}
