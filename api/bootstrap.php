<?php
declare(strict_types=1);

// Basic CORS for local development
$origin = $_SERVER['HTTP_ORIGIN'] ?? '*';
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Credentials: true');
header('Access-Control-Allow-Methods: GET, POST, PUT, PATCH, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With, X-HTTP-Method-Override');
header('Content-Type: application/json; charset=utf-8');

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') {
    http_response_code(204);
    exit;
}

set_exception_handler(function (Throwable $e) {
    http_response_code(500);
    echo json_encode([
        'error' => 'Server error',
        'message' => $e->getMessage(),
    ]);
    exit;
});

function read_json_body(): array {
    $raw = file_get_contents('php://input');
    if ($raw === false || $raw === '') return [];
    $data = json_decode($raw, true);
    if (json_last_error() !== JSON_ERROR_NONE) {
        http_response_code(400);
        echo json_encode(['error' => 'Invalid JSON body']);
        exit;
    }
    return $data ?: [];
}

function json_response($data, int $status = 200): void {
    http_response_code($status);
    echo json_encode($data);
    exit;
}

function bad_request(string $message = 'Bad Request'): void { json_response(['error' => $message], 400); }
function not_found(string $message = 'Not Found'): void { json_response(['error' => $message], 404); }
function method_not_allowed($allowed): void {
    header('Allow: ' . implode(', ', (array)$allowed));
    json_response(['error' => 'Method Not Allowed'], 405);
}

function require_fields(array $data, array $fields): void {
    foreach ($fields as $f) {
        if (!array_key_exists($f, $data)) {
            bad_request("Missing field: $f");
        }
    }
}
