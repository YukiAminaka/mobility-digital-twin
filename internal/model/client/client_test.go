package client

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/YukiAminaka/mobility-digital-twin/internal/model/riderstate"
	"github.com/coder/websocket"
	"github.com/coder/websocket/wsjson"
)

func connectedClient(t *testing.T) (*Client, *websocket.Conn) {
	t.Helper()
	accepted := make(chan *websocket.Conn, 1)
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		conn, err := websocket.Accept(w, r, nil)
		if err == nil {
			accepted <- conn
		}
	}))
	t.Cleanup(srv.Close)
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	remote, _, err := websocket.Dial(ctx, srv.URL, nil)
	if err != nil {
		t.Fatal(err)
	}
	c := NewClient(<-accepted)
	t.Cleanup(func() { c.CloseNow(); _ = remote.CloseNow() })
	return c, remote
}

func startWriter(c *Client) <-chan error {
	done := make(chan error, 1)
	go func() { done <- c.WriteLoop(context.Background()) }()
	return done
}

func waitWriter(t *testing.T, done <-chan error) error {
	t.Helper()
	select {
	case err := <-done:
		return err
	case <-time.After(2 * time.Second):
		t.Fatal("writer did not exit")
		return nil
	}
}

func TestLatestStatePerRider(t *testing.T) {
	c, remote := connectedClient(t)
	c.Enqueue(riderstate.RiderState{RiderID: "a", X: 1})
	c.Enqueue(riderstate.RiderState{RiderID: "b", X: 2})
	c.Enqueue(riderstate.RiderState{RiderID: "a", X: 3})
	done := startWriter(c)
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	for _, want := range []riderstate.RiderState{{RiderID: "a", X: 3}, {RiderID: "b", X: 2}} {
		var got riderstate.RiderState
		if err := wsjson.Read(ctx, remote, &got); err != nil {
			t.Fatal(err)
		}
		if got != want {
			t.Fatalf("got %+v, want %+v", got, want)
		}
	}
	if err := remote.Close(websocket.StatusNormalClosure, ""); err != nil {
		t.Fatal(err)
	}
	if err := waitWriter(t, done); websocket.CloseStatus(err) != websocket.StatusNormalClosure {
		t.Fatalf("got %v, want normal closure", err)
	}
}

func TestPendingRiderLimit(t *testing.T) {
	c := NewClient(nil)
	defer c.cancel()
	for i := 0; i <= maxPendingRiders; i++ {
		c.Enqueue(riderstate.RiderState{RiderID: fmt.Sprint(i)})
	}
	for i := 1; i <= maxPendingRiders; i++ {
		got, ok := c.next()
		if !ok || got.RiderID != fmt.Sprint(i) {
			t.Fatalf("got %+v, %v; want rider %d", got, ok, i)
		}
	}
	if _, ok := c.next(); ok {
		t.Fatal("pending queue exceeded its limit")
	}
}

func TestWriteTimeout(t *testing.T) {
	c, _ := connectedClient(t)
	// The peer does not read; this message exceeds the TCP send buffer.
	c.Enqueue(riderstate.RiderState{RiderID: strings.Repeat("x", 8<<20)})
	err := waitWriter(t, startWriter(c))
	if !errors.Is(err, context.DeadlineExceeded) {
		t.Fatalf("got %v, want deadline exceeded", err)
	}
}

func TestPingTimeout(t *testing.T) {
	c, _ := connectedClient(t)
	// Without a reader the peer cannot respond with Pong.
	err := waitWriter(t, startWriter(c))
	if !errors.Is(err, context.DeadlineExceeded) {
		t.Fatalf("got %v, want deadline exceeded", err)
	}
}
