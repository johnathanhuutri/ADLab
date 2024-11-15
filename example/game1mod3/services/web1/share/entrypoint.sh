#!/bin/sh

service ssh start
apache2ctl -D FOREGROUND
