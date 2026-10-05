package server

import (
	"context"
	"errors"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/YukiAminaka/mobility-digital-twin/internal/model/client"
	"github.com/YukiAminaka/mobility-digital-twin/internal/model/hub"
	"github.com/YukiAminaka/mobility-digital-twin/internal/model/riderstate"
	"github.com/coder/websocket"
	"github.com/gin-gonic/gin"
)

func handleWebSocket(hub *hub.Hub) gin.HandlerFunc {
	return func(c *gin.Context) {
		conn, err := websocket.Accept(c.Writer, c.Request, nil)
		if err != nil {
			log.Printf("accept failed: %v", err)
			return
		}

		client := client.NewClient(conn)

		hub.Register() <- client

		log.Println("Client connected")

		ctx := c.Request.Context()

		client.WriteLoop(ctx)

		hub.Unregister() <- client

		conn.Close(
			websocket.StatusNormalClosure,
			"",
		)

		log.Println("Client disconnected")
	}
}

func generateDummyData(hub *hub.Hub) {

	ticker := time.NewTicker(time.Second)
	defer ticker.Stop()

	var x float64

	for range ticker.C {

		x++

		state := riderstate.RiderState{
			RiderID:   "rider-01",
			Timestamp: time.Now().UnixMilli(),
			X:         x,
			Y:         0,
			Z:         0,
			Speed:     1,
			Heading:   90,
		}

		hub.Broadcast() <- state
	}
}

func Run(ctx context.Context) {
	hub := hub.NewHub()
	go hub.Run()
	go generateDummyData(hub)

	router := gin.Default()
	router.GET("/ws", handleWebSocket(hub))
	log.Println("server started :8080")

	srv := &http.Server{
		Addr:    ":8080",
		Handler: router.Handler(),
	}

	// サーバーを起動
	go func() {
		// srv.Shutdownが呼ばれるとhttp.ErrServerClosedを返すのでこれは無視する
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("listen: %s\n", err)
		}
	}()

	// 割り込みシグナルを待ち、5秒のタイムアウトで
	// サーバーをグレースフルにシャットダウン。
	quit := make(chan os.Signal, 1)
	// kill（パラメータなし）はデフォルトでsyscall.SIGTERMを送信
	// kill -2はsyscall.SIGINT
	// kill -9はsyscall.SIGKILLですがキャッチできないため追加不要
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Println("Shutdown Server ...")

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Println("Server Shutdown:", err)
	}
	log.Println("Server exiting")
}
