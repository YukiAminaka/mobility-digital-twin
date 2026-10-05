package main

import (
	"context"

	"github.com/YukiAminaka/mobility-digital-twin/internal/server"
)

func main() {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	server.Run(ctx)
}
