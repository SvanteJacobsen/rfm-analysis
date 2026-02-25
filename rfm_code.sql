--My aggregation table where I aggregate order data to use in my final table, as well as for a basis to my RFM scoring and segmentation. 
with aggregate_data as (
    select
        o_custkey,
        count(o_orderkey) as order_count,
        max(o_orderdate) as last_order_date,
        sum(o_totalprice) as total_revenue,
        round(avg(o_totalprice),2) as avg_order_value,
        datediff(day,max(o_orderdate), '1998-08-02') as days_since_last_order -- 1998-08-02 is the last available purchase date.
              
    from
        snowflake_sample_data.tpch_sf1.orders
    group by 
        o_custkey
    order by
        days_since_last_order
),

-- assigning rfm values to each customer by using ntile function. Gives a number from 1-4 based on their value in that category and in this case what quartile of the population they fall into. For the r_value I order desc so that the lowest days_since_last_order get the highset value. 
rfm_value as (
    select
        *, -- select star because I want everything from my previous table, to later join with the customer tavble.
        ntile(4) over (order by order_count) as f_value,
        ntile(4) over (order by days_since_last_order desc) as r_value,
        ntile(4) over (order by total_revenue) as m_value
    from
        aggregate_data
),

-- Below I calculate rfm score. Because the vast majority of customers have a last purchas in 1998 (the last 8 months) we get a big difference in score even if it only differs with a couple of months in their last order date, so I weigh recency a little lighter than frequency and monetary value in my final RFM score below
rfm_score as (
    select
        *, -- select star because I want everything from my previous table, to later join with the customer tavble.
        ((0.4 * f_value) + (0.2 * r_value) + (0.4 * m_value)) as rfm_score
    from
        rfm_value
),

/*Below I am segmenting my customers into buckets. 
Champion - Top marks in all three rfm values. Our best customers
Loyal customer - Active and frequent buyer who purchased relatively recently
Potential Loyalist - Purchased recently but is not as frequent of a buyer... yet ;)
New customer - Purchased recently but is not a frequent buyer. Just started buying from us. 
Promising - Not as recent of a buyer and also not a very frequent customer.
At Risk - Has been a relatively frequent buyer, but it has now been a while since their last purchase. 
Can Not Lose - A customer that has been a frequent buyer and also a high spender but has not ordered for a good while. 
Lost customer - Has not ordered in a very long time and is not a frequent buyer.
Hibernating - Has not ordered in a long time but has been a frequent buyer at one point. 
Others - The rest of the customers that do not fit any of the bills above. 
No Orders - Customers with no orders, will be added in a later cte. 

*/

rfm_segmentation as (
    select
        *, -- select star because I want everything from my previous table, to later join with the customer tavble.
        case 
            when r_value = 4 and f_value = 4 and m_value = 4 then 'Champion'
            when r_value >= 3 and f_value >= 2  then 'Loyal Customer'
            when r_value = 4 and f_value between 3 and 2 then 'Potential Loyalist'
            when r_value = 4 and f_value = 1 then 'New Customer'
            when r_value = 3 and f_value = 1 then 'Promising'
            when r_value = 2 and f_value >= 2 then 'At Risk'
            when r_value = 1 and f_value >= 3 and m_value >= 3 then 'Can Not Lose'
            when r_value = 1 and f_value = 1 then 'Lost Customer'
            when r_value = 1 and f_value = 2 then 'Hibernating'
            else 'Others'
        end as rfm_segment
    from
        rfm_score
),

-- final CTE where I at the bottom of the select statement give the segment 'No Orders' to all customers with null value on orders. Using coalesce function on many rows to replace null values from non-purchasing customers. 
final_cte as (
    select
        c.c_custkey as customer_id,
        c.c_name as customer,
        c.c_address as address,
        c.c_phone as phone,
        n.n_name as country,
        r.order_count as total_orders,
        r.total_revenue,
        r.last_order_date,
        r.days_since_last_order,
        r.avg_order_value,
        f_value,
        r.r_value,
        r.m_value,
        r.rfm_score,
        r.rfm_segment,
    from
        snowflake_sample_data.tpch_sf1.customer as c
-- inner join below to only include customer with minimum one order, since RFM is a transaction based analysis and based on purchase behaviour, I don't want users who have not converted to customers in this analysis. 
    inner join
        rfm_segmentation as r
        on c.c_custkey = r.o_custkey
    inner join
        snowflake_sample_data.tpch_sf1.nation as n
        on c.c_nationkey = n.n_nationkey
)


select
    *
from
    final_cte
order by
    rfm_score desc,
    rfm_segment,
    total_revenue desc
;

-- Below is code for further analysis on the final dataset

/*
-- Find out how many customers fall into each segment.

select
    rfm_segment,
    count(customer_id) as total_customers
from
    final_cte
group by
    rfm_segment
order by
    total_customers desc
;
-- Loyal Customer-segment has the most users, with almost 24 000. "New Customers" have the lowest with 3423. Points to a potential issue of not acquiring new customers well enough. 
*/


/*
-- Calculate the total revenue generated by each segment.

select
    rfm_segment,
    sum(total_revenue) as segment_total_revenue,
    round(avg(total_revenue),2) as segment_avg_revenue
from
    final_cte
group by
    rfm_segment
order by
    segment_total_revenue desc
;
-- Loyal Customer-Segment has the highest total revenue and Champion comes in at third place. Those are two high value segments so that is not a surprise. What is interesting is that "At Risk" comes in second and "Can Not Lose" comes in fifth place. That points to the importance of not losing the customers in those two segments. When looking at their avg revenue it also very high. 
*/

/*
-- Identify the top 5 High Value customers by the RFM score
select
   *
from
    final_cte
where
    rfm_segment in ('Champion', 'Loyal Customer', 'Can Not Lose')
order by
    rfm_score desc,
    total_revenue desc,
    total_orders desc,
    days_since_last_order
limit 5
;
-- I consider Champion, Loyal Customers and Can Not Lose to be my high value segments. Naturally the Champions get the highest RFM score, so I also ordered by total revenue, total orders and days since last order to break the ties and show the best of the best. 
*/



/*
-- Show which nations have the highest number of High Value customers.
select
    country,
    count(customer_id) as high_value_customers
from
    final_cte
where
    rfm_segment in ('Champion', 'Loyal Customer', 'Can Not Lose')
group by
    country
order by high_value_customers desc
;

-- Russia has the most high value customers, followed by Mozambique and China. Egypt and Kenya have the fewest.
/*




