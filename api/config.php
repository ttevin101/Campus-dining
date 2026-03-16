<?php
 $__env_candidates = [dirname(__DIR__) . '/.env', __DIR__ . '/.env'];
 foreach ($__env_candidates as $__env_path) {
     if (is_file($__env_path) && is_readable($__env_path)) {
         $lines = file($__env_path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
         if ($lines !== false) {
             foreach ($lines as $line) {
                 $line = trim($line);
                 if ($line === '' || $line[0] === '#' || $line[0] === ';') continue;
                 if (strpos($line, '=') === false) continue;
                 if (strpos($line, 'export ') === 0) $line = substr($line, 7);
                 [$key, $val] = explode('=', $line, 2);
                 $key = trim($key);
                 $val = trim($val);
                 if ($val !== '' && ((($val[0] ?? '') === '"' && substr($val, -1) === '"') || (($val[0] ?? '') === "'" && substr($val, -1) === "'"))) {
                     $val = substr($val, 1, -1);
                     $val = strtr($val, [
                         "\\n" => "\n",
                         "\\r" => "\r",
                         "\\t" => "\t",
                         "\\\"" => "\"",
                         "\\'" => "'",
                     ]);
                 }
                 $existing = getenv($key);
                 if ($existing !== false && $existing !== '') continue;
                 putenv($key . '=' . $val);
                 $_ENV[$key] = $val;
                 $_SERVER[$key] = $val;
             }
         }
         break;
     }
 }
 return [
     'db_host' => getenv('DB_HOST') ?: '127.0.0.1',
     'db_port' => getenv('DB_PORT') ?: '3306',
     'db_name' => getenv('DB_NAME') ?: 'campus_dining',
     'db_user' => getenv('DB_USER') ?: 'root',
     'db_pass' => getenv('DB_PASS') ?: '',
 ];
