<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Fetch from URL</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            padding: 20px;
        }
        form {
            margin-bottom: 20px;
        }
        input[type="text"] {
            padding: 10px;
            width: 400px;
            border: 1px solid #ccc;
            border-radius: 5px;
            font-size: 16px;
        }
        input[type="submit"] {
            padding: 10px 20px;
            background-color: #4CAF50;
            color: white;
            border: none;
            border-radius: 5px;
            cursor: pointer;
            font-size: 16px;
        }
        img {
            max-width: 100%;
            height: auto;
            margin-top: 20px;
        }
        .error {
            color: red;
            font-weight: bold;
        }
    </style>
</head>
<body>
    <h2>Fetch from URL</h2>
    <form method="GET">
        <input type="text" name="url" placeholder="Enter URL">
        <input type="submit" value="Fetch">
    </form>

    <?php
   
    session_start();
    
    if (!isset($_SESSION['username'])) {
        header('Location: login.php');
        exit();
    }

    if (isset($_GET['url'])) {
        $url = $_GET['url'];
        $ch = curl_init($url); 
        echo curl_exec($ch);    
   }else {
        echo '<p class="error">The "url" GET parameter is not set.</p>';
    }
    ?>
</body>
</html>
