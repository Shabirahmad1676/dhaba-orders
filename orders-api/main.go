package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	_ "github.com/lib/pq"
	"github.com/redis/go-redis/v9"
)

var Version = "dev"

type Order struct {
	ID       int    `json:"id"`
	Item     string `json:"item"`
	Quantity int    `json:"quantity,omitempty"`
	Status   string `json:"status"`
}

func main() {
	dbURL := os.Getenv("DATABASE_URL")
	redisAddr := os.Getenv("REDIS_ADDR")
	if redisAddr == "" {
		redisAddr = "redis:6379"
	}

	var db *sql.DB
	var err error
	if dbURL != "" {
		db, err = sql.Open("postgres", dbURL)
		if err != nil {
			log.Printf("db open error: %v", err)
		}
	}

	rdb := redis.NewClient(&redis.Options{Addr: redisAddr})

	mux := http.NewServeMux()
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"status":"ok","version":"` + Version + `"}`))
	})

	mux.HandleFunc("/api/orders", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		if db == nil {
			http.Error(w, "database not configured", http.StatusServiceUnavailable)
			return
		}

		switch r.Method {
		case http.MethodGet:
			rows, err := db.Query("SELECT id, item, quantity, status FROM orders ORDER BY id DESC LIMIT 20")
			if err != nil {
				http.Error(w, "database error", http.StatusInternalServerError)
				return
			}
			defer rows.Close()

			orders := make([]Order, 0)
			for rows.Next() {
				var o Order
				if err := rows.Scan(&o.ID, &o.Item, &o.Quantity, &o.Status); err == nil {
					orders = append(orders, o)
				}
			}
			_ = json.NewEncoder(w).Encode(orders)

		case http.MethodPost:
			var req Order
			if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Item == "" {
				http.Error(w, "invalid payload", http.StatusBadRequest)
				return
			}
			if req.Quantity <= 0 {
				req.Quantity = 1
			}

			var id int
			err := db.QueryRow(
				"INSERT INTO orders (item, quantity, status) VALUES ($1, $2, 'new') RETURNING id",
				req.Item, req.Quantity,
			).Scan(&id)
			if err != nil {
				http.Error(w, "database error", http.StatusInternalServerError)
				return
			}

			payload, _ := json.Marshal(map[string]any{"id": id, "item": req.Item, "quantity": req.Quantity})
			_ = rdb.RPush(context.Background(), "orders_queue", payload).Err()

			w.WriteHeader(http.StatusCreated)
			_ = json.NewEncoder(w).Encode(Order{ID: id, Item: req.Item, Status: "new"})

		default:
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		}
	})

	mux.HandleFunc("/api/orders/", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		idStr := strings.TrimPrefix(r.URL.Path, "/api/orders/")
		id, err := strconv.Atoi(idStr)
		if err != nil || db == nil {
			http.Error(w, "invalid id", http.StatusBadRequest)
			return
		}
		var o Order
		err = db.QueryRow("SELECT id, item, quantity, status FROM orders WHERE id=$1", id).Scan(&o.ID, &o.Item, &o.Quantity, &o.Status)
		if err != nil {
			http.Error(w, "not found", http.StatusNotFound)
			return
		}
		_ = json.NewEncoder(w).Encode(o)
	})

	srv := &http.Server{
		Addr:              ":8080",
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
	}
	log.Printf("orders-api listening on :8080 (version=%s)", Version)
	log.Fatal(srv.ListenAndServe())
}
