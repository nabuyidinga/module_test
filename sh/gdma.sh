#!/bin/ash

path=/sys/module
path_dma=$path/dmatest/parameters
success=1

run_dmatest(){
	echo $1 > ${path_dma}/iterations
	echo $2 > ${path_dma}/threads_per_chan
	echo $3 > ${path_dma}/test_buf_size
	echo $4 > ${path_dma}/timeout
	echo 1 > ${path_dma}/run
}

if [ ! -d ${path}/dmatest ]; then
	insmod ${MOD_DIR}/dmatest.ko
fi

if [ ! -d ${path}/dmatest ]; then
	exit 1
fi

#get free dma channel

run_dmatest 1000 16 65536 5000

while [ `ps | grep -c dma0chan` -gt 1 ]
do
	sleep 1
done

dmesg | grep dmatest > $LOG_DIR/$MODULE_LOG
success="$success""`awk -F ' ' '{ for(i=1;i<=NF;i++) if($i~/failures/) if($(i-1)!=0) print 0}' $LOG_DIR/$MODULE_LOG`"
if [ "$success" == "1" ];then
	echo success! > /dev/ttyS0
else
	echo fail! >> /dev/ttyS0
	echo fail! >> $LOG_DIR/$MODULE_LOG
	exit 2
fi
