package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"time"
)

var startTime = time.Now()

type HealthInfo struct {
	Status    string `json:"status"`
	StartedAt string `json:"started_at"`
	Uptime    string `json:"uptime"`
}

func main() {
	http.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		uptime := time.Since(startTime)
		h := HealthInfo{
			Status:    "ok",
			StartedAt: startTime.Format(time.RFC3339),
			Uptime:    fmt.Sprintf("%dh %dm %ds",
				int(uptime.Hours()),
				int(uptime.Minutes())%60,
				int(uptime.Seconds())%60),
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(h)
	})

	port := os.Getenv("PORT")
	if port == "" {
		port = "80" // Render에서 자동 주입, 없으면 80 기본
	}

	fmt.Println("✅ Health check server started on :" + port)
	http.ListenAndServe(":"+port, nil)
}
