// Package dummy は、GPX の経路を一定速度で周回するダミーの走行データを提供する。
package dummy

import (
	_ "embed"
	"encoding/xml"
	"errors"
	"fmt"
	"math"
	"sort"
)

//go:embed sample.gpx
var sampleGPX []byte

const earthRadius = 6378137.0 // m (WGS84 長半径)

type Point struct {
	Lat float64
	Lon float64
}

// Route は終点から始点へ戻る区間を含む周回経路。
type Route struct {
	points []Point
	// cum[i] は始点から points[i] までの距離 (m)。最後の要素は1周の長さ。
	cum []float64
}

type gpxPoint struct {
	Lat float64 `xml:"lat,attr"`
	Lon float64 `xml:"lon,attr"`
}

type gpxFile struct {
	Routes []struct {
		Points []gpxPoint `xml:"rtept"`
	} `xml:"rte"`
	Tracks []struct {
		Segments []struct {
			Points []gpxPoint `xml:"trkpt"`
		} `xml:"trkseg"`
	} `xml:"trk"`
}

// SampleRoute は埋め込んだ sample.gpx の周回経路を返す。
func SampleRoute() (*Route, error) {
	return ParseGPX(sampleGPX)
}

// ParseGPX は GPX の rtept と trkpt を出現順につないだ周回経路を返す。
func ParseGPX(data []byte) (*Route, error) {
	var f gpxFile
	if err := xml.Unmarshal(data, &f); err != nil {
		return nil, fmt.Errorf("parse gpx: %w", err)
	}
	var points []Point
	for _, r := range f.Routes {
		for _, p := range r.Points {
			points = append(points, Point{Lat: p.Lat, Lon: p.Lon})
		}
	}
	for _, t := range f.Tracks {
		for _, s := range t.Segments {
			for _, p := range s.Points {
				points = append(points, Point{Lat: p.Lat, Lon: p.Lon})
			}
		}
	}
	return NewRoute(points)
}

// NewRoute は points を順にたどり、終点から始点へ戻る周回経路を作る。
// 連続する同じ座標は1点にまとめる。
func NewRoute(points []Point) (*Route, error) {
	var deduped []Point
	for _, p := range points {
		if len(deduped) == 0 || deduped[len(deduped)-1] != p {
			deduped = append(deduped, p)
		}
	}
	if len(deduped) > 1 && deduped[0] == deduped[len(deduped)-1] {
		deduped = deduped[:len(deduped)-1]
	}
	if len(deduped) < 2 {
		return nil, errors.New("route needs at least 2 distinct points")
	}

	// 始点を末尾に追加し、終点から始点へ戻る区間も通常の区間として扱う。
	closed := append(deduped, deduped[0])
	cum := make([]float64, len(closed))
	for i := 1; i < len(closed); i++ {
		dx, dy := offset(closed[i-1], closed[i])
		cum[i] = cum[i-1] + math.Hypot(dx, dy)
	}
	return &Route{points: closed, cum: cum}, nil
}

// Length は1周の長さ (m) を返す。
func (r *Route) Length() float64 {
	return r.cum[len(r.cum)-1]
}

// At は始点から経路に沿って distance (m) 進んだ位置と、その区間の進行方向
// (北を0度とした時計回りの角度) を返す。1周を超えた距離は周回として扱う。
func (r *Route) At(distance float64) (Point, float64) {
	d := math.Mod(distance, r.Length())
	if d < 0 {
		d += r.Length()
	}
	// cum[i] > d となる最初の i を探し、区間 [i-1, i] 上の位置を求める。
	i := sort.SearchFloat64s(r.cum, d)
	if i < len(r.cum) && r.cum[i] == d {
		i++
	}
	i = min(max(i, 1), len(r.cum)-1)

	a, b := r.points[i-1], r.points[i]
	t := (d - r.cum[i-1]) / (r.cum[i] - r.cum[i-1])
	p := Point{
		Lat: a.Lat + (b.Lat-a.Lat)*t,
		Lon: a.Lon + (b.Lon-a.Lon)*t,
	}
	dx, dy := offset(a, b)
	heading := math.Mod(math.Atan2(dx, dy)*180/math.Pi+360, 360)
	return p, heading
}

// offset は a から b への東方向・北方向の距離 (m) を返す。
// 短い区間を前提に、平面で近似する。
func offset(a, b Point) (east, north float64) {
	rad := math.Pi / 180
	midLat := (a.Lat + b.Lat) / 2 * rad
	east = (b.Lon - a.Lon) * rad * earthRadius * math.Cos(midLat)
	north = (b.Lat - a.Lat) * rad * earthRadius
	return east, north
}
