/* Data type of all columns in the “customers” table.*/
SELECT
    column_name,
    data_type
FROM
    information_schema.columns
WHERE
    table_name = 'customers'
    AND table_schema = 'target';
/*time range between which the orders were placed.*/
SELECT
    MIN(order_purchase_timestamp) AS first_order,
    MAX(order_purchase_timestamp) AS last_order
FROM
    target.orders;
/*Count the Cities & States of customers who ordered during the given period.*/
SELECT
    COUNT(DISTINCT c.customer_city) AS city_cnt,
    COUNT(DISTINCT c.customer_state) AS state_cnt
FROM
    target.orders o
INNER JOIN
    target.customers c
ON
    o.customer_id = c.customer_id;
/*in depth analysis
1.. Is there a growing trend in the no. of orders placed over the past years? */
SELECT
    YEAR(order_purchase_timestamp) AS year,
    MONTH(order_purchase_timestamp) AS month,
    COUNT(1) AS num_orders
FROM
    target.orders
GROUP BY
    year,
    month
ORDER BY
    year,
    month;
/*2.some kind of monthly seasonality in terms of the no. of orders being placed*/
SELECT
    MONTH(order_purchase_timestamp) AS month,
    COUNT(1) AS num_orders
FROM
    target.orders
GROUP BY
    month
ORDER BY
    month;
/*3.During what time of the day, do the Brazilian customers mostly place their orders? (Dawn, Morning, Afternoon or Night) */
SELECT
    CASE
        WHEN HOUR(order_purchase_timestamp) BETWEEN 0 AND 6 THEN 'dawn'
        WHEN HOUR(order_purchase_timestamp) BETWEEN 7 AND 12 THEN 'morning'
        WHEN HOUR(order_purchase_timestamp) BETWEEN 13 AND 18 THEN 'afternoon'
        WHEN HOUR(order_purchase_timestamp) BETWEEN 19 AND 23 THEN 'night'
    END AS time_of_day,
    COUNT(DISTINCT order_id) AS counter
FROM
    target.orders
GROUP BY
    time_of_day
ORDER BY
    counter DESC;
/*3.	Evolution of E-commerce orders in the Brazil region: 
Now we’ll try to understand data based on state or city level and see what variations are present and how the people in various states order and receive deliveries.*/
/*a.month on month no. of orders placed in each state. */
SELECT
    EXTRACT(MONTH FROM o.order_purchase_timestamp) AS month,
    c.customer_state,
    COUNT(1) AS num_orders
FROM
    target.orders o
INNER JOIN
    target.customers c
ON
    o.customer_id = c.customer_id
GROUP BY
    c.customer_state, month
ORDER BY
    num_orders DESC;
/*b.customers distributed across all the states*/
SELECT
c.customer_state,
COUNT(DISTINCT(c.customer_unique_id)) AS num_customers
FROM target.customers c
GROUP BY c.customer_state
ORDER BY num_customers DESC;
/*Impact on Economy: 
until now,just answered questions on the E-commerce scenario considering the number of orders received. We could see the volumetry by a month, day of week, time of the day and even the geolocation states.
will Analyze the money movement by e-commerce by looking at order prices, freight and others.*/
/*a.Get the % increase in the cost of orders from year 2017 to 2018 (include months between Jan to Aug only).*/
-- Define CTEs first
WITH base_1 AS (
     SELECT a.*, b.payment_value
     FROM target.orders a
     INNER JOIN target.payments b
     ON a.order_id = b.order_id
     WHERE
     EXTRACT(YEAR FROM a.order_purchase_timestamp) BETWEEN 2017 AND 2018
     AND
     EXTRACT(MONTH FROM a.order_purchase_timestamp) BETWEEN 1 AND 8
 ),
 base_2 AS (
     SELECT
     EXTRACT(YEAR FROM order_purchase_timestamp) AS year,
     SUM(payment_value) AS cost
     FROM base_1
     GROUP BY year
     ORDER BY year ASC
 ),
 base_3 AS (
     SELECT *, LEAD(cost, 1) OVER (ORDER BY year) AS next_year_cost
     FROM base_2
 )

-- Now, use the CTEs in the main query
 SELECT *, (next_year_cost - cost) / cost * 100 AS percent_increase
 FROM base_3;
with cte_table as (

select Extract( month from o.order_purchase_timestamp) as month,
Extract( year from o.order_purchase_timestamp) as year,
(sum(price)/count(o.order_id)) as price_per_order,
(sum(freight_value)/count(o.order_id)) as freight_per_order
from `sqlfreetest-353004.Ecommerce.orders` o
inner join `sqlfreetest-353004.Ecommerce.order_items` i
on o.order_id= i.order_id
group by year,month

)
select (price_per_order), (freight_per_order), month , year
from cte_table;
/*4.a)Total amount sold in 2017 between Jan to august (Jan to Aug because data is available starting 2017 01 to 2018 08) and we can only compare cycles with cycles*/
WITH cte_table AS (
    SELECT
        EXTRACT(MONTH FROM o.order_purchase_timestamp) AS month,
        EXTRACT(YEAR FROM o.order_purchase_timestamp) AS year,
        SUM(i.price) AS total_price,
        SUM(i.freight_value) AS total_freight
    FROM
        target.orders o
    INNER JOIN
        target.order_items i
    ON
        o.order_id = i.order_id
    GROUP BY
        year, month
)
SELECT
    SUM(total_price) AS total_transaction_amt
FROM
    cte_table
WHERE
    year = 2017
    AND month BETWEEN 1 AND 8;
/*b.Total amount sold in 2018 between Jan to august*/
SELECT
    *,
    (orders - COALESCE(lagger_orders, 0)) / COALESCE(orders, 1) * 100 AS difference
FROM
    (
        SELECT
            *,
            LAG(orders, 1) OVER (ORDER BY year ASC) AS lagger_orders
        FROM
            (
                SELECT
                    EXTRACT(YEAR FROM a.order_purchase_timestamp) AS year,
                    COUNT(DISTINCT a.order_id) AS orders,
                    COUNT(DISTINCT b.customer_unique_id) AS customers
                FROM
                    target.orders a
                LEFT JOIN
                    target.customers b
                ON
                    a.customer_id = b.customer_id
                GROUP BY
                    year
            ) base
    ) base_2
ORDER BY
    year ASC;
/*c.the Total & Average value of order price for each state*/
WITH cte_table AS (
    SELECT
        c.customer_state AS state,
        SUM(i.price) AS total_price,
        COUNT(DISTINCT o.order_id) AS num_orders
    FROM
        target.orders o
    INNER JOIN
        target.order_items i
    ON
        o.order_id = i.order_id
    INNER JOIN
        target.customers c
    ON
        o.customer_id = c.customer_id
    GROUP BY
        state
)
SELECT
    state,
    total_price,
    num_orders,
    (total_price / num_orders) AS avg_price
FROM
    cte_table
ORDER BY
    total_price DESC;
/*Total & Average value of order freight for each state*/
WITH cte_table AS (
    SELECT
        c.customer_state AS state,
        SUM(i.freight_value) AS total_freight,
        COUNT(DISTINCT o.order_id) AS num_orders
    FROM
        target.orders o
    INNER JOIN
        target.order_items i
    ON
        o.order_id = i.order_id
    INNER JOIN
        target.customers c
    ON
        o.customer_id = c.customer_id
    GROUP BY
        state
)
SELECT
    state,
    total_freight,
    num_orders,
    (total_freight / num_orders) AS avg_freight
FROM
    cte_table
ORDER BY
    total_freight DESC;
/*5.Analysis based on sales, freight and delivery time*/
/*no. of days taken to deliver each order from the order’s purchase date as delivery time.
●	time_to_deliver = order_delivered_customer_date - order_purchase_timestamp
●	diff_estimated_delivery = order_estimated_delivery_date - order_delivered_customer_date
*/
SELECT
    order_id,
    DATEDIFF(order_delivered_customer_date, order_purchase_timestamp) AS time_to_dil,
    DATEDIFF(order_delivered_customer_date, order_estimated_delivery_date) AS diff_estimated_dil
FROM
    target.orders
WHERE
    order_status = 'delivered';
/*top 5 states with the highest & lowest average freight value.*/
SELECT
    c.customer_state AS state,
    SUM(DATEDIFF(order_delivered_customer_date, order_purchase_timestamp)) / COUNT(order_id) AS avg_dil_time
FROM
    target.orders o
INNER JOIN
    target.customers c
ON
    o.customer_id = c.customer_id
WHERE
    order_status = 'delivered'
GROUP BY
    state
ORDER BY
    avg_dil_time
LIMIT 5;
/*top 5 states with the highest & lowest average delivery time*/
SELECT
    c.customer_state AS state,
    AVG(i.freight_value) AS total_freight
FROM
    target.orders o
INNER JOIN
    target.order_items i
ON
    o.order_id = i.order_id
INNER JOIN
    target.customers c
ON
    o.customer_id = c.customer_id
GROUP BY
    state
ORDER BY
    total_freight DESC
LIMIT 5;
/*c.top 5 states where the order delivery is really fast as compared to the estimated date of delivery.*/
SELECT
    customer_state AS state,
    ROUND(SUM(DATEDIFF(order_delivered_customer_date, order_purchase_timestamp)) / COUNT(order_id), 2) AS average_time_for_del,
    ROUND(SUM(DATEDIFF(order_estimated_delivery_date, order_purchase_timestamp)) / COUNT(order_id), 2) AS average_est_dil_time
FROM
    target.orders o
INNER JOIN
    target.customers c
ON
    o.customer_id = c.customer_id
WHERE
    order_status = 'delivered'
GROUP BY
    customer_state
ORDER BY
    (average_time_for_del - average_est_dil_time);
/*6.	Analysis based on the payments:

6.a. Find the month on month no. of orders placed using different payment types.*/
SELECT
    p.payment_type,
    COUNT(o.order_id) AS order_count,
    EXTRACT(MONTH FROM o.order_purchase_timestamp) AS month,
    EXTRACT(YEAR FROM o.order_purchase_timestamp) AS year
FROM
    target.payments p
JOIN
    target.orders o
ON
    o.order_id = p.order_id
GROUP BY
    payment_type, year, month
ORDER BY
    year, month;
/*6b.Find the no. of orders placed on the basis of the payment installments that have been paid.*/
SELECT
    DISTINCT(payment_installments) AS installments,
    COUNT(order_id) AS num_orders
FROM
    target.payments
WHERE
    payment_installments > 1
GROUP BY
    installments
ORDER BY
    num_orders DESC;
























