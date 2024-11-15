START TRANSACTION;
CREATE TABLE `users` (
    `id` int(11) PRIMARY KEY NOT NULL AUTO_INCREMENT,
    `username` text NOT NULL,
    `password` text NOT NULL,
    `email` text NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

INSERT INTO `users` (`id`, `username`, `password`, `email`) VALUES
(1, 'kun', 'password1', 'nightcore77777@gmail.com'),
(2, 'tado', 'password2', 'tadokun468@gmail.com'),
(4, 'alice', 'password4', 'alice@gmail.com'),
(5, 'emma', 'password5', 'emma@gmail.com'),
(6, 'mike', 'password6', 'mike1233@gmail.com'),
(7, 'sara', 'password7', 'sara3321@gmail.com'),
(8, 'chris', 'password8', 'chris222@gmail.com'),
(9, 'linda', 'password9', 'linda567@gmail.com'),
(10, 'ryan', 'password10', 'ryankka2@gmail.com'),
(11, 'lili', 'FLAG{is_here_but_this_is_local_testing}', 'lolo@gmail.com');

GRANT ALL PRIVILEGES ON CHALLENGE.users TO 'ctf';
FLUSH PRIVILEGES;
COMMIT;
