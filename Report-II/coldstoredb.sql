CREATE DATABASE IF NOT EXISTS coldstoredb;
USE coldstoredb;

-- Drop views in order of dependency
DROP VIEW IF EXISTS stocksummary;
DROP VIEW IF EXISTS completedorders;
DROP VIEW IF EXISTS activeorders;

-- Drop tables in reverse foreign key dependency order
DROP TABLE IF EXISTS feedback;
DROP TABLE IF EXISTS temperature_log;
DROP TABLE IF EXISTS temperature_sensor;
DROP TABLE IF EXISTS inventorylog;
DROP TABLE IF EXISTS customer_order;
DROP TABLE IF EXISTS product;
DROP TABLE IF EXISTS customer;
DROP TABLE IF EXISTS supplier;
DROP TABLE IF EXISTS warehouse;
DROP TABLE IF EXISTS user;

-- -----------------------------------------------------------------------------
-- 1. User Table
-- -----------------------------------------------------------------------------
CREATE TABLE user (
    UserID INT AUTO_INCREMENT PRIMARY KEY,
    Username VARCHAR(50) NOT NULL UNIQUE,
    Password VARCHAR(255) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- -----------------------------------------------------------------------------
-- 2. Warehouse Table
-- -----------------------------------------------------------------------------
CREATE TABLE warehouse (
    WID INT AUTO_INCREMENT PRIMARY KEY,
    Name VARCHAR(100) NOT NULL,
    Location VARCHAR(255) NOT NULL,
    Capacity INT NOT NULL,
    Temperature_Range VARCHAR(50)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- -----------------------------------------------------------------------------
-- 3. Supplier Table
-- -----------------------------------------------------------------------------
CREATE TABLE supplier (
    SupplierID INT AUTO_INCREMENT PRIMARY KEY,
    Name VARCHAR(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- -----------------------------------------------------------------------------
-- 4. Customer Table
-- -----------------------------------------------------------------------------
CREATE TABLE customer (
    CustomerID INT AUTO_INCREMENT PRIMARY KEY,
    Name VARCHAR(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- -----------------------------------------------------------------------------
-- 5. Product Table
-- -----------------------------------------------------------------------------
CREATE TABLE product (
    ProductID INT AUTO_INCREMENT PRIMARY KEY,
    Name VARCHAR(100) NOT NULL,
    Description TEXT,
    Price DECIMAL(10, 2) NOT NULL,
    Temp_Requirement VARCHAR(50),
    SupplierID INT,
    CONSTRAINT fk_product_supplier FOREIGN KEY (SupplierID) 
        REFERENCES supplier(SupplierID) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- -----------------------------------------------------------------------------
-- 6. Customer Order Table
-- -----------------------------------------------------------------------------
CREATE TABLE customer_order (
    OrderID INT AUTO_INCREMENT PRIMARY KEY,
    CustomerID INT NOT NULL,
    Order_Date DATETIME DEFAULT CURRENT_TIMESTAMP,
    Total_Amount DECIMAL(10, 2) NOT NULL,
    Status VARCHAR(50) DEFAULT 'Pending',
    CONSTRAINT fk_order_customer FOREIGN KEY (CustomerID) 
        REFERENCES customer(CustomerID) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- -----------------------------------------------------------------------------
-- 7. Inventory Log Table
-- -----------------------------------------------------------------------------
CREATE TABLE inventorylog (
    InventoryLogID INT AUTO_INCREMENT PRIMARY KEY,
    ProductID INT NOT NULL,
    WarehouseID INT NOT NULL,
    Change_Quantity INT NOT NULL,
    Log_Date DATETIME DEFAULT CURRENT_TIMESTAMP,
    Note VARCHAR(255),
    CONSTRAINT fk_inventory_product FOREIGN KEY (ProductID) 
        REFERENCES product(ProductID) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_inventory_warehouse FOREIGN KEY (WarehouseID) 
        REFERENCES warehouse(WID) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- -----------------------------------------------------------------------------
-- 8. Temperature Sensor Table
-- -----------------------------------------------------------------------------
CREATE TABLE temperature_sensor (
    SensorID INT AUTO_INCREMENT PRIMARY KEY,
    WarehouseID INT NOT NULL,
    CONSTRAINT fk_sensor_warehouse FOREIGN KEY (WarehouseID) 
        REFERENCES warehouse(WID) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- -----------------------------------------------------------------------------
-- 9. Temperature Log Table
-- -----------------------------------------------------------------------------
CREATE TABLE temperature_log (
    LogID INT AUTO_INCREMENT PRIMARY KEY,
    SensorID INT NOT NULL,
    Recorded_Temp DECIMAL(5, 2) NOT NULL,
    Timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_templog_sensor FOREIGN KEY (SensorID) 
        REFERENCES temperature_sensor(SensorID) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- -----------------------------------------------------------------------------
-- 10. Feedback Table
-- -----------------------------------------------------------------------------
CREATE TABLE feedback (
    FeedbackID INT AUTO_INCREMENT PRIMARY KEY,
    UserID INT NOT NULL,
    Comment TEXT,
    Rating INT CHECK (Rating BETWEEN 1 AND 5),
    Feedback_Date DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_feedback_user FOREIGN KEY (UserID) 
        REFERENCES user(UserID) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =============================================================================
-- DATABASE VIEWS
-- =============================================================================

-- View: Active Orders Pipeline
CREATE VIEW activeorders AS
SELECT 
    co.OrderID, 
    c.Name AS CustomerName, 
    co.Order_Date, 
    co.Total_Amount, 
    co.Status
FROM customer_order co
JOIN customer c ON co.CustomerID = c.CustomerID
WHERE co.Status NOT IN ('Completed', 'Cancelled');

-- View: Completed Orders History
CREATE VIEW completedorders AS
SELECT 
    co.OrderID, 
    c.Name AS CustomerName, 
    co.Order_Date, 
    co.Total_Amount, 
    co.Status
FROM customer_order co
JOIN customer c ON co.CustomerID = c.CustomerID
WHERE co.Status = 'Completed';

-- View: Stock Level Aggregation Summary
CREATE VIEW stocksummary AS
SELECT 
    ROW_NUMBER() OVER (ORDER BY SUM(il.Change_Quantity) DESC) AS StockID,
    p.Name AS Product,
    w.Name AS Warehouse,
    SUM(il.Change_Quantity) AS Quantity
FROM inventorylog il
JOIN product p ON il.ProductID = p.ProductID
JOIN warehouse w ON il.WarehouseID = w.WID
GROUP BY p.ProductID, w.WID;
