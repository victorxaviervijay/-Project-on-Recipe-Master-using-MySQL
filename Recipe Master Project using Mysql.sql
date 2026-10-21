USE recipe_db;

-- =====================================================================
-- Existing tables assumed: Recipes, Recipe_Ingredients, Nutrition
-- =====================================================================


-- 1. Recipes with Rating > 4.5 and a cooking time that contains "mins".
--    Cooking_Time_Mins is an INT, so text matching is not possible; the
--    column already stores minutes, so we just require a valid time.
SELECT *
FROM Recipes
WHERE Rating > 4.5
  AND Cooking_Time_Mins IS NOT NULL
  AND Cooking_Time_Mins > 0;
-- If Cooking_Time were a VARCHAR such as '30 mins', use instead:
-- SELECT * FROM Recipes WHERE Rating > 4.5 AND Cooking_Time LIKE '%mins%';


-- 2. Group by Servings (Quantity), keep groups with average rating > 4.0.
SELECT Servings, AVG(Rating) AS Avg_Rating
FROM Recipes
GROUP BY Servings
HAVING AVG(Rating) > 4.0;


-- 3. Recipe names with their category names (uses Categories table).
SELECT r.Recipe_Name, c.Category_Name
FROM Recipes r
INNER JOIN Categories c ON r.Recipe_ID = c.Recipe_ID;


-- 4. All recipes with their reviews; recipes with zero reviews still appear.
SELECT r.Recipe_Name, v.Review_Text, v.Review_Rating
FROM Recipes r
LEFT JOIN Reviews v ON r.Recipe_ID = v.Recipe_ID;


-- 5. All users and the recipes they created; users with no recipes included.
SELECT u.User_ID, u.User_Name, r.Recipe_Name
FROM Users u
LEFT JOIN Recipes r ON u.User_ID = r.User_ID;
-- Equivalent using RIGHT JOIN:
-- SELECT u.User_ID, u.User_Name, r.Recipe_Name
-- FROM Recipes r RIGHT JOIN Users u ON r.User_ID = u.User_ID;


-- 6. Recipes and Sponsors: all rows from both sides (FULL OUTER JOIN emulation).
SELECT r.Recipe_Name, s.Sponsor_Name
FROM Recipes r
LEFT JOIN Sponsors s ON r.Recipe_ID = s.Recipe_ID
UNION
SELECT r.Recipe_Name, s.Sponsor_Name
FROM Recipes r
RIGHT JOIN Sponsors s ON r.Recipe_ID = s.Recipe_ID;


-- 7. Average number of reviews across all recipes.
SELECT AVG(Review_Count) AS Average_Popularity
FROM Recipes;


-- 8. Most and least expensive recipe, extracting the numeric value from Price.
--    The cast works whether Price_USD is VARCHAR (e.g. '$12.50') or already numeric.
SELECT Recipe_Name,
       CAST(REPLACE(REPLACE(Price_USD, '$', ''), ',', '') AS DECIMAL(10,2)) AS Price_Value
FROM Recipes
WHERE CAST(REPLACE(REPLACE(Price_USD, '$', ''), ',', '') AS DECIMAL(10,2)) IN (
    (SELECT MIN(CAST(REPLACE(REPLACE(Price_USD, '$', ''), ',', '') AS DECIMAL(10,2))) FROM Recipes),
    (SELECT MAX(CAST(REPLACE(REPLACE(Price_USD, '$', ''), ',', '') AS DECIMAL(10,2))) FROM Recipes)
)
ORDER BY Price_Value;


-- 9. Recipes created in 2024 (range form can use an index on Creation_Timestamp).
SELECT *
FROM Recipes
WHERE Creation_Timestamp >= '2024-01-01'
  AND Creation_Timestamp <  '2025-01-01';


-- 10. Records where ingredients are not empty, and records where Quantity is missing.
-- 10a. Ingredient rows that are not NULL and not empty:
SELECT *
FROM Recipe_Ingredients
WHERE Ingredient_Name IS NOT NULL
  AND TRIM(Ingredient_Name) <> '';

-- 10b. Recipes where Quantity (Servings) is missing:
SELECT *
FROM Recipes
WHERE Servings IS NULL;


-- 11. Each recipe's rating and its difference from the overall average rating.
SELECT Recipe_Name,
       Rating,
       Rating - (SELECT AVG(Rating) FROM Recipes) AS Rating_Difference
FROM Recipes;


-- 12. Derived table (subquery in FROM): recipes with more than 300 reviews.
SELECT Sub.Recipe_Name, Sub.Price_USD
FROM (SELECT Recipe_Name, Price_USD
      FROM Recipes
      WHERE Review_Count > 300) AS Sub;


-- 13. Recipes rated above the average for their own serving size (Quantity).
SELECT Recipe_Name, Rating, Servings
FROM Recipes r1
WHERE Rating > (SELECT AVG(Rating)
                FROM Recipes r2
                WHERE r2.Servings = r1.Servings);


-- 14. 1NF (Explanation): The original CSV stored comma-separated ingredients in one
--     column. 1NF is achieved by giving each ingredient its own row in Recipe_Ingredients.
-- 15. 2NF (Redesign): To remove partial dependency, chef details move to a Chefs table
--     (Chef_ID, Chef_Name, ...) and Recipes references it through Chef_ID.
-- 16. 3NF (Redesign): Remove transitive dependencies (e.g. City depends on ZipCode) by
--     moving them into a separate Locations (ZipCode, City) table.


-- 17. Create Ingredients_List table.
CREATE TABLE Ingredients_List (
    Ingredient_ID INT AUTO_INCREMENT PRIMARY KEY,
    Recipe_ID INT,
    Ingredient_Name VARCHAR(255),
    FOREIGN KEY (Recipe_ID) REFERENCES Recipes(Recipe_ID)
);


-- 18. Add Is_Vegetarian (Boolean) column to Recipes.
ALTER TABLE Recipes ADD COLUMN Is_Vegetarian BOOLEAN DEFAULT FALSE;


-- 19. Change Price column from VARCHAR to DECIMAL(10,2).
--     Strip any currency symbols first so the conversion does not fail.
UPDATE Recipes
SET Price_USD = REPLACE(REPLACE(Price_USD, '$', ''), ',', '');

ALTER TABLE Recipes MODIFY COLUMN Price_USD DECIMAL(10,2);


-- 20. Delete all data from "Test_Recipes" but keep the table structure.
CREATE TABLE IF NOT EXISTS Test_Recipes (
    Recipe_ID INT AUTO_INCREMENT PRIMARY KEY,
    Recipe_Name VARCHAR(255)
);

TRUNCATE TABLE Test_Recipes;


-- 21. Create Users with an auto-increment primary key (already created in setup).
CREATE TABLE IF NOT EXISTS Users (
    User_ID INT AUTO_INCREMENT PRIMARY KEY,
    User_Name VARCHAR(100),
    Email VARCHAR(255)
);


-- 22. Comments table; deleting a recipe deletes its comments.
CREATE TABLE Comments (
    Comment_ID INT AUTO_INCREMENT PRIMARY KEY,
    Recipe_ID INT,
    Comment_Text TEXT,
    FOREIGN KEY (Recipe_ID) REFERENCES Recipes(Recipe_ID) ON DELETE CASCADE
);


-- 23. No two users may share the same Email.
ALTER TABLE Users ADD CONSTRAINT unique_email UNIQUE (Email);


-- 24. Rating must be between 0 and 5.
ALTER TABLE Recipes ADD CONSTRAINT chk_rating CHECK (Rating >= 0 AND Rating <= 5);


-- 25. Default Creation_Timestamp to the current system time.
ALTER TABLE Recipes MODIFY COLUMN Creation_Timestamp DATETIME DEFAULT CURRENT_TIMESTAMP;


-- 26. Stored procedure returning recipes with fewer than 200 calories.
DROP PROCEDURE IF EXISTS GetLowCalorie;
DELIMITER //
CREATE PROCEDURE GetLowCalorie()
BEGIN
    SELECT r.Recipe_ID, r.Recipe_Name, n.Calories_kcal
    FROM Recipes r
    JOIN Nutrition n ON r.Recipe_ID = n.Recipe_ID
    WHERE n.Calories_kcal < 200;
END //
DELIMITER ;
-- CALL GetLowCalorie();


-- 27. Stored procedure taking Min_Rating as input.
DROP PROCEDURE IF EXISTS GetByRating;
DELIMITER //
CREATE PROCEDURE GetByRating(IN Min_Rating DECIMAL(3,1))
BEGIN
    SELECT * FROM Recipes WHERE Rating >= Min_Rating;
END //
DELIMITER ;
-- CALL GetByRating(4.5);


-- 28. View of top rated recipes (score 4.8 or higher).
CREATE OR REPLACE VIEW Top_Rated_Recipes AS
SELECT Recipe_Name, Rating
FROM Recipes
WHERE Rating >= 4.8;


-- 29. Index on Recipe_Name to speed up dish searches.
CREATE INDEX idx_recipe_name ON Recipes(Recipe_Name);


-- 30. Transaction: update a price, then roll it back.
START TRANSACTION;
UPDATE Recipes SET Price_USD = Price_USD + 1.00 WHERE Recipe_ID = 1;
ROLLBACK; -- Undoes the price increase.