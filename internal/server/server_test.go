package server

import (
	"context"
	"errors"
	"net"
	"net/http"
	"net/http/httptest"
	"sync"
	"testing"
	"time"

	mdtv1 "github.com/YukiAminaka/mobility-digital-twin/gen/mdt/v1"
	"github.com/YukiAminaka/mobility-digital-twin/internal/model/hub"
	"github.com/coder/websocket"
	"github.com/gin-gonic/gin"
)

func testServer(t *testing.T) (*hub.Hub, string, <-chan struct{}) {
	t.Helper()
	h := hub.NewHub()
	ended := make(chan struct{}, 32)
	router := gin.New()
	handler := handleWebSocket(h)
	router.GET("/ws", func(c *gin.Context) {
		defer func() { ended <- struct{}{} }()
		handler(c)
	})
	srv := httptest.NewServer(router)
	t.Cleanup(func() {
		ctx, cancel := context.WithTimeout(context.Background(), time.Second)
		defer cancel()
		_ = h.Shutdown(ctx)
		srv.Close()
	})
	return h, srv.URL + "/ws", ended
}

func dial(t *testing.T, url string) *websocket.Conn {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	conn, _, err := websocket.Dial(ctx, url, nil)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = conn.CloseNow() })
	return conn
}

func waitEnded(t *testing.T, ended <-chan struct{}) {
	t.Helper()
	select {
	case <-ended:
	case <-time.After(2 * time.Second):
		t.Fatal("connection handler did not exit")
	}
}

func TestControlFramesAndClientClose(t *testing.T) {
	_, url, ended := testServer(t)
	conn := dial(t, url)
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	conn.CloseRead(ctx)
	if err := conn.Ping(ctx); err != nil {
		t.Fatalf("server did not respond to Ping: %v", err)
	}
	if err := conn.Close(websocket.StatusNormalClosure, ""); err != nil {
		t.Fatal(err)
	}
	waitEnded(t, ended)
}

func TestUnexpectedDataClosesConnection(t *testing.T) {
	_, url, ended := testServer(t)
	conn := dial(t, url)
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	if err := conn.Write(ctx, websocket.MessageText, []byte("unexpected")); err != nil {
		t.Fatal(err)
	}
	_, _, err := conn.Read(ctx)
	if websocket.CloseStatus(err) != websocket.StatusPolicyViolation {
		t.Fatalf("got %v, want policy violation", err)
	}
	waitEnded(t, ended)
}

func TestShutdownNotifiesClientsAndRejectsNewConnections(t *testing.T) {
	h, url, ended := testServer(t)
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	results := make(chan error, 2)
	for i := 0; i < 2; i++ {
		conn := dial(t, url)
		// Ping confirms that registration and the server's read loop have started.
		go func() { _, _, err := conn.Read(ctx); results <- err }()
		if err := conn.Ping(ctx); err != nil {
			t.Fatal(err)
		}
	}
	if err := h.Shutdown(ctx); err != nil {
		t.Fatal(err)
	}
	for i := 0; i < 2; i++ {
		if err := <-results; websocket.CloseStatus(err) != websocket.StatusGoingAway {
			t.Fatalf("got %v, want GoingAway", err)
		}
		waitEnded(t, ended)
	}
	conn, response, err := websocket.Dial(ctx, url, nil)
	if conn != nil {
		_ = conn.CloseNow()
	}
	if err == nil || response == nil || response.StatusCode != http.StatusServiceUnavailable {
		t.Fatalf("new connection was not rejected: response=%v, err=%v", response, err)
	}
}

func TestShutdownDeadlineUnblocksUnresponsiveClient(t *testing.T) {
	h, url, ended := testServer(t)
	conn := dial(t, url)
	// Receiving a broadcast proves that the connection has been registered.
	producerCtx, stopProducer := context.WithCancel(context.Background())
	defer stopProducer()
	producerDone := make(chan struct{})
	go func() {
		defer close(producerDone)
		ticker := time.NewTicker(time.Millisecond)
		defer ticker.Stop()
		for {
			select {
			case <-producerCtx.Done():
				return
			case <-ticker.C:
				h.Broadcast(&mdtv1.RiderState{RiderId: "ready"})
			}
		}
	}()
	readCtx, readCancel := context.WithTimeout(context.Background(), time.Second)
	defer readCancel()
	if _, _, err := conn.Read(readCtx); err != nil {
		t.Fatal(err)
	}
	stopProducer()
	<-producerDone
	// No further reads: the peer will not acknowledge the shutdown Close frame.
	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 30*time.Millisecond)
	defer shutdownCancel()
	if err := h.Shutdown(shutdownCtx); !errors.Is(err, context.DeadlineExceeded) {
		t.Fatalf("got %v, want deadline exceeded", err)
	}
	waitEnded(t, ended)
}

func TestServeStopsOnContextCancellation(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if err := serve(ctx, &http.Server{Addr: "127.0.0.1:0"}, hub.NewHub()); err != nil {
		t.Fatal(err)
	}
}

func TestServeReturnsListenError(t *testing.T) {
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer listener.Close()
	if err := serve(context.Background(), &http.Server{Addr: listener.Addr().String()}, hub.NewHub()); err == nil {
		t.Fatal("expected listen failure")
	}
}

func TestConnectionsRacingShutdownExit(t *testing.T) {
	h, url, _ := testServer(t)
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	var clients sync.WaitGroup
	for i := 0; i < 20; i++ {
		clients.Add(1)
		go func() {
			defer clients.Done()
			conn, _, err := websocket.Dial(ctx, url, nil)
			if err == nil {
				defer conn.CloseNow()
				_, _, _ = conn.Read(ctx)
			}
		}()
	}
	if err := h.Shutdown(ctx); err != nil {
		t.Fatal(err)
	}
	clients.Wait()
	if ctx.Err() != nil {
		t.Fatal("clients survived shutdown")
	}
}
