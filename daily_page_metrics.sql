-- =============================
-- 日次ページ指標テーブル (daily_page_metrics)
-- =============================

CREATE OR REPLACE TABLE `mingla-analytics.analytics_280973219.daily_page_metrics` AS

WITH 
-- =============================
-- 1) Search Consoleを日付×URL単位で集計（ホスト名＋パス）
-- =============================
gsc_daily AS (
  SELECT
    data_date AS date_ymd,
    REGEXP_EXTRACT(url, r'^https?://([^/]+)') AS host_name,
    REGEXP_REPLACE(REGEXP_REPLACE(url, r'^https?://[^/]+', ''), r'#.*$', '') AS page_path,
    SUM(impressions) AS impressions,
    SUM(clicks) AS clicks,
    SUM(sum_position) AS sum_position
  FROM `mingla-analytics.searchconsole.searchdata_url_impression`
  WHERE
    -- ホスト名の指定のみ残し、日付の制限を削除
    REGEXP_EXTRACT(url, r'^https?://([^/]+)') = 'mingla.jp'
  GROUP BY
    1, 2, 3
),

-- =============================
-- 2) GA4データを日付×ページパス単位で集計
-- =============================
ga4_daily AS (
  SELECT
    date_ymd,
    page_path,
    COUNT(DISTINCT user_pseudo_id) AS active_users,
    SUM(new_user_flag) AS new_users,
    SUM(session_count) AS sessions,
    SUM(total_engagement_sec) AS total_engagement_sec,
    SUM(purchase_count) AS purchase_count
  FROM `mingla-analytics.analytics_280973219.daily_user_metrics` AS user_metrics
  CROSS JOIN UNNEST(user_metrics.visited_page_paths) AS page_path
  GROUP BY
    date_ymd,
    page_path
)

-- =============================
-- 3) GA4とSearch Consoleを結合
-- =============================
SELECT
  COALESCE(g.date_ymd, a.date_ymd) AS date_ymd,
  'mingla.jp' AS host_name,
  COALESCE(g.page_path, a.page_path) AS page_path,
  
  -- Search Console指標
  COALESCE(g.impressions, 0) AS impressions,
  COALESCE(g.clicks, 0) AS clicks,
  CASE
    WHEN COALESCE(g.impressions, 0) > 0 THEN ROUND(g.clicks / g.impressions, 4)
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
    WHEN COALESCE(a.sessions, 0) > 0 THEN ROUND(a.purchase_count / a.sessions, 4)
    ELSE 0
  END AS cvr_percent,
  
  -- カテゴリ情報
  CASE 
    WHEN COALESCE(g.page_path, a.page_path) LIKE '/category/kanto/%' THEN 'kanto'
    WHEN COALESCE(g.page_path, a.page_path) LIKE '/category/kansai/%' THEN 'kansai'
    WHEN COALESCE(g.page_path, a.page_path) LIKE '/category/hokkaido/%' THEN 'hokkaido'
    ELSE 'other'
  END AS category
  
FROM gsc_daily AS g
FULL OUTER JOIN ga4_daily AS a
  ON g.date_ymd = a.date_ymd
  AND g.page_path = a.page_path
WHERE
  COALESCE(g.page_path, a.page_path) IS NOT NULL; 