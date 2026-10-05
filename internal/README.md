# WebSocketサーバー

```
データ
    ↓
WebSocket Server
    ↓
Unity Client
```

WebSocketライブラリは `github.com/coder/websocket` を使用。現在もメンテナンスされており、`context.Context` を自然に扱えて、JSONヘルパーもあるため採用する。 gorilla/websocketは一度アーカイブされた経緯があるため新規ならcoder/websocketが有力な候補となっている様子

## 1. 送信するデータ型

自転車1台の状態を、以下のように定義します(仮)。
位置情報をPLATEAUで扱えるようにする座標変換は後で実装する。

```go
type RiderState struct {
    RiderID   string  `json:"riderId"`
    Timestamp int64   `json:"timestamp"`
    X         float64 `json:"x"`
    Y         float64 `json:"y"`
    Z         float64 `json:"z"`
    Speed     float64 `json:"speed"`
    Heading   float64 `json:"heading"`
}
```

最初は緯度経度ではなく **Unity座標そのもの `x,y,z` を送る**

## 2. 設計

現段階のイメージは以下のように、複数のクライアントにデータをブロードキャストする形になる

```text
Kinesis
   ↓
Go server
   ↓
Unity A
Unity B
Unity C
```

そこで、

- データ生成・受信
- WebSocket通信

を分離する。

```text
                     RiderState
                         │
                         ▼
Kinesis Consumer ──→ broadcast channel
                         │
                         ▼
                      WebSocket Hub
                      /      |      \
                     /       |       \
                  Unity A  Unity B  Unity C
```

## 3. Hub

`hub.go`

WebSocket接続を集中管理する。

```go

type Hub struct {
	clients map[*Client]struct{}

	register chan *Client

	unregister chan *Client

	broadcast chan RiderState
}

func NewHub() *Hub {
	return &Hub{
		clients:    make(map[*Client]struct{}),
		register:   make(chan *Client),
		unregister: make(chan *Client),
		broadcast:  make(chan RiderState, 100),
	}
}

func (h *Hub) Run() {
	for {
		select {
		case client := <-h.register:
			h.clients[client] = struct{}{}

		case client := <-h.unregister:
			delete(h.clients, client)

		case state := <-h.broadcast:
			for client := range h.clients {
				select {
				case client.send <- state:

				default:
					// クライアントが詰まっている場合
					// サーバー全体を止めない
				}
			}
		}
	}
}
```

チャネル broadcast は接続しているクライアントにデータをブロードキャストするために使用する

```go
broadcast chan RiderState
```

例えばKinesisからデータを受け取ったら、

```go
hub.broadcast <- state
```

Hubが接続中のUnityへ配る。

## 4. Client

`client.go`

```go
package main

import (
	"context"
	"log"

	"github.com/coder/websocket"
	"github.com/coder/websocket/wsjson"
)

type Client struct {
	conn *websocket.Conn
	send chan RiderState
}

func (c *Client) WriteLoop(ctx context.Context) {
	for {
		select {
		case <-ctx.Done():
			return

		case state := <-c.send:
			if err := wsjson.Write(ctx, c.conn, state); err != nil {
				log.Printf("WebSocket write error: %v", err)
				return
			}
		}
	}
}
```

各WebSocket接続でクライアントにメッセージを送信する

```text
Hub
 ↓
client.send
 ↓
Client.WriteLoop()
 ↓
WebSocket
 ↓
Unity
```

## 5. WebSocket接続時にClientを登録

```go
package main

import (
	"context"
	"log"
	"net/http"
	"time"

	"github.com/coder/websocket"
)

func websocketHandler(hub *Hub) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {

		conn, err := websocket.Accept(w, r, nil)
		if err != nil {
			log.Printf("accept error: %v", err)
			return
		}

		client := &Client{
			conn: conn,
			send: make(chan RiderState, 32),
		}

		hub.register <- client

		log.Println("Unity connected")

		ctx := context.Background()

		client.WriteLoop(ctx)

		hub.unregister <- client

		conn.Close(
			websocket.StatusNormalClosure,
			"",
		)

		log.Println("Unity disconnected")
	}
}
```

## 6. ダミーデータ生成を独立させる

```go
func generateDummyData(hub *Hub) {

	ticker := time.NewTicker(time.Second)
	defer ticker.Stop()

	var x float64

	for range ticker.C {

		x++

		state := RiderState{
			RiderID:   "rider-01",
			Timestamp: time.Now().UnixMilli(),
			X:         x,
			Y:         0,
			Z:         0,
			Speed:     1,
			Heading:   90,
		}

		hub.broadcast <- state
	}
}
```

この関数を使用する場合`main()` は、以下のようになる。

```go
func main() {

	hub := NewHub()

	go hub.Run()

	go generateDummyData(hub)

	http.HandleFunc(
		"/ws",
		websocketHandler(hub),
	)

	log.Println("server started :8080")

	log.Fatal(
		http.ListenAndServe(":8080", nil),
	)
}
```

ここで２つのgoroutine `go hub.Run()`と`go generateDummyData(hub)`が独立して動きます。

## 7. 全体のデータフロー

```text
generateDummyData()
       │
       │ RiderState
       ▼
┌────────────────┐
│ broadcast chan │
└───────┬────────┘
        │
        ▼
    Hub.Run()
        │
        ├───────────────┐
        │               │
        ▼               ▼
 Client A send      Client B send
        │               │
        ▼               ▼
 WebSocket          WebSocket
        │               │
        ▼               ▼
    Unity A          Unity B
```

ローカルの開発環境ではgenerateDummyData()を使用して、実際のデータを取得して動かす場合は、
generateDummyData()を実データ取得を行う関数に置き換えられる。

例えば以下のようにする

```go
func consumeKinesis(hub *Hub) {

	for {

		records := getRecordsFromKinesis()

		for _, record := range records {

			state := convert(record)

			hub.broadcast <- state
		}
	}
}
```

つまりWebSocket側は、

```text
ダミーデータなのか
Kinesisなのか
MQTTなのか
UDPなのか
```

を意識しない。
