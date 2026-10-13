# WebSocketサーバー

`github.com/coder/websocket` を使用し、`/ws` に接続した Unity などへ
自転車の状態を JSON のテキストメッセージとして配信する。
現在のデータソースは1秒ごとに更新するダミーデータ。

```text
generateDummyData(ctx, hub) / 将来の Kinesis Consumer
                         │ RiderState
                         ▼
                  Hub.Broadcast(state)
                         │
                ┌────────┴────────┐
                ▼                 ▼
         Client.Enqueue    Client.Enqueue
                │                 │
         Client.WriteLoop  Client.WriteLoop
                │                 │
             Unity A           Unity B
```

## 配信するデータ

```json
{
  "riderId": "rider-01",
  "timestamp": 1720000000000,
  "x": 1,
  "y": 0,
  "z": 0,
  "speed": 1,
  "heading": 90
}
```

`timestamp` は Unix ミリ秒。`x,y,z` は Unity 座標を想定しており、
緯度経度からの座標変換や Kinesis との接続は未実装。

## Hub の接続管理

- `Register(client)` は接続を登録し、停止中なら `false` を返す。
- `Unregister(client)` はハンドラの後片付け完了時に接続を削除する。
- `Broadcast(state)` は各接続の送信待ち状態を更新する。ネットワーク送信は待たない。
- `Shutdown(ctx)` は新規登録を拒否し、全接続の終了通知とハンドラ終了を待つ。

登録・配信・停止判定を Mutex で保護するため、`Hub.Run()` は不要。
登録と停止開始の競合でも、接続が終了処理の対象から漏れないようにする。
チャネルを外部へ公開せず、送信とチャネルの close が競合する操作を避ける。

## 遅いクライアントへの対応

各 Client は最大32個の異なる RiderID の未送信状態を保持する。
同じ RiderID の状態が届くと、その RiderID の未送信状態を最新の到着データで置き換える。
別の RiderID の送信順は維持する。32台を超えた場合は、最も古くから待っている
RiderID の状態を破棄して新しい RiderID を追加する。

すでに送信を開始したメッセージは置き換えない。
全更新の配送や保存を保証するキューではないため、履歴保存は別途実装する。
32台を超える状態を欠落なく扱う必要があれば、上限や配信の分割方法を見直す。

## 接続監視

`Client.WriteLoop(ctx)` は接続ごとに一度だけ実行する。

- 専用の読み取り処理が相手からの Ping・Pong・Close を処理する。
- サーバーは30秒ごとに Ping を送り、Pong を最大5秒待つ。
- JSON の書き込みは1回あたり最大5秒で打ち切る。
- 接続終了や Context の取り消しで書き込みループを終了する。

現在の `/ws` は送信専用。クライアントから通常のデータメッセージを受信すると
`StatusPolicyViolation (1008)` で切断する。
将来、操作コマンドなどを受け付ける場合は、受信処理にメッセージの振り分けを追加する。
使用中の v1.8.15 では `CloseRead` がデータ受信時に自分の終了を待つため、
読み取り処理の起動と終了待ちは Client 内で管理している。

## 終了処理

`server.Run(ctx)` は SIGINT・SIGTERM または引数の Context の取り消しで終了する。
HTTP サーバーの起動失敗時も、データ生成を停止してエラーを返す。

1. ダミーデータ生成を停止し、終了を待つ。
2. Hub を停止状態にし、新規登録を拒否する。`/ws` は停止中に HTTP 503 を返す。
3. 既存の接続へ `StatusGoingAway (1001)` を並行して送信する。
4. 接続の後片付けを待ち、HTTP サーバーを停止する。

終了処理全体の期限は5秒。応答しない接続は読み取り Context を取り消して切断する。
WebSocket 接続は `http.Server.Shutdown` の管理対象外のため、Hub が別途終了させる。
Upgrade と停止開始が重なり、登録を拒否された接続も直ちに閉じる。

## 検証

```sh
go test -race ./...
```

最新状態への置換、キュー上限、Ping/Pong、送信・Pingのタイムアウト、
Close 通知、終了期限、新規接続と終了処理の競合を検証する。
テストにはローカル TCP ポートを開く権限が必要。
