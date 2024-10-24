#!/usr/bin/env python

import paramiko

client = paramiko.SSHClient()
# k = paramiko.RSAKey.from_private_key_file()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('192.168.0.1', port=10121, username='root', 	key_filename="/checkers/id_rsa")

stdin, stdout, stderr = client.exec_command('ls')
client.close()


