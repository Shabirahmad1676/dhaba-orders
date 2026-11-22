package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestHealthAndInfo(t *testing.T) {
	srv := &Server{}

	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	rr := httptest.NewRecorder()
	srv.healthHandler(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rr.Code)
	}

	Version = "abc1234"
	reqInfo := httptest.NewRequest(http.MethodGet, "/info", nil)
	rrInfo := httptest.NewRecorder()
	srv.infoHandler(rrInfo, reqInfo)

	var body map[string]string
	if err := json.Unmarshal(rrInfo.Body.Bytes(), &body); err != nil {
		t.Fatal(err)
	}
	if body["version"] != "abc1234" {
		t.Fatalf("expected version abc1234, got %s", body["version"])
	}
}

func TestCreateOrderValidation(t *testing.T) {
	srv := &Server{}
	payload := []byte(`{"item":"Chicken Karahi","quantity":2}`)
	req := httptest.NewRequest(http.MethodPost, "/api/orders", bytes.NewBuffer(payload))
	rr := httptest.NewRecorder()
	srv.createOrderHandler(rr, req)

	if rr.Code != http.StatusCreated {
		t.Fatalf("expected 201 Created, got %d", rr.Code)
	}
}
