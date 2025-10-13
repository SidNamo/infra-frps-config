package main

import (
	"fmt"
	"net/http"
	"os"
	"time"
)

func main() {
	started := time.Now()
	port := getEnv("PORT", "80")

	http.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) {
		uptime := time.Since(started).Round(time.Second)
		fmt.Fprintf(w, "✅ frps running\nUptime: %s\n", uptime)
	})

	fmt.Printf("✅ Healthz server started on :%s\n", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		fmt.Println("❌ Failed to start:", err)
	}
}

func getEnv(key, def string) string {
	v := os.Getenv(key)
	if v == "" {
		return def
	}
	return v
}
