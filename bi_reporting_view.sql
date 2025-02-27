-- =============================
-- BIツール用レポートビュー (bi_reporting_view)
-- =============================

CREATE OR REPLACE VIEW `mingla-analytics.analytics_280973219.bi_reporting_view` AS

WITH 
-- =============================
-- 1) カテゴリ別サマリー
-- =============================
category_summary AS (
  SELECT
    date_ymd,
    category,
    SUM(impressions) AS impressions,
    SUM(clicks) AS clicks,
    CASE
      WHEN SUM(impressions) > 0 THEN ROUND(100.0 * SUM(clicks) / SUM(impressions), 2)
      ELSE 0
    END AS ctr_percent,
    
    -- 平均掲載順位（インプレッション加重平均）
    ROUND(
      SUM(impressions * avg_position) / NULLIF(SUM(impressions), 0),
      2
    ) AS avg_position,
    
    SUM(sessions) AS sessions,
    SUM(active_users) AS active_users,
    SUM(new_users) AS new_users,
    SUM(total_engagement_sec) AS total_engagement_sec,
    SUM(purchase_count) AS purchase_count,
    
    -- 平均エンゲージメント時間（秒）
    ROUND(
      SUM(total_engagement_sec) / NULLIF(SUM(sessions), 0),
      2
    ) AS avg_engagement_sec,
    
    -- コンバージョン率
    CASE
      WHEN SUM(sessions) > 0 THEN ROUND(100.0 * SUM(purchase_count) / SUM(sessions), 2)
      ELSE 0
    END AS cvr_percent,
    
    -- 新規ユーザー率
    CASE
      WHEN SUM(active_users) > 0 THEN ROUND(100.0 * SUM(new_users) / SUM(active_users), 2)
      ELSE 0
    END AS new_user_percent,
    
    -- データタイプ（サマリー）
    'category_summary' AS data_type
    
  FROM `mingla-analytics.analytics_280973219.daily_page_metrics`
  GROUP BY
    date_ymd,
    category
),

-- =============================
-- 2) 人気ページランキング（カテゴリ別）
-- =============================
popular_pages AS (
  SELECT
    date_ymd,
    category,
    page_path,
    impressions,
    clicks,
    ctr_percent,
    avg_position,
    sessions,
    active_users,
    new_users,
    avg_engagement_sec,
    purchase_count,
    cvr_percent,
    
    -- カテゴリ内でのセッション数ランキング
    ROW_NUMBER() OVER (
      PARTITION BY date_ymd, category
      ORDER BY sessions DESC
    ) AS session_rank,
    
    -- カテゴリ内でのインプレッション数ランキング
    ROW_NUMBER() OVER (
      PARTITION BY date_ymd, category
      ORDER BY impressions DESC
    ) AS impression_rank,
    
    -- データタイプ（詳細）
    'page_detail' AS data_type
    
  FROM `mingla-analytics.analytics_280973219.daily_page_metrics`
)

-- =============================
-- 3) 最終的な結果を出力（サマリーと詳細を結合）
-- =============================
SELECT
  date_ymd,
  category,
  NULL AS page_path,
  impressions,
  clicks,
  ctr_percent,
  avg_position,
  sessions,
  active_users,
  new_users,
  avg_engagement_sec,
  purchase_count,
  cvr_percent,
  new_user_percent,
  0 AS session_rank,
  0 AS impression_rank,
  data_type
FROM category_summary

UNION ALL

SELECT
  date_ymd,
  category,
  page_path,
  impressions,
  clicks,
  ctr_percent,
  avg_position,
  sessions,
  active_users,
  new_users,
  avg_engagement_sec,
  purchase_count,
  cvr_percent,
  CASE
    WHEN active_users > 0 THEN ROUND(100.0 * new_users / active_users, 2)
    ELSE 0
  END AS new_user_percent,
  session_rank,
  impression_rank,
  data_type
FROM popular_pages
WHERE
  -- 上位10位までのページのみを表示
  session_rank <= 10 OR impression_rank <= 10

ORDER BY
  date_ymd,
  category,
  data_type DESC,  -- サマリーを先に表示
  session_rank; 