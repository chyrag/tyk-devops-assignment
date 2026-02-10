package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/TykTechnologies/tyk-devops-assignement/internal/server"
)

func main() {
	// Parse command-line flags
	host := flag.String("host", "0.0.0.0", "Host to bind the server to")
	port := flag.Int("port", 8080, "Port to bind the server to")
	flag.Parse()

	// Create server
	addr := fmt.Sprintf("%s:%d", *host, *port)
	srv := server.New(addr)

	// Start server in a goroutine
	go func() {
		log.Printf("Starting httpbin server on %s", addr)
		if err := srv.Start(); err != nil {
			log.Fatalf("Server failed to start: %v", err)
		}
	}()

	// Wait for interrupt signal for graceful shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("Shutting down server...")

	// Create context with timeout for shutdown
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := srv.Shutdown(ctx); err != nil {
		log.Fatalf("Server forced to shutdown: %v", err)
	}

	log.Println("Server exited")
}
