#!/bin/bash

case $1 in
	"start" )
		res=`find . -mindepth 1 -maxdepth 1 -type d`
		for i in $res; do
			cd $i;
			docker compose build --build-arg SSHKEY="`cat /root/.ssh/id_rsa`"
			docker compose up --detach
			cd -
		done
	;;
	"stop" )
		res=`find . -mindepth 1 -maxdepth 1 -type d`
		for i in $res; do
			cd $i;
			docker compose down
			cd -
		done
	;;
	* )
		echo "Invalid command!"
	;;
esac
