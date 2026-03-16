# Campus Dining

A simple campus cafeteria management system with a PHP API (PDO + MySQL) and a vanilla HTML/CSS/JS frontend.

## Tech Stack

- PHP 8+ (built-in dev server) + PDO
- MySQL 8+
- Vanilla HTML/CSS/JS (served via a simple static server)

## Prerequisites

- PHP 8+ installed (macOS: `brew install php`)
- MySQL 8+ (or MariaDB)
- Python 3 (for a simple static server) or VS Code Live Server

## 1) Database Setup

Create the database and import the schema + seed data.

```bash
mysql -u root -e "CREATE DATABASE IF NOT EXISTS campus_dining CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -u root campus_dining < campus_dining_schema.sql
```

Verify tables:

```bash
mysql -u root -e "SHOW TABLES IN campus_dining;"
```

## 2) Environment Variables (.env)

The API reads configuration from environment variables and supports a `.env` file. The loader automatically looks for `.env` in the project root and `api/`.

Create/edit `.env` at the project root:

```dotenv
DB_HOST=127.0.0.1
DB_PORT=3306
DB_NAME=campus_dining
DB_USER=root
DB_PASS=''
```

Notes:

- Existing shell environment variables take precedence over `.env`.
- If your MySQL `root` user has no password, keep `DB_PASS=''` as shown.
- Restart the PHP server after changing `.env`.

## 3) Run the PHP API

From the project root:

```bash
php -S 127.0.0.1:8000 -t api
```

Health check:

```bash
curl -s http://127.0.0.1:8000/health
```

Sample data check:

```bash
curl -s http://127.0.0.1:8000/menu-items | head
```

## 4) Run the Frontend

Serve the HTML file with a simple static server (or VS Code Live Server):

```bash
python3 -m http.server 5500
# Open: http://127.0.0.1:5500/campus_dining_app_clean.html
```

## 5) Using the App

- Customer: enter your name + 6‑digit student ID and log in.
  - The app calls `POST /users/login` and creates the user if not present.
  - Browse Menu (loads from DB), add items to cart, checkout → order is saved.
  - View orders in “My Orders”.
- Staff: choose Staff login.
  - Inventory page loads real stock levels from DB (`/inventory`).

## 6) Key API Endpoints

- Health: `GET /health`
- Menu Items: `GET /menu-items`, `GET /menu-items/{id}`, `POST /menu-items`, `PATCH /menu-items/{id}`, `DELETE /menu-items/{id}`
- Orders: `POST /orders`, `GET /orders?customer_id={id}`, `GET /orders/{id}`, `PATCH /orders/{id}/status`
- Reservations: `POST /reservations`, `GET /reservations?customer_id={id}`, `GET /reservations/{id}`
- Dining Tables: `GET /dining-tables`
- Inventory: `GET /inventory`, `POST /inventory-transactions`
- Notifications: `GET /notifications?user_id={id}`, `PATCH /notifications/{id}/read`
- Users: `POST /users/login` (upsert by `student_id`)

## 7) Troubleshooting

- Address already in use (8000):
  ```bash
  lsof -ti:8000 | xargs kill -9
  ```
- MySQL access denied:
  - Ensure `DB_HOST=127.0.0.1` (not `localhost`)
  - If no password, keep `DB_PASS=''`
- CORS or fetch errors:
  - Serve the HTML via a local server (not `file://`)
  - The API sets permissive CORS for local dev
- `.env` changes not applied: restart the PHP server

## Project Structure

```
api/
  bootstrap.php     # CORS, JSON helpers, error handling
  config.php        # Loads .env and returns DB config
  db.php            # PDO connection
  index.php         # Routing + endpoint handlers

campus_dining_app_clean.html  # Frontend SPA
campus_dining_schema.sql      # Database schema + seed data
.env                           # Local environment variables (do not commit)
```

## Notes

- Keep `.env` out of version control. If desired, add it to `.gitignore`:
  ```
  .env
  ```
