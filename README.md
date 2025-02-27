# mingla-analytics 中間テーブル分析フレームワーク

## 概要

このプロジェクトは、mingla.jpウェブサイトのGoogle Analytics 4（GA4）データとSearch Consoleデータを効率的に分析するための中間テーブルフレームワークを提供します。

## アーキテクチャ

このフレームワークは以下の3層構造で設計されています：

1. **ローデータ層**：GA4イベントデータ（`analytics_280973219.events_*`）とSearch Consoleデータ（`searchconsole.*`）
2. **中間テーブル層**：
   - `daily_user_metrics`：日次ユーザー指標テーブル
   - `daily_page_metrics`：日次ページ指標テーブル
3. **レポート層**：
   - `bi_reporting_view`：BIツール用のレポートビュー

## 中間テーブルの説明

### 1. daily_user_metrics

ユーザーごとの日次指標を格納するテーブルです。

**主な列**：
- `date_ymd`：日付
- `user_pseudo_id`：ユーザー識別子
- `new_user_flag`：新規ユーザーフラグ
- `active_user_flag`：アクティブユーザーフラグ
- `session_count`：セッション数
- `total_engagement_sec`：総エンゲージメント時間（秒）
- `purchase_count`：購入数
- `visited_page_paths`：訪問したページパスのリスト（配列）
- `entry_page_path`：最初に訪問したページパス

### 2. daily_page_metrics

ページごとの日次指標を格納するテーブルです。GA4データとSearch Consoleデータを結合しています。

**主な列**：
- `date_ymd`：日付
- `host_name`：ホスト名
- `page_path`：ページパス
- `impressions`：インプレッション数（Search Console）
- `clicks`：クリック数（Search Console）
- `ctr_percent`：クリック率（Search Console）
- `avg_position`：平均掲載順位（Search Console）
- `sessions`：セッション数（GA4）
- `active_users`：アクティブユーザー数（GA4）
- `new_users`：新規ユーザー数（GA4）
- `total_engagement_sec`：総エンゲージメント時間（GA4）
- `purchase_count`：購入数（GA4）
- `avg_engagement_sec`：平均エンゲージメント時間（GA4）
- `cvr_percent`：コンバージョン率（GA4）
- `category`：カテゴリ情報

### 3. bi_reporting_view

BIツール用のレポートビューです。カテゴリ別のサマリーと人気ページランキングを提供します。

## 利点

このフレームワークには以下の利点があります：

1. **パフォーマンスの向上**：
   - 複雑な集計を一度だけ行い、結果を再利用
   - BIツールからのクエリ実行時間の短縮

2. **一貫性の確保**：
   - 指標の定義が統一され、異なる分析間での整合性が向上
   - データの不整合リスクの低減

3. **メンテナンス性の向上**：
   - 指標の定義変更が一箇所で済む
   - コードの重複を削減

4. **コスト削減**：
   - BigQueryの処理量を削減
   - 同じデータに対する重複計算を防止

5. **拡張性**：
   - 新しい分析要件に対して、既存の中間テーブルを活用可能
   - 新しい指標の追加が容易

## 使用方法

### 初期セットアップ

1. `daily_user_metrics.sql`を実行して日次ユーザー指標テーブルを作成
2. `daily_page_metrics.sql`を実行して日次ページ指標テーブルを作成
3. `bi_reporting_view.sql`を実行してBIツール用のレポートビューを作成

### 定期更新

`scheduled_refresh.sql`をBigQueryのスケジュールクエリとして設定し、毎日自動的に中間テーブルを更新します。

### BIツールでの利用

Looker StudioなどのBIツールから`bi_reporting_view`を参照することで、効率的なレポート作成が可能です。

## 注意事項

- テーブル名やフィールド名は、実際のデータ構造に合わせて適宜調整してください
- スケジュールクエリの実行頻度は、データの更新頻度に合わせて設定してください
- 長期間のデータを保持する場合は、パーティショニングやクラスタリングの設定を検討してください 