-- Core Product & Stock Levels
CREATE TABLE Inventory (
    product_id INT PRIMARY KEY,
    sku VARCHAR(50) UNIQUE,
    product_name VARCHAR(100),
    quantity_on_hand INT,
    warehouse_location VARCHAR(10)
);
DESCRIBE Inventory;

-- Customer Demand History
CREATE TABLE Order_Items (
    order_id INT,
    product_id INT REFERENCES Inventory(product_id),
    quantity INT,
    order_date DATE,
    PRIMARY KEY (order_id, product_id)
);

-- Physical Fulfillment Records
CREATE TABLE Shipments (
    shipment_id INT PRIMARY KEY,
    order_id INT,
    shipment_date DATE,
    status VARCHAR(20) -- e.g., 'Shipped', 'Delivered'
);

-- Populating the Table
INSERT INTO Inventory VALUES 
(101, 'AMZ-PHN-01', 'Smartphone X', 500, 'SEA-1'),
(102, 'AMZ-LPT-02', 'Pro Laptop', 15, 'SEA-1'),
(103, 'AMZ-DSK-03', 'Vintage Lamp', 80, 'NYC-2');

INSERT INTO Order_Items VALUES 
(5000, 101, 200, DATE_SUB(CURDATE(), INTERVAL 5 DAY)),
(5002, 102, 50, DATE_SUB(CURDATE(), INTERVAL 2 DAY));

INSERT INTO Shipments (shipment_id, order_id, shipment_date, status) VALUES 
(9001, 5001, DATE_SUB(CURDATE(), INTERVAL 4 DAY), 'Delivered'),
(9002, 5002, DATE_SUB(CURDATE(), INTERVAL 1 DAY), 'Shipped'),
-- Dead stock shipment: last moved over 90 days ago
(9003, 4000, '2025-11-01', 'Delivered'); 


WITH ProductPerformance AS (
    SELECT 
        i.product_id,
        i.sku,
        i.quantity_on_hand,
        -- Calculate days since last shipment
        CURRENT_DATE - MAX(s.shipment_date) AS days_since_last_sale,
        -- Calculate total units sold in last 30 days
        SUM(CASE WHEN o.order_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY) 
            THEN o.quantity ELSE 0 END) AS units_sold_30d,
        -- Rank products by sales velocity
        PERCENT_RANK() OVER (ORDER BY SUM(o.quantity) DESC) AS velocity_rank
    FROM Inventory i
    LEFT JOIN Order_Items o ON i.product_id = o.product_id
    LEFT JOIN Shipments s ON o.order_id = s.order_id
    GROUP BY i.product_id, i.sku, i.quantity_on_hand
)
SELECT 
    product_id,
    sku,
    quantity_on_hand,
    units_sold_30d,
    CASE 
        WHEN days_since_last_sale >= 90 THEN 'DEAD STOCK'
        WHEN velocity_rank <= 0.10 THEN 'HIGH VELOCITY'
        ELSE 'STANDARD'
    END AS stock_category,
    -- Predictive: Identify potential stockout for high-velocity items
    CASE 
        WHEN velocity_rank <= 0.10 AND quantity_on_hand < (units_sold_30d * 0.5) 
        THEN 'URGENT REORDER' 
        ELSE 'OK' 
    END AS reorder_status
FROM ProductPerformance
ORDER BY velocity_rank ASC;
