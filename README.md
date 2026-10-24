## 全体の処理の流れ

```text
車載デバイス
  ↓ UDP
SORACOM Air
  ↓
SORACOM Funnel
  ↓
Amazon Kinesis Data Streams
  ↓
リアルタイム処理サーバ ECS / EC2
  ↓ WebSocket
シミュレータ / Unity + PLATEAU
```

### それぞれの役割

```text
SORACOM Funnel
  デバイスからのUDPデータをAWSへ転送

Kinesis Data Streams
  高頻度な時系列データを一時的に受ける入口

ECS / EC2
  WebSocketサーバを配置

WebSocketサーバ
  シミュレータ側へリアルタイム配信

S3
  後から分析するためのログ保存
```


## 送信データの例

```json
{
  "device_id": "bike-001",
  "seq": 12345,
  "timestamp": 1720000000000,
  "lat": 35.0,
  "lon": 139.0,
  "speed": 8.5,
  "heading": 90.0,
  "status": "smooth"
}
```
