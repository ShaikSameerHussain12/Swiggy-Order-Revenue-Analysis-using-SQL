---------------------------------------------------------------------------
CREATE DATABASE PROJECT2

USE PROJECT2

SELECT * 
FROM SWIGGY_DATA

--------------------------------------------------------------------------
--###
SELECT 
SUM(CASE WHEN STATE IS NULL THEN 1 ELSE 0 END) AS NULL_STATE,
SUM(CASE WHEN CITY IS NULL THEN 1 ELSE 0 END) AS NULL_CITY,
SUM(CASE WHEN ORDER_DATE IS NULL THEN 1 ELSE 0 END) AS NULL_ORDER_DATE,
SUM(CASE WHEN RESTAURANT_NAME IS NULL THEN 1 ELSE 0 END) AS NULL_RESTAURANT_NAME,
SUM(CASE WHEN LOCATION IS NULL THEN 1 ELSE 0 END) AS NULL_LOCATION,
SUM(CASE WHEN CATEGORY IS NULL THEN 1 ELSE 0 END) AS NULL_CATEGORY,
SUM(CASE WHEN DISH_NAME IS NULL THEN 1 ELSE 0 END) AS NULL_DISH_NAME,
SUM(CASE WHEN PRICE_INR IS NULL THEN 1 ELSE 0 END) AS NULL_PRICE_INR,
SUM(CASE WHEN RATING IS NULL THEN 1 ELSE 0 END) AS NULL_RATING,
SUM(CASE WHEN RATING_COUNT IS NULL THEN 1 ELSE 0 END) AS NULL_RATING_COUNT
FROM SWIGGY_DATA

--- ###BLANK OR EMPTY STRING
SELECT * 
FROM SWIGGY_DATA
WHERE STATE = '' OR CITY = '' OR ORDER_DATE = '' OR RESTAURANT_NAME = '' OR LOCATION = '' OR CATEGORY = '' OR DISH_NAME = ''

-- ###DUPLICATE DETECTION 
SELECT S.State,S.City,S.Order_Date,S.Restaurant_Name,S.Location,S.Category,S.Dish_Name,S.Price_INR,S.Rating,S.Rating_Count,
COUNT(*)
FROM SWIGGY_DATA AS S
GROUP BY S.State,S.City,S.Order_Date,S.Restaurant_Name,S.Location,S.Category,S.Dish_Name,S.Price_INR,S.Rating,S.Rating_Count
HAVING COUNT(*) > 1

-- ###DELETING DUPLICATON
WITH CTE AS (
			SELECT * ,
			ROW_NUMBER() OVER(PARTITION BY S.State,S.City,S.Order_Date,S.Restaurant_Name,S.Location,S.Category,S.Dish_Name,S.Price_INR,S.Rating,S.Rating_Count
			ORDER BY (SELECT NULL)) AS RN
			FROM Swiggy_Data AS S
			) 
DELETE FROM CTE WHERE RN > 1

-- ###STAR SCHEMA CREATION (DIMENSIONAL MODELING) 
-- ###1. Create Date Dimension 
CREATE TABLE dim_date (
    date_id INT IDENTITY(1,1) PRIMARY KEY,
    full_date DATE,
    year INT,
    month INT,
    month_name VARCHAR(20),
    quarter INT,
    day INT,
    week_number INT
);

-- ###2. Create Location Dimension
CREATE TABLE dim_location (
    location_id INT IDENTITY(1,1) PRIMARY KEY,
    state VARCHAR(100),
    city VARCHAR(100),
    location VARCHAR(200)
);

-- ###3. Create Restaurant Dimension 
CREATE TABLE dim_restaurant (
    restaurant_id INT IDENTITY(1,1) PRIMARY KEY,
    restaurant_name VARCHAR(200)
);

-- ###4. Create Category Dimension 
CREATE TABLE dim_category (
    category_id INT IDENTITY(1,1) PRIMARY KEY,
    category VARCHAR(100)
);

-- ###5. Create Dish Dimension 
CREATE TABLE dim_dish (
    dish_id INT IDENTITY(1,1) PRIMARY KEY,
    dish_name VARCHAR(200)
);

-- ###6. Create Central Fact Table with Foreign Keys 
CREATE TABLE fact_swiggy_orders (
    order_id INT IDENTITY(1,1) PRIMARY KEY,
    date_id INT REFERENCES dim_date(date_id),
    location_id INT REFERENCES dim_location(location_id),
    restaurant_id INT REFERENCES dim_restaurant(restaurant_id),
    category_id INT REFERENCES dim_category(category_id),
    dish_id INT REFERENCES dim_dish(dish_id),
    price_inr DECIMAL(10,2),
    rating DECIMAL(4,2),
    rating_count INT
);

-- ###DATA INSERTION
INSERT INTO dim_date (full_date, year, month, month_name, quarter, day, week_number)
SELECT DISTINCT 
    order_date, 
    YEAR(order_date), 
    MONTH(order_date), 
    DATENAME(MONTH, order_date), 
    DATEPART(QUARTER, order_date), 
    DAY(order_date), 
    DATEPART(WEEK, order_date)
FROM swiggy_data WHERE order_date IS NOT NULL;

INSERT INTO dim_location (state, city, location)
SELECT DISTINCT state, city, location 
FROM swiggy_data 
WHERE state IS NOT NULL AND city IS NOT NULL AND location IS NOT NULL;

INSERT INTO dim_restaurant (restaurant_name)
SELECT DISTINCT restaurant_name 
FROM swiggy_data 
WHERE restaurant_name IS NOT NULL;

INSERT INTO dim_category (category)
SELECT DISTINCT category 
FROM swiggy_data 
WHERE category IS NOT NULL;

INSERT INTO dim_dish (dish_name)
SELECT DISTINCT dish_name 
FROM swiggy_data 
WHERE dish_name IS NOT NULL;

INSERT INTO fact_swiggy_orders (date_id, location_id, restaurant_id, category_id, dish_id, price_inr, rating, rating_count)
SELECT 
    d.date_id, l.location_id, r.restaurant_id, c.category_id, ds.dish_id, 
    s.Price_INR, s.rating, s.rating_count
FROM swiggy_data s
JOIN dim_date d ON s.order_date = d.full_date
JOIN dim_location l ON s.location = l.location AND s.city = l.city
JOIN dim_restaurant r ON s.restaurant_name = r.restaurant_name
JOIN dim_category c ON s.category = c.category
JOIN dim_dish ds ON s.dish_name = ds.dish_name;

--KPI'S
--TOTAL ORDERS
SELECT COUNT(*) AS TOTAL_ORDERS 
FROM fact_swiggy_orders

--TOTAL REVENUE (INR MILLION)
SELECT 
FORMAT(SUM(CONVERT(FLOAT,price_inr))/1000000,'N2') + 'INR MILLION' AS TOTAL_REVENUE
FROM fact_swiggy_orders

--AVERAGE DISH PRICE
SELECT 
FORMAT(AVG(CONVERT(FLOAT,price_inr)),'N2') + 'INR' AS AVG_PRICE
FROM fact_swiggy_orders

--AVERAGE RATING
SELECT 
FAFROM fact_swiggy_orders

--DEEP-DIVE BUSSINESS ANALYSIS

--MONTHLY ORDER TRENDS
SELECT 
D.year,
D.month,
D.month_name,
COUNT(*) AS TOTAL_ORDERS
FROM fact_swiggy_orders AS F
JOIN dim_date AS D 
ON F.date_id = D.date_id
GROUP BY D.year,
D.month,
D.month_name
ORDER BY COUNT(*) DESC

SELECT 
D.year,
D.month,
D.month_name,
SUM(price_inr) AS TOTAL_REVENUE
FROM fact_swiggy_orders AS F
JOIN dim_date AS D 
ON F.date_id = D.date_id
GROUP BY D.year,
D.month,
D.month_name
ORDER BY SUM(price_inr) DESC

-- QUARTERLY TREND 

SELECT 
D.year,
D.quarter,
COUNT(*) AS TOTAL_ORDERS
FROM fact_swiggy_orders AS F
JOIN dim_date AS D 
ON F.date_id = D.date_id
GROUP BY D.year,
D.quarter
ORDER BY COUNT(*) DESC

-- YEARLY TREND
SELECT 
D.year,
COUNT(*) AS TOTAL_ORDERS
FROM fact_swiggy_orders AS F
JOIN dim_date AS D 
ON F.date_id = D.date_id
GROUP BY D.year
ORDER BY COUNT(*) DESC

-- ORDER BY DAY OF WEEK (MON-SUN)
SELECT 
DATENAME(WEEKDAY,D.FULL_DATE) AS DAY_NAME,
COUNT(*) AS TOTAL_ORDERS
FROM fact_swiggy_orders AS F
JOIN dim_date AS D
ON F.date_id = D.date_id
GROUP BY DATENAME(WEEKDAY,D.FULL_DATE),DATEPART(WEEKDAY,D.full_date)
ORDER BY DATEPART(WEEKDAY,D.full_date)

--TOP 10 CITIES BY ORDER VOLUME
SELECT TOP (10)
l.city, 
COUNT(*) AS Total_Orders
FROM fact_swiggy_orders AS f
JOIN dim_location AS l 
ON f.location_id = l.location_id
GROUP BY l.city
ORDER BY Total_Orders DESC

-- REVENUE CONTRIBUTION BY STATES
SELECT 
l.city, 
SUM(F.price_inr) AS Total_Revenue
FROM fact_swiggy_orders AS f
JOIN dim_location AS l 
ON f.location_id = l.location_id
GROUP BY l.city
ORDER BY SUM(F.price_inr) DESC

-- TOP 10 RESTAURANTS BY ORDERS
SELECT TOP (10)
R.restaurant_name, 
COUNT(*) AS Total_Orders
FROM fact_swiggy_orders AS f
JOIN dim_restaurant AS R
ON f.restaurant_id = R.restaurant_id
GROUP BY R.restaurant_name
ORDER BY Total_Orders DESC 

--TOP CATEGORIES BY ORDER VOLUME
SELECT TOP (10)
C.category, 
COUNT(*) AS Total_Orders
FROM fact_swiggy_orders AS F
JOIN dim_category AS C
ON C.category_id = F.category_id
GROUP BY C.category
ORDER BY Total_Orders DESC 

--MORE ORDERED DISHES 
SELECT TOP (10)
d.dish_name, 
COUNT(*) AS order_count
FROM fact_swiggy_orders AS F
JOIN dim_dish AS d
ON d.dish_id = F.dish_id
GROUP BY d.dish_name
ORDER BY order_count DESC 

--CUISINE PERFORMANCE (ORDERS + AVERAGE RATING)
SELECT 
C.category, 
COUNT(*) AS Total_Orders,
AVG(F.rating) AS AVG_RATING
FROM fact_swiggy_orders AS F
JOIN dim_category AS C
ON C.category_id = F.category_id
GROUP BY C.category
ORDER BY Total_Orders DESC 

--TOTAL ORDERS BY PRICE RANGE
SELECT 
    CASE 
        WHEN price_inr < 100 THEN 'Under 100'
        WHEN price_inr BETWEEN 100 AND 199 THEN '100-199'
        WHEN price_inr BETWEEN 200 AND 299 THEN '200-299'
        WHEN price_inr BETWEEN 200 AND 299 THEN '300-499'
        ELSE '500 Plus'
    END AS Spending_Bucket,
    COUNT(*) AS Order_Count
FROM fact_swiggy_orders
GROUP BY 
    CASE 
        WHEN price_inr < 100 THEN 'Under 100'
        WHEN price_inr BETWEEN 100 AND 199 THEN '100-199'
        WHEN price_inr BETWEEN 200 AND 299 THEN '200-299'
        WHEN price_inr BETWEEN 200 AND 299 THEN '300-499'
        ELSE '500 Plus'
    END;

-- RATIING COUNT DISTRIBUTION
SELECT 
RATING,
COUNT(*) AS RATING_COUNT
FROM fact_swiggy_orders
GROUP BY RATING 
ORDER BY COUNT(*) DESC