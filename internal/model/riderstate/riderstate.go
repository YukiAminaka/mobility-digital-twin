package riderstate

type RiderState struct {
    RiderID   string  `json:"riderId"`
    Timestamp int64   `json:"timestamp"`
    X         float64 `json:"x"`
    Y         float64 `json:"y"`
    Z         float64 `json:"z"`
    Speed     float64 `json:"speed"`
    Heading   float64 `json:"heading"`
}
