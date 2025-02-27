-- =============================
-- 日次ユーザー指標テーブル (daily_user_metrics)
-- =============================

CREATE OR REPLACE TABLE `mingla-analytics.analytics_280973219.daily_user_metrics` AS

WITH raw_events AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS date_ymd,
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
  WHERE _TABLE_SUFFIX BETWEEN '20250101' AND FORMAT_DATE('%Y%m%d', CURRENT_DATE())  -- 1月から現在までのデータを処理
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
  user_pseudo_id; 