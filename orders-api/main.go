package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"time"

	_ "github.com/lib/pq"
	"github.com/redis/go-redis/v9"
)

// Version is injected at build time via -ldflags
var Version = "dev"

type OrderRequest struct {
	Item     string `json:"item"`
	Quantity int    `json:"quantity"`
}

type Server struct {
	db  *sql.DB
	rdb *redis.Client
}

func (s *Server) healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
}

func (s *Server) infoHandler(w http.ResponseWriter, r *http.Request) {
	hostname, _ := os.Hostname()
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]string{
		"service": "orders-api",
		"version": Version,
		"pod":     hostname,
	})
}

func (s *Server) createOrderHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req OrderRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Item == "" || req.Quantity < 1 {
		http.Error(w, "invalid order payload", http.StatusBadRequest)
		return
	}

	var orderID int
	if s.db != nil {
		err := s.db.QueryRow(
			"INSERT INTO orders (item, quantity, status) VALUES ($1, $2, 'new') RETURNING id",
			req.Item, req.Quantity,
		).Scan(&orderID)
		if err != nil {
			http.Error(w, "database error", http.StatusInternalServerError)
			return
		}
	} else {
		orderID = 1
	}

	if s.rdb != nil {
		ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
		defer cancel()
		if err := s.rdb.LPush(ctx, "orders_queue", orderID).Err(); err != nil {
			http.Error(w, "queue error", http.StatusInternalServerError)
			return
		}
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	_ = json.NewEncoder(w).Encode(map[string]any{
		"id":     orderID,
		"item":   req.Item,
		"status": "new",
	})
}

func main() {
	var db *sql.DB
	if dsn := os.Getenv("DATABASE_URL"); dsn != "" {
		var err error
		db, err = sql.Open("postgres", dsn)
		if err != nil {
			log.Fatalf("failed to open db: %v", err)
		}
	}

	var rdb *redis.Client
	if redisAddr := os.Getenv("REDIS_ADDR"); redisAddr != "" {
		rdb = redis.NewClient(&redis.Options{Addr: redisAddr})
	}

	srv := &Server{db: db, rdb: rdb}
	mux := http.NewServeMux()
	mux.HandleFunc("/health", srv.healthHandler)
	mux.HandleFunc("/info", srv.infoHandler)
	mux.HandleFunc("/api/orders", srv.createOrderHandler)

	log.Printf("orders-api %s listening on :8080", Version)
	log.Fatal(http.ListenAndServe(":8080", mux))
}
