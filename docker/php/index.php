<?php
# SPDX-License-Identifier: MPL-2.0

echo "<h1>PHP " . PHP_VERSION . "</h1>";
echo "<p>This container is running PHP CLI version: <code>" . PHP_BINARY . "</code></p>";

// Attempt to detect FPM socket from environment or config
$fpm_socket = ini_get("listen");
if (!$fpm_socket) {
    $fpm_socket = "unknown (not running FPM?)";
}

echo "<p>FPM socket (from ini_get): <code>$fpm_socket</code></p>";
echo "<hr>";

phpinfo();
