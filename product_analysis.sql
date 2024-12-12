
-- Exploratory Data Analysis for some gadget product sales 

SELECT * 
FROM product_sales;

SELECT *
FROM product_data ;

SELECT *
FROM discount_data ;

-- Create staging tables so we can leaving raw tables untouched

CREATE TABLE staging_sales
LIKE product_sales ;

CREATE TABLE staging_data
LIKE product_data ;

CREATE TABLE staging_discount
LIKE discount_data ;

INSERT staging_sales
SELECT *
FROM product_sales;

INSERT staging_data
SELECT *
FROM product_data;

INSERT staging_discount
SELECT *
FROM discount_data;

-- Changing date data type for product sales and

SELECT `date`
FROM staging_sales ;

UPDATE staging_sales
SET `date` = str_to_date(`date`, '%d/%m/%Y');

ALTER TABLE staging_sales
MODIFY COLUMN `date` DATE;

-- Standardrizing some data

UPDATE staging_discount
SET Discount_Band = LOWER(Discount_Band)
WHERE Discount_Band IS NOT NULL;

UPDATE staging_discount
SET Discount_Band = TRIM(Discount_Band)
WHERE Discount_Band IS NOT NULL;

UPDATE staging_sales
SET Discount_Band = TRIM(Discount_Band)
WHERE Discount_Band IS NOT NULL;

SELECT *
FROM staging_sales ;

SELECT *
FROM staging_data ;

SELECT *
FROM staging_discount ;

-- Create our table

CREATE TABLE eda_table AS
WITH CTE_1 AS (
SELECT 
pd.Product_ID, 
pd.Product, 
pd.Category, 
pd.Cost_Price_USD, 
pd.Sale_Price_USD,
pd.Brand, 
pd.`Description`, 
sales.`Date`,
sales.Customer_Type, 
sales.Country, 
sales.Discount_Band, 
sales.Units_Sold,
date_format(`date`, '%M') as Month,
date_format(`date`, '%Y') as Year,
(Sale_Price_USD*Units_Sold) as Revenue,
(Cost_Price_USD*Units_Sold) as Total_Cost
FROM staging_data as pd
JOIN staging_sales as sales
ON pd.Product_ID = sales.Product
)
SELECT cte.*,
((1 - (d.Discount * 1 / 100)) * cte.Revenue) AS Disc_Revenue,
(((1 - (d.Discount * 1 / 100)) * cte.Revenue) - cte.Total_Cost) AS Profit
FROM CTE_1 AS cte
JOIN staging_discount AS d 
ON cte.Discount_Band = d.Discount_Band AND cte.Month = d.Month
;

SELECT * FROM eda_table
;

-- What costumer type give us most profit?

SELECT Customer_Type, SUM(Profit) AS Total_Profit
FROM eda_table
GROUP BY 1
ORDER BY 2 DESC
;

-- When does highest unit sold and highest profit happen?

SELECT SUBSTRING(`Date`,1,7) AS `Year_Month`, 
SUM(Profit) AS Total_Profit
FROM eda_table
GROUP BY `Year_Month`
ORDER BY 2 DESC
;

SELECT SUBSTRING(`Date`,1,7) AS `Year_Month`,
Product, 
SUM(Units_Sold) AS Total_Unit_Sold
FROM eda_table
GROUP BY `Year_Month`, Product
ORDER BY 3 DESC
;

SELECT SUBSTRING(`Date`,1,7) AS `Year_Month`,
Product, 
SUM(Units_Sold) AS Total_Unit_Sold,
SUM(Profit)
FROM eda_table
GROUP BY `Year_Month`, Product
ORDER BY 4 DESC
;

-- How much profit increase we got this year?

WITH Profit_Per_Year AS (
SELECT 
Year,
SUM(Profit) AS Total_Profit
FROM eda_table
GROUP BY Year
)
SELECT Year,
Total_Profit AS Profit_This_Year,
LAG(Total_Profit) OVER (ORDER BY Year) AS Profit_Last_Year,
(Total_Profit - LAG(Total_Profit) OVER (ORDER BY Year)) AS Profit_Difference,
CASE WHEN
LAG(Total_Profit) OVER (ORDER BY Year) IS NULL THEN NULL  -- No previous year to compare
ELSE ((Total_Profit - LAG(Total_Profit) OVER (ORDER BY Year)) / LAG(Total_Profit) OVER (ORDER BY Year)) * 100
END AS Profit_Percentage_Change
FROM Profit_Per_Year
ORDER BY Year;

-- Lets see that profit compared to the product sold

WITH Profit_Per_Product AS (
SELECT 
Product,
Year,
SUM(Profit) AS Total_Profit
FROM eda_table
GROUP BY Product, Year
)
SELECT 
Product,
Year,
Total_Profit AS Profit_This_Year,
LAG(Total_Profit) OVER (PARTITION BY Product ORDER BY Year) AS Profit_Last_Year,
(Total_Profit - LAG(Total_Profit) OVER (PARTITION BY Product ORDER BY Year)) AS Profit_Difference,
CASE
WHEN LAG(Total_Profit) OVER (PARTITION BY Product ORDER BY Year) IS NULL THEN NULL  -- No previous year to compare
ELSE ((Total_Profit - LAG(Total_Profit) OVER (PARTITION BY Product ORDER BY Year)) / LAG(Total_Profit) OVER (PARTITION BY Product ORDER BY Year)) * 100
END AS Profit_Percentage_Change
FROM Profit_Per_Product
WHERE Product = 'MV7'
ORDER BY Year;

-- we can also use these queries to check trend about unit sold
-- other exploratory data will be conducted directly on Power BI

