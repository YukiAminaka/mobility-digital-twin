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
シミュレータ / Unreal / Unity
```

### それぞれの役割

```text
SORACOM Funnel
  デバイスからのUDPデータをAWSへ転送

Kinesis Data Streams
  高頻度な時系列データを一時的に受ける入口

ECS / EC2
  Kinesisを購読して、順序補正・間引き・JSON変換を行う

WebSocketサーバ
  シミュレータ側へリアルタイム配信

S3
  後から分析するためのログ保存
```

最小構成は以下

```text
SORACOM Funnel
  → Kinesis Data Streams
  → ECS Fargate または EC2
  → WebSocket
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
