-- =============================
-- 中間テーブル更新スケジュールクエリ
-- =============================

-- このクエリはBigQueryのスケジュールクエリとして設定することを想定しています
-- 例: 毎日午前3時に前日のデータを処理

DECLARE yesterday_date STRING;
SET yesterday_date = FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY));

-- 1. 日次ユーザー指標テーブルの更新
EXECUTE IMMEDIATE FORMAT("""
CREATE OR REPLACE TABLE `mingla-analytics.analytics_280973219.daily_user_metrics_%s` AS

WITH raw_events AS (
  SELECT
    PARSE_DATE('%%Y%%m%%d', event_date) AS date_ymd,
    user_pseudo_id,
    event_name,
    
    -- ページパス情報を抽出
    REGEXP_EXTRACT(
      (SELECT ep.value.string_value
       FROM UNNEST(event_params) AS ep
       WHERE ep.key = 'page_location'),
      r'^https?://([^/]+)'
    ) AS host_name,
    
    REGEXP_REPLACE(
      (SELECT ep.value.string_value
       FROM UNNEST(event_params) AS ep
       WHERE ep.key = 'page_location'),
      r'^https?://[^/]+', ''
    ) AS page_path,
    
    -- ユーザーの初回タッチタイムスタンプ
    (SELECT ep.value.int_value
     FROM UNNEST(user_properties) AS ep
     WHERE ep.key = 'first_touch_timestamp') AS user_first_touch_timestamp,
    
    -- エンゲージメント時間
    CASE
      WHEN event_name = 'user_engagement' THEN
        (SELECT ep.value.int_value
         FROM UNNEST(event_params) AS ep
         WHERE ep.key = 'engagement_time_msec')
      ELSE 0
    END AS engagement_time_msec,
    
    -- 購入イベント情報
    CASE WHEN event_name = 'purchase' THEN 1 ELSE 0 END AS purchase_count
    
  FROM `mingla-analytics.analytics_280973219.events_*`
  WHERE _TABLE_SUFFIX = '%s'
)

SELECT
  date_ymd,
  user_pseudo_id,
  
  -- 新規ユーザーフラグ（その日が初回訪問日かどうか）
  MAX(CASE 
    WHEN event_name = 'first_visit' THEN 1 
    ELSE 0 
  END) AS new_user_flag,
  
  -- アクティブユーザーフラグ（常に1、このテーブルに存在する = アクティブ）
  1 AS active_user_flag,
  
  -- セッション数
  COUNTIF(event_name = 'session_start') AS session_count,
  
  -- 総エンゲージメント時間（秒）
  SUM(engagement_time_msec) / 1000.0 AS total_engagement_sec,
  
  -- 購入数
  SUM(purchase_count) AS purchase_count,
  
  -- 訪問したページパスのリスト（配列として保存）
  ARRAY_AGG(DISTINCT 
    CASE 
      WHEN host_name = 'mingla.jp' AND page_path IS NOT NULL 
      THEN page_path 
    END 
    IGNORE NULLS
  ) AS visited_page_paths,
  
  -- 最初に訪問したページパス
  ARRAY_AGG(
    CASE 
      WHEN host_name = 'mingla.jp' AND page_path IS NOT NULL 
      THEN page_path 
    END 
    IGNORE NULLS
    ORDER BY engagement_time_msec DESC
    LIMIT 1
  )[OFFSET(0)] AS entry_page_path
  
FROM raw_events
WHERE 
  -- mingla.jpドメインのみを対象とする
  host_name = 'mingla.jp'
GROUP BY
  date_ymd,
  user_pseudo_id
""", yesterday_date, yesterday_date);

-- 2. 日次ページ指標テーブルの更新
EXECUTE IMMEDIATE FORMAT("""
CREATE OR REPLACE TABLE `mingla-analytics.analytics_280973219.daily_page_metrics_%s` AS

WITH 
-- Search Consoleを日付×URL単位で集計（ホスト名＋パス）
gsc_daily AS (
  SELECT
    data_date AS date_ymd,
    REGEXP_EXTRACT(url, r'^https?://([^/]+)') AS host_name,
    REGEXP_REPLACE(url, r'^https?://[^/]+', '') AS page_path,
    SUM(impressions) AS impressions,
    SUM(clicks) AS clicks,
    SUM(sum_position) AS sum_position
  FROM `mingla-analytics.searchconsole.searchdata_url_impression`
  WHERE
    data_date = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
    -- 必要に応じてホスト名を指定
    AND REGEXP_EXTRACT(url, r'^https?://([^/]+)') = 'mingla.jp'
  GROUP BY
    1, 2, 3
),

-- GA4データを日付×ページパス単位で集計
ga4_daily AS (
  SELECT
    date_ymd,
    page_path,
    COUNT(DISTINCT user_pseudo_id) AS active_users,
    SUM(new_user_flag) AS new_users,
    SUM(session_count) AS sessions,
    SUM(total_engagement_sec) AS total_engagement_sec,
    SUM(purchase_count) AS purchase_count
  FROM `mingla-analytics.analytics_280973219.daily_user_metrics_%s` AS user_metrics
  CROSS JOIN UNNEST(user_metrics.visited_page_paths) AS page_path
  GROUP BY
    date_ymd,
    page_path
)

-- GA4とSearch Consoleを結合
SELECT
  COALESCE(g.date_ymd, a.date_ymd) AS date_ymd,
  'mingla.jp' AS host_name,
  COALESCE(g.page_path, a.page_path) AS page_path,
  
  -- Search Console指標
  COALESCE(g.impressions, 0) AS impressions,
  COALESCE(g.clicks, 0) AS clicks,
  CASE
    WHEN COALESCE(g.impressions, 0) > 0 THEN ROUND(100.0 * g.clicks / g.impressions, 2)
    ELSE 0
  END AS ctr_percent,
  CASE
    WHEN COALESCE(g.impressions, 0) > 0 THEN ROUND(g.sum_position / g.impressions, 2)
    ELSE NULL
  END AS avg_position,
  
  -- GA4指標
  COALESCE(a.sessions, 0) AS sessions,
  COALESCE(a.active_users, 0) AS active_users,
  COALESCE(a.new_users, 0) AS new_users,
  COALESCE(a.total_engagement_sec, 0) AS total_engagement_sec,
  COALESCE(a.purchase_count, 0) AS purchase_count,
  
  -- 派生指標
  CASE
    WHEN COALESCE(a.sessions, 0) > 0 THEN ROUND(a.total_engagement_sec / a.sessions, 2)
    ELSE 0
  END AS avg_engagement_sec,
  
  CASE
    WHEN COALESCE(a.sessions, 0) > 0 THEN ROUND(a.purchase_count * 100.0 / a.sessions, 2)
    ELSE 0
  END AS cvr_percent,
  
  -- カテゴリ情報
  CASE 
    WHEN COALESCE(g.page_path, a.page_path) LIKE '/category/kanto/%%' THEN 'kanto'
    WHEN COALESCE(g.page_path, a.page_path) LIKE '/category/kansai/%%' THEN 'kansai'
    WHEN COALESCE(g.page_path, a.page_path) LIKE '/category/hokkaido/%%' THEN 'hokkaido'
    ELSE 'other'
  END AS category
  
FROM gsc_daily AS g
FULL OUTER JOIN ga4_daily AS a
  ON g.date_ymd = a.date_ymd
  AND g.page_path = a.page_path
WHERE
  COALESCE(g.page_path, a.page_path) IS NOT NULL
""", yesterday_date, yesterday_date);

-- 3. 日次テーブルを集約テーブルにマージ
-- 日次ユーザー指標テーブルのマージ
EXECUTE IMMEDIATE FORMAT("""
MERGE INTO `mingla-analytics.analytics_280973219.daily_user_metrics` T
USING `mingla-analytics.analytics_280973219.daily_user_metrics_%s` S
ON T.date_ymd = S.date_ymd AND T.user_pseudo_id = S.user_pseudo_id
WHEN MATCHED THEN
  UPDATE SET
    new_user_flag = S.new_user_flag,
    active_user_flag = S.active_user_flag,
    session_count = S.session_count,
    total_engagement_sec = S.total_engagement_sec,
    purchase_count = S.purchase_count,
    visited_page_paths = S.visited_page_paths,
    entry_page_path = S.entry_page_path
WHEN NOT MATCHED THEN
  INSERT (
    date_ymd,
    user_pseudo_id,
    new_user_flag,
    active_user_flag,
    session_count,
    total_engagement_sec,
    purchase_count,
    visited_page_paths,
    entry_page_path
  )
  VALUES (
    S.date_ymd,
    S.user_pseudo_id,
    S.new_user_flag,
    S.active_user_flag,
    S.session_count,
    S.total_engagement_sec,
    S.purchase_count,
    S.visited_page_paths,
    S.entry_page_path
  )
""", yesterday_date);

-- 日次ページ指標テーブルのマージ
EXECUTE IMMEDIATE FORMAT("""
MERGE INTO `mingla-analytics.analytics_280973219.daily_page_metrics` T
USING `mingla-analytics.analytics_280973219.daily_page_metrics_%s` S
ON T.date_ymd = S.date_ymd AND T.page_path = S.page_path
WHEN MATCHED THEN
  UPDATE SET
    host_name = S.host_name,
    impressions = S.impressions,
    clicks = S.clicks,
    ctr_percent = S.ctr_percent,
    avg_position = S.avg_position,
    sessions = S.sessions,
    active_users = S.active_users,
    new_users = S.new_users,
    total_engagement_sec = S.total_engagement_sec,
    purchase_count = S.purchase_count,
    avg_engagement_sec = S.avg_engagement_sec,
    cvr_percent = S.cvr_percent,
    category = S.category
WHEN NOT MATCHED THEN
  INSERT (
    date_ymd,
    host_name,
    page_path,
    impressions,
    clicks,
    ctr_percent,
    avg_position,
    sessions,
    active_users,
    new_users,
    total_engagement_sec,
    purchase_count,
    avg_engagement_sec,
    cvr_percent,
    category
  )
  VALUES (
    S.date_ymd,
    S.host_name,
    S.page_path,
    S.impressions,
    S.clicks,
    S.ctr_percent,
    S.avg_position,
    S.sessions,
    S.active_users,
    S.new_users,
    S.total_engagement_sec,
    S.purchase_count,
    S.avg_engagement_sec,
    S.cvr_percent,
    S.category
  )
""", yesterday_date);

-- 4. 一時テーブルの削除
EXECUTE IMMEDIATE FORMAT("DROP TABLE IF EXISTS `mingla-analytics.analytics_280973219.daily_user_metrics_%s`", yesterday_date);
EXECUTE IMMEDIATE FORMAT("DROP TABLE IF EXISTS `mingla-analytics.analytics_280973219.daily_page_metrics_%s`", yesterday_date); 