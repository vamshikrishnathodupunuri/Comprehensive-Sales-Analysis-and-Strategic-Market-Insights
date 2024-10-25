SELECT * FROM gdb0041.fact_sales_monthly where customer_code=90002002;

-- calcultaing quantity sold in 2021 fiscal year for customer croma
-- added 4 months to date to create fiscal year as atliq fiscal year starts from september

select * from fact_sales_monthly 
where 
customer_code=90002002 and year(date_add(date,interval 4 month))=2021
order by date desc 


-- created a function called get_fiscal_year

SELECT * from fact_sales_monthly 
where 
customer_code=90002002 and 
get_fiscal_year(date)=2021
order by date 



-- Created a function called get_fiscal_quarter 

SELECT * from fact_sales_monthly 
where 
customer_code=90002002 and 
get_fiscal_year(date)=2021 and
get_fiscal_quarter(date)="Q1"
order by date DESC





-- Joined Product and Gross_price with  fact sales monthly

SELECT 
f.date,p.product_code,p.product,p.variant,f.sold_quantity,g.gross_price,
round(g.gross_price*f.sold_quantity,2) as total_gross_price
from fact_sales_monthly f
join dim_product p
on p.product_code=f.product_code
join fact_gross_price g
on g.product_code=f.product_code and 
   g.fiscal_year=get_fiscal_year(f.date)
where 
customer_code=90002002 and 
get_fiscal_year(date)=2021 
order by date 
limit 1000000


-- CROMA MONTLY TOTAL SALES


SELECT 
s.date, round(sum(g.gross_price*s.sold_quantity),2) as total_gross_price
FROM  fact_sales_monthly s
JOIN fact_gross_price g
ON g.product_code=s.product_code 
AND g.fiscal_year=get_fiscal_year(s.date)
WHERE customer_code=90002002
GROUP BY s.date
ORDER BY s.date 


-- total gross sales of croma by fiscal year

SELECT 
g.fiscal_year, round(sum(g.gross_price*s.sold_quantity),2) as total_gross_price
FROM  fact_sales_monthly s
JOIN fact_gross_price g
ON g.product_code=s.product_code 
AND g.fiscal_year=get_fiscal_year(s.date)
WHERE customer_code=90002002
GROUP BY g.fiscal_year
ORDER BY g.fiscal_year





-- gives total quantity sold by country and fiscal year
EXPLAIN ANALYZE
SELECT sum(sold_quantity) as total_qty from
fact_sales_monthly s
join
dim_customer c
on s.customer_code=c.customer_code
where get_fiscal_year(s.date)=2021 AND c.market="India"
group by c.market 


-- gives sales after 2018
select * from fact_sales_monthly where year(date)>2018


-- gives count of movies by studios but gives count of empty studio names aswell
select studio,count(movie_id) as movies_produced from moviesdb.movies   group  by studio 
having studio is not null;

-- gives count of movies by studios will not count of empty studio names 
SELECT studio, COUNT(movie_id) AS movies_produced
FROM moviesdb.movies
WHERE TRIM(studio) IS NOT NULL AND TRIM(studio) != ''
GROUP BY studio;



-- Include pre-invoice deductions in Croma detailed report


	SELECT 
    	   s.date, 
           s.product_code, 
           p.product, 
	   p.variant, 
           s.sold_quantity, 
           g.gross_price as gross_price_per_item,
           ROUND(s.sold_quantity*g.gross_price,2) as gross_price_total,
           pre.pre_invoice_discount_pct
	FROM fact_sales_monthly s
	JOIN dim_product p
            ON s.product_code=p.product_code
	JOIN fact_gross_price g
    	    ON g.fiscal_year=get_fiscal_year(s.date)
    	    AND g.product_code=s.product_code
	JOIN fact_pre_invoice_deductions as pre
            ON pre.customer_code = s.customer_code AND
            pre.fiscal_year=get_fiscal_year(s.date)
	WHERE 
	    s.customer_code=90002002 AND 
    	    get_fiscal_year(s.date)=2021     
	LIMIT 1000000;

-- Same report but all the customers
	EXPLAIN ANALYZE
    SELECT 
    	   s.date, 
           s.product_code, 
           p.product, 
	   p.variant, 
           s.sold_quantity, 
           g.gross_price as gross_price_per_item,
           ROUND(s.sold_quantity*g.gross_price,2) as gross_price_total,
           pre.pre_invoice_discount_pct
	FROM fact_sales_monthly s
	JOIN dim_product p
            ON s.product_code=p.product_code
	JOIN fact_gross_price g
    	    ON g.fiscal_year=get_fiscal_year(s.date)
    	    AND g.product_code=s.product_code
	JOIN fact_pre_invoice_deductions as pre
            ON pre.customer_code = s.customer_code AND
            pre.fiscal_year=get_fiscal_year(s.date)
	WHERE 
    	    get_fiscal_year(s.date)=2021     
	LIMIT 1000000;



-- top 5 countries with highest net sales in fy 2021 and created a stored procedure

SELECT market, 
round(sum(net_sales)/1000000,2) as net_sales_mil
FROM gdb0041.sales_netsales 
where fiscal_year=2021
group by market
order by net_sales_mil desc
limit 5;


-- top 5 customers with highest net sales and created a stored procedure

SELECT customer, 
round(sum(net_sales)/1000000,2) as net_sales_mil
FROM gdb0041.sales_netsales
join dim_customer on dim_customer.customer_code=sales_netsales.customer_code 
group by customer
order by net_sales_mil desc
limit 5;



-- top 5 product with highest net sales and created a stored procedure

SELECT product,round(sum(net_sales)/1000000,2) as Net_sales_in_mil FROM gdb0041.sales_netsales
where fiscal_year=2020
group by product
order by sum(net_sales) desc
limit 5;




--  customers with highest market share using over()

with c as (with b as (with a as (SELECT c.customer,s.fiscal_year,s.net_sales FROM gdb0041.sales_netsales s
join dim_customer c
using(customer_code))

select customer,round(sum(net_sales)/1000000,2) as total_net_sales_millions from a 
where a.fiscal_year=2021
group by customer
order by total_net_sales_millions desc )
select *,
total_net_sales_millions*100/sum(total_net_sales_millions) over() as market_share_pct 
from b)

select customer,round(market_share_pct,2) as ms_pct from c




-- market share percent by region

with a as (SELECT customer,dim_customer.region,round(sum(net_sales)/1000000,2) as net_sales FROM sales_netsales 
join dim_Customer 
using(customer_code)
where fiscal_year=2021
group by customer,region
order by region,sum(net_sales) desc)

select *, net_sales*100/sum(net_sales) over(partition by region) as pct_share_region from a




-- top 3 products quantity sold per segment and created stored procedure

with b as (with a as (select d.division,d.product,sum(sold_quantity) as total_sold_quantity from fact_sales_monthly f
join dim_product d
on d.product_code=f.product_code
where fiscal_year=2021
group by d.division,d.product)
select *,
dense_rank() over(partition by division order by total_sold_quantity desc) as rnk
from a)
select division,product,total_sold_quantity from b where rnk<=5





-- top n markets in region with total gross sales and created stored procedure

with c as (with b as (with a as (SELECT market,round(sum(gross_price_total)/1000000,2) as total_gross_sales
FROM gdb0041.`gross sales`
where fiscal_year=2021
group by market)
select distinct(a.market),region,total_gross_sales from a 
inner join dim_customer
on dim_customer.market=a.market
order by region,total_gross_sales desc)
select *,dense_rank() over(partition by region order by total_gross_sales desc) as drnk from b)
select * from c where drnk<=2




-- created new  table contains sold quantity and forecast quantity

create table fact_act_est
	(
        	select 
                    s.date as date,
                    s.fiscal_year as fiscal_year,
                    s.product_code as product_code,
                    s.customer_code as customer_code,
                    s.sold_quantity as sold_quantity,
                    f.forecast_quantity as forecast_quantity
        	from 
                    fact_sales_monthly s
        	left join fact_forecast_monthly f 
        	using (date, customer_code, product_code)
	)
	union
	(
        	select 
                    f.date as date,
                    f.fiscal_year as fiscal_year,
                    f.product_code as product_code,
                    f.customer_code as customer_code,
                    s.sold_quantity as sold_quantity,
                    f.forecast_quantity as forecast_quantity
        	from 
		    fact_forecast_monthly  f
        	left join fact_sales_monthly s 
        	using (date, customer_code, product_code)
	);



-- updated null values in sold and forecast quantity as 0

 update fact_act_est
	set sold_quantity = 0
	where sold_quantity is null;
    
update fact_act_est
set forecast_quantity = 0 
where forecast_quantity is null;






-- created forecast accuracy table and created stored procedure 
 
 with forecast_err_table as (

 select
                  s.customer_code as customer_code,
                  c.customer as customer_name,
                  c.market as market,
                  sum(s.sold_quantity) as total_sold_qty,
                  sum(s.forecast_quantity) as total_forecast_qty,
                  sum(s.forecast_quantity-s.sold_quantity) as net_error,
                  round(sum(s.forecast_quantity-s.sold_quantity)*100/sum(s.forecast_quantity),1) as net_error_pct,
                  sum(abs(s.forecast_quantity-s.sold_quantity)) as abs_error,
                  round(sum(abs(s.forecast_quantity-sold_quantity))*100/sum(s.forecast_quantity),2) as abs_error_pct
             from fact_act_est s
             join dim_customer c
             on s.customer_code = c.customer_code
             where s.fiscal_year=2021
             group by customer_code
	)
	select 
            *,
            if (abs_error_pct > 100, 0, 100.0 - abs_error_pct) as forecast_accuracy
	from forecast_err_table
        order by forecast_accuracy desc;





-- created temporary tables  and retrieved forecast accuracy dropped from 2021 to 2022

create temporary table fa2021 with forecast_err_table as (

 select
                  s.customer_code as customer_code,
                  c.customer as customer_name,
                  c.market as market,
                  sum(s.sold_quantity) as total_sold_qty,
                  sum(s.forecast_quantity) as total_forecast_qty,
                  sum(s.forecast_quantity-s.sold_quantity) as net_error,
                  round(sum(s.forecast_quantity-s.sold_quantity)*100/sum(s.forecast_quantity),1) as net_error_pct,
                  sum(abs(s.forecast_quantity-s.sold_quantity)) as abs_error,
                  round(sum(abs(s.forecast_quantity-sold_quantity))*100/sum(s.forecast_quantity),2) as abs_error_pct
             from fact_act_est s
             join dim_customer c
             on s.customer_code = c.customer_code
             where s.fiscal_year=2021
             group by customer_code
	)
	select 
            *,
            if (abs_error_pct > 100, 0, 100.0 - abs_error_pct) as forecast_accuracy
	from forecast_err_table
        order by forecast_accuracy desc;
        
create temporary table fa2022 with forecast_err_table as (

 select
                  s.customer_code as customer_code,
                  c.customer as customer_name,
                  c.market as market,
                  sum(s.sold_quantity) as total_sold_qty,
                  sum(s.forecast_quantity) as total_forecast_qty,
                  sum(s.forecast_quantity-s.sold_quantity) as net_error,
                  round(sum(s.forecast_quantity-s.sold_quantity)*100/sum(s.forecast_quantity),1) as net_error_pct,
                  sum(abs(s.forecast_quantity-s.sold_quantity)) as abs_error,
                  round(sum(abs(s.forecast_quantity-sold_quantity))*100/sum(s.forecast_quantity),2) as abs_error_pct
             from fact_act_est s
             join dim_customer c
             on s.customer_code = c.customer_code
             where s.fiscal_year=2022
             group by customer_code
	)
	select 
            *,
            if (abs_error_pct > 100, 0, 100.0 - abs_error_pct) as forecast_accuracy
	from forecast_err_table
        order by forecast_accuracy desc;
        
        
        
    -- temporary tables    
      select s.*,v.forecast_accuracy,v.forecast_accuracy-s.forecast_accuracy as fa_2022vs2021 from fa2021 s
      join fa2022 v
      using(customer_code,customer_name,market)
      having fa_2022vs2021 < 0
      order by fa_2022vs2021

   