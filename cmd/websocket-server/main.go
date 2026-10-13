package main

import (
	"context"
	"log"

	"github.com/YukiAminaka/mobility-digital-twin/internal/server"
)

func main() {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	if err := server.Run(ctx); err != nil {
		log.Fatal(err)
	}
}
