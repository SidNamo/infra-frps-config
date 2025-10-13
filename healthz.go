package main

import (
	"encoding/json"
	"fmt"
	"net/http"
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

	fmt.Println("✅ Health check server started on :8080 at", startTime.Format(time.RFC3339))
	http.ListenAndServe(":8080", nil)
}
