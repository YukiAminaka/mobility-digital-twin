package client

import (
	"context"
	"log"

	"github.com/YukiAminaka/mobility-digital-twin/internal/model/riderstate"
	"github.com/coder/websocket"
	"github.com/coder/websocket/wsjson"
)

// 接続しているクライアントを表す構造体
type Client struct {
    conn     *websocket.Conn          // clientのコネクション
    send chan riderstate.RiderState
}

func NewClient(conn *websocket.Conn) *Client {
    c := &Client{
        conn:     conn,
        send: make(chan riderstate.RiderState),
    }
    return c
}

func (c *Client) Conn() *websocket.Conn{
    return c.conn
}

func (c *Client) Send() chan riderstate.RiderState {
    return c.send
}

func (c *Client) WriteLoop(ctx context.Context) {
    for {
        select {
        case <-ctx.Done():
            return
        
        case state := <-c.send:
            if err := wsjson.Write(ctx,c.conn, state); err != nil {
                log.Printf("WebSocket write error: %v", err)
                return
            }
        }
    }
}