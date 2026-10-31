package dummy

import (
	"math"
	"testing"
)

func TestSampleRoute(t *testing.T) {
	r, err := SampleRoute()
	if err != nil {
		t.Fatal(err)
	}
	if r.Length() < 100 {
		t.Fatalf("length = %v m, want a loop of at least 100 m", r.Length())
	}
}

func TestParseGPXTrack(t *testing.T) {
	data := []byte(`<gpx><trk><trkseg>
		<trkpt lat="35" lon="139"></trkpt>
		<trkpt lat="35.001" lon="139"></trkpt>
	</trkseg></trk></gpx>`)
	r, err := ParseGPX(data)
	if err != nil {
		t.Fatal(err)
	}
	if len(r.points) != 3 {
		t.Fatalf("got %d points, want 2 plus closing point", len(r.points))
	}
}

func TestNewRouteNeedsTwoPoints(t *testing.T) {
	if _, err := NewRoute([]Point{{35, 139}, {35, 139}}); err == nil {
		t.Fatal("expected error for a single distinct point")
	}
}

func TestAt(t *testing.T) {
	// 北 → 東 → 南 → 西 と進む四角形。
	square := []Point{{35, 139}, {35.001, 139}, {35.001, 139.001}, {35, 139.001}}
	r, err := NewRoute(square)
	if err != nil {
		t.Fatal(err)
	}
	side := r.cum[1]
	// 経度方向の辺は緯度方向の辺より短い。
	last := r.Length() - r.cum[3]
	tests := []struct {
		name     string
		distance float64
		want     Point
		heading  float64
	}{
		{"start", 0, Point{35, 139}, 0},
		{"middle of first side", side / 2, Point{35.0005, 139}, 0},
		{"second corner", side, Point{35.001, 139}, 90},
		{"closing side", r.Length() - last/2, Point{35, 139.0005}, 270},
		{"wraps around", r.Length() + side/2, Point{35.0005, 139}, 0},
		{"negative", -last / 2, Point{35, 139.0005}, 270},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, heading := r.At(tt.distance)
			if math.Abs(got.Lat-tt.want.Lat) > 1e-6 || math.Abs(got.Lon-tt.want.Lon) > 1e-6 {
				t.Fatalf("position = %+v, want %+v", got, tt.want)
			}
			if math.Abs(heading-tt.heading) > 0.1 {
				t.Fatalf("heading = %v, want %v", heading, tt.heading)
			}
		})
	}
}
