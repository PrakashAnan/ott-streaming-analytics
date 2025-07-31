use ottanalytics 

--1: Lets understand the data first

select * from [ott_content]   -- 500 rows
select * from ott_users -- 1000 rows
select * from ott_subscriptions   --1000 rows
Select * from ott_watch_history  -- 50k

-- 2.	Detect and Handle Duplicates
-- No duplicate in ott_contents
Select title, genre,release_year
from ott_content
group by title, genre,release_year
having count(*)>1


Select age_group, country from ott_users group by age_group, country having count(*)>1

--3.	Detect Users with Overlapping Subscription Periods
--o	Any users with multiple active plans?

Select 
user_id,
count(distinct plan_type) as Diff_Plan
from ott_subscriptions
group by user_id
having count(distinct plan_type)>1

-- 4.	Missing Country or Age Group Entries
-- o	Find and handle missing demographics in users table.

Select * from ott_users where country='' or country is Null

-- PHASE:-2

-- 1.	Top Genres Watched Overall and Per Platform

SELECT * FROM ott_watch_history
SELECT * FROM ott_content

SELECT 
oc.genre,
oc.platform,
count(wh.user_id) as Total_views
from ott_watch_history wh
join ott_content oc
on wh.content_id = oc.content_id
group by oc.genre,oc.platform

--2.	Most Used Device Types
--o	Which device is most commonly used to stream content?

select 
device_type,
count(*) as No_of_devices
from ott_watch_history
group by device_type
order by No_of_devices desc


-- 3.	Average Watch Duration per Platform
-- o	Breakdown of engagement across Netflix, Prime, etc.

select * from ott_watch_history
select * from ott_content

select 
c.platform,
avg(wh.watch_duration) as avg_time
from ott_content c
join ott_watch_history wh 
on c.content_id = wh.content_id
group by c.platform
order by avg_time desc

-- 4.	Monthly Active Users (MAU) Trend
-- o	Count distinct users watching content each month.

select * from ott_watch_history
select * from ott_content


select
format(watch_date,'yyyy-MM') as Month,
count(distinct user_id) as No_of_users
from ott_watch_history
group by format(watch_date,'yyyy-MM')
order by month desc


--5.	Top 10 Most Watched Titles
--o	Based on total watch time.

select
c.title,
sum(wh.watch_duration) as total_watch_time_min
from ott_watch_history wh 
join ott_content c
on wh.content_id=c.content_id
group by c.title
order by total_watch_time_min desc

--6.	User Retention Analysis
--Are users coming back after signing up? And how long do they stay active?

exec sp_help ott_users

select * from ott_users
select * from ott_watch_history

--Here we are working in three steps
--STEP 1: Find the diffreence between watch_date and signup_date and find max of it.
--STEP 2: THEN COUNT OF ALL USERS, USER IN 30DAYS AND IN 90 DAYS.
--STEP 3: FIND THE PERCENTAGE.

;WITH activity_flags AS (
    SELECT 
        u.user_id,
        MAX(CASE WHEN DATEDIFF(DAY, u.signup_date, vh.watch_date) BETWEEN 1 AND 30 THEN 1 ELSE 0 END) AS active_30,
        MAX(CASE WHEN DATEDIFF(DAY, u.signup_date, vh.watch_date) BETWEEN 1 AND 60 THEN 1 ELSE 0 END) AS active_60,
        MAX(CASE WHEN DATEDIFF(DAY, u.signup_date, vh.watch_date) BETWEEN 1 AND 90 THEN 1 ELSE 0 END) AS active_90
    FROM 
        ott_users u
    LEFT JOIN 
        ott_watch_history vh ON u.user_id = vh.user_id
    GROUP BY 
        u.user_id
),
retention_summary AS (
    SELECT 
        COUNT(*) AS total_users,
        SUM(active_30) AS retained_30,
        SUM(active_60) AS retained_60,
        SUM(active_90) AS retained_90
    FROM 
        activity_flags
)
SELECT 
    total_users,
    retained_30,
    CAST(retained_30 * 100.0 / total_users AS DECIMAL(5,2)) AS pct_retained_30,
    retained_60,
    CAST(retained_60 * 100.0 / total_users AS DECIMAL(5,2)) AS pct_retained_60,
    retained_90,
    CAST(retained_90 * 100.0 / total_users AS DECIMAL(5,2)) AS pct_retained_90
FROM 
    retention_summary;


--7.Binge Watching Pattern
--o.Users watching more than 3 episodes on the same day.

Select * from ott_watch_history
select * from ott_content

select 
wh.user_id,
wh.watch_date,
count(*) as No_of_Episode
from ott_watch_history wh 
join ott_content c 
on wh.content_id= c.content_id
group by wh.user_id,wh.watch_date
having count(*) > 3


select 
user_id,
watch_date,
count(*) as No_of_Episode
from ott_watch_history 
group by user_id,watch_date
having count(*) > 3

-- 8.	Genre Popularity by Age Group
-- o	Preferred content types by age segments.

select * from ott_watch_history
select * from ott_users
select * from ott_content

select 
c.genre,
u.age_group,
count(distinct wh.user_id) as Total_genre
from ott_users u 
join ott_watch_history wh 
on u.user_id = wh.user_id
join ott_content c 
on wh.content_id = c.content_id
group by c.genre, u.age_group
ORDER BY u.age_group, Total_genre DESC


-- Phase 3: Analytical Insights (CTEs, Window Functions, Joins)

--1.	Rank Content by Watch Time Within Each Genre
--o	Use RANK() or DENSE_RANK() over genre. 

;with content_watch_duration as (
Select 
c.genre,
c.title,
sum(wh.watch_duration) as Total_time_in_min
from ott_content c
join ott_watch_history wh 
on c.content_id=wh.content_id
group by c.genre, c.title
),

rank_content as
(
Select
genre,
title,
Total_time_in_min,
rank() over (partition by genre order by Total_time_in_min desc) as genre_rnk
from content_watch_duration
)
Select* from rank_content

--2.	User Quartiles Based on Total Watch Duration
--o	Use NTILE(4) to segment user engagement.


;with user_watched_time as 
(
select user_id,
sum(watch_duration) as total_watched_time
from ott_watch_history
group by user_id
),

quartile_users as 
(
select 
USER_ID,
total_watched_time,
ntile(4) over (order by total_watched_time desc ) as engagement_quartile
from user_watched_time
)

SELECT 
    engagement_quartile,
    COUNT(*) AS user_count,
    MIN(total_watched_time) AS min_watch_time,
    MAX(total_watched_time) AS max_watch_time,
    AVG(total_watched_time) AS avg_watch_time
FROM 
    quartile_users
GROUP BY 
    engagement_quartile
ORDER BY 
    engagement_quartile;


-- 3.	Top Users by Platform (Window Function)
-- o	ROW_NUMBER() to get top watchers per platform

select * from ott_content
select * from ott_watch_history

;with user_watch_time as (
select 
wh.user_id,
c.platform,
sum(wh.watch_duration) as total_watched_time
from ott_watch_history wh
join ott_content c
on wh.content_id = c.content_id
group by user_id, c.platform
),
ranked_users as (
select 
USER_ID,
platform,
total_watched_time,
ROW_NUMBER() over (partition by platform order by total_watched_time desc) as rn
from user_watch_time
)
select * from ranked_users where rn=1


--5.	Year-on-Year Growth in Subscribers and Revenue
-- o	Window functions + LAG() to calculate growth rates.

-- Note: This question will not work on these dataset.

;with yearly_metrics as 
(
select 
USER_ID,
year(start_date) as yr,
count(distinct user_id) as Total_users,
sum(amount) as Total_revenue
from ott_subscriptions
group by USER_ID, year(start_date)
),

yearly_growth as (
select 
yr,
total_revenue,
total_subscribers,
lag(total_subscribers) over (order by year ) as prev_year_subs,
lag(total_revenue) over (order by year ) as prev_year_revenue
from yearly_metrics
) 

select 
yr,
total_revenue,
total_subscribers,
prev_year_subs,
(total_subscribers - prev_year_subs)*100 / prev_year_subs as subs_growth_pct,
(total_revenue - prev_year_revenue ) * 100 / prev_year_revenue as revenue_growth_percentage
from yearly_growth


-- 7.	Content Saturation
-- o	How many unique users have watched a specific content?

Select * from ott_watch_history

Select
title,
count(distinct wh.user_id) as Total_Users
from ott_content c
join ott_watch_history wh 
on wh.content_id = c.content_id
group by title
order by Total_Users desc


-- 9.	Identify Inactive Users (No Activity in Last 90 Days)
-- o	Use MAX(watch_date) + DATEDIFF.

Select 
user_id,
max(watch_date) as last_watch_date,
DATEDIFF(day, max(watch_date),getdate()) days_since_last_watch
from ott_watch_history
group by user_id
having DATEDIFF(day, max(watch_date),getdate())>90
order by days_since_last_watch desc

-- 10.	% of Users Watching Across Multiple Devices
-- o	How many users watched on >1 device type?

Select * from ott_watch_history

;WITH user_count AS (
    SELECT 
        user_id,
        COUNT(DISTINCT device_type) AS Device_Count
    FROM ott_watch_history
    GROUP BY user_id
    HAVING COUNT(DISTINCT device_type) > 3
)
SELECT 
    (COUNT(*) * 100.0) / 
    (SELECT COUNT(DISTINCT user_id) FROM ott_watch_history) AS Pct_of_user_from_multiple_device
FROM user_count;


-- Additional Questions Focused on Percentages

-- 1.	% of Users Who Watched Content on Weekends vs. Weekdays

WITH view_type AS (
  SELECT 
    user_id,
    watch_date,
    CASE 
      WHEN DATEPART(WEEKDAY, watch_date) IN (1,7) THEN 'Weekend'
      ELSE 'Weekday'
    END AS day_type
  FROM ott_watch_history
)

select 
round(count(case when day_type ='weekend' then 1 end) *100.0 / (select count(*) from view_type),2) as pct_weekend,
round(count(case when day_type ='weekday' then 1 end) *100.0 / (select count(*) from view_type),2) as pct_weekday
from view_type

-- 2.	% of Users Who Watched from Multiple Platforms

select * from ott_content
Select * from ott_watch_history

;WITH user_platforms AS (
  SELECT 
    wh.user_id,
    COUNT(DISTINCT c.platform) AS platforms_watched
  FROM ott_watch_history wh
  join ott_content c
  on c.content_id=wh.content_id
  GROUP BY user_id
),
user_classification as
(
Select
USER_ID,
case
	when platforms_watched > 1 then 'Multi-Platform' 
	else 'Single-Platform'
end as platform_type
from user_platforms
)
SELECT 
  platform_type,
  COUNT(*) AS user_count,
  ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM user_classification),2) AS percentage_users
FROM user_classification
GROUP BY platform_type;


-- 3.	% of Users Who Watched at Least 1 Hour Daily on Average

;WITH user_activity AS (
  SELECT 
    user_id,
    SUM(watch_duration) AS total_watch_minutes,
    COUNT(DISTINCT CAST(watch_date AS DATE)) AS active_days
  FROM ott_watch_history
  GROUP BY user_id
), 
qualified_users AS (
  SELECT 
    user_id,
    total_watch_minutes,
    active_days,
    total_watch_minutes * 1.0 / NULLIF(active_days, 0) AS avg_watch_per_day
  FROM user_activity
)
SELECT 
  ROUND(
    COUNT(CASE WHEN avg_watch_per_day >= 60 THEN 1 END) * 100.0 / 
    COUNT(*), 2
  ) AS percentage_users_1hr_or_more
FROM qualified_users;


-- 4.	% Change in Average Watch Duration MoM

WITH monthly_avg AS (
  SELECT 
    FORMAT (watch_date, 'yyyy-MM') AS month,
    AVG(watch_duration) AS avg_watch_duration
  FROM ott_watch_history
  GROUP BY FORMAT (watch_date, 'yyyy-MM')
)
  SELECT 
    month,
    avg_watch_duration,
    LAG(avg_watch_duration) OVER (ORDER BY month) AS prev_month_avg,
	((avg_watch_duration -  LAG(avg_watch_duration) OVER (ORDER BY month)) * 100) /  nullif(LAG(avg_watch_duration) OVER (ORDER BY month),0) as Pct_Mom_Change
  FROM monthly_avg


--5.	% of Users by Country
--o	Distribution of total users by region.

SELECT 
  country,
  COUNT(*) AS total_users,
  ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM ott_users),2) AS percentage_of_users
FROM ott_users
GROUP BY country
ORDER BY percentage_of_users DESC;

-- 6.	% of Titles Watched at Least Once
-- o	Compare distinct content_ids watched vs. total available.

SELECT COUNT(DISTINCT content_id) AS total_titles
FROM ott_content;
SELECT COUNT(DISTINCT content_id) AS watched_titles
FROM ott_watch_history;

SELECT 
  round(COUNT(DISTINCT w.content_id) * 100.0 / COUNT(DISTINCT c.content_id),2) AS pct_titles_watched
FROM ott_content c
LEFT JOIN ott_watch_history w
  ON c.content_id = w.content_id;

