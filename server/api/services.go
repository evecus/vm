package api

import (
	"bytes"
	"net/http"
	"os"
	"os/exec"
	"strings"

	"github.com/gin-gonic/gin"
)

func GetServices(c *gin.Context) {
	out := runCmd("systemctl", "list-units", "--type=service", "--all",
		"--no-pager", "--no-legend", "--plain")

	enabledOut := runCmd("systemctl", "list-unit-files", "--type=service",
		"--no-pager", "--no-legend", "--plain")

	enabledMap := map[string]bool{}
	for _, line := range strings.Split(enabledOut, "\n") {
		fields := strings.Fields(line)
		if len(fields) >= 2 {
			enabledMap[fields[0]] = fields[1] == "enabled"
		}
	}

	result := []gin.H{}
	for _, line := range strings.Split(out, "\n") {
		if strings.TrimSpace(line) == "" {
			continue
		}
		fields := strings.Fields(line)
		if len(fields) < 4 {
			continue
		}
		name := fields[0]
		loadState := fields[1]
		activeState := fields[2]
		subState := fields[3]
		description := ""
		if len(fields) > 4 {
			description = strings.Join(fields[4:], " ")
		}
		result = append(result, gin.H{
			"name":        name,
			"description": description,
			"loadState":   loadState,
			"activeState": activeState,
			"subState":    subState,
			"enabled":     enabledMap[name],
		})
	}
	c.JSON(http.StatusOK, gin.H{"services": result})
}

func ServiceAction(c *gin.Context) {
	name := c.Param("name")
	var req struct {
		Action string `json:"action"`
	}
	if err := c.BindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
		return
	}
	allowed := map[string]bool{
		"start": true, "stop": true, "restart": true,
		"reload": true, "enable": true, "disable": true,
	}
	if !allowed[req.Action] {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid action"})
		return
	}
	var buf bytes.Buffer
	cmd := exec.Command("systemctl", req.Action, name)
	cmd.Stderr = &buf
	if err := cmd.Run(); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": strings.TrimSpace(buf.String())})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true})
}

func GetServiceUnit(c *gin.Context) {
	name := strings.TrimSuffix(c.Param("name"), ".service")
	paths := []string{
		"/etc/systemd/system/" + name + ".service",
		"/lib/systemd/system/" + name + ".service",
		"/usr/lib/systemd/system/" + name + ".service",
	}
	for _, p := range paths {
		if data, err := os.ReadFile(p); err == nil {
			c.JSON(http.StatusOK, gin.H{"content": string(data), "path": p})
			return
		}
	}
	c.JSON(http.StatusNotFound, gin.H{"error": "unit file not found"})
}

func CreateService(c *gin.Context) {
	var req struct {
		Name        string `json:"name"`
		Description string `json:"description"`
		ExecStart   string `json:"execStart"`
		WorkingDir  string `json:"workingDir"`
		User        string `json:"user"`
		Restart     string `json:"restart"`
		WantedBy    string `json:"wantedBy"`
	}
	if err := c.BindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
		return
	}
	if req.Name == "" || req.ExecStart == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "name and execStart required"})
		return
	}
	for _, ch := range req.Name {
		if !((ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') ||
			(ch >= '0' && ch <= '9') || ch == '-' || ch == '_') {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid service name"})
			return
		}
	}
	if req.Restart == "" {
		req.Restart = "on-failure"
	}
	if req.WantedBy == "" {
		req.WantedBy = "multi-user.target"
	}
	unit := buildUnit(req.Description, req.ExecStart, req.WorkingDir, req.User, req.Restart, req.WantedBy)
	path := "/etc/systemd/system/" + req.Name + ".service"
	if err := os.WriteFile(path, []byte(unit), 0644); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	runCmd("systemctl", "daemon-reload")
	c.JSON(http.StatusOK, gin.H{"success": true, "path": path})
}

func UpdateService(c *gin.Context) {
	name := strings.TrimSuffix(c.Param("name"), ".service")
	var req struct {
		Description string `json:"description"`
		ExecStart   string `json:"execStart"`
		WorkingDir  string `json:"workingDir"`
		User        string `json:"user"`
		Restart     string `json:"restart"`
		WantedBy    string `json:"wantedBy"`
	}
	if err := c.BindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
		return
	}
	if req.Restart == "" {
		req.Restart = "on-failure"
	}
	if req.WantedBy == "" {
		req.WantedBy = "multi-user.target"
	}
	unit := buildUnit(req.Description, req.ExecStart, req.WorkingDir, req.User, req.Restart, req.WantedBy)
	path := "/etc/systemd/system/" + name + ".service"
	if err := os.WriteFile(path, []byte(unit), 0644); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	runCmd("systemctl", "daemon-reload")
	c.JSON(http.StatusOK, gin.H{"success": true})
}

func DeleteService(c *gin.Context) {
	name := strings.TrimSuffix(c.Param("name"), ".service")
	runCmd("systemctl", "stop", name+".service")
	runCmd("systemctl", "disable", name+".service")
	if err := os.Remove("/etc/systemd/system/" + name + ".service"); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	runCmd("systemctl", "daemon-reload")
	c.JSON(http.StatusOK, gin.H{"success": true})
}

func buildUnit(desc, execStart, workingDir, user, restart, wantedBy string) string {
	var sb strings.Builder
	sb.WriteString("[Unit]\n")
	if desc != "" {
		sb.WriteString("Description=" + desc + "\n")
	}
	sb.WriteString("After=network.target\n\n[Service]\nType=simple\n")
	if user != "" {
		sb.WriteString("User=" + user + "\n")
	}
	if workingDir != "" {
		sb.WriteString("WorkingDirectory=" + workingDir + "\n")
	}
	sb.WriteString("ExecStart=" + execStart + "\n")
	sb.WriteString("Restart=" + restart + "\nRestartSec=5\n\n[Install]\nWantedBy=" + wantedBy + "\n")
	return sb.String()
}
