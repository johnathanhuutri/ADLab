<?php

    session_start();
    
    if (!isset($_SESSION['username'])) {
        header('Location: login.php');
        exit();
    }

    $result = "";

    function check_input($value) {
        if (strlen($value) > 3) {
            if ($value < "1" && $value > "0.99") {
                if (strlen($value) <= 4) {
                    return true;
                }
            }
        }
        return false;
    }

    if(isset($_GET['g1']) && isset($_GET["g2"])){
        $input1 = $_GET["g1"];
        $input1 = str_replace(".", "", $input1);

        $input2 = $_GET["g2"];
        $answer = json_decode($input2);

        $token = base64_encode(bin2hex(random_bytes(16)));
        @$password = $answer->password;

        if ($password == $token && check_input($input1)) {
            $result = shell_exec("echo ".$_SESSION['username']." win this game!");
        } else {
            $result = shell_exec("echo you not win this game!");
        }
    }
?>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Game Challenge</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background-color: #f2f2f2;
            margin: 0;
            padding: 0;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            flex-direction: column;
        }
        .container {
            background-color: white;
            padding: 20px;
            border-radius: 10px;
            box-shadow: 0 0 10px rgba(0, 0, 0, 0.1);
            text-align: center;
            width: 300px;
        }
        .container input[type="text"], .container input[type="password"] {
            padding: 10px;
            margin: 10px 0;
            border: 1px solid #ccc;
            border-radius: 5px;
            width: 80%;
        }
        .container button {
            padding: 10px 20px;
            border: none;
            background-color: #4CAF50;
            color: white;
            border-radius: 5px;
            cursor: pointer;
        }
        .container button:hover {
            background-color: #45a049;
        }
        .result {
            margin-top: 20px;
            padding: 10px;
            border: 1px solid #ccc;
            border-radius: 5px;
            background-color: #e7f3fe;
            color: #31708f;
        }
        .result.success {
            background-color: #d4edda;
            color: #155724;
        }
        .result.error {
            background-color: #f8d7da;
            color: #721c24;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Game Challenge</h1>
        <form method="GET" action="game.php">
            <div>
                <label for="g1">Game 1 Input:</label>
                <input type="text" id="g1" name="g1">
            </div>
            <div>
                <label for="g2">Game 2 Password:</label>
                <input type="text" id="g2" name="g2">
            </div>
            <button type="submit">Submit</button>
        </form>
        <div class="result">
            <div id="result">
                <?php
                    echo $result;
                ?>
            </div>
        </div>
    </div>
</body>
</html>

