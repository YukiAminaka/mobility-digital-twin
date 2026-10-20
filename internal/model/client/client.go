package client

import (
	"context"
	"sync"
	"time"

	mdtv1 "github.com/YukiAminaka/mobility-digital-twin/gen/mdt/v1"
	"github.com/coder/websocket"
	"google.golang.org/protobuf/proto"
)

const (
	maxPendingRiders = 32
	pingInterval     = 30 * time.Second
	pingTimeout      = 5 * time.Second
	writeTimeout     = 5 * time.Second
)

// Client は送信専用の接続と、RiderID ごとの最新の送信待ち状態を管理する。
type Client struct {
	conn    *websocket.Conn
	mu      sync.Mutex
	pending []*mdtv1.RiderState // 送信待ち状態のスライス
	ready   chan struct{}
	ctx     context.Context
	cancel  context.CancelFunc
}

func NewClient(conn *websocket.Conn) *Client {
	ctx, cancel := context.WithCancel(context.Background())
	return &Client{
		conn: conn, ready: make(chan struct{}, 1), ctx: ctx, cancel: cancel,
	}
}

// Enqueue は送信待ちリストへの追加を行う。ネットワークI/Oは持っていません。
// 同一 RiderID の未送信状態は置換し、台数の上限を超える場合は最も古くから待っている RiderID を除く。
func (c *Client) Enqueue(state *mdtv1.RiderState) {
	c.mu.Lock()
	defer c.mu.Unlock()
	// 送信待ち状態のリストを先頭から走査して、引数state(新しいライダーの状態)とRiderIDが一致した要素があれば置換する。
	for i := range c.pending {
		if c.pending[i].GetRiderId() == state.GetRiderId() {
			c.pending[i] = state
			return
		}
	}
	// 新しい状態を追加する前に、上限を超える場合は先頭の要素を削除して最も古い状態を削除する
	if len(c.pending) == maxPendingRiders {
		copy(c.pending, c.pending[1:])           //[A,B,C] -> [B,C,C]
		c.pending = c.pending[:len(c.pending)-1] // [B,C] ← 末尾に残っていた要素を除去
	}
	c.pending = append(c.pending, state)
	c.notify()
}

func (c *Client) notify() {
	select {
	case c.ready <- struct{}{}:
	default:
	}
}

func (c *Client) next() (*mdtv1.RiderState, bool) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if len(c.pending) == 0 {
		return nil, false
	}
	state := c.pending[0]
	c.pending[0] = nil
	c.pending = c.pending[1:]
	if len(c.pending) > 0 {
		c.notify()
	}
	return state, true
}

// WriteLoop は接続ごとに一度だけ実行し、受信処理で制御フレームを処理する。
// クライアントからのアプリケーションメッセージは受け付けない。
func (c *Client) WriteLoop(ctx context.Context) error {
	ctx, cancel := context.WithCancel(ctx)
	stop := context.AfterFunc(c.ctx, cancel)
	defer stop()
	// v1.8.15 の CloseRead はデータ受信時の Close 内で自身の終了を待つため、
	// 読み取りの終了をここで管理する。
	readDone := make(chan error, 1)
	readStopped := make(chan struct{})
	go func() {
		defer close(readStopped)
		_, _, err := c.conn.Read(ctx)
		if err == nil {
			_ = c.conn.Close(websocket.StatusPolicyViolation, "unexpected data message")
			err = websocket.CloseError{Code: websocket.StatusPolicyViolation, Reason: "unexpected data message"}
		}
		readDone <- err
	}()
	defer func() {
		cancel()
		<-readStopped
	}()

	ticker := time.NewTicker(pingInterval)
	defer ticker.Stop()

	for {
		// selectは実行可能なcaseが複数あるとランダムに選ばれるため、
		// ctx.Done()と他のcaseが同時に成立した場合でも必ずここで抜けるようにする。
		if ctx.Err() != nil {
			return nil
		}

		select {
		case <-ctx.Done():
			return nil
		case err := <-readDone:
			return err
		case <-c.ready:
			state, ok := c.next()
			if !ok {
				continue
			}
			b, err := proto.Marshal(state)
			if err != nil {
				return err
			}
			writeCtx, writeCancel := context.WithTimeout(ctx, writeTimeout)
			err = c.conn.Write(writeCtx, websocket.MessageBinary, b)
			writeCancel()
			if err != nil {
				return err
			}
		// pingフレームを送信してクライアントの死活監視を行う。pingTimeoutを超えてもpongが返ってこなければ切断する。
		case <-ticker.C:
			pingCtx, pingCancel := context.WithTimeout(ctx, pingTimeout)
			err := c.conn.Ping(pingCtx)
			pingCancel()
			if err != nil {
				return err
			}
		}
	}
}

// Close はサーバー停止時に呼び出され、closeフレームを送って接続を正常に終了する。
// ctx がキャンセルされた場合は Close 処理を中断し、Run を強制終了させる。
func (c *Client) Close(ctx context.Context) {
	stop := context.AfterFunc(ctx, c.cancel)
	defer stop()
	_ = c.conn.Close(websocket.StatusGoingAway, "server shutting down")
}

// CloseNow はハンドシェイクなしで即座に接続を切断する。
func (c *Client) CloseNow() {
	c.cancel()
	_ = c.conn.CloseNow()
}
