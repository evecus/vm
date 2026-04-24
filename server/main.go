package main

import (
	"flag"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"

	"vps-manager/server/api"
	"vps-manager/server/config"
	"vps-manager/server/ws"
)

// errorOnlyLogger only logs requests that result in errors (4xx/5xx).
func errorOnlyLogger() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		c.Next()
		status := c.Writer.Status()
		// Only log errors
		if status >= 400 {
			log.Printf("ERROR %d | %s | %s %s | %v",
				status,
				c.ClientIP(),
				c.Request.Method,
				c.Request.URL.Path,
				time.Since(start),
			)
		}
	}
}

func main() {
	configPath := flag.String("c", "config.yaml", "config file path")
	flag.Parse()

	cfg, err := config.Load(*configPath)
	if err != nil {
		log.Fatalf("failed to load config: %v", err)
	}

	gin.SetMode(gin.ReleaseMode)
	// Use gin.New() instead of gin.Default() to skip built-in logger
	r := gin.New()
	r.Use(gin.Recovery(), errorOnlyLogger())

	r.Use(cors.New(cors.Config{
		AllowAllOrigins:  true,
		AllowMethods:     []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Type", "Authorization", "X-Token"},
		ExposeHeaders:    []string{"Content-Disposition"},
		AllowCredentials: true,
	}))

	// Auth middleware
	authMiddleware := func(c *gin.Context) {
		token := c.GetHeader("X-Token")
		if token == "" {
			token = c.Query("token")
		}
		if token != cfg.Token {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
			return
		}
		c.Next()
	}

	// Public routes
	r.POST("/api/auth/verify", func(c *gin.Context) {
		var req struct {
			Token string `json:"token"`
		}
		if err := c.BindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
			return
		}
		if req.Token != cfg.Token {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid token"})
			return
		}
		c.JSON(http.StatusOK, gin.H{"success": true})
	})

	// Protected routes
	protected := r.Group("/api", authMiddleware)
	{
		// System
		protected.GET("/system/info", api.GetSystemInfo)
		protected.GET("/system/processes", api.GetProcesses)
		protected.DELETE("/system/processes/:pid", api.KillProcess)

		// Services
		protected.GET("/services", api.GetServices)
		protected.POST("/services/:name/action", api.ServiceAction)
		protected.GET("/services/:name/unit", api.GetServiceUnit)
		protected.POST("/services", api.CreateService)
		protected.PUT("/services/:name", api.UpdateService)
		protected.DELETE("/services/:name", api.DeleteService)

		// Files
		protected.GET("/files", api.ListFiles)
		protected.GET("/files/download", api.DownloadFile)
		protected.POST("/files/upload", api.UploadFile)
		protected.POST("/files/mkdir", api.MkDir)
		protected.POST("/files/rename", api.RenameFile)
		protected.DELETE("/files", api.DeleteFile)
		protected.GET("/files/read", api.ReadFile)
		protected.POST("/files/write", api.WriteFile)
		protected.POST("/files/touch", api.TouchFile)
	}

	// WebSocket terminal
	r.GET("/ws/terminal", func(c *gin.Context) {
		token := c.Query("token")
		if token != cfg.Token {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
			return
		}
		ws.HandleTerminal(c.Writer, c.Request)
	})

	addr := ":" + cfg.Port
	log.Printf("VPS Agent starting on %s (TLS: %v)", addr, cfg.TLS.Enabled)

	if cfg.TLS.Enabled {
		if cfg.TLS.Cert == "" || cfg.TLS.Key == "" {
			log.Fatal("TLS enabled but cert/key not provided")
		}
		if err := r.RunTLS(addr, cfg.TLS.Cert, cfg.TLS.Key); err != nil {
			log.Fatalf("server error: %v", err)
		}
	} else {
		if err := r.Run(addr); err != nil {
			log.Fatalf("server error: %v", err)
		}
	}
	os.Exit(0)
}
