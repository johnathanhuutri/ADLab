<?php

@$input = $_GET['dir'];

function securePath($path) {
    $path = preg_replace('@\.\.*@', '.', $path);
    $path = preg_replace('@\..\..*@', '', $path);
    $path = preg_replace('@://*@', '', $path);
    $path = htmlentities($path);
    return strip_tags($path);
}

?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Story World</title>
    <link rel="stylesheet" type="text/css" href="style/stories.css">
</head>
<body>
    <div class="header">
        <h1>Welcome to Our Stories World</h1>
        <form method="GET">
            <label for="dir">Enter story's name:</label>
            <input type="text" id="dir" name="dir" placeholder="Echoes_of_Silence.html">
            <button type="submit">Include</button>
        </form>
        <br>
        <a href="stories.php?dir=The_Forgotten_Key.html" class="The_Forgotten_Key-link">The Forgotten Key</a>
        <a href="stories.php?dir=Echoes_of_Silence.html" class="Echoes_of_Silence-link">Echoes of Silence</a>
        <a href="stories.php?dir=The_Last_Letter.html" class="The_Last_Letter-link">The Last Letter</a>
    </div>

    <div class="content">
        <?php
        if ($_SERVER['REMOTE_ADDR'] == '127.0.0.1' || $_SERVER['REMOTE_ADDR'] == 'localhost') {
            include(securePath($input));
        }
        else{
            $include = "stories/".securePath($input);
            if (file_exists($include)) {
                    include($include);
            } else {
                    echo "<p>File not found.</p>";
                } 
        }
        ?>
    </div>
</body>
</html>