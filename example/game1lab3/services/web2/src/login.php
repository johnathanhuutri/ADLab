<?php
include_once("db.php");
session_start();

if (isset($_SESSION['username'])) {
    header('Location: index.php');
    exit();
}


if ($_SERVER['REQUEST_METHOD'] == "POST") {
    if (isset($_POST['username']) && isset($_POST['password'])) {
        $username = $_POST['username'];
        $password = $_POST['password'];
        try {
            $query = "SELECT * FROM users WHERE username=? and password =?";
            $stmt = $conn->prepare($query);
            $stmt->bind_param("ss", $username, $password);
            $stmt->execute();
        } catch (Exception $e) {
            die("Error");
        }
        $result = $stmt->get_result();
        if ($result->num_rows > 0) {
            try {
                $_SESSION['username'] = $username;
                header("Location: index.php");
                exit();
            } catch (Exception $e) {
                die("Error");
            }
        } else {
            header("Location: /login.php?error=");
            exit();
        }
    }
}
?>


<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Login</title>
<link rel="stylesheet" type="text/css" href="style/form.css">
</head>
<body>
    <div class="wrapper">
        <div id="formContent">
            <div class="fadeIn first">
                <h2>Login</h2>
                <?php if(isset($_GET['error'])) echo "<h5>Wrong username or password</h5>"?>
            </div>

            <form action="login.php" method="post">
                <input type="text" id="username" class="fadeIn second" name="username" placeholder="Username" required>
                <input type="password" id="password" class="fadeIn third" name="password" placeholder="Password" required>
                <input type="submit" class="fadeIn fourth" value="Log In">
            </form>

            <div id="formFooter">
                <a class="underlineHover" href="/register.php">Register</a>
            </div>
        </div>
    </div>
</body>
</html>
