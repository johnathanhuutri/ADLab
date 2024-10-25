<?php 
include_once("db.php");
session_start();

if (!isset($_SESSION['username'])) {
    header('Location: login.php');
    exit();
}

?>


<!DOCTYPE html>
<html>
<head>
  <title>Search</title>
  <link rel="stylesheet" type="text/css" href="style/styles.css">
</head>
<body>
  <div class="header">
    <form method="POST">
      <input type="text" name="username" placeholder="Username">
      <button type="submit">Search</button>
    </form><br>
    <a href="profile.php">Profile</a><br>
    <a href="game.php">Game Challenge</a><br>
    <a href="fetch.php">Fetch from URL</a><br>
    <a href="convert.php?map=strtoupper">Convert Names to Uppercase</a><br>
    <a href="stories.php?dir=Echoes_of_Silence.html">Stories World</a><br>
    <a href="logout.php">Logout</a><br>
  </div>

  <table class="content-table">
    <thead>
        <tr>
          <th>ID</th>
          <th>Email</th>
        </tr>
    </thead>
    <tbody>
      <?php
        if (isset($_POST['username'])) {
            $username = $_POST['username'];
            $whitelist = "/^[a-z()_,`' ]+$/";
            $blacklist = "/username|password|id|email|if|and|or|sleep|where|like|rlike|substring|substr|concat|concat_ws|group_concat|case|when|then|as/";
            if(!preg_match($whitelist,$username) || preg_match($blacklist,$username) || strlen($username) > 150){
              echo "<tr><td>Not Found</td><td>Not Found</td></tr>";
              exit();
            }
            else {
              $query = "SELECT id,email FROM users WHERE username='{$username}';";
              $result = $conn->query($query);
              if($result->num_rows > 0){
                  while ($row = $result->fetch_assoc()) {
                    if(!preg_match("/^[0-9]+$/", $row['id']) || !preg_match('/gmail/', $row['email'])){
                      echo "<tr><td> </td><td>User error</td></tr>";
                    }
                    else{
                      echo "<tr><td>".$row['id']."</td><td>".$row['email']."</td></tr>";
                    }
                  }
                  $result->free();
             }
             else {
              echo "<tr><td>Not Foud</td><td>Not Found</td></tr>";
                exit();
              }
            }
          }
      ?>
    </tbody>
  </table>
</body>
</html>

