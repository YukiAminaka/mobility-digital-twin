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

	mdtv1 "github.com/YukiAminaka/mobility-digital-twin/gen/mdt/v1"
	"github.com/coder/websocket"
	"google.golang.org/protobuf/proto"
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

// assertElapsed は経過時間が want 以上かつ want+tolerance 以下であることを確認する。
func assertElapsed(t *testing.T, elapsed, want time.Duration) {
	t.Helper()
	const tolerance = 500 * time.Millisecond
	if elapsed < want || elapsed > want+tolerance {
		t.Fatalf("writer exited after %v, want about %v", elapsed, want)
	}
}

func readState(ctx context.Context, conn *websocket.Conn) (*mdtv1.RiderState, error) {
	typ, b, err := conn.Read(ctx)
	if err != nil {
		return nil, err
	}
	if typ != websocket.MessageBinary {
		return nil, fmt.Errorf("got message type %v, want binary", typ)
	}
	state := &mdtv1.RiderState{}
	if err := proto.Unmarshal(b, state); err != nil {
		return nil, err
	}
	return state, nil
}

func TestLatestStatePerRider(t *testing.T) {
	c, remote := connectedClient(t)
	c.Enqueue(&mdtv1.RiderState{RiderId: "a", Latitude: 1})
	c.Enqueue(&mdtv1.RiderState{RiderId: "b", Latitude: 2})
	c.Enqueue(&mdtv1.RiderState{RiderId: "a", Latitude: 3})
	done := startWriter(c)
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	for _, want := range []*mdtv1.RiderState{{RiderId: "a", Latitude: 3}, {RiderId: "b", Latitude: 2}} {
		got, err := readState(ctx, remote)
		if err != nil {
			t.Fatal(err)
		}
		if !proto.Equal(got, want) {
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
		c.Enqueue(&mdtv1.RiderState{RiderId: fmt.Sprint(i)})
	}
	for i := 1; i <= maxPendingRiders; i++ {
		got, ok := c.next()
		if !ok || got.GetRiderId() != fmt.Sprint(i) {
			t.Fatalf("got %+v, %v; want rider %d", got, ok, i)
		}
	}
	if _, ok := c.next(); ok {
		t.Fatal("pending queue exceeded its limit")
	}
}

func TestWriteTimeout(t *testing.T) {
	c, _ := connectedClient(t)
	c.writeTimeout = 100 * time.Millisecond
	// The peer does not read; this message exceeds the TCP send buffer.
	c.Enqueue(&mdtv1.RiderState{RiderId: strings.Repeat("x", 8<<20)})
	start := time.Now()
	err := waitWriter(t, startWriter(c))
	if !errors.Is(err, context.DeadlineExceeded) {
		t.Fatalf("got %v, want deadline exceeded", err)
	}
	assertElapsed(t, time.Since(start), c.writeTimeout)
}

func TestPingTimeout(t *testing.T) {
	c, _ := connectedClient(t)
	c.pingInterval = 100 * time.Millisecond
	c.pingTimeout = 100 * time.Millisecond
	// Without a reader the peer cannot respond with Pong.
	start := time.Now()
	err := waitWriter(t, startWriter(c))
	if !errors.Is(err, context.DeadlineExceeded) {
		t.Fatalf("got %v, want deadline exceeded", err)
	}
	assertElapsed(t, time.Since(start), c.pingInterval+c.pingTimeout)
}
