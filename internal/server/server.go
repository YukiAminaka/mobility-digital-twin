package server

import (
	"context"
	"errors"
	"log"
	"net/http"
	"os/signal"
	"syscall"
	"time"

	mdtv1 "github.com/YukiAminaka/mobility-digital-twin/gen/mdt/v1"
	"github.com/YukiAminaka/mobility-digital-twin/internal/dummy"
	"github.com/YukiAminaka/mobility-digital-twin/internal/model/client"
	"github.com/YukiAminaka/mobility-digital-twin/internal/model/hub"
	"github.com/coder/websocket"
	"github.com/gin-gonic/gin"
)

func handleWebSocket(h *hub.Hub) gin.HandlerFunc {
	return func(c *gin.Context) {
		// シャットダウンフラグが立っていれば、WebSocket接続を拒否
		// WebSocket接続をシャットダウンしている間にも、HTTPリクエストが来る可能性があるため、ここでチェックする。
		if h.IsShuttingDown() {
			c.Status(http.StatusServiceUnavailable) // ステータスコード503を返す
			return
		}

		conn, err := websocket.Accept(c.Writer, c.Request, nil)
		if err != nil {
			log.Printf("accept failed: %v", err)
			return
		}

		peer := client.NewClient(conn)
		if !h.Register(peer) {
			// 冒頭のIsShuttingDown()の判定後にWebSocketの停止が始まった場合でも、ここで接続を拒否する。
			peer.CloseNow()
			return
		}
		defer h.Unregister(peer)
		defer peer.CloseNow()
		log.Println("Client connected")

		// Hijack 後の寿命は HTTP リクエストではなく Client/Hub が管理する。
		if err := peer.WriteLoop(context.Background()); err != nil {
			code := websocket.CloseStatus(err)
			if code != websocket.StatusNormalClosure && code != websocket.StatusGoingAway {
				log.Printf("WebSocket error: %v", err)
			}
		}
		log.Println("Client disconnected")
	}
}

// dummySpeed は route を周回するダミーの自転車の速度 (km/h)。
const dummySpeed = 15.0

func generateDummyData(ctx context.Context, h *hub.Hub, route *dummy.Route) {
	ticker := time.NewTicker(time.Second)
	defer ticker.Stop()
	start := time.Now()
	for {
		select {
		case <-ctx.Done():
			return
		case now := <-ticker.C:
			distance := dummySpeed / 3.6 * now.Sub(start).Seconds()
			p, heading := route.At(distance)
			h.Broadcast(&mdtv1.RiderState{
				RiderId:   "rider-01",
				Timestamp: now.UnixMilli(),
				Latitude:  p.Lat,
				Longitude: p.Lon,
				Speed:     dummySpeed,
				Heading:   heading,
			})
		}
	}
}

func Run(ctx context.Context) error {
	ctx, stop := signal.NotifyContext(ctx, syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	route, err := dummy.SampleRoute()
	if err != nil {
		return err
	}

	h := hub.NewHub()

	router := gin.Default()

	router.GET("/ws", handleWebSocket(h))

	srv := &http.Server{
		Addr:              ":8080",
		Handler:           router,
		ReadHeaderTimeout: 5 * time.Second,
	}

	return serve(ctx, srv, h, route)
}

func serve(ctx context.Context, srv *http.Server, h *hub.Hub, route *dummy.Route) error {
	producerCtx, stopProducer := context.WithCancel(ctx)

	producerDone := make(chan struct{})
	go func() {
		defer close(producerDone)
		generateDummyData(producerCtx, h, route)
	}()

	serverErr := make(chan error, 1)
	go func() {
		serverErr <- srv.ListenAndServe()
	}()
	log.Printf("server starting %s", srv.Addr)

	var listenErr error
	select {
	case <-ctx.Done():
	case listenErr = <-serverErr:
	}
	stopProducer()
	<-producerDone
	log.Println("Shutdown Server ...")

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// まずWebSocketサーバーのシャットダウン
	wsErr := h.Shutdown(shutdownCtx)
	// 次にHTTPサーバーのシャットダウン
	httpErr := srv.Shutdown(shutdownCtx)
	if httpErr != nil {
		_ = srv.Close()
	}
	if listenErr == nil {
		listenErr = <-serverErr
	}
	if errors.Is(listenErr, http.ErrServerClosed) {
		listenErr = nil
	}
	log.Println("Server exiting")
	return errors.Join(listenErr, wsErr, httpErr)
}
