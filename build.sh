#!/bin/bash

export KBUILD_BUILD_USER="Peppe289"

export KBUILD_BUILD_HOST="RaveRules"

export TOOLCHAIN=clang

export DEVICES=lavender

source helper

gen_toolchain

send_msg "⏳ Start build ${DEVICES}..."

START=$(date +"%s")

for i in ${DEVICES//,/ }
do 
	build ${i} -kernel
done

END=$(date +"%s")

DIFF=$(( END - START ))
