package main

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"time"
)

func main() {
	started := time.Now()
	port := getEnv("PORT", "80")
	bindPort := getEnv("FRPS_BIND_PORT", "7000")
	apiPort := getEnv("FRPS_API_PORT", "7400")
	dashPort := getEnv("FRPS_DASH_PORT", "7500")

	http.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		uptime := time.Since(started).Round(time.Second)
		now := time.Now().Format("2006-01-02 15:04:05")
		fmt.Fprintf(w, "✅ frps server running\nStarted at: %s\nUptime: %s\n", now, uptime)
	})

	// Dashboard proxy
	http.HandleFunc("/dashboard", func(w http.ResponseWriter, r *http.Request) {
		target := fmt.Sprintf("http://127.0.0.1:%s", dashPort)
		proxyLocal(w, r, target)
	})

	// API proxy
	http.HandleFunc("/api/", func(w http.ResponseWriter, r *http.Request) {
		target := fmt.Sprintf("http://127.0.0.1:%s%s", apiPort, r.URL.Path)
		if r.URL.RawQuery != "" {
			target += "?" + r.URL.RawQuery
		}
		proxyLocal(w, r, target)
	})

	// Bind port proxy (일반적으로는 HTTP 불가, 내부 테스트용)
	http.HandleFunc("/bind/", func(w http.ResponseWriter, r *http.Request) {
		target := fmt.Sprintf("http://127.0.0.1:%s%s", bindPort, r.URL.Path)
		proxyLocal(w, r, target)
	})

	fmt.Printf("✅ Healthz and proxy server started on :%s\n", port)
	fmt.Printf("🛰  Proxying ports: bind=%s, api=%s, dashboard=%s\n", bindPort, apiPort, dashPort)
	http.ListenAndServe(":"+port, nil)
}

// 공통 프록시 함수
func proxyLocal(w http.ResponseWriter, r *http.Request, target string) {
	req, err := http.NewRequest(r.Method, target, r.Body)
	if err != nil {
		http.Error(w, "Bad request: "+err.Error(), http.StatusBadRequest)
		return
	}
	req.Header = r.Header.Clone()

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		http.Error(w, "Proxy error: "+err.Error(), http.StatusBadGateway)
		return
	}
	defer resp.Body.Close()

	for k, vv := range resp.Header {
		for _, v := range vv {
			w.Header().Add(k, v)
		}
	}
	w.WriteHeader(resp.StatusCode)
	io.Copy(w, resp.Body)
}

func getEnv(key, def string) string {
	v := os.Getenv(key)
	if v == "" {
		return def
	}
	return v
}
