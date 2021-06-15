-- Detect duplicates
SELECT  *,count(*) FROM jd GROUP BY customer_id,product_id,action_id
HAVING count(*)>1; 

-- Delete duplicates
CREATE TABLE tmp LIKE jd;
ALTER TABLE tmp ADD UNIQUE(customer_id,product_id,action_id);
INSERT IGNORE INTO tmp SELECT * FROM jd;

-- data Transform 
-- 1. action_date from datetime to weekdays
ALTER TABLE tmp ADD COLUMN day_name VARCHAR(255);
UPDATE tmp SET day_name = DAYNAME(action_date);
-- 2. create date only action_date
ALTER TABLE tmp ADD COLUMN action_dat date;
UPDATE tmp SET action_dat = DATE(action_date);
-- 2. categorize shop_score 
ALTER TABLE tmp ADD COLUMN shop_score_level VARCHAR(255);
UPDATE tmp SET shop_score_level = 
CASE WHEN shop_score > 9 THEN '[9,10]' 
	    when shop_score between 8 and  9 then '[8,9]'
			when shop_score between 7 and  8 then '[7,8]'
			when shop_score between 6 and  7 then '[6,7]' 
			when shop_score < 6 then '[<6]' END;

-- Prepare for Data modeling 
-- PV
SELECT date(action_date) AS 'Date', count(*) AS 'PV' FROM tmp WHERE type='PageView'
GROUP BY date(action_date) 
ORDER BY date(action_date) asc;

-- UV
SELECT DATE(action_date) AS 'Date', COUNT(DISTINCT customer_id) AS 'UV'
FROM tmp
GROUP BY DATE(action_date)
ORDER BY DATE(action_date);

-- bounce rate
# bounce rate='Single-page views'/'Total pageviews';
-- total single-page view by day
SELECT  DATE(action_date) AS 'Date', COUNT(DISTINCT customer_id) AS 'Single-page views', COUNT(*) FROM tmp 
WHERE customer_id not in (select DISTINCT customer_id from tmp where type = 'Follow')
and customer_id not in (select DISTINCT customer_id from tmp where type = 'SavedCart')
and customer_id not in (select DISTINCT customer_id from tmp where type = 'Order')
and customer_id not in (select DISTINCT customer_id from tmp where type = 'Comment')
GROUP BY DATE(action_date)
ORDER BY DATE(action_date);
-- toatl pageview by day
SELECT DATE(action_date) AS 'Date', count(*) AS 'Total pageviews'
FROM tmp WHERE type='PageView'
GROUP BY DATE(action_date)
ORDER BY DATE(action_date);

-- page per visit
# page per visit= toatl pageview by day /UV by day;

-- # of behaviors by ages and sex
SELECT gender, age_range, type, COUNT(*) AS '# of behaviors' FROM tmp
GROUP BY gender, type, age_range
ORDER BY gender, type, age_range;

-- # of behaviors by customer level and city_level
SELECT customer_level , city_level, type, COUNT(*) '# of behaviors' FROM tmp
GROUP BY customer_level , city_level, type
ORDER BY customer_level , city_level, type;

-- Acquisition: new users per day
select c.action_dat as firstday, COUNT(DISTINCT(c.customer_id)) as day_0 from 
(select a.customer_id,a.action_dat,datediff(a.action_dat,b.firstday) as by_day 
from tmp as a INNER JOIN 
(select customer_id,MIN(action_dat) as firstday from tmp GROUP BY customer_id ) 
as b on a.customer_id=b.customer_id) as c
where by_day=0 GROUP BY c.action_dat ORDER BY c.action_dat;

-- Activation: active users
# by day
SELECT action_dat, count(*) AS '# of active users' FROM tmp 
GROUP BY action_dat
ORDER BY action_dat;
# by weekday and behavior type
SELECT day_name, SUM(CASE WHEN type='PageView' THEN 1 ELSE 0 END) AS 'Click',
SUM(CASE WHEN type='Follow' THEN 1 ELSE 0 END) AS 'Follow',
SUM(CASE WHEN type='SavedCart' THEN 1 ELSE 0 END ) AS 'SavedCart',
SUM(CASE WHEN type='Order' THEN 1 ELSE 0 END) AS 'Order',
SUM(CASE WHEN type='Comment' THEN 1 ELSE 0 END) AS 'Comment',
count(*) AS 'Total # of active users' FROM tmp 
GROUP BY day_name
ORDER BY day_name;

-- Retentions
-- users and their first userd dates
select customer_id,action_dat, MIN(action_dat) as firstday 
from tmp GROUP BY customer_id,action_dat
order by customer_id,action_dat;
-- Users and date ranges between first register dates and  current action dates
select customer_id,action_dat,firstday,DATEDIFF(action_dat,firstday) as by_day 
from (select a.customer_id,a.action_dat,b.firstday from tmp as a 
INNER JOIN (select customer_id,MIN(action_dat) as firstday 
from tmp GROUP BY customer_id) as b 
on a.customer_id=b.customer_id GROUP BY customer_id,action_dat order by customer_id,action_dat) as c
GROUP BY customer_id,action_dat order by customer_id,action_dat;
-- retentions in 7 days
select firstday,
SUM(case when by_day=0 then 1 else 0 end ) as 'day_0',
SUM(case when by_day=1 then 1 else 0 end ) as 'day_1',
SUM(case when by_day=2 then 1 else 0 end ) as 'day_2',
SUM(case when by_day=3 then 1 else 0 end ) as 'day_3',
SUM(case when by_day=4 then 1 else 0 end ) as 'day_4',
SUM(case when by_day=5 then 1 else 0 end ) as 'day_5',
SUM(case when by_day=6 then 1 else 0 end ) as 'day_6',
SUM(case when by_day=7 then 1 else 0 end ) as 'day_7' from
(select customer_id,action_dat,firstday,DATEDIFF(action_dat,firstday) as by_day 
from (select a.customer_id,a.action_dat,b.firstday from tmp as a 
INNER JOIN (select customer_id,MIN(action_dat) as firstday 
from tmp GROUP BY customer_id) as b 
on a.customer_id=b.customer_id GROUP BY customer_id,action_dat order by customer_id,action_dat) as c
GROUP BY customer_id,action_dat order by customer_id,action_dat) as d
GROUP BY firstday order by firstday;

-- Retention rates
select firstday,day_0,
concat(round(day_1/day_0*100,2),'%') as 'day_1%',
concat(round(day_2/day_0*100,2),'%') as 'day_2%',
concat(round(day_3/day_0*100,2),'%') as 'day_3%',
concat(round(day_4/day_0*100,2),'%') as 'day_4%',
concat(round(day_5/day_0*100,2),'%') as 'day_5%',
concat(round(day_6/day_0*100,2),'%') as 'day_6%',
concat(round(day_7/day_0*100,2),'%') as 'day_7%' FROM
(select firstday,
SUM(case when by_day=0 then 1 else 0 end ) as 'day_0',
SUM(case when by_day=1 then 1 else 0 end ) as 'day_1',
SUM(case when by_day=2 then 1 else 0 end ) as 'day_2',
SUM(case when by_day=3 then 1 else 0 end ) as 'day_3',
SUM(case when by_day=4 then 1 else 0 end ) as 'day_4',
SUM(case when by_day=5 then 1 else 0 end ) as 'day_5',
SUM(case when by_day=6 then 1 else 0 end ) as 'day_6',
SUM(case when by_day=7 then 1 else 0 end ) as 'day_7' from
(select customer_id,action_dat,firstday,DATEDIFF(action_dat,firstday) as by_day 
from (select a.customer_id,a.action_dat,b.firstday from tmp as a 
INNER JOIN (select customer_id,MIN(action_dat) as firstday 
from tmp GROUP BY customer_id) as b 
on a.customer_id=b.customer_id GROUP BY customer_id,action_dat
order by customer_id,action_dat) as c
GROUP BY customer_id,action_dat order by customer_id,action_dat) as d
GROUP BY firstday order by firstday) as e
GROUP BY firstday order by firstday;

-- Behaviors by shop category and shop_score
select shop_category,shop_score_level,count(*) as '# of behaviors'
from tmp GROUP BY shop_category,shop_score_level ORDER BY count(*) DESC;

-- Behavior's counts and percentages
select type,count(*) from tmp GROUP BY type;

-- behavior's unique users nad percentages
select type,count( DISTINCT customer_id) from tmp GROUP BY type;

-- Conversion rate： calculate based on behavior's counts and percentages

-- RFM model
# Frequency
select buy_time from ( select count(customer_id) as 'buy_time'
from tmp where type = 'order' GROUP BY customer_id) as buy_list
GROUP BY buy_time;
-- 创建F视图
create view F(user_id,B,F) as 
select customer_id,B, 
(case when B = 1 then 1 
			when B = 2 then 2 
			when B = 3 then 3
			else null end) as F 
from (select customer_id,count(*) as B 
from tmp where type='order' group by customer_id) 
AS BUYTIMES order by F desc;
SELECT * FROM F;

-- Recency
select MAX(action_dat),min(action_dat),
(MAX(action_dat)-min(action_dat)) as 'Date difference',
(MAX(action_dat)-min(action_dat))/5 as 'Interval' from tmp;
-- 创建R视图
create view R(customer_id,A,R) as
select customer_id,A, 
(case when A between 0 and 43 then 4 
      when A between 44 and 87 then 3 
      when A between 88 and 131 then 2 
      when A between 132 and 175 then 1 
      when A between 176 and 214 then 0 
      else null end) as R 
from (select customer_id,datediff('2018-04-15',max(action_dat)) as 'A' 
from tmp where type='order' group by customer_id) AS BUYTIME;

-- R平均值
 SELECT avg(R) FROM r;
-- F平均值
SELECT avg(F) FROM f;

-- 创建RFM模型
create view RFM as 
select a.customer_id,a.R,b.F,
(case when a.R>=3.6348 and b.F>=1.0043 then '重要高价值客户'
			when a.R<3.6348 and b.F>=1.0043 then '重要唤回客户'
			when a.R>=3.6348 and b.F<1.0043 then '重要深耕客户'
			when a.R<3.6348 and b.F<1.0043 then '重要挽留客户'
end) as '客户分类'from r as a inner join f as b 
on a.customer_id=b.user_id order by R desc,F desc;

-- 客户分类占比
SELECT 客户分类,COUNT(customer_id) FROM rfm
GROUP BY 客户分类 ORDER BY COUNT(customer_id) desc;

-- 核心用户
SELECT * FROM rfm ORDER BY R desc,F desc limit 3;

-- 核心付费用户商品消费偏向
select customer_id,product_id,COUNT(product_id)
from jd_fnl WHERE type = 'order'
and customer_id in ('653834','375400','129926')
GROUP BY product_id ORDER BY COUNT(product_id) desc;

-- 核心付费用户商品品类消费偏向
select customer_id,category,COUNT(category)
from jd_fnl WHERE type = 'order'
and customer_id in ('653834','375400','129926')
GROUP BY category ORDER BY COUNT(category) desc;

-- 核心付费用户商品品牌消费偏向
select customer_id,brand,COUNT(brand)
from jd_fnl WHERE type = 'order'
and customer_id in ('653834','375400','129926')
GROUP BY brand ORDER BY COUNT(brand) desc;

-- 重复购买list
select buy_time,count(*) as '购买人数'
from (select count(customer_id) as 'buy_time' from jd_fnl
where type = 'order' GROUP BY customer_id  ) as buy_list
GROUP BY buy_time ORDER BY buy_time asc;

-- 产品销售数量及排名
select product_id,COUNT(product_id) as '商品销售数量'
from jd_fnl GROUP BY product_id ORDER BY COUNT(product_id) desc;

-- 品类销售数量及排名
select category,COUNT(category) as '品类销售数量'
from jd_fnl GROUP BY category ORDER BY COUNT(category) desc;

-- 品类各行为数占比
select category,type,COUNT(type) as '行为数' from jd_fnl GROUP BY category,type;

-- 品牌销售数量及排名
select brand,COUNT(brand) as '品牌销售数量'
from jd_fnl GROUP BY brand ORDER BY COUNT(brand) desc;

-- 品牌各行为数占比
select brand,type,COUNT(type) as '行为数' from jd_fnl GROUP BY brand,type;
