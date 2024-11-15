#!/bin/sh

service ssh start
socat tcp-listen:1337,fork,reuseaddr exec:"/bin/sh"
while true; do sleep 1; done