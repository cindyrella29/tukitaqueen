<?php
declare(strict_types=1);

require_once __DIR__ . '/db_config.php';

function tq_clean(string $value): string
{
    return trim($value);
}

function tq_response(string $title, string $message, int $statusCode = 200): void
{
    http_response_code($statusCode);
    $safeTitle = htmlspecialchars($title, ENT_QUOTES, 'UTF-8');
    $safeMessage = htmlspecialchars($message, ENT_QUOTES, 'UTF-8');

    echo <<<HTML
<!doctype html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{$safeTitle} - Tukita Queen</title>
  <style>
    body {
      min-height: 100vh;
      margin: 0;
      display: grid;
      place-items: center;
      background: radial-gradient(circle at 50% 0, rgba(160, 32, 240, .24), transparent 34%), #05000a;
      color: #f8f4ff;
      font-family: Montserrat, Arial, sans-serif;
    }
    .panel {
      width: min(520px, calc(100vw - 32px));
      padding: 30px;
      border: 1px solid rgba(193, 91, 255, .42);
      border-radius: 12px;
      background: rgba(11, 0, 20, .94);
      box-shadow: 0 0 34px rgba(160, 32, 240, .34);
      text-align: center;
    }
    a { color: #d946ef; font-weight: 800; }
  </style>
</head>
<body>
  <main class="panel">
    <h1>{$safeTitle}</h1>
    <p>{$safeMessage}</p>
    <a href="registro.html">Volver al registro</a>
  </main>
</body>
</html>
HTML;
}

function tq_generate_promo_code(mysqli $db, string $username): string
{
    $prefix = strtoupper(preg_replace('/[^A-Za-z0-9]/', '', $username));
    $prefix = substr($prefix !== '' ? $prefix : 'TUKITA', 0, 8);

    for ($attempt = 0; $attempt < 12; $attempt++) {
        $random = strtoupper(bin2hex(random_bytes(3)));
        $code = $prefix . $random;

        $stmt = $db->prepare('SELECT id FROM promo_codes WHERE code = ? LIMIT 1');
        $stmt->bind_param('s', $code);
        $stmt->execute();
        $exists = $stmt->get_result()->fetch_assoc();
        $stmt->close();

        if (!$exists) {
            return $code;
        }
    }

    return 'TQ' . strtoupper(bin2hex(random_bytes(6)));
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    tq_response('Registro no disponible', 'Envía el formulario de registro para crear tu cuenta.', 405);
    exit;
}

$username = tq_clean($_POST['username'] ?? '');
$email = tq_clean($_POST['email'] ?? '');
$password = (string) ($_POST['password'] ?? '');
$confirmPassword = (string) ($_POST['confirm_password'] ?? '');
$mmr = tq_clean($_POST['mmr'] ?? '');
$roles = $_POST['roles'] ?? [];
$incomingPromoCode = strtoupper(tq_clean($_POST['promo_code'] ?? ''));
$acceptedTerms = isset($_POST['terms']);

if ($username === '' || $email === '' || $password === '' || $confirmPassword === '') {
    tq_response('Faltan datos', 'Completa usuario, correo, contraseña y confirmación.', 422);
    exit;
}

if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    tq_response('Correo inválido', 'Ingresa un correo electrónico válido.', 422);
    exit;
}

if ($password !== $confirmPassword) {
    tq_response('Contraseñas distintas', 'La contraseña y su confirmación no coinciden.', 422);
    exit;
}

if (strlen($password) < 8) {
    tq_response('Contraseña muy corta', 'Usa una contraseña de al menos 8 caracteres.', 422);
    exit;
}

if (!$acceptedTerms) {
    tq_response('Términos requeridos', 'Debes aceptar los términos y la política de privacidad.', 422);
    exit;
}

if (!is_array($roles)) {
    $roles = [];
}

$allowedRoles = ['carry', 'mid', 'offlane', 'soft_support', 'hard_support'];
$roles = array_values(array_intersect($allowedRoles, array_unique($roles)));
$mmrValue = $mmr === '' ? null : max(0, min(20000, (int) $mmr));
$passwordHash = password_hash($password, PASSWORD_DEFAULT);

try {
    $db = tq_db();
    $db->begin_transaction();

    $stmt = $db->prepare('SELECT id FROM users WHERE username = ? OR email = ? LIMIT 1');
    $stmt->bind_param('ss', $username, $email);
    $stmt->execute();
    $existingUser = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if ($existingUser) {
        $db->rollback();
        tq_response('Cuenta existente', 'Ese usuario o correo electrónico ya está registrado.', 409);
        exit;
    }

    $referrerUserId = null;
    $promoCodeId = null;

    if ($incomingPromoCode !== '') {
        $stmt = $db->prepare("SELECT id, user_id FROM promo_codes WHERE code = ? AND status = 'active' LIMIT 1");
        $stmt->bind_param('s', $incomingPromoCode);
        $stmt->execute();
        $promoCode = $stmt->get_result()->fetch_assoc();
        $stmt->close();

        if (!$promoCode) {
            $db->rollback();
            tq_response('Código inválido', 'El código promocional no existe o no está activo.', 422);
            exit;
        }

        $promoCodeId = (int) $promoCode['id'];
        $referrerUserId = (int) $promoCode['user_id'];
    }

    $stmt = $db->prepare(
        "INSERT INTO users (username, email, password_hash, terms_accepted_at, status, last_login_at)
         VALUES (?, ?, ?, NOW(), 'active', NULL)"
    );
    $stmt->bind_param('sss', $username, $email, $passwordHash);
    $stmt->execute();
    $userId = (int) $stmt->insert_id;
    $stmt->close();

    $stmt = $db->prepare('INSERT INTO user_profiles (user_id, display_name, dota_mmr) VALUES (?, ?, ?)');
    $stmt->bind_param('isi', $userId, $username, $mmrValue);
    $stmt->execute();
    $stmt->close();

    if ($roles !== []) {
        $findRole = $db->prepare('SELECT id FROM dota_roles WHERE code = ? LIMIT 1');
        $saveRole = $db->prepare('INSERT INTO user_dota_roles (user_id, dota_role_id, is_main_role) VALUES (?, ?, ?)');

        foreach ($roles as $index => $roleCode) {
            $findRole->bind_param('s', $roleCode);
            $findRole->execute();
            $roleRow = $findRole->get_result()->fetch_assoc();

            if (!$roleRow) {
                continue;
            }

            $roleId = (int) $roleRow['id'];
            $isMainRole = $index === 0 ? 1 : 0;
            $saveRole->bind_param('iii', $userId, $roleId, $isMainRole);
            $saveRole->execute();
        }

        $findRole->close();
        $saveRole->close();
    }

    $ownCode = tq_generate_promo_code($db, $username);
    $stmt = $db->prepare("INSERT INTO promo_codes (user_id, code, type, status) VALUES (?, ?, 'referral', 'active')");
    $stmt->bind_param('is', $userId, $ownCode);
    $stmt->execute();
    $stmt->close();

    $stmt = $db->prepare('INSERT INTO referral_stats (user_id) VALUES (?)');
    $stmt->bind_param('i', $userId);
    $stmt->execute();
    $stmt->close();

    if ($referrerUserId !== null && $promoCodeId !== null && $referrerUserId !== $userId) {
        $stmt = $db->prepare(
            "INSERT INTO referrals (referrer_user_id, referred_user_id, promo_code_id, status, reward_status)
             VALUES (?, ?, ?, 'registered', 'none')"
        );
        $stmt->bind_param('iii', $referrerUserId, $userId, $promoCodeId);
        $stmt->execute();
        $referralId = (int) $stmt->insert_id;
        $stmt->close();

        $stmt = $db->prepare('UPDATE promo_codes SET uses_count = uses_count + 1 WHERE id = ?');
        $stmt->bind_param('i', $promoCodeId);
        $stmt->execute();
        $stmt->close();

        $stmt = $db->prepare(
            'INSERT INTO referral_stats (user_id, invited_count)
             VALUES (?, 1)
             ON DUPLICATE KEY UPDATE invited_count = invited_count + 1'
        );
        $stmt->bind_param('i', $referrerUserId);
        $stmt->execute();
        $stmt->close();

        $description = 'Recompensa futura por referido registrado';
        $stmt = $db->prepare(
            "INSERT INTO referral_rewards (referral_id, user_id, reward_type, description, status)
             VALUES (?, ?, 'future_reward', ?, 'pending')"
        );
        $stmt->bind_param('iis', $referralId, $referrerUserId, $description);
        $stmt->execute();
        $stmt->close();
    }

    $db->commit();
    $db->close();

    tq_response('Cuenta creada', 'Tu cuenta fue registrada. Tu código promocional es: ' . $ownCode);
} catch (mysqli_sql_exception $error) {
    if (isset($db) && $db instanceof mysqli) {
        $db->rollback();
    }

    tq_response('Error al registrar', 'No se pudo guardar el registro. Revisa la conexión y que database.sql esté importado.', 500);
}
