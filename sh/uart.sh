#!/bin/ash



######################################################################
## mode: test type: tt (transmission test), et(exception test)
## num: transmission times( num * num)
## success: transmission successful times
## fail: 	transmission failed times
## msg_num: each transmission contains how many msgs
## msg_len: each msgs contains how many bytes data
#####################################################################
#mode=tt
num=20
success=0
fail=0
logfile="${LOG_DIR}/${MODULE_LOG}"

savelog(){
	sed "s/^/$(echo -n `date "+%Y-%m-%d %H:%M:%S"`)\t/" | tee -a $logfile
}


for j in `seq $num`
do
	for i in `seq $num`
	do
		$BIN_DIR/uart_test | savelog
		if [ "$?" == "0" ] ;then
			let success=success+1
		else
			let fail=fail+1
		fi
		sleep 1

		echo "" | awk -v num=$num -v i=$i -v j=$j -v success=$success -v fail=$fail '{printf"%f%% completed, %d success, %d fail\n", ((j -1) * num + i ) / (num * num ) * 100, success, fail}'| savelog
	done

	end=`cat /proc/uptime | awk -F '.' '{printf"%d\n",$1 * 100 +  $2}'`
done

if [ $fail -eq 0 ] ; then
	exit 0
else
	exit 1
fi
