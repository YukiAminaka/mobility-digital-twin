package hub

import (
	"context"
	"sync"

	"github.com/YukiAminaka/mobility-digital-twin/internal/model/client"
	"github.com/YukiAminaka/mobility-digital-twin/internal/model/riderstate"
)

type Hub struct {
	mu       sync.Mutex
	clients  map[*client.Client]struct{}
	stopping bool
	sessions sync.WaitGroup
	stopOnce sync.Once
	done     chan struct{}
}

func NewHub() *Hub {
	return &Hub{clients: make(map[*client.Client]struct{}), done: make(chan struct{})}
}

func (h *Hub) IsShuttingDown() bool {
	h.mu.Lock()
	defer h.mu.Unlock()
	return h.stopping
}

// Register と Shutdown の判定を同じロックで行い、停止中の登録を拒否する。
func (h *Hub) Register(c *client.Client) bool {
	h.mu.Lock()
	defer h.mu.Unlock()
	if h.stopping {
		return false
	}
	if _, exists := h.clients[c]; !exists {
		h.clients[c] = struct{}{}
		h.sessions.Add(1)
	}
	return true
}

// Unregister は接続ハンドラの後片付けが完了してから呼ぶ。
func (h *Hub) Unregister(c *client.Client) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if _, exists := h.clients[c]; exists {
		delete(h.clients, c)
		h.sessions.Done()
	}
}

func (h *Hub) Broadcast(state riderstate.RiderState) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if h.stopping {
		return
	}
	for c := range h.clients {
		c.Enqueue(state)
	}
}

func (h *Hub) Shutdown(ctx context.Context) error {
	// 終了処理は一度だけ実行する。
	h.stopOnce.Do(func() {
		h.mu.Lock()
		h.stopping = true
		// 接続一覧の取得
		clients := make([]*client.Client, 0, len(h.clients))
		for c := range h.clients {
			clients = append(clients, c)
		}
		h.mu.Unlock()

		go func() {
			var closing sync.WaitGroup
			for _, c := range clients {
				closing.Add(1)
				go func() {
					defer closing.Done()
					c.Close(ctx)
				}()
			}
			closing.Wait() // 全てのクライアントの終了処理が完了するまで待つ
			h.sessions.Wait() // 接続ハンドラの後片付けが完了するまで待つ(Unregisterでゴルーチン数のカウンタをデクリメントしている)
			close(h.done) // doneチャネルをクローズ
		}()
	})

	select {
	case <-h.done:
		return nil
	case <-ctx.Done():
		return ctx.Err()
	}
}
