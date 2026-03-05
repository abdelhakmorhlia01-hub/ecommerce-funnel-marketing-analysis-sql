--  ----------- First 5 records --------------------
SELECT * from users_event LIMIT 5;

-- =================================================
-- 1. SALES FUNNEL ANALYSIS (LAST 30 DAYS)

-- Measure user progression from page view to purchase

WITH 
    -- Identify the most recent date in the dataset
	max_date AS (
        SELECT MAX(event_date)AS last_date FROM users_event
    ),
    
    -- Count unique users at each funnel stage
   sales_funnel AS(
    	SELECT 
    		COUNT(DISTINCT CASE WHEN event_type='page_view' THEN user_id END) AS satge_1_page,
        COUNT(DISTINCT CASE WHEN event_type='add_to_cart' THEN user_id END) AS satge_2_cart,
        COUNT(DISTINCT CASE WHEN event_type='checkout_start' THEN user_id END) AS satge_3_checkout,
        COUNT(DISTINCT CASE WHEN event_type='payment_info' THEN user_id END) AS satge_4_payment,
        COUNT(DISTINCT CASE WHEN event_type='purchase' THEN user_id END) AS satge_5_purchase 
    	FROM users_event 
      CROSS JOIN max_date
    	WHERE event_date >= last_date-INTERVAL 30 DAY 
) 
SELECT * FROM funnel;

-- =============================================
-- 2. FUNNEL CONVERSION RATE ANALYSIS (LAST 30 DAYS)

-- Measure user progression through the ecommerce funnel

WITH 
    -- Identify the most recent date in the dataset
	max_date AS (
        SELECT MAX(event_date)AS last_date FROM users_event
    ),
    
    
    funnel AS(
        -- Each stage counts DISTINCT users to avoid duplication
    	SELECT 
    		  COUNT(DISTINCT CASE WHEN event_type='page_view' THEN user_id END) AS satge_1_page,
          COUNT(DISTINCT CASE WHEN event_type='add_to_cart' THEN user_id END) AS satge_2_cart,
          COUNT(DISTINCT CASE WHEN event_type='checkout_start' THEN user_id END) AS satge_3_checkout,
          COUNT(DISTINCT CASE WHEN event_type='payment_info' THEN user_id END) AS satge_4_payment,
          COUNT(DISTINCT CASE WHEN event_type='purchase' THEN user_id END) AS satge_5_purchase 
    	FROM users_event 
      CROSS JOIN max_date
    	WHERE event_date >= last_date-INTERVAL 30 DAY 
)
-- Calculate stage-to-stage conversion rates
SELECT 
	  ROUND(satge_2_cart *100/satge_1_page)AS view_to_cart,
    ROUND(satge_3_checkout *100/satge_2_cart )AS cart_to_checkout,
    ROUND(satge_4_payment *100/satge_3_checkout) AS checkout_to_payment,
    ROUND(satge_5_purchase *100/satge_4_payment) AS payment_to_purchase,
    ROUND(satge_5_purchase*100/satge_1_page) AS overall_conversion_rate
FROM funnel;

-- ==================================================
-- 3.TRAFFIC SOURCE PERFORMANCE ANALYSIS (LAST 30 DAYS)

-- Evaluate marketing channel efficiency by measuring
with source_funnel as (
   
    -- For each channel, count DISTINCT users at key stages
    -- DISTINCT ensures users are not double-counted.
    SELECT
    	traffic_source,
    	COUNT(DISTINCT CASE WHEN event_type='page_view' THEN user_id END) AS views,
      COUNT(DISTINCT CASE WHEN event_type='add_to_cart' THEN user_id END) AS cart,
      COUNT(DISTINCT CASE WHEN event_type='purchase' THEN user_id END) AS purchase
    FROM users_event
    WHERE event_date>= (SELECT MAX(event_date)AS last_date FROM users_event)- INTERVAL 30 DAY
    GROUP BY traffic_source
)

-- Calculate channel-level conversion rates
-- These metrics allow performance comparison across channels.
SELECT 
	traffic_source,
    views,
    cart,
    purchase,
    ROUND(cart *100/views)AS cart_conversion_rate,
    ROUND(purchase *100/cart)AS purchase_conversion_rate,
    ROUND(purchase *100/views)AS all_conversion_rate
FROM source_funnel 
ORDER by purchase DESC;

-- ===========================================
-- 4.TIME-TO-CONVERSION ANALYSIS (LAST 30 DAYS)
-- Measure the average time (in minutes) users take to move through the shopping journey 

-- Build user-level funnel timestamps
with time_funnel as (
    SELECT
    	user_id,
    	MIN(CASE WHEN event_type='page_view' THEN event_date END) AS view_time,
      MIN(CASE WHEN event_type='add_to_cart' THEN event_date END) AS cart_time,
      MIN(CASE WHEN event_type='purchase' THEN event_date END) AS purchase_time
    FROM users_event
    WHERE event_date>= (SELECT MAX(event_date)AS last_date FROM users_event)- INTERVAL 30 DAY
    GROUP BY user_id
    HAVING MIN(CASE WHEN event_type='purchase' THEN event_date END) IS NOT NULL
)

-- Calculate average time differences (in minutes)
SELECT 
	COUNT(*) AS coverted_users,
    ROUND(AVG (TIMESTAMPDIFF(MINUTE,view_time,cart_time)),2) AS avg_time_view_cart,
    ROUND(AVG (TIMESTAMPDIFF(MINUTE,cart_time,purchase_time)),2) AS avg_time_cart_purchase,
    ROUND(AVG (TIMESTAMPDIFF(MINUTE,view_time,purchase_time)),2) AS avg_total_journey_time
    
FROM time_funnel;

-- ============================================================
-- 5.REVENUE  ANALYSIS (LAST 30 DAYS)
-- Evaluate overall monetization performance by calculating:
-- ------
-- Aggregate revenue-related metrics
-- - viewers: unique users who viewed a product
-- - total_buyers: unique users who completed a purchase
-- - total_revenue: total revenue generated
-- - total_orders: number of purchase transactions
with revenue_funnel as (
    SELECT
    	
    	COUNT(DISTINCT CASE WHEN event_type='page_view' THEN user_id END) AS viewers,
      COUNT(DISTINCT CASE WHEN event_type='purchase'THEN user_id END) AS total_buyers,
    	SUM(CASE WHEN event_type='purchase' THEN amount END ) AS total_revenue,
    	COUNT(CASE WHEN event_type='purchase' THEN product_id END) AS total_orders
    FROM users_event
    WHERE event_date>= (SELECT MAX(event_date)AS last_date FROM users_event)- INTERVAL 30 DAY
    
)

-- Calculate REVENUE KPIs
SELECT 
	viewers,
    total_buyers,
    total_orders,
    total_revenue,
    total_revenue/total_orders as avg_order_value,
    total_revenue/total_buyers as revenue_per_buyer,
    total_revenue/viewers as revenue_per_view    
FROM revenue_funnel
