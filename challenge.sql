-- SQL Queries
-- ad hoc requests
-- Q1 Generate a report that displays the total trips, average fare per km, average fare per trip, and the percentage contribution of each city’s trips to the overall trips. This report will help in assessing trip volume, pricing efficiency, and each city’s contribution to the overall trip count.

SELECT 
    c.*, 
    (c.total_trips / (SELECT COUNT(trip_id) FROM fact_trips) * 100) AS percentage_contribution
FROM (
    SELECT 
        b.city_name, 
        COUNT(a.trip_id) AS total_trips, 
        AVG(a.fare_amount / a.distance_travelled_km) AS avg_fare_per_km, 
        SUM(a.fare_amount) / COUNT(a.trip_id) AS avg_fare_per_trip
    FROM 
        fact_trips AS a
    INNER JOIN 
        dim_city AS b 
        ON a.city_id = b.city_id
    GROUP BY 
        b.city_name
) AS c
GROUP BY 
    c.city_name;


-- Q2 Generate a report that evaluates the target performance for trips at the monthly and city level. For each city and month, compare the actual total trips with the target trips and categorize the performance as follows:
-- If actual trips are greater than target trips, mark it as "Above Target".
-- If actual trips are less than or equal to target trips, mark it as "Below Target".
-- Additionally, calculate the % difference between actual and target trips to quantify the performance gap.

select 
	a.city_name, 
    b.month_name,
    b.actual_trips,
    c.total_target_trips,
    case when (b.actual_trips - c.total_target_trips) < 0 then "Below Target" else "Above Target" end as performance_status,
    (b.actual_trips - c.total_target_trips)/c.total_target_trips*100 as percentage_difference 
from 
	(select 
		city_id, 
        monthname(date) as month_name, 
        month(date) as month_, 
        count(trip_id) as actual_trips 
	from fact_trips 
    group by 
		city_id, 
		monthname(date), 
        month(date)) 
	as b
	inner join dim_city as a
		on a.city_id = b.city_id
	inner join (select *, monthname(month) as month_name from targets_db.monthly_target_trips) as c
		on c.city_id = b.city_id and c.month_name = b.month_name
order by a.city_name, b.month_
;

-- Q3 Generate a report that shows the percentage distribution of repeat passengers by the number of trips they have taken in each city. Calculate the percentage of repeat passengers who took 2 trips, 3 trips, and so on, up to 10 trips.
-- Each column should represent a trip count category, displaying the percentage of repeat passengers who fall into that category out of the total repeat passengers for that city.

select city_name,
	sum(case when trip_count = "2-Trips" then percentage else 0 end) as "2-Trips",
    sum(case when trip_count = "3-Trips" then percentage else 0 end) as "3-Trips",
    sum(case when trip_count = "4-Trips" then percentage else 0 end) as "4-Trips",
    sum(case when trip_count = "5-Trips" then percentage else 0 end) as "5-Trips",
    sum(case when trip_count = "6-Trips" then percentage else 0 end) as "6-Trips",
    sum(case when trip_count = "7-Trips" then percentage else 0 end) as "7-Trips",
    sum(case when trip_count = "8-Trips" then percentage else 0 end) as "8-Trips",
    sum(case when trip_count = "9-Trips" then percentage else 0 end) as "9-Trips",
    sum(case when trip_count = "10-Trips" then percentage else 0 end) as "10-Trips"
from 
	(select city_name, trip_count, trip_sum/city_sum*100 as percentage from
		(select b.city_name, a.trip_count, sum(a.repeat_passenger_count) as trip_sum, 
		sum(sum(a.repeat_passenger_count)) over(partition by b.city_name rows between unbounded preceding and unbounded following) as city_sum 
		from dim_repeat_trip_distribution a
		inner join dim_city b
		on a.city_id  = b.city_id
		group by b.city_name, a.trip_count) c ) d
group by city_name;
        
-- Q4 Generate a report that calculates the total new passengers for each city and ranks them based on this value. Identify the top 3 cities with the highest number of new passengers as well as the bottom 3 cities with the lowest number of new passengers, categorizing them as "Top 3" or "Bottom 3" accordingly.
select * from 
	(select city_name, total_new_passengers, 
		case when rnk <= 3 then "Top 3"
		when rnk >=8 then "Bottom 3" 
		else "Others" end as city_category from
		(select b.city_name, sum(a.new_passengers) as total_new_passengers, rank() over(order by sum(a.new_passengers) desc) as rnk
		from fact_passenger_summary a
		inner join  dim_city b
			on a.city_id = b.city_id
		group by b.city_name) c) d
;

-- Q5 Generate a report that identifies the month with the highest revenue for each city. For each city, display the month_name, the revenue amount for that month, and the percentage contribution of that month’s revenue to the city’s total revenue.

select city_name, month_name as highest_revenue_month, revenue as Revenue_INR, (revenue/total_revenue)*100 as percentage_contirbution from
	(select *, rank() over(partition by city_name order by revenue desc) rnk, 
		sum(revenue) over(partition by city_name rows between unbounded preceding and unbounded following) total_revenue
	from
		(select b.city_name, 
			monthname(a.date) month_name, 
			sum(fare_amount) as revenue
			from fact_trips a
		inner join dim_city b
			on a.city_id = b.city_id
		group by b.city_name, month_name) c) d
where rnk = 1
;

-- Q6 Generate a report that calculates two metrics:
-- Monthly Repeat Passenger Rate: Calculate the repeat passenger rate for each city and month by comparing the number of repeat passengers to the total passengers.
-- City-wide Repeat Passenger Rate: Calculate the overall repeat passenger rate for each city, considering all passengers across months.


select city_name, month, total_passengers, repeat_passengers, 
	monthly_repeat_passenger_rate, 
	(sum_repeat_passengers/sum_total_passengers)*100 as city_wide_repeat_rate 
from
	(select b.city_name, monthname(a.month) as month, month(a.month) as month_num, a.total_passengers, a.repeat_passengers, 
		(a.repeat_passengers/a.total_passengers)*100 as monthly_repeat_passenger_rate, 
		sum(a.total_passengers) over(partition by b.city_name rows between unbounded preceding and unbounded following) as sum_total_passengers,
		sum(a.repeat_passengers) over(partition by b.city_name rows between unbounded preceding and unbounded following) as sum_repeat_passengers
	from fact_passenger_summary as a
	inner join dim_city b
		on a.city_id=b.city_id) c
order by city_name, month_num;

-- More Research Question ---------------------------------------------------------------------
-- Q1. Here, using fact_trips and dim_date is used to calculate avg trip volume on Weekday and Weekends 
select Weekday/5 as AVG_Weekday_trips, Weekend/2 as AVG_Weekend_trips 
from
	(SELECT 
		SUM(CASE WHEN a.day_type = "Weekday" THEN 1 ELSE 0 END) AS Weekday,
		SUM(CASE WHEN a.day_type = "Weekend" THEN 1 ELSE 0 END) AS Weekend
	FROM dim_date a 
	INNER JOIN fact_trips b
		ON a.date = b.date) c
;

-- Q2 Passenger Repeat Rate Analysis of Each Trip Type out of Total Passengers
select city_name, total_passenger, repeat_trip_passenger_percentage,
	case when rnk <= 3 then "Highest"
    when rnk >= 8 then "Lowest"
    else "Mediocre" end as Perfromance_Status,
	sum(case when trip_count = "1-Trips" then passenger_trip_type_percentage else 0 end) as "1-Trips",
	sum(case when trip_count = "2-Trips" then passenger_trip_type_percentage else 0 end) as "2-Trips",
    sum(case when trip_count = "3-Trips" then passenger_trip_type_percentage else 0 end) as "3-Trips",
    sum(case when trip_count = "4-Trips" then passenger_trip_type_percentage else 0 end) as "4-Trips",
    sum(case when trip_count = "5-Trips" then passenger_trip_type_percentage else 0 end) as "5-Trips",
    sum(case when trip_count = "6-Trips" then passenger_trip_type_percentage else 0 end) as "6-Trips",
    sum(case when trip_count = "7-Trips" then passenger_trip_type_percentage else 0 end) as "7-Trips",
    sum(case when trip_count = "8-Trips" then passenger_trip_type_percentage else 0 end) as "8-Trips",
    sum(case when trip_count = "9-Trips" then passenger_trip_type_percentage else 0 end) as "9-Trips",
    sum(case when trip_count = "10-Trips" then passenger_trip_type_percentage else 0 end) as "10-Trips"
from 
	(select *, 
		(trip_sum/total_passenger)*100 as passenger_trip_type_percentage, 
		(total_repeat/total_passenger)*100 as repeat_trip_passenger_percentage,
        dense_rank() over(order by ((total_repeat/total_passenger)*100) desc) as rnk
	from
		(select city_name, trip_count, trip_sum, city_sum as total_repeat, sum(total_sum) over(partition by city_name rows between unbounded preceding and unbounded following) as total_passenger
		from    
			(select * from 
				(select b.city_name, a.trip_count, sum(a.repeat_passenger_count) as trip_sum, 
						sum(sum(a.repeat_passenger_count)) over(partition by b.city_name rows between unbounded preceding and unbounded following) as city_sum,
						0 as total_sum
						from dim_repeat_trip_distribution a
						inner join dim_city b
						on a.city_id  = b.city_id
						group by b.city_name, a.trip_count) c
			union all
			select * from 
				(select b.city_name, "1-Trips" as trip_count, sum(a.new_passengers) as new_sum, 
					sum(a.repeat_passengers) as repeat_sum, sum(total_passengers) as total_sum
				from fact_passenger_summary a
				inner join dim_city b
					on a.city_id = b.city_id
				group by b.city_name) d
			order by city_name, trip_count ) e ) f ) g
group by city_name, total_passenger, repeat_trip_passenger_percentage;	

-- Q3 Passenger Repeat Rate Analysis wrt to Passenger Rating & Driver Rating

select d.city_name, d.month, d.repeat_rate, e.avg_passenger_rating, e.avg_driver_rating
from
	(select city_name, month, repeat_rate, month_num
	from
		(select b.city_name, monthname(a.month) as month, month(a.month) as month_num,
			(a.repeat_passengers/a.total_passengers)*100 as repeat_rate
		from fact_passenger_summary as a
		inner join dim_city b
			on a.city_id=b.city_id) c ) d
inner join
	(select b.city_name, monthname(a.date) month, avg(a.passenger_rating) avg_passenger_rating, avg(a.driver_rating) avg_driver_rating
	from fact_trips a
	inner join dim_city b
		on a.city_id = b.city_id
	group by b.city_name, monthname(a.date) ) e 
on d.city_name = e.city_name and d.month = e.month
order by city_name, d.month_num
;

-- Q4 Comparison of Actual New Passengers v/s Target New Passenger

select b.city_name, monthname(a.month), c.target_new_passengers, a.new_passengers, 
	(a.new_passengers-c.target_new_passengers)/c.target_new_passengers*100 as difference_percentage,
	case when a.new_passengers-c.target_new_passengers <= -200 then "Missing Target" 
	when a.new_passengers-c.target_new_passengers >= 400 then "Good Performance" 
    else "Works Fine" end as Performance_Status_200
from trips_db.fact_passenger_summary as a
inner join trips_db.dim_city b
	on a.city_id = b.city_id
inner join targets_db.monthly_target_new_passengers c
	on c.month = a.month and c.city_id = a.city_id
order by b.city_name;
    
-- Q5 Monthly Split between trip by New Customer and Repeated Customers

select city_name, 
	month, 
	Repeated, 
	New, 
    Insights 
from
	(SELECT city_name, 
		   month, 
           month_num,
		   Repeated, 
		   New, 		   
		   CONCAT(
			   CASE 
				   WHEN New > 1.15 * mean_new THEN "Seasonal Demand or Marketing Success"
				   WHEN New < 0.95 * mean_new THEN "Require Marketing"
				   ELSE "Fine" 
			   END, 
			   " - ",
			   CASE 
				   WHEN New > 1.15 * mean_new THEN "Improved Customer Relations"
				   WHEN New < 0.95 * mean_new THEN "Need to Improve Services"
				   ELSE "Fine" 
			   END
		   ) AS Insights
	FROM    
		(SELECT *, 
				AVG(New) OVER(PARTITION BY city_name ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) mean_new,
				AVG(Repeated) OVER(PARTITION BY city_name ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) mean_repeated
		 FROM    
			(SELECT b.city_name, 
					MONTHNAME(a.date) AS month, 
                    month(a.date) as month_num,
					COUNT(CASE WHEN a.passenger_type = 'Repeated' THEN a.trip_id END) AS Repeated,
					COUNT(CASE WHEN a.passenger_type = 'New' THEN a.trip_id END) AS New
			 FROM fact_trips a
			 INNER JOIN dim_city b ON a.city_id = b.city_id
			 GROUP BY city_name, month, month_num) c
		) d ) e
order by city_name, month_num;

use targets_db;
select * from targets_db.monthly_target_trips;
select * from targets_db.monthly_target_new_passengers;
select * from targets_db.city_target_passenger_rating;

use trips_db;
select * from trips_db.dim_city;
select * from trips_db.dim_date;
select * from trips_db.dim_repeat_trip_distribution;
select * from trips_db.fact_passenger_summary;
select * from trips_db.fact_trips;