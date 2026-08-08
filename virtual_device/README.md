## 仮想デバイス

仮想的に生成したGPSデータを、SORACOM ArcとSORACOM Funnelを経由してUDPで送信します。

```text
gps-sender container
  └─ UDP JSON → funnel.soracom.io:23080
       └─ soratun container / SORACOM Arc
            └─ SORACOM Funnel → 設定済みの転送先
```

`gps-sender` は `soratun` コンテナのネットワーク名前空間を共有します。Arc用のインターフェースとルートはコンテナ内だけに作られ、PCのルーティングには影響しません。

### 前提条件

- Linux上でDocker EngineとDocker Composeが利用できること
- ホストのLinuxカーネルでTUN/TAPが利用できること
- SORACOM ArcのバーチャルSIM/Subscriberを作成済みであること
- バーチャルSIM/Subscriberが所属するグループでSORACOM Funnelが有効であること
- Funnelの送信データ形式がJSONに設定されていること

### Arc設定ファイルを配置する

SORACOMユーザーコンソールから取得した接続情報で `soratun/arc.json` を作成します。既存の設定がなければ、サンプルをコピーして各プレースホルダーを実際の値に置き換えます。

```bash
cd virtual_device
cp soratun/arc.json.sample soratun/arc.json
chmod 600 soratun/arc.json
```

`arc.json` の `arcAllowedIPs` は、Funnelのエントリポイントが属する `100.127.0.0/16` をカバーしている必要があります。ユーザーコンソールが出力する設定では、この範囲が複数のCIDRに分割される場合があります。ユーザーコンソールが出力した値を優先し、秘密鍵を含む `arc.json` はGitにコミットしないでください。

### 仮想デバイスを起動する

必要に応じて環境変数を変更します。変更しない場合はComposeに記載されたデフォルト値で動作します。

```bash
cp .env.example .env
docker compose up --build
```

初回ビルド時に、CPUアーキテクチャに合った `soratun` v1.2.8を公式GitHub Releasesから取得し、SHA-256を検証してイメージにインストールします。PCへの `soratun` のインストールは不要です。

正常に送信できると、`gps-sender` のログにFunnelからの `200` 応答と送信JSONが表示されます。

```text
gps-sender-1  | ... Sent seq=1 response='200' payload={"device_id":"bike-001",...}
```

Funnel側の設定によって応答内容は異なる場合があります。UDP応答がタイムアウトしても送信自体が失敗したとは限りませんが、継続して応答がない場合は、Arcのセッション、`arcAllowedIPs`、バーチャルSIM/Subscriberのグループ設定、Funnelのエラーログを確認してください。

次の応答が表示された場合、Arc接続とFunnelまでの通信は成功していますが、バーチャルSIM/Subscriberがグループに所属していません。

```text
400 No group ID is specified: ...
```

SORACOMユーザーコンソールの **SIM管理** で `arc.json` の `simId` に対応するバーチャルSIM/Subscriberを選び、**操作 → 所属グループを変更** から、Funnelを有効化したSIMグループへ所属させてください。詳しくは、SORACOM公式の[グループ切り替え手順](https://users.soracom.io/ja-jp/docs/group-configuration/set-group/)と[Funnelを有効化する手順](https://users.soracom.io/ja-jp/docs/funnel/enable-funnel/)を参照してください。

バックグラウンドで起動する場合と停止する場合は次のとおりです。

```bash
docker compose up --build -d
docker compose logs -f gps-sender
docker compose down
```

### 送信データ

初期値では5秒ごとに東京駅付近から移動するデータを送信します。

```json
{
  "device_id": "bike-001",
  "seq": 1,
  "timestamp": 1720000000000,
  "lat": 35.681236,
  "lon": 139.767125,
  "speed": 8.5,
  "heading": 90.0,
  "status": "smooth"
}
```

設定できる値は [`.env.example`](./.env.example) を参照してください。1秒間隔など高頻度でFunnelを利用する場合は、SORACOMの利用条件と料金も確認してください。

### ローカルテスト

GPS生成処理はSORACOMへ接続せずにテストできます。

```bash
cd data_sender
python -m unittest -v
```

Compose設定の展開結果は次のコマンドで確認できます。

```bash
docker compose config
```
