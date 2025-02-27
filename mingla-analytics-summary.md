# GCPプロジェクト「mingla-analytics」調査レポート

## プロジェクト基本情報
- **プロジェクトID**: mingla-analytics
- **プロジェクト番号**: 991778499971
- **作成日時**: 2025-01-08
- **ステータス**: アクティブ

## 有効なサービス
主に以下のサービスが有効化されています：
- BigQuery API
- BigQuery Storage API
- BigQuery Connection API
- Cloud Storage API
- Analytics Hub API
- Dataform API
- Cloud Dataplex API
- その他のGCPコアサービス

## データセット
プロジェクトには2つのデータセットがあります：

### 1. analytics_280973219
Google Analyticsのデータを格納しているデータセットです。
- **テーブル**: events_YYYYMMDD（日付ごとのイベントデータ）
- **スキーマ**: イベント日付、イベント名、ユーザー情報、デバイス情報、地理情報、トラフィックソース、eコマース情報など
- **主なイベント**: 
  - page_view
  - session_start
  - first_visit
  - user_engagement
  - scroll
  - click
  - open_booking_site
  - view_item
  - hotel_page_view
  - experience_impression

### 2. searchconsole
Google Search Consoleのデータを格納しているデータセットです。
- **テーブル**:
  - searchdata_site_impression: サイト全体のインプレッションデータ
  - searchdata_url_impression: URL別のインプレッションデータ
  - ExportLog: エクスポートログ
- **スキーマ**:
  - サイトURL、クエリ、国、検索タイプ、デバイス、インプレッション数、クリック数など
- **主なデータ**:
  - サイト: https://mingla.jp/
  - 主要国: 日本（jpn）、アメリカ（usa）など
  - 検索クエリ: 「グランピング」「グランピング 相場」など

## データサンプル

### analytics_280973219.events_20250208
```
+------------+-----------------------+----------+-------+
| event_date |      event_name       | platform | count |
+------------+-----------------------+----------+-------+
| 20250208   | page_view             | WEB      |  4610 |
| 20250208   | session_start         | WEB      |  2522 |
| 20250208   | first_visit           | WEB      |  2087 |
| 20250208   | user_engagement       | WEB      |  1709 |
| 20250208   | scroll                | WEB      |  1409 |
| 20250208   | click                 | WEB      |  1084 |
| 20250208   | open_booking_site     | WEB      |   847 |
| 20250208   | view_item             | WEB      |   787 |
| 20250208   | hotel_page_view       | WEB      |   368 |
| 20250208   | experience_impression | WEB      |   191 |
+------------+-----------------------+----------+-------+
```

### searchconsole.searchdata_site_impression
```
+------------+--------------------+---------+-------------+-------------------+--------------+
| data_date  |      site_url      | country | search_type | total_impressions | total_clicks |
+------------+--------------------+---------+-------------+-------------------+--------------+
| 2025-02-23 | https://mingla.jp/ | jpn     | WEB         |               442 |           14 |
| 2025-02-23 | https://mingla.jp/ | usa     | WEB         |                79 |            0 |
| 2025-02-23 | https://mingla.jp/ | jpn     | IMAGE       |                18 |            0 |
| 2025-02-23 | https://mingla.jp/ | ind     | WEB         |                14 |            0 |
| 2025-02-23 | https://mingla.jp/ | bra     | WEB         |                12 |            0 |
| 2025-02-23 | https://mingla.jp/ | gbr     | WEB         |                 9 |            0 |
| 2025-02-23 | https://mingla.jp/ | fra     | WEB         |                 7 |            0 |
| 2025-02-23 | https://mingla.jp/ | idn     | WEB         |                 4 |            0 |
| 2025-02-23 | https://mingla.jp/ | rus     | WEB         |                 4 |            0 |
| 2025-02-23 | https://mingla.jp/ | mex     | WEB         |                 3 |            0 |
+------------+--------------------+---------+-------------+-------------------+--------------+
```

### searchconsole.searchdata_url_impression
```
+------------+----------------------------------------------+-------------------------------------------+------------------+--------------+
| data_date  |                     url                      |                   query                   | total_impressions | total_clicks |
+------------+----------------------------------------------+-------------------------------------------+------------------+--------------+
| 2025-02-23 | https://mingla.jp/glamping-goingprice/       | グランピング                              |                15 |            0 |
| 2025-02-23 | https://mingla.jp/circus-outdoor/            | circus outdoor tokyo                      |                14 |            0 |
| 2025-02-23 | https://mingla.jp/glamping-goingprice/       | グランピング 相場                         |                12 |            0 |
| 2025-02-23 | https://mingla.jp/sumisunoie-futtsu-takeoka/ | スミスのいえ富津海岸ｄ                    |                 9 |            0 |
| 2025-02-23 | https://mingla.jp/luxuna-ise-shima/          | グランピング ラグ                         |                 8 |            0 |
| 2025-02-23 | https://mingla.jp/sumisunoie-futtsu-takeoka/ | スミスのいえ富津竹岡                      |                 8 |            0 |
| 2025-02-23 | https://mingla.jp/kamiogawa-leisure-pension/ | 上小川レジャーペンション                  |                 5 |            0 |
| 2025-02-23 | https://mingla.jp/shojiko-camping-cottage/   | 精進湖キャンピングコテージ                |                 5 |            0 |
| 2025-02-23 | https://mingla.jp/fureai-glamping-and-bbq/   | fureai グランピング&バーベキュー レビュー |                 5 |            0 |
| 2025-02-23 | https://mingla.jp/tsukubane-aute-camp/       | つくば市 キャンプセンター                 |                 5 |            0 |
+------------+----------------------------------------------+-------------------------------------------+------------------+--------------+
```

## 結論
このプロジェクトは「mingla.jp」というグランピングやアウトドア関連のWebサイトのアナリティクスデータを管理するために使用されています。Google AnalyticsとSearch Consoleのデータが格納されており、サイトのパフォーマンス分析に利用されていると考えられます。

主なコンテンツはグランピング施設やアウトドア体験に関するもので、日本からのトラフィックが最も多く、次いでアメリカなどの国からのアクセスがあります。 