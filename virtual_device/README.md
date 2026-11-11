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
- ホストの `/dev/net/tun` をUID 65532から読み書きできること（[TUNデバイスの権限を確認する](#tunデバイスの権限を確認する)）
- SORACOM ArcのバーチャルSIM/Subscriberを作成済みであること
- バーチャルSIM/Subscriberが所属するグループでSORACOM Funnelが有効であること
- Funnelの送信データ形式がJSONに設定されていること

### TUNデバイスの権限を確認する

`soratun` コンテナは非rootユーザー（UID 65532）で実行され、ホストの `/dev/net/tun` をそのままコンテナに渡して使います。コンテナ内のデバイスノードはホストのモードと所有者を引き継ぐため、ホスト側でUID 65532が読み書きできる必要があります。

```bash
ls -l /dev/net/tun
```

多くのディストリビューションでは、systemdの既定のudevルールにより `crw-rw-rw-`（`0666`）になっています。

`crw-------` など、UID 65532が読み書きできないモードになっている場合は、udevルールでモードを設定します。

```bash
echo 'KERNEL=="tun", MODE="0666"' | sudo tee /etc/udev/rules.d/99-tun.rules
sudo udevadm control --reload
sudo udevadm trigger --action=add --sysname-match=tun
sudo udevadm settle
ls -l /dev/net/tun
```

モードが変わらない場合はホストを再起動してください。`setfacl` などのACLだけで許可しても、コンテナ内のデバイスノードには反映されません。

> [!NOTE]
> この手順は、ホストを単一ユーザーで使う前提です。CVE-2026-99281が未修正のカーネルでは、`/dev/net/tun` を開けるローカルユーザーなら誰でも、所有者・グループが設定されていない永続TUN/TAPデバイスに接続できます。`soratun` のインターフェースはコンテナ内にあり、永続化もされないため影響を受けません。ほかのユーザーがいるホストで使う場合は、`uname -r` と `ip -d tuntap show` で状況を確認し、カーネルを更新してください。
>
> 上流カーネルの修正版は系列ごとに異なり、6.12系は6.12.117以降、6.18系は6.18.61以降、7.3系は7.3.2以降、7.4以降は修正済みです。それ以外の系列には上流の修正がありません。ディストリビューションのカーネルは独自のバージョン番号で修正を取り込むため、各ディストリビューションのセキュリティ情報で[CVE-2026-99281](https://www.cve.org/CVERecord?id=CVE-2026-99281)への対応状況を確認してください。

初回セットアップの場合は、このまま[Arc設定ファイルを配置する](#arc設定ファイルを配置する)に進んでください。コンテナは[仮想デバイスを起動する](#仮想デバイスを起動する)で新しく作成されます。

すでにArcを設定してコンテナを作成済みの場合は、古い権限のデバイスノードが残っています。コンテナを再作成してください。

```bash
cd virtual_device
docker compose up -d --force-recreate
```

### Arc設定ファイルを配置する

SORACOMユーザーコンソールから取得した接続情報で `soratun/arc.json` を作成します。既存の設定がなければ、サンプルをコピーして各プレースホルダーを実際の値に置き換えます。

```bash
cd virtual_device
cp soratun/arc.json.sample soratun/arc.json
chmod 600 soratun/arc.json
```

`arc.json` がない状態で `docker compose up` を実行すると、`bind source path does not exist` というエラーで起動が止まります。その場合は上記の手順で `arc.json` を作成してください。

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
  "role": -1.456,
  "pitch": 250.001,
  "heading": 90.0
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
