#!/bin/sh

${SHELL_DIR}/storage_test.sh storage_test start /src /dst 2 spi
result=$(${SHELL_DIR}/storage_test.sh storage_test check)
if [ "$result" == "storage test success" ]; then
	return 0
else
	return 1
fi
