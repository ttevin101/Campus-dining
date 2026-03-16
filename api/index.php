<?php
declare(strict_types=1);

require __DIR__ . '/bootstrap.php';
require __DIR__ . '/db.php';

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
$path = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';
$segments = array_values(array_filter(explode('/', trim($path, '/'))));

// If serving from /api, drop the first segment if it is 'api'
if (!empty($segments) && strtolower($segments[0]) === 'api') {
    array_shift($segments);
}

$route = $segments[0] ?? '';
$id = $segments[1] ?? null;
$sub = $segments[2] ?? null;

switch ($route) {
    case 'health':
        json_response(['status' => 'ok', 'time' => date('c')]);
        break;

    case 'menu-items':
        handle_menu_items($method, $id);
        break;

    case 'orders':
        handle_orders($method, $id, $sub);
        break;

    case 'reservations':
        handle_reservations($method, $id);
        break;

    case 'dining-tables':
        handle_dining_tables($method, $id);
        break;

    case 'inventory':
        handle_inventory($method, $id);
        break;

    case 'inventory-transactions':
        handle_inventory_txn($method);
        break;

    case 'notifications':
        handle_notifications($method, $id, $sub);
        break;

    case 'sales-reports':
        handle_sales_reports($method, $id, $sub);
        break;

    case 'users':
        handle_users($method, $id, $sub);
        break;

    default:
        not_found('Unknown route');
}

// ===== Menu Items =====
function handle_menu_items(string $method, $id): void {
    if ($id !== null && !ctype_digit($id)) {
        bad_request('Invalid item id');
    }
    $pdo = db();

    if ($method === 'GET' && $id === null) {
        $available = isset($_GET['available']) ? (int)$_GET['available'] : null;
        $meal = $_GET['meal_type'] ?? null;
        $cat = $_GET['category'] ?? null;
        $q = 'SELECT * FROM menu_items WHERE 1=1';
        $params = [];
        if ($available !== null) { $q .= ' AND is_available = ?'; $params[] = $available; }
        if ($meal) { $q .= ' AND meal_type = ?'; $params[] = $meal; }
        if ($cat)  { $q .= ' AND category = ?'; $params[] = $cat; }
        $q .= ' ORDER BY FIELD(meal_type,\'Breakfast\',\'Lunch\',\'Dinner\',\'Snacks\'), name';
        $stmt = $pdo->prepare($q);
        $stmt->execute($params);
        json_response($stmt->fetchAll());
    }

    if ($method === 'GET' && $id !== null) {
        $stmt = $pdo->prepare('SELECT * FROM menu_items WHERE item_id = ?');
        $stmt->execute([$id]);
        $row = $stmt->fetch();
        if (!$row) not_found('Menu item not found');
        json_response($row);
    }

    if ($method === 'POST' && $id === null) {
        $d = read_json_body();
        require_fields($d, ['name','meal_type','category','price_ksh']);
        $stmt = $pdo->prepare('INSERT INTO menu_items (name, emoji, meal_type, category, description, price_ksh, image_url, is_available) VALUES (?,?,?,?,?,?,?,?)');
        $stmt->execute([
            $d['name'], $d['emoji'] ?? null, $d['meal_type'], $d['category'], $d['description'] ?? null,
            $d['price_ksh'], $d['image_url'] ?? null, isset($d['is_available']) ? (int)$d['is_available'] : 1
        ]);
        $newId = (int)$pdo->lastInsertId();
        $stmt = $pdo->prepare('SELECT * FROM menu_items WHERE item_id = ?');
        $stmt->execute([$newId]);
        json_response($stmt->fetch(), 201);
    }

    if (($method === 'PUT' || $method === 'PATCH') && $id !== null) {
        $d = read_json_body();
        // Build dynamic update
        $fields = ['name','emoji','meal_type','category','description','price_ksh','image_url','is_available'];
        $sets = [];$vals=[];
        foreach ($fields as $f) {
            if (array_key_exists($f, $d)) { $sets[] = "$f = ?"; $vals[] = $d[$f]; }
        }
        if (!$sets) bad_request('No updatable fields supplied');
        $vals[] = $id;
        $sql = 'UPDATE menu_items SET ' . implode(', ', $sets) . ' WHERE item_id = ?';
        $stmt = $pdo->prepare($sql);
        $stmt->execute($vals);
        $stmt = $pdo->prepare('SELECT * FROM menu_items WHERE item_id = ?');
        $stmt->execute([$id]);
        json_response($stmt->fetch());
    }

    if ($method === 'DELETE' && $id !== null) {
        $stmt = $pdo->prepare('DELETE FROM menu_items WHERE item_id = ?');
        $stmt->execute([$id]);
        json_response(['deleted' => true]);
    }

    method_not_allowed(['GET','POST','PUT','PATCH','DELETE']);
}

// ===== Orders =====
function handle_orders(string $method, $id, $sub): void {
    $pdo = db();

    if ($method === 'GET' && $id === null) {
        $where = [];$params = [];
        if (isset($_GET['status'])) { $where[] = 'o.status = ?'; $params[] = $_GET['status']; }
        if (isset($_GET['customer_id'])) { $where[] = 'o.customer_id = ?'; $params[] = (int)$_GET['customer_id']; }
        $sql = 'SELECT o.* FROM orders o';
        if ($where) { $sql .= ' WHERE ' . implode(' AND ', $where); }
        $sql .= ' ORDER BY o.ordered_at DESC';
        $stmt = $pdo->prepare($sql);
        $stmt->execute($params);
        $orders = $stmt->fetchAll();
        if (!$orders) json_response([]);
        $ids = array_column($orders, 'order_id');
        $in = implode(',', array_fill(0, count($ids), '?'));
        $st2 = $pdo->prepare("SELECT * FROM order_items WHERE order_id IN ($in) ORDER BY order_item_id");
        $st2->execute($ids);
        $items = $st2->fetchAll();
        $byOrder = [];
        foreach ($items as $it) { $byOrder[$it['order_id']][] = $it; }
        foreach ($orders as &$o) { $o['items'] = $byOrder[$o['order_id']] ?? []; }
        json_response($orders);
    }

    if ($method === 'GET' && $id !== null && $sub === null) {
        $st = $pdo->prepare('SELECT * FROM orders WHERE order_id = ?');
        $st->execute([$id]);
        $o = $st->fetch();
        if (!$o) not_found('Order not found');
        $st2 = $pdo->prepare('SELECT * FROM order_items WHERE order_id = ? ORDER BY order_item_id');
        $st2->execute([$id]);
        $o['items'] = $st2->fetchAll();
        json_response($o);
    }

    if ($method === 'POST' && $id === null) {
        $d = read_json_body();
        require_fields($d, ['customer_id','order_type','payment_method','items']);
        if (!is_array($d['items']) || !$d['items']) bad_request('Items array required');

        $pdo->beginTransaction();
        try {
            // Generate order id if not provided
            $orderId = $d['order_id'] ?? ('ORD-' . mt_rand(100000, 999999));
            // Compute total and backfill unit prices if missing
            $total = 0.0;
            foreach ($d['items'] as &$it) {
                if (!isset($it['item_id']) || !isset($it['quantity'])) bad_request('Each item requires item_id and quantity');
                if (!isset($it['unit_price_ksh'])) {
                    $p = $pdo->prepare('SELECT price_ksh FROM menu_items WHERE item_id = ?');
                    $p->execute([$it['item_id']]);
                    $row = $p->fetch();
                    if (!$row) bad_request('Invalid item_id ' . $it['item_id']);
                    $it['unit_price_ksh'] = (float)$row['price_ksh'];
                }
                $total += (float)$it['unit_price_ksh'] * (int)$it['quantity'];
            }
            unset($it);

            $st = $pdo->prepare('INSERT INTO orders (order_id, customer_id, order_type, total_amount_ksh, status, payment_method, payment_status, pickup_time, special_requests) VALUES (?,?,?,?,?,?,?,?,?)');
            $st->execute([
                $orderId,
                (int)$d['customer_id'],
                $d['order_type'],
                $total,
                $d['status'] ?? 'pending',
                $d['payment_method'],
                $d['payment_status'] ?? 'pending',
                $d['pickup_time'] ?? null,
                $d['special_requests'] ?? null,
            ]);

            $sti = $pdo->prepare('INSERT INTO order_items (order_id, item_id, quantity, unit_price_ksh, special_request) VALUES (?,?,?,?,?)');
            foreach ($d['items'] as $it) {
                $sti->execute([$orderId, (int)$it['item_id'], (int)$it['quantity'], (float)$it['unit_price_ksh'], $it['special_request'] ?? null]);
            }
            $pdo->commit();

            $st = $pdo->prepare('SELECT * FROM orders WHERE order_id = ?');
            $st->execute([$orderId]);
            $o = $st->fetch();
            $st2 = $pdo->prepare('SELECT * FROM order_items WHERE order_id = ? ORDER BY order_item_id');
            $st2->execute([$orderId]);
            $o['items'] = $st2->fetchAll();
            json_response($o, 201);
        } catch (Throwable $e) {
            $pdo->rollBack();
            throw $e;
        }
    }

    if (($method === 'PUT' || $method === 'PATCH') && $id !== null && $sub === 'status') {
        $d = read_json_body();
        if (!isset($d['status']) && !isset($d['payment_status'])) bad_request('Provide status and/or payment_status');
        $fields=[];$vals=[];
        if (isset($d['status'])) { $fields[] = 'status = ?'; $vals[] = $d['status']; }
        if (isset($d['payment_status'])) { $fields[] = 'payment_status = ?'; $vals[] = $d['payment_status']; }
        $vals[] = $id;
        $sql = 'UPDATE orders SET ' . implode(', ', $fields) . ', updated_at = CURRENT_TIMESTAMP WHERE order_id = ?';
        $st = db()->prepare($sql);
        $st->execute($vals);
        $st = db()->prepare('SELECT * FROM orders WHERE order_id = ?');
        $st->execute([$id]);
        $o = $st->fetch();
        json_response($o);
    }

    method_not_allowed(['GET','POST','PATCH','PUT']);
}

// ===== Reservations =====
function handle_reservations(string $method, $id): void {
    $pdo = db();

    if ($method === 'GET' && $id === null) {
        $where=[];$params=[];
        if (isset($_GET['customer_id'])) { $where[] = 'r.customer_id = ?'; $params[] = (int)$_GET['customer_id']; }
        if (isset($_GET['status'])) { $where[] = 'r.status = ?'; $params[] = $_GET['status']; }
        $sql = 'SELECT r.*, dt.table_number FROM reservations r JOIN dining_tables dt ON dt.table_id = r.table_id';
        if ($where) { $sql .= ' WHERE ' . implode(' AND ', $where); }
        $sql .= ' ORDER BY r.created_at DESC';
        $st = $pdo->prepare($sql);
        $st->execute($params);
        json_response($st->fetchAll());
    }

    if ($method === 'GET' && $id !== null) {
        $st = $pdo->prepare('SELECT * FROM reservations WHERE reservation_id = ?');
        $st->execute([$id]);
        $r = $st->fetch();
        if (!$r) not_found('Reservation not found');
        json_response($r);
    }

    if ($method === 'POST' && $id === null) {
        $d = read_json_body();
        require_fields($d, ['customer_id','table_id','party_size','reservation_time']);
        $resId = $d['reservation_id'] ?? ('RES-' . mt_rand(100, 999) . mt_rand(100, 999));
        // Basic availability check (same time slot and confirmed)
        $chk = $pdo->prepare('SELECT COUNT(*) AS c FROM reservations WHERE table_id = ? AND reservation_time = ? AND status = \'confirmed\'');
        $chk->execute([(int)$d['table_id'], $d['reservation_time']]);
        $c = (int)$chk->fetch()['c'];
        if ($c > 0) bad_request('Table already reserved at that time');

        $st = $pdo->prepare('INSERT INTO reservations (reservation_id, customer_id, table_id, party_size, reservation_time, deadline_time, notes, status) VALUES (?,?,?,?,?,?,?,?)');
        $st->execute([
            $resId,
            (int)$d['customer_id'],
            (int)$d['table_id'],
            (int)$d['party_size'],
            $d['reservation_time'],
            $d['deadline_time'] ?? null,
            $d['notes'] ?? null,
            $d['status'] ?? 'confirmed',
        ]);
        $st = $pdo->prepare('SELECT * FROM reservations WHERE reservation_id = ?');
        $st->execute([$resId]);
        json_response($st->fetch(), 201);
    }

    if (($method === 'PUT' || $method === 'PATCH') && $id !== null) {
        $d = read_json_body();
        $fields = ['party_size','reservation_time','deadline_time','notes','status','table_id'];
        $sets=[];$vals=[];
        foreach ($fields as $f) if (array_key_exists($f, $d)) { $sets[] = "$f = ?"; $vals[] = $d[$f]; }
        if (!$sets) bad_request('No updatable fields supplied');
        $vals[] = $id;
        $sql = 'UPDATE reservations SET ' . implode(', ', $sets) . ', updated_at = CURRENT_TIMESTAMP WHERE reservation_id = ?';
        $st = $pdo->prepare($sql);
        $st->execute($vals);
        $st = $pdo->prepare('SELECT * FROM reservations WHERE reservation_id = ?');
        $st->execute([$id]);
        json_response($st->fetch());
    }

    method_not_allowed(['GET','POST','PUT','PATCH']);
}

// ===== Dining Tables =====
function handle_dining_tables(string $method, $id): void {
    $pdo = db();

    if ($method === 'GET' && $id === null) {
        $st = $pdo->query('SELECT * FROM dining_tables ORDER BY table_number');
        json_response($st->fetchAll());
    }

    if ($method === 'GET' && $id !== null) {
        if (!ctype_digit((string)$id)) bad_request('Invalid table id');
        $st = $pdo->prepare('SELECT * FROM dining_tables WHERE table_id = ?');
        $st->execute([(int)$id]);
        $row = $st->fetch();
        if (!$row) not_found('Table not found');
        json_response($row);
    }

    method_not_allowed(['GET']);
}

// ===== Inventory =====
function handle_inventory(string $method, $id): void {
    $pdo = db();

    if ($method === 'GET') {
        try {
            $st = $pdo->query('SELECT * FROM v_stock_levels');
            json_response($st->fetchAll());
        } catch (Throwable $e) {
            // Fallback if view not present
            $st = $pdo->query('SELECT inventory_id, name, category, quantity, reorder_level, unit, unit_cost_ksh FROM inventory WHERE is_active = 1');
            $rows = $st->fetchAll();
            foreach ($rows as &$r) {
                $pct = ($r['reorder_level'] > 0) ? round(($r['quantity'] / $r['reorder_level']) * 100) : null;
                $r['stock_pct'] = $pct;
                $r['stock_status'] = ($pct === null) ? 'OK' : ($r['quantity'] <= $r['reorder_level'] / 2 ? 'CRITICAL' : ($r['quantity'] <= $r['reorder_level'] ? 'LOW' : 'OK'));
            }
            json_response($rows);
        }
    }

    method_not_allowed(['GET']);
}

function handle_inventory_txn(string $method): void {
    if ($method !== 'POST') method_not_allowed(['POST']);
    $d = read_json_body();
    require_fields($d, ['inventory_id','txn_type','quantity_change']);
    $pdo = db();
    $pdo->beginTransaction();
    try {
        $sti = $pdo->prepare('INSERT INTO inventory_transactions (inventory_id, txn_type, quantity_change, performed_by, notes) VALUES (?,?,?,?,?)');
        $sti->execute([(int)$d['inventory_id'], $d['txn_type'], (float)$d['quantity_change'], $d['performed_by'] ?? null, $d['notes'] ?? null]);
        // Update inventory quantity (quantity_change may be negative)
        $upd = $pdo->prepare('UPDATE inventory SET quantity = quantity + ? WHERE inventory_id = ?');
        $upd->execute([(float)$d['quantity_change'], (int)$d['inventory_id']]);
        $pdo->commit();
        json_response(['ok' => true], 201);
    } catch (Throwable $e) {
        $pdo->rollBack();
        throw $e;
    }
}

// ===== Notifications =====
function handle_notifications(string $method, $id, $sub): void {
    $pdo = db();

    if ($method === 'GET' && $id === null) {
        $where=[];$params=[];
        if (isset($_GET['user_id'])) { $where[] = '(user_id = ? OR user_id IS NULL)'; $params[] = (int)$_GET['user_id']; }
        if (isset($_GET['is_read'])) { $where[] = 'is_read = ?'; $params[] = (int)$_GET['is_read']; }
        $sql = 'SELECT * FROM notifications';
        if ($where) $sql .= ' WHERE ' . implode(' AND ', $where);
        $sql .= ' ORDER BY sent_at DESC, notification_id DESC';
        $st = $pdo->prepare($sql);
        $st->execute($params);
        json_response($st->fetchAll());
    }

    if (($method === 'PUT' || $method === 'PATCH') && $id !== null && $sub === 'read') {
        $now = date('Y-m-d H:i:s');
        $st = $pdo->prepare('UPDATE notifications SET is_read = 1, read_at = ? WHERE notification_id = ?');
        $st->execute([$now, (int)$id]);
        json_response(['ok' => true]);
    }

    if ($method === 'POST' && $id === 'mark-all-read') {
        $d = read_json_body();
        require_fields($d, ['user_id']);
        $now = date('Y-m-d H:i:s');
        $st = $pdo->prepare('UPDATE notifications SET is_read = 1, read_at = ? WHERE user_id = ?');
        $st->execute([$now, (int)$d['user_id']]);
        json_response(['ok' => true]);
    }

    method_not_allowed(['GET','PATCH','PUT','POST']);
}

// ===== Sales Reports =====
function handle_sales_reports(string $method, $id, $sub): void {
    $pdo = db();

    if ($method === 'GET' && $id === null) {
        $st = $pdo->query('SELECT * FROM sales_reports ORDER BY report_date DESC');
        json_response($st->fetchAll());
    }

    if ($method === 'POST' && $id === 'generate') {
        $d = read_json_body();
        $userId = isset($d['user_id']) ? (int)$d['user_id'] : null;
        // Compute for today (server date)
        $today = (new DateTime('now', new DateTimeZone('Africa/Nairobi')))->format('Y-m-d');

        $st = $pdo->prepare('SELECT COUNT(*) AS total_orders, SUM(CASE WHEN status = \'completed\' THEN total_amount_ksh ELSE 0 END) AS total_revenue_ksh FROM orders WHERE DATE(ordered_at) = ?');
        $st->execute([$today]);
        $row = $st->fetch() ?: ['total_orders' => 0, 'total_revenue_ksh' => 0];

        $st2 = $pdo->prepare('SELECT SUM(oi.quantity) AS items_sold FROM order_items oi JOIN orders o ON o.order_id = oi.order_id WHERE DATE(o.ordered_at) = ? AND o.status = \'completed\'');
        $st2->execute([$today]);
        $itemsSold = (int)($st2->fetch()['items_sold'] ?? 0);

        // Upsert
        $sql = 'INSERT INTO sales_reports (report_date, total_orders, total_revenue_ksh, items_sold, generated_by) VALUES (?,?,?,?,?) ON DUPLICATE KEY UPDATE total_orders=VALUES(total_orders), total_revenue_ksh=VALUES(total_revenue_ksh), items_sold=VALUES(items_sold), generated_by=VALUES(generated_by), generated_at=CURRENT_TIMESTAMP';
        $st3 = $pdo->prepare($sql);
        $st3->execute([$today, (int)$row['total_orders'], (float)($row['total_revenue_ksh'] ?? 0), $itemsSold, $userId]);

        $st4 = $pdo->prepare('SELECT * FROM sales_reports WHERE report_date = ?');
        $st4->execute([$today]);
        json_response($st4->fetch(), 201);
    }

    method_not_allowed(['GET','POST']);
}

// ===== Users (basic lookup for prototype) =====
function handle_users(string $method, $id, $sub): void {
    if ($method === 'POST' && $id === 'login') {
        $d = read_json_body();
        if (!isset($d['student_id'])) bad_request('student_id is required');
        require_fields($d, ['name', 'email']);
        
        $pdo = db();
        $st = $pdo->prepare('SELECT * FROM users WHERE student_id = ?');
        $st->execute([$d['student_id']]);
        $u = $st->fetch();
        
        if (!$u) {
            $insert = $pdo->prepare('INSERT INTO users (student_id, full_name, email, phone, role, created_at) VALUES (?, ?, ?, ?, ?, NOW())');
            $insert->execute([
                $d['student_id'],
                $d['name'],
                $d['email'],
                $d['phone'] ?? null,
                $d['role'] ?? 'student',
            ]);
            $userId = $pdo->lastInsertId();
            $st = $pdo->prepare('SELECT * FROM users WHERE user_id = ?');
            $st->execute([$userId]);
            $u = $st->fetch();
        }
        
        json_response($u);
    }
    method_not_allowed(['POST']);
}
