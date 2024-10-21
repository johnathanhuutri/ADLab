#!/bin/sh

service ssh start
service apache2 start
while true; do sleep 1; done