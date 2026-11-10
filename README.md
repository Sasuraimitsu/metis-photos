# metis-photos — 商品写真の公開置き場

METIS B2B受注システム（system5）の注文サイトに表示する**商品写真**と、注文サイトの雰囲気づくりに使う**イメージ画像（`site/` フォルダ）**の公開リポジトリです。
GitHub Pages で CDN 配信します（設計：`docs/system5_B2B受注/設計/スタック選定.md` §A1-3）。

- 配信URL：`https://sasuraimitsu.github.io/metis-photos/<ファイル名>`
- system5 側の設定：本番シート `設定_連携.写真ベースURL` = `https://sasuraimitsu.github.io/metis-photos/`
- 表示条件：カタログ（productlist）の `photo` フィールドに**ここに置いたファイル名と完全一致**の値が登録されていること

## 掟（このリポジトリは公開です）

1. **画像ファイルのみ**を置く。カタログJSON・CSV・スプレッドシートの類は**絶対に置かない**（仕入値等の機微はカタログ側にあり、物理分離がこの設計の目的）。
2. **機微が写り込んだ画像は禁止**：納品書・価格メモ・仕入値・サプライヤー名が読める札など。push 前に必ず目視する。
3. **ファイル名＝商品コード（注文キー_コード品）.jpg** に統一する（例：`S2-001.jpg`）。system5 は `photo` フィールドの値をそのまま使う（推測しない）ため、登録値と実ファイル名の一致が唯一の契約。
4. 写真の差し替えは**同名で上書き**する（URL が変わらないのでカタログ側の変更が不要）。

## 写真の追加手順

1. 元写真を `inbox/` フォルダに入れる（**フォルダごと入れてOK**・サブフォルダの中まで探索する。このフォルダは git 管理外。元データは push されない）
   - 別フォルダに同名ファイルがあると後の方はスキップして警告する（重複に気づける）
2. `tools/resize.ps1` を実行 → 長辺1200px・JPEG品質80 に一括変換され、リポジトリ直下に出力される
   - 位置情報などの EXIF は再エンコードで**自動的に除去**される（公開しても安全）
   - ファイル名を商品コードへ変えるには対応表CSV（`元ファイル名,商品コード`）を `-MapCsv` で渡す
3. 出力された画像を目視（機微の写り込みチェック）
4. commit & push → 1〜2分で配信開始
5. productlist 側の `photo` フィールドにファイル名を登録してもらう（プロダクトチームへ依頼文書方式）

### resize.ps1 の使い方

```powershell
# 基本（inbox → リポジトリ直下、ファイル名そのまま）
pwsh -File tools/resize.ps1

# 対応表つき（ファイル名を商品コードへリネーム）
pwsh -File tools/resize.ps1 -MapCsv tools/map.csv
# map.csv の例：
#   元ファイル名,商品コード
#   IMG_1234.jpg,S2-001
#   IMG_1235.jpg,S2-002
```

## サイト用イメージ画像（`site/`）

- 中身：注文サイトの売り場（ゾーン）の雰囲気づくりに使う **AI 生成のイメージ画像**（2026-11-10 追加・22枚）。**商品写真ではない**。
- 配信URL：`https://sasuraimitsu.github.io/metis-photos/site/<用途キー>.jpg`
  - system5 は `設定_連携.写真ベースURL` ＋ `site/` ＋ 用途キー ＋ `.jpg` で引く（設定の追加は不要）
- ファイル名＝**用途キー（小文字）.jpg**（上の掟3「ファイル名＝商品コード」の例外）：
  hero / uni_zone / uni_yellow / uni_red / uni_purple / tuna_zone / tuna_wild / tuna_farmed /
  brand_tai / brand_kanpachi / brand_buri / brand_salmon / brand_shimaaji / brand_hirame /
  oyster_zone / oyster_1〜oyster_5 / catalog / market
- 決まり：
  1. **商品カードには使わない**（商品カードは実物の写真だけ）。商品の実物・産地・ブランド・天然／養殖の証明として見せない。
  2. 画像の中に文字・ロゴ・実在ブランドの箱を入れない。push 前に目視する（掟2と同じ）。
  3. 用途・説明文の一覧表（CSV）は**ここに置かない**（掟1）。一覧は非公開の metis-catalog 側で持つ。
  4. 差し替えは同名で上書き（URL が変わらない）。用途キーを足す・やめるときは system5 の担当へ連絡する。
- 作り方：**元データ（PNG）を元の解像度のまま**変換する。引き伸ばした大きな版は使わない（細部は増えず、重くなるだけ）。
  ```powershell
  pwsh -File tools/resize.ps1 -Source <元データ PNG のフォルダ> -Dest site -MaxEdge 2000
  ```
  resize.ps1 は拡大しないので、長辺 2000px 以下の元データは元の大きさのまま・品質80 になる（1枚 200〜300KB が目安）。

## 注意

- **iPhone の HEIC はそのままでは変換できない**。iPhone 側で「設定 > カメラ > フォーマット > 互換性優先」にするか、転送時に JPEG で書き出す。
- `_test.jpg` は Pages 配信の疎通確認用（商品ではない・削除しない）。
