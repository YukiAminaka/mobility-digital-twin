package hub

import (
	"github.com/YukiAminaka/mobility-digital-twin/internal/model/client"
	"github.com/YukiAminaka/mobility-digital-twin/internal/model/riderstate"
)

type Hub struct {
    clients    map[*client.Client]bool
    broadcast  chan riderstate.RiderState
    register   chan *client.Client
    unregister chan *client.Client
}

func NewHub() *Hub {
  return &Hub{
    clients: make(map[*client.Client]bool),
	register: make(chan *client.Client),
	unregister: make(chan *client.Client),
	broadcast: make(chan riderstate.RiderState, 100),
  }
}

func (h *Hub) Run() {
  for {
    select {
    case client := <-h.register:
      h.clients[client] = true
    
    case client := <-h.unregister:
      delete(h.clients, client)
    
    case state := <-h.broadcast:
      for client := range h.clients {
        select {
        case client.Send() <- state:

        default:
        }
      }
    }
  }
}

func (h *Hub) Register() chan *client.Client {
  return h.register
}

func (h *Hub) Unregister() chan *client.Client {
  return h.unregister
}

func (h *Hub) Broadcast() chan riderstate.RiderState {
  return h.broadcast
}
