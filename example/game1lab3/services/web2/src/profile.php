<?php

    session_start();
    
    if (!isset($_SESSION['username'])) {
        header('Location: login.php');
        exit();
    }

    function uploadFile($file) {
        $msg = "";
        $is_ok = true;

        $allowed = array('gif', 'png', 'jpg', 'txt');
        $filename = $file['name'];

        $ext = pathinfo($filename, PATHINFO_EXTENSION);
        if (!in_array($ext, $allowed)) {
            $msg = 'Only allowed gif, png, jpg, txt';
            $is_ok = false;
            return array($is_ok, $msg);
        }

        if ($file["size"] > 1000000) {
            $msg = "Sorry, your file is too large.";
            $is_ok = false;
            return array($is_ok, $msg);
        } 

        if($ext !== 'txt'){
            if (@!getimagesize($file['tmp_name'])) {
                $msg = "Not a valid image";
                $is_ok = false;
                return array($is_ok, $msg);
            }
        }

        $file_name = bin2hex(random_bytes(10)).'.'.$ext;
        $target_file = dirname(__FILE__)."/uploads/".$file_name;

        if (move_uploaded_file($file["tmp_name"], $target_file)) {
            $msg =  "Your file stored at: ". $target_file;
            $is_ok = true;
            return array($is_ok, $msg);
        } else {
            $msg = "Sorry, there was an error uploading your file.";
            $is_ok = false;
            return array($is_ok, $msg);
        }
    }

    if (isset($_FILES['file'])) {
        $result = uploadFile($_FILES['file']);
    }

    include 'static/profile.html';
?>