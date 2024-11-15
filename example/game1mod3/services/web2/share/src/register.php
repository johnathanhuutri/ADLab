<?php
include_once("db.php");
session_start();

if (isset($_SESSION['username'])) {
    header('Location: index.php');
    exit();
}


if ($_SERVER['REQUEST_METHOD'] == "POST") {
    if (isset($_POST['username']) && isset($_POST['password']) && isset($_POST['email'])) {
        $username = $_POST['username'];
        $password = $_POST['password'];
        $email = $_POST['email'];

        $query = "SELECT * FROM users WHERE username = ?";
        $stmt = $conn->prepare($query);
        $stmt->bind_param("s", $username);
        $stmt->execute();

        if ($stmt->get_result()->num_rows > 0) {
            header("Location: /register.php?exists=");
            exit();
        }

        try {
            $query = "INSERT INTO users (username,password,email) VALUES (?,?,?)";
            $stmt = $conn->prepare($query);
            $stmt->bind_param("sss", $username, $password, $email);
            $stmt->execute();
            header('Location: login.php');
            exit();
        } catch (Exception $e) {
            die("Error");
        }
    }
}
?>

<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Register</title>
<link rel="stylesheet" type="text/css" href="style/form.css">
</head>
<body>
    <div class="wrapper">
        <div id="formContent">
            <div class="fadeIn first">
                <h2>Register</h2>
                <?php if(isset($_GET['exists'])) echo "<h5>User already exists</h5>"?>
            </div>

            <form action="register.php" method="post">
                <input type="text" id="username" class="fadeIn second" name="username" placeholder="Username" required>
                <input type="password" id="password" class="fadeIn third" name="password" placeholder="Password" required>
                <input type="email" id="email" class="fadeIn third" name="email" placeholder="Email" required>
                <input type="submit" class="fadeIn fourth" value="Register">
            </form>

            <div id="formFooter">
                <a class="underlineHover" href="/login.php">Login</a>
            </div>
        </div>
    </div>
</body>
</html>
