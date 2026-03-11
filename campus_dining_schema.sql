-- ================================================================
--  CAMPUS DINING SYSTEM — MySQL Database Schema
--  Strathmore University · Nairobi, Kenya
--  Cafeteria Management System
--  Student IDs: 223250 | 221118
--  Supervisor: Lawrence Kasera
-- ================================================================

SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS sales_reports;
DROP TABLE IF EXISTS inventory_transactions;
DROP TABLE IF EXISTS feedback;
DROP TABLE IF EXISTS notifications;
DROP TABLE IF EXISTS reservations;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS menu_items;
DROP TABLE IF EXISTS dining_tables;
DROP TABLE IF EXISTS inventory;
DROP TABLE IF EXISTS users;

SET FOREIGN_KEY_CHECKS = 1;

-- ================================================================
-- TABLE 1: users
-- All system actors: students, lecturers, staff, sales clerks
-- ================================================================
CREATE TABLE users (
    user_id         INT          NOT NULL AUTO_INCREMENT,
    full_name       VARCHAR(120) NOT NULL,
    student_id      VARCHAR(30)  NOT NULL,
    email           VARCHAR(180) NULL,
    phone           VARCHAR(25)  NULL,
    role            ENUM('student','lecturer','staff','sales_clerk','admin')
                                 NOT NULL DEFAULT 'student',
    portal_type     ENUM('customer','staff') NOT NULL DEFAULT 'customer',
    password_hash   VARCHAR(255) NULL,
    is_active       TINYINT(1)   NOT NULL DEFAULT 1,
    created_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_login_at   DATETIME     NULL,
    PRIMARY KEY (user_id),
    UNIQUE KEY uq_users_student_id (student_id),
    UNIQUE KEY uq_users_email      (email),
    INDEX idx_users_role        (role),
    INDEX idx_users_portal_type (portal_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='All system users — students, lecturers, staff and portal admins';

-- ================================================================
-- TABLE 2: menu_items
-- Food and beverage items displayed in the dining menu
-- ================================================================
CREATE TABLE menu_items (
    item_id      INT           NOT NULL AUTO_INCREMENT,
    name         VARCHAR(120)  NOT NULL,
    emoji        VARCHAR(10)   NULL,
    meal_type    ENUM('Breakfast','Lunch','Dinner','Snacks') NOT NULL,
    category     ENUM('Local Dishes','Fast Food','Beverages','Snacks','Salads','Desserts')
                               NOT NULL DEFAULT 'Local Dishes',
    description  TEXT          NULL,
    price_ksh    DECIMAL(10,2) NOT NULL,
    image_url    VARCHAR(500)  NULL,
    is_available TINYINT(1)    NOT NULL DEFAULT 1,
    created_at   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (item_id),
    INDEX idx_menu_meal_type    (meal_type),
    INDEX idx_menu_category     (category),
    INDEX idx_menu_is_available (is_available)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Menu items available for customer ordering';

-- ================================================================
-- TABLE 3: dining_tables
-- Physical tables in the dining hall and seating areas
-- ================================================================
CREATE TABLE dining_tables (
    table_id     INT         NOT NULL AUTO_INCREMENT,
    table_number VARCHAR(10) NOT NULL,
    capacity     INT         NOT NULL,
    location     ENUM('Main Hall','Corner','Group Area','Outdoor','VIP')
                             NOT NULL DEFAULT 'Main Hall',
    is_available TINYINT(1)  NOT NULL DEFAULT 1,
    created_at   DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (table_id),
    UNIQUE KEY uq_dining_tables_number (table_number),
    INDEX idx_dining_tables_available  (is_available)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Physical dining tables with capacity and location details';

-- ================================================================
-- TABLE 4: inventory
-- Kitchen ingredient and supply stock
-- ================================================================
CREATE TABLE inventory (
    inventory_id  INT           NOT NULL AUTO_INCREMENT,
    name          VARCHAR(120)  NOT NULL,
    category      ENUM('Proteins','Vegetables','Grains','Dairy','Beverages','Condiments')
                                NOT NULL DEFAULT 'Grains',
    quantity      DECIMAL(10,2) NOT NULL DEFAULT 0,
    unit          ENUM('kg','litres','units','packets','grams') NOT NULL DEFAULT 'kg',
    reorder_level DECIMAL(10,2) NOT NULL DEFAULT 10,
    unit_cost_ksh DECIMAL(10,2) NOT NULL DEFAULT 0,
    is_active     TINYINT(1)    NOT NULL DEFAULT 1,
    created_at    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (inventory_id),
    INDEX idx_inventory_category (category),
    INDEX idx_inventory_quantity (quantity)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Kitchen ingredient and supply stock with reorder thresholds';

-- ================================================================
-- TABLE 5: orders
-- Customer order header — one row per placed order
-- ================================================================
CREATE TABLE orders (
    order_id         VARCHAR(20)   NOT NULL,
    customer_id      INT           NOT NULL,
    order_type       ENUM('dine_in','takeaway','pre_order') NOT NULL DEFAULT 'dine_in',
    total_amount_ksh DECIMAL(10,2) NOT NULL DEFAULT 0,
    status           ENUM('pending','confirmed','ready','completed','cancelled')
                                   NOT NULL DEFAULT 'pending',
    payment_method   ENUM('mobile_money','student_id_card','cash','card')
                                   NOT NULL DEFAULT 'cash',
    payment_status   ENUM('pending','paid','failed','refunded') NOT NULL DEFAULT 'pending',
    pickup_time      TIME          NULL,
    special_requests TEXT          NULL,
    ordered_at       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (order_id),
    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id) REFERENCES users (user_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    INDEX idx_orders_customer_id (customer_id),
    INDEX idx_orders_status      (status),
    INDEX idx_orders_ordered_at  (ordered_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Order header records — each customer order placed in the system';

-- ================================================================
-- TABLE 6: order_items
-- Individual line items for each order
-- ================================================================
CREATE TABLE order_items (
    order_item_id  INT           NOT NULL AUTO_INCREMENT,
    order_id       VARCHAR(20)   NOT NULL,
    item_id        INT           NOT NULL,
    quantity       INT           NOT NULL DEFAULT 1,
    unit_price_ksh DECIMAL(10,2) NOT NULL,
    line_total_ksh DECIMAL(10,2) GENERATED ALWAYS AS (quantity * unit_price_ksh) STORED,
    special_request TEXT         NULL,
    PRIMARY KEY (order_item_id),
    CONSTRAINT fk_order_items_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_order_items_menu
        FOREIGN KEY (item_id) REFERENCES menu_items (item_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    INDEX idx_order_items_order (order_id),
    INDEX idx_order_items_item  (item_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Line items for each order — one row per menu item per order';

-- ================================================================
-- TABLE 7: reservations
-- Table booking records made by customers
-- ================================================================
CREATE TABLE reservations (
    reservation_id   VARCHAR(20) NOT NULL,
    customer_id      INT         NOT NULL,
    table_id         INT         NOT NULL,
    party_size       INT         NOT NULL DEFAULT 1,
    reservation_time TIME        NOT NULL,
    deadline_time    TIME        NULL,
    notes            TEXT        NULL,
    status           ENUM('confirmed','cancelled','completed','no_show')
                                 NOT NULL DEFAULT 'confirmed',
    created_at       DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (reservation_id),
    CONSTRAINT fk_reservations_customer
        FOREIGN KEY (customer_id) REFERENCES users (user_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_reservations_table
        FOREIGN KEY (table_id) REFERENCES dining_tables (table_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    INDEX idx_reservations_customer (customer_id),
    INDEX idx_reservations_table    (table_id),
    INDEX idx_reservations_status   (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Customer table reservations including party size and time slot';

-- ================================================================
-- TABLE 8: feedback
-- Post-order ratings and comments submitted by customers
-- ================================================================
CREATE TABLE feedback (
    feedback_id    INT         NOT NULL AUTO_INCREMENT,
    order_id       VARCHAR(20) NOT NULL,
    customer_id    INT         NOT NULL,
    food_rating    TINYINT     NOT NULL,
    service_rating TINYINT     NULL,
    comment        TEXT        NULL,
    submitted_at   DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (feedback_id),
    UNIQUE KEY uq_feedback_order (order_id),
    CONSTRAINT fk_feedback_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_feedback_customer
        FOREIGN KEY (customer_id) REFERENCES users (user_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    INDEX idx_feedback_customer  (customer_id),
    INDEX idx_feedback_submitted (submitted_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Customer feedback with food and service ratings per completed order';

-- ================================================================
-- TABLE 9: notifications
-- In-app alerts for users and system-wide broadcasts
-- user_id = NULL means system broadcast (visible to all staff)
-- ================================================================
CREATE TABLE notifications (
    notification_id   INT       NOT NULL AUTO_INCREMENT,
    user_id           INT       NULL,
    notification_type ENUM('order_ready','reservation_reminder','stock_alert','promo','system')
                                NOT NULL DEFAULT 'system',
    message           TEXT      NOT NULL,
    is_read           TINYINT(1) NOT NULL DEFAULT 0,
    sent_at           DATETIME  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    read_at           DATETIME  NULL,
    PRIMARY KEY (notification_id),
    CONSTRAINT fk_notifications_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    INDEX idx_notifications_user    (user_id),
    INDEX idx_notifications_is_read (is_read),
    INDEX idx_notifications_sent_at (sent_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='User and system-wide notifications including order alerts and promos';

-- ================================================================
-- TABLE 10: inventory_transactions
-- Full audit trail of every stock movement in the kitchen
-- ================================================================
CREATE TABLE inventory_transactions (
    txn_id          INT           NOT NULL AUTO_INCREMENT,
    inventory_id    INT           NOT NULL,
    txn_type        ENUM('restock','sale_deduction','adjustment','wastage')
                                  NOT NULL DEFAULT 'restock',
    quantity_change DECIMAL(10,2) NOT NULL,
    performed_by    INT           NULL,
    notes           TEXT          NULL,
    txn_at          DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (txn_id),
    CONSTRAINT fk_inv_txn_inventory
        FOREIGN KEY (inventory_id) REFERENCES inventory (inventory_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_inv_txn_user
        FOREIGN KEY (performed_by) REFERENCES users (user_id)
        ON UPDATE CASCADE ON DELETE SET NULL,
    INDEX idx_inv_txn_inventory (inventory_id),
    INDEX idx_inv_txn_type      (txn_type),
    INDEX idx_inv_txn_at        (txn_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Audit log of all inventory stock movements — restock, sales, wastage';

-- ================================================================
-- TABLE 11: sales_reports
-- Daily aggregated sales snapshots generated by staff
-- ================================================================
CREATE TABLE sales_reports (
    report_id         INT           NOT NULL AUTO_INCREMENT,
    report_date       DATE          NOT NULL,
    total_orders      INT           NOT NULL DEFAULT 0,
    total_revenue_ksh DECIMAL(12,2) NOT NULL DEFAULT 0,
    items_sold        INT           NOT NULL DEFAULT 0,
    generated_by      INT           NULL,
    generated_at      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (report_id),
    UNIQUE KEY uq_sales_reports_date (report_date),
    CONSTRAINT fk_sales_reports_user
        FOREIGN KEY (generated_by) REFERENCES users (user_id)
        ON UPDATE CASCADE ON DELETE SET NULL,
    INDEX idx_sales_reports_date (report_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Daily rolled-up sales snapshots for management reporting';

-- ================================================================
-- SEED DATA
-- ================================================================

INSERT INTO users (full_name, student_id, email, phone, role, portal_type) VALUES
('Kas Baby',       '221939', 'kas.baby@strathmore.edu',       '+254700000001', 'student',     'customer'),
('Karen Judith',   '221118', 'karen.judith@strathmore.edu',   '+254700000002', 'student',     'customer'),
('Tendo Moses',    '223250', 'tendo.moses@strathmore.edu',    '+254700000003', 'student',     'customer'),
('Cynthia Masaba', '223013', 'cynthia.masaba@strathmore.edu', '+254700000004', 'lecturer',    'customer'),
('John Kamau',     'STAFF01','john.kamau@strathmore.edu',     '+254700000005', 'sales_clerk', 'staff'),
('Grace Wanjiru',  'STAFF02','grace.wanjiru@strathmore.edu',  '+254700000006', 'admin',       'staff');

INSERT INTO menu_items (name, emoji, meal_type, category, description, price_ksh, is_available) VALUES
('Mandazi & Chai',         '🍩','Breakfast','Local Dishes','Freshly fried mandazi served with a hot cup of spiced Kenyan chai.',         80.00, 1),
('Scrambled Eggs & Toast', '🥚','Breakfast','Fast Food',   'Fluffy scrambled eggs with buttered wholemeal toast and fresh juice.',       120.00,1),
('Uji wa Wimbi',           '🥣','Breakfast','Local Dishes','Warm millet porridge, lightly sweetened. Nutritious start to the day.',      60.00, 1),
('Full Breakfast Plate',   '🍳','Breakfast','Fast Food',   'Eggs, sausages, baked beans, toast and juice. The ultimate morning fuel.',   220.00,1),
('Ugali na Nyama',         '🍖','Lunch',    'Local Dishes','Traditional ugali with tender beef stew and sukuma wiki.',                   200.00,1),
('Rice & Chicken Curry',   '🍛','Lunch',    'Local Dishes','Basmati rice with rich aromatic chicken curry and kachumbari.',              220.00,1),
('Chapati & Beans',        '🫓','Lunch',    'Local Dishes','Soft layered chapati with spiced kidney beans.',                            130.00,1),
('Pilau with Kachumbari',  '🍚','Lunch',    'Local Dishes','Fragrant pilau rice with cumin, cardamom and pepper.',                      190.00,1),
('Beef Burger',            '🍔','Lunch',    'Fast Food',   'Juicy beef patty with lettuce, tomato, pickles and cheese.',                280.00,1),
('Chicken Wrap',           '🌯','Lunch',    'Fast Food',   'Grilled chicken strips with avocado and garlic sauce in a soft tortilla.',   250.00,0),
('Mukimo & Stew',          '🥘','Dinner',   'Local Dishes','Mashed green maize, potatoes and peas with slow-cooked beef stew.',         180.00,1),
('Pasta Bolognese',        '🍝','Dinner',   'Fast Food',   'Al dente pasta with a rich meat sauce and parmesan cheese.',                260.00,1),
('Grilled Tilapia',        '🐟','Dinner',   'Local Dishes','Whole grilled tilapia with ugali and steamed vegetables.',                  320.00,1),
('Vegetable Fried Rice',   '🥗','Dinner',   'Salads',      'Fried rice with mixed vegetables, eggs and soy sauce.',                     150.00,1),
('Fresh Juice',            '🥤','Snacks',   'Beverages',   'Freshly squeezed mango, passion or orange juice.',                          80.00, 1),
('Samosa (3 pcs)',          '🥟','Snacks',   'Snacks',      'Crispy golden samosas filled with spiced minced beef or vegetables.',        90.00, 1),
('Fruit Salad',            '🍓','Snacks',   'Desserts',    'Seasonal fresh fruits — mango, pineapple, watermelon, banana.',             120.00,1),
('Masala Tea',             '☕','Snacks',   'Beverages',   'Spiced Kenyan milk tea with ginger, cardamom and cinnamon.',                 60.00, 1);

INSERT INTO dining_tables (table_number, capacity, location, is_available) VALUES
('T-01',4,'Main Hall', 1),('T-02',4,'Main Hall', 1),('T-03',6,'Main Hall', 0),
('T-04',2,'Corner',    1),('T-05',8,'Group Area',1),('T-06',4,'Outdoor',   1),
('T-07',2,'Outdoor',   0),('T-08',6,'VIP',       1);

INSERT INTO inventory (name, category, quantity, unit, reorder_level, unit_cost_ksh) VALUES
('Chicken Breast',    'Proteins',  45,'kg',    10,650),
('Beef (Stewing)',    'Proteins',   8,'kg',    15,800),
('Tilapia Fish',      'Proteins',  20,'kg',     8,400),
('Maize Flour (Unga)','Grains',    80,'kg',    20, 80),
('Rice (Basmati)',    'Grains',    60,'kg',    15,150),
('Milk',              'Dairy',      5,'litres', 20, 70),
('Sukuma Wiki',       'Vegetables',25,'kg',     5, 30),
('Tomatoes',          'Vegetables',15,'kg',     5, 60),
('Cooking Oil',       'Condiments',12,'litres', 5,250),
('Tea Leaves',        'Beverages',  3,'kg',     2,900);

INSERT INTO orders (order_id, customer_id, order_type, total_amount_ksh, status, payment_method, payment_status, pickup_time, ordered_at) VALUES
('ORD-987',1,'dine_in', 280,'completed','mobile_money',   'paid',   '12:00:00','2026-03-10 11:30:00'),
('ORD-988',2,'takeaway',220,'confirmed','student_id_card','pending','12:30:00','2026-03-10 12:05:00'),
('ORD-989',3,'dine_in', 620,'pending',  'cash',           'pending','12:45:00','2026-03-10 12:15:00'),
('ORD-990',4,'takeaway',130,'ready',    'mobile_money',   'paid',   '12:40:00','2026-03-10 12:20:00');

INSERT INTO order_items (order_id, item_id, quantity, unit_price_ksh) VALUES
('ORD-987',5,1,200),('ORD-987',15,1,80),('ORD-988',6,1,220),
('ORD-989',9,2,280),('ORD-989',18,1,60),('ORD-990',7,1,130);

INSERT INTO reservations (reservation_id, customer_id, table_id, party_size, reservation_time, deadline_time, notes, status, created_at) VALUES
('RES-100',1,4,2,'12:30:00','12:45:00','Near window','confirmed','2026-01-15 11:00:00'),
('RES-101',2,3,5,'13:00:00','13:15:00','',           'confirmed','2026-01-15 11:30:00');

INSERT INTO notifications (user_id, notification_type, message, is_read, sent_at) VALUES
(1,   'order_ready',          'Your order ORD-987 is ready for pickup at the counter!',         0,'2026-03-10 11:55:00'),
(1,   'reservation_reminder', 'Reminder: Your table RES-100 is reserved for 12:30.',           1,'2026-03-10 12:15:00'),
(2,   'promo',                'Today only — 10% off all Snacks before 3 PM!',                  0,'2026-03-10 09:00:00'),
(NULL,'stock_alert',          'Milk is below reorder level (5 L remaining, reorder at 20 L).', 0,'2026-03-10 08:30:00'),
(NULL,'system',               'Scheduled maintenance Sunday 02:00 to 04:00 AM.',               0,'2026-03-10 07:00:00');

INSERT INTO inventory_transactions (inventory_id, txn_type, quantity_change, performed_by, notes, txn_at) VALUES
(1, 'restock',45,5,'Initial stock entry',        '2026-03-10 07:00:00'),
(2, 'restock', 8,5,'Initial stock entry',        '2026-03-10 07:00:00'),
(3, 'restock',20,5,'Initial stock entry',        '2026-03-10 07:00:00'),
(6, 'restock', 5,5,'Initial stock — low supply', '2026-03-10 07:00:00'),
(10,'restock', 3,5,'Initial stock entry',        '2026-03-10 07:00:00');

-- ================================================================
-- VIEWS
-- ================================================================

CREATE OR REPLACE VIEW v_active_menu AS
    SELECT item_id, name, emoji, meal_type, category, price_ksh, description
    FROM   menu_items WHERE is_available = 1
    ORDER  BY FIELD(meal_type,'Breakfast','Lunch','Dinner','Snacks'), name;

CREATE OR REPLACE VIEW v_stock_levels AS
    SELECT inventory_id, name, category, quantity, reorder_level, unit, unit_cost_ksh,
           ROUND((quantity / NULLIF(reorder_level,0)) * 100, 0) AS stock_pct,
           CASE WHEN quantity <= reorder_level/2 THEN 'CRITICAL'
                WHEN quantity <= reorder_level   THEN 'LOW' ELSE 'OK' END AS stock_status
    FROM   inventory WHERE is_active = 1 ORDER BY stock_pct ASC;

CREATE OR REPLACE VIEW v_order_summary AS
    SELECT o.order_id, u.full_name AS customer_name, u.student_id,
           o.order_type, o.total_amount_ksh, o.status,
           o.payment_method, o.payment_status, o.pickup_time, o.ordered_at
    FROM   orders o JOIN users u ON u.user_id = o.customer_id
    ORDER  BY o.ordered_at DESC;

CREATE OR REPLACE VIEW v_daily_revenue AS
    SELECT DATE(ordered_at) AS report_date, COUNT(*) AS total_orders,
           SUM(total_amount_ksh) AS gross_revenue_ksh,
           SUM(CASE WHEN status='completed' THEN total_amount_ksh ELSE 0 END) AS confirmed_revenue_ksh
    FROM   orders GROUP BY DATE(ordered_at) ORDER BY report_date DESC;

CREATE OR REPLACE VIEW v_feedback_summary AS
    SELECT f.feedback_id, f.order_id, u.full_name AS customer_name,
           f.food_rating, f.service_rating,
           ROUND((f.food_rating + COALESCE(f.service_rating,f.food_rating))/2.0,1) AS avg_rating,
           f.comment, f.submitted_at
    FROM   feedback f JOIN users u ON u.user_id = f.customer_id
    ORDER  BY f.submitted_at DESC;

CREATE OR REPLACE VIEW v_top_menu_items AS
    SELECT m.name, m.meal_type, m.category,
           SUM(oi.quantity) AS total_qty_sold,
           SUM(oi.line_total_ksh) AS total_revenue_ksh
    FROM   order_items oi
    JOIN   menu_items m ON m.item_id = oi.item_id
    JOIN   orders     o ON o.order_id = oi.order_id
    WHERE  o.status = 'completed'
    GROUP  BY m.item_id, m.name, m.meal_type, m.category
    ORDER  BY total_qty_sold DESC;

-- ================================================================
-- END OF SCHEMA
-- ================================================================
