<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Convert Names to Uppercase</title>
    <link rel="stylesheet" type="text/css" href="style/convert.css">
</head>
<body>
    <div class="container">
        <h2>Convert Names to Uppercase</h2>
        <form method="get">
            <label for="names">Enter names (comma separated):</label><br>
            <input type="hidden" id="map" name="map" value="strtoupper">
            <textarea id="names" name="names" rows="4" cols="50"></textarea><br>
            <input type="submit" value="Convert">
        </form>
        <?php
            session_start();
            
            if (!isset($_SESSION['username'])) {
                header('Location: login.php');
                exit();
            }

            $names = $_GET['names'] ?? 'Nightcore,Tado';
            @$input = $_GET['map'];
            $names_array = explode(',',$names);
            $uppercase_names = array_map($input, $names_array);

            echo "<h3>Converted Names:</h3>";
            echo "<ul>";
            foreach ($uppercase_names as $name) {
                echo "<li>" . htmlspecialchars(trim($name)) . "</li>";
            }
            echo "</ul>";
        ?>
    </div>
</body>
</html>
