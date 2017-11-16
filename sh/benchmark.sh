#!/bin/sh

# run_coremark $timeout
run_coremark() {
	date >> $LOG_DIR/$MODULE_LOG
	$BIN_DIR/coremark_ci40.elf M2 >> $LOG_DIR/$MODULE_LOG &
}

run_coremark

while [ `ps | grep -c coremark_ci40` -ge 1 ]
do
	sleep 2
done

coremark_mhz=`grep "CoreMark 1.0 :" $LOG_DIR/$MODULE_LOG | awk '{ printf "%d", $4 }'`
if [ -e /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq ]; then
	echo "get cpu freq from cpufreq" > /dev/ttyS0
	cpufreq=`cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq | awk '{ printf "%d", $NF }'`
else
	if [ -e /sys/kernel/debug/cpu-freq ]; then
		echo "get cpu freq from debugfs" > /dev/ttyS0
	else
		mount -t debugfs none /sys/kernel/debug
	fi
	cpufreq=`cat /sys/kernel/debug/cpu-freq | awk '{ printf "%d", $NF }'`
fi
let cpufreq=cpufreq/1000000
let coremark_mhz=coremark_mhz*100/cpufreq
if [ $coremark_mhz -le 350 ]; then
	echo "coremark/MHZ less than 3.5, failed" >> $LOG_DIR/$MODULE_LOG
else
	echo "benchmark success" >> $LOG_DIR/$MODULE_LOG
fi
let coremark_int=coremark_mhz/100
let coremark_dec=coremark_mhz%100
echo "coremark_mhz is ${coremark_int}.${coremark_dec}" >> $LOG_DIR/$MODULE_LOG

coremark_mhz=`grep "coremark_mhz is" $LOG_DIR/$MODULE_LOG`
echo "get coremark result : $coremark_mhz" >> $LOG_DIR/$MODULE_LOG

