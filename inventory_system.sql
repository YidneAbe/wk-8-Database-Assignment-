-- inventory_system.sql
-- Real-World Inventory Tracking System (MySQL)
-- Drop & recreate database for a clean test environment
DROP DATABASE IF EXISTS inventory_system;
CREATE DATABASE inventory_system CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci;
USE inventory_system;

-- ====================================================================
-- Lookup / Reference Tables
-- ====================================================================

-- Units of measure (e.g., pcs, kg, liter)
CREATE TABLE unit (
    unit_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(10) NOT NULL UNIQUE,          -- e.g., "pcs", "kg"
    name VARCHAR(60) NOT NULL,
    description VARCHAR(255)
) ENGINE=InnoDB;

-- Product categories (MANY products can belong to MANY categories via product_category)
CREATE TABLE category (
    category_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT
) ENGINE=InnoDB;

-- Suppliers
CREATE TABLE supplier (
    supplier_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    contact_name VARCHAR(150),
    phone VARCHAR(30),
    email VARCHAR(150),
    address TEXT,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Customers (for sales orders)
CREATE TABLE customer (
    customer_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    contact_name VARCHAR(150),
    phone VARCHAR(30),
    email VARCHAR(150),
    address TEXT,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Employees (users who create orders, do stock moves)
CREATE TABLE employee (
    employee_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(80) NOT NULL UNIQUE,
    full_name VARCHAR(150) NOT NULL,
    email VARCHAR(150) UNIQUE,
    phone VARCHAR(30),
    role VARCHAR(50),
    active TINYINT(1) NOT NULL DEFAULT 1,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Warehouses (one product's inventory is tracked per warehouse)
CREATE TABLE warehouse (
    warehouse_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(30) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    address TEXT,
    capacity INT UNSIGNED, -- optional
    active TINYINT(1) NOT NULL DEFAULT 1,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ====================================================================
-- Core Product & Inventory Tables
-- ====================================================================

-- Products: SKU is unique; unit_id references unit
CREATE TABLE product (
    product_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    sku VARCHAR(80) NOT NULL UNIQUE,           -- stock keeping unit
    name VARCHAR(255) NOT NULL,
    description TEXT,
    unit_id INT UNSIGNED NOT NULL,
    purchase_price DECIMAL(12,4) DEFAULT 0.0000, -- last purchase cost / typical cost
    retail_price DECIMAL(12,4) DEFAULT 0.0000,   -- selling price
    is_active TINYINT(1) NOT NULL DEFAULT 1,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_product_unit FOREIGN KEY (unit_id) REFERENCES unit(unit_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- Many-to-Many: product <> category
CREATE TABLE product_category (
    product_id INT UNSIGNED NOT NULL,
    category_id INT UNSIGNED NOT NULL,
    PRIMARY KEY (product_id, category_id),
    CONSTRAINT fk_pc_product FOREIGN KEY (product_id) REFERENCES product(product_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_pc_category FOREIGN KEY (category_id) REFERENCES category(category_id)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

-- Inventory: quantity per product per warehouse (One-to-Many from product to inventory and warehouse to inventory)
CREATE TABLE inventory (
    product_id INT UNSIGNED NOT NULL,
    warehouse_id INT UNSIGNED NOT NULL,
    quantity DECIMAL(14,4) NOT NULL DEFAULT 0.0000,
    reorder_level DECIMAL(14,4) DEFAULT 0.0000,
    reserved DECIMAL(14,4) NOT NULL DEFAULT 0.0000, -- reserved for orders
    last_updated DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (product_id, warehouse_id),
    CONSTRAINT fk_inv_product FOREIGN KEY (product_id) REFERENCES product(product_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_inv_warehouse FOREIGN KEY (warehouse_id) REFERENCES warehouse(warehouse_id)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

-- ====================================================================
-- Orders: Purchase (incoming stock) & Sales (outgoing stock)
-- ====================================================================

-- Purchase orders header: one supplier, created by employee
CREATE TABLE purchase_order (
    po_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    po_number VARCHAR(50) NOT NULL UNIQUE,
    supplier_id INT UNSIGNED NOT NULL,
    created_by_employee_id INT UNSIGNED,
    status ENUM('DRAFT','ORDERED','RECEIVED','CANCELLED') NOT NULL DEFAULT 'DRAFT',
    order_date DATE NOT NULL DEFAULT (CURRENT_DATE),
    expected_date DATE,
    notes TEXT,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_po_supplier FOREIGN KEY (supplier_id) REFERENCES supplier(supplier_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_po_employee FOREIGN KEY (created_by_employee_id) REFERENCES employee(employee_id)
        ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB;

-- Purchase order items: many items per PO
CREATE TABLE purchase_order_item (
    po_item_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    po_id BIGINT UNSIGNED NOT NULL,
    product_id INT UNSIGNED NOT NULL,
    warehouse_id INT UNSIGNED NOT NULL, -- where the incoming stock will be stored
    quantity_ordered DECIMAL(14,4) NOT NULL,
    quantity_received DECIMAL(14,4) NOT NULL DEFAULT 0.0000,
    unit_price DECIMAL(12,4) DEFAULT 0.0000,
    notes TEXT,
    CONSTRAINT fk_poi_po FOREIGN KEY (po_id) REFERENCES purchase_order(po_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_poi_product FOREIGN KEY (product_id) REFERENCES product(product_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_poi_warehouse FOREIGN KEY (warehouse_id) REFERENCES warehouse(warehouse_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- Sales orders header: one customer, created by employee
CREATE TABLE sales_order (
    so_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    so_number VARCHAR(50) NOT NULL UNIQUE,
    customer_id INT UNSIGNED,
    created_by_employee_id INT UNSIGNED,
    status ENUM('DRAFT','CONFIRMED','FULFILLED','CANCELLED') NOT NULL DEFAULT 'DRAFT',
    order_date DATE NOT NULL DEFAULT (CURRENT_DATE),
    shipment_date DATE,
    notes TEXT,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_so_customer FOREIGN KEY (customer_id) REFERENCES customer(customer_id)
        ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT fk_so_employee FOREIGN KEY (created_by_employee_id) REFERENCES employee(employee_id)
        ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB;

-- Sales order items: many items per SO
CREATE TABLE sales_order_item (
    so_item_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    so_id BIGINT UNSIGNED NOT NULL,
    product_id INT UNSIGNED NOT NULL,
    warehouse_id INT UNSIGNED NOT NULL, -- from which warehouse the items will be shipped
    quantity_ordered DECIMAL(14,4) NOT NULL,
    quantity_shipped DECIMAL(14,4) NOT NULL DEFAULT 0.0000,
    unit_price DECIMAL(12,4) DEFAULT 0.0000,
    CONSTRAINT fk_soi_so FOREIGN KEY (so_id) REFERENCES sales_order(so_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_soi_product FOREIGN KEY (product_id) REFERENCES product(product_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_soi_warehouse FOREIGN KEY (warehouse_id) REFERENCES warehouse(warehouse_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ====================================================================
-- Stock Movement / Audit (All inventory changes recorded here)
-- ====================================================================
-- This table represents each change to inventory (inbound, outbound, adjustment, transfer)
CREATE TABLE stock_movement (
    movement_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    movement_type ENUM('PURCHASE_RECEIPT','SALES_SHIPMENT','ADJUSTMENT','TRANSFER_IN','TRANSFER_OUT','RETURN') NOT NULL,
    product_id INT UNSIGNED NOT NULL,
    from_warehouse_id INT UNSIGNED, -- nullable for receipts
    to_warehouse_id INT UNSIGNED,   -- nullable for shipments
    quantity DECIMAL(14,4) NOT NULL, -- positive number
    unit_id INT UNSIGNED NOT NULL,
    reference_type VARCHAR(50), -- e.g., 'PO', 'SO', 'ADJ'
    reference_id BIGINT UNSIGNED, -- id of PO or SO etc.
    performed_by_employee_id INT UNSIGNED,
    notes TEXT,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_sm_product FOREIGN KEY (product_id) REFERENCES product(product_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_sm_from_wh FOREIGN KEY (from_warehouse_id) REFERENCES warehouse(warehouse_id)
        ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT fk_sm_to_wh FOREIGN KEY (to_warehouse_id) REFERENCES warehouse(warehouse_id)
        ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT fk_sm_unit FOREIGN KEY (unit_id) REFERENCES unit(unit_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_sm_employee FOREIGN KEY (performed_by_employee_id) REFERENCES employee(employee_id)
        ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB;

-- ====================================================================
-- Helpful indexes to speed up common queries
-- ====================================================================
CREATE INDEX idx_product_sku_name ON product(sku, name);
CREATE INDEX idx_inventory_qty ON inventory(quantity);
CREATE INDEX idx_sm_product_date ON stock_movement(product_id, created_at);
CREATE INDEX idx_po_supplier_date ON purchase_order(supplier_id, order_date);
CREATE INDEX idx_so_customer_date ON sales_order(customer_id, order_date);

-- ====================================================================
-- Example data (optional) - uncomment to insert sample rows for testing
-- ====================================================================
/*
INSERT INTO unit (code, name) VALUES ('pcs','Pieces'),('kg','Kilogram'),('ltr','Liter');
INSERT INTO warehouse (code, name, address) VALUES ('WH1','Main Warehouse','100 Central Ave'),('WH2','Secondary','200 Depot St');
INSERT INTO supplier (name, contact_name, phone) VALUES ('ACME Supplies','Tina', '0123456789');
INSERT INTO customer (name, contact_name, phone) VALUES ('Retailer A','John','0987654321');
INSERT INTO employee (username, full_name, email) VALUES ('admin','System Admin','admin@example.com');
INSERT INTO category (name) VALUES ('Electronics'),('Furniture');
INSERT INTO product (sku,name,unit_id,purchase_price,retail_price) VALUES ('SKU-100','Widget A',1,10.00,15.00);
INSERT INTO product_category (product_id, category_id) VALUES (1,1);
INSERT INTO inventory (product_id, warehouse_id, quantity, reorder_level) VALUES (1,1,100,10);
*/

-- ====================================================================
-- Notes:
-- - inventory has composite PK (product_id, warehouse_id) to enforce unique inventory row per product+warehouse.
-- - product_category implements a MANY-TO-MANY relationship between products and categories.
-- - stock_movement logs every change (single source of truth for adjustments).
-- - purchase_order_item and sales_order_item reference warehouses so incoming/outgoing stock is targetted.
-- - Use transactions in application code to keep inventory and stock_movement synchronized.
-- ====================================================================
