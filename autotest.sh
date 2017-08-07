#!/bin/ash

logfile="result"
savelog(){
	sed "s/^/$(echo -n `date "+%Y-%m-%d %H:%M:%S"`)\t/" | tee -a $logfile
}

SHELL_DIR=$PWD"/sh"
BIN_DIR=$PWD"/bin"
MOD_DIR=$PWD"/mod"
TESTLIST=$PWD"/test_list"
LOG_DIR=$PWD"/log"
export SHELL_DIR
export BIN_DIR
export MOD_DIR
export LOG_DIR
export MODULE_LOG


if [ ! -f "$TESTLIST" ]; then
	echo "Nothing to do!"
else
	for i in `cat $TESTLIST`
	do
		echo "$i test start" | savelog
		res=`find $SUB_SHELL -name "$i.sh"`
		if [ ! -f "$res" ] ; then
			echo "$i test script no found!" | savelog
		else
			MODULE_LOG="${i}_$(echo -n `date "+%Y_%m_%d_%H_%M_%S"`).log"	
			touch "${LOG_DIR}/${MODULE_LOG}"
			$res
			if [ $? -eq 0 ] ; then
				echo "$i test success!" | savelog
			else
				echo "$i test fail!" | savelog
			fi
		fi
	done
fi
