#!/bin/sh

#source /router/common.sh

g_first_filepath=0
g_filepath=0

rand(){
	min=$1
	max=$(($2-$min+1))
	num=$(cat /proc/sys/kernel/random/uuid | sed "s/[a-zA-Z]//g" | awk -F '-' '{printf"%d\n",$1+$4}')
	echo $((num%max+min))
}

rand_path(){
	length=$(rand $1 $2)
	for i in `seq $length`
	do
	rnd=$(rand $3 $4)
	file_name=$(head /dev/urandom | tr -dc a-z0-9 | head -c $rnd)
	mkdir $file_name
	cd $file_name
	if [ $i -eq 1 ];then
		g_first_filepath=$(pwd)
	fi
	done

	g_filepath=$(pwd)
}

rand_filename(){
	length=$(rand $1 $2)
	prefix=$(head /dev/urandom | tr -dc a-z0-9 | head -c $length)

	length=$(rand $3 $4)
	suffix=$(head /dev/urandom | tr -dc a-z0-9 | head -c $length)

	temp_filename=$prefix.$suffix

	touch $temp_filename

	echo $temp_filename
}

speed_show(){
	if [ $1 -ge 1048576 ];then
		speed=$(awk -v count=$1 -v num=1048576 'BEGIN{print count/num}')
		echo "present speed show: write_speed="$speed"MB/s;"
	elif [	$1 -ge 1024 ];then
		speed=$(awk -v count=$1 -v num=1024 'BEGIN{print count/num}')
		echo "present speed show: write_speed="$speed"KB/s;"
	elif [	$1 -gt 0 ];then
		echo "present speed show: write_speed="$1"B/s;"
	fi

	if [ $2 -ge 1048576 ];then
		speed=$(awk -v count=$2 -v num=1048576 'BEGIN{print count/num}')
		echo "present speed show: read_speed="$speed"MB/s;"
	elif [	$2 -ge 1024 ];then
		speed=$(awk -v count=$2 -v num=1024 'BEGIN{print count/num}')
		echo "present speed show: read_speed="$speed"KB/s;"
	elif [	$2 -gt 0 ];then
		echo "present speed show: read_speed="$2"B/s;"
	fi

	if [ $3 -ge 1048576 ];then
		speed=$(awk -v count=$3 -v num=1048576 'BEGIN{print count/num}')
		echo "present speed show: whole_speed="$speed"MB/s;"
	elif [	$3 -ge 1024 ];then
		speed=$(awk -v count=$3 -v num=1024 'BEGIN{print count/num}')
		echo "present speed show: whole_speed="$speed"KB/s;"
	elif [	$3 -gt 0 ];then
		echo "present speed show: whole_speed="$3"B/s;"
	fi
}

present_speed(){
	echo "enter present_speed show!"

	write_startcnt=`cat /sys/kernel/debug/mmc0/write_count`
	read_startcnt=`cat /sys/kernel/debug/mmc0/read_count`

	while [ 1 ]
	do
		write_count=`cat /sys/kernel/debug/mmc0/write_count`
		read_count=`cat /sys/kernel/debug/mmc0/read_count`

		sleep 1

		write_count=$((`cat /sys/kernel/debug/mmc0/write_count`-$write_count))
		read_count=$((`cat /sys/kernel/debug/mmc0/read_count`-$read_count))
		#whole_count=$(($write_count+$read_count))

		if [[ $write_count -ne 0 ]] || [[ $read_count -ne 0 ]];then
			if [ "$1" == "write" ];then
				speed_show $write_count 0 0
			else
				speed_show 0 $read_count 0
			fi
		else
			break
		fi
	done

	write_allcnt=$((`cat /sys/kernel/debug/mmc0/write_count`-$write_startcnt))
	read_allcnt=$((`cat /sys/kernel/debug/mmc0/read_count`-$read_startcnt))
	echo "write_allcnt="$write_allcnt",read_allcnt="$read_allcnt""
	if [[ $write_allcnt -lt $2 ]] || [[ $read_allcnt -lt $3 ]];then
		echo "error! the byte count is smaller than experted!"
	else
		echo "speed show end!"
	fi
}

sd_test(){
	k=1
	while [ $k -le 10 ]
	do

	#get the rand file path
	cd $1
	rand_path 1 10 1 10
	first_path_1=$g_first_filepath
	file_path_1=$g_filepath

	echo echo "$(date "+%H:%M:%S")" >> /tmp/sd_log.txt
	echo "filepath1="$g_filepath"" >> /tmp/sd_log.txt

	cd $2
	rand_path 1 10 1 10
	first_path_2=$g_first_filepath
	file_path_2=$g_filepath

	echo "filepath2="$g_filepath"" >> /tmp/sd_log.txt

	cd $file_path_1
	#get the rand file name
	#create the rand file
	filename=$(rand_filename 1 10 1 10)
	echo "filename="$filename"" >> /tmp/sd_log.txt
	count_test=$(rand 1 $3)
	blk_size=$(rand 1 $4)
	echo "count="$count_test" blk_size="$blk_size"" >> /tmp/sd_log.txt
	dd if=/dev/urandom of=$filename count=$count_test bs=$blk_size > /dev/null 2>&1

	#cacl md5 value
	md5sum $filename >> md5sum.txt

	#move file
	cp $file_path_1/$filename $file_path_2/
	sync
	rm $file_path_1/$filename
	cd $file_path_2
	md5sum $filename >> md5sum.txt
	cd
	#compare
	cmp $file_path_1/md5sum.txt $file_path_2/md5sum.txt > /dev/zero
	if [ $? -eq 1 ]; then
		echo "fail in compare 1-2" >> /tmp/sd_log.txt
		echo "error! exit here 1-2"
		rm -rf $first_path_1
		rm -rf $first_path_2
		echo "OUT test over" >> /tmp/sd_log.txt
		umount $5
		break
	else
		echo "success in 1-2!!!" >> /tmp/sd_log.txt
	fi
	#move back
	cp $file_path_2/$filename $file_path_1/$filename
	sync
	#rm $file_path_2/$filename
	cd $file_path_1
	md5sum $filename >> md5sum_last.txt
	cd
	#compare again
	cmp /$file_path_1/md5sum.txt /$file_path_1/md5sum_last.txt > /dev/zero
	if [ $? -eq 1 ]; then
		echo "fail in compare 2-1" >> /tmp/sd_log.txt
		echo "error! exit here 2-1"
		rm -rf $first_path_1
		rm -rf $first_path_2
		echo "OUT test over" >> /tmp/sd_log.txt
		umount $5
		break
	else
		echo "success in 2-1!!!" >> /tmp/sd_log.txt
	fi

	rm -rf $first_path_1
	rm -rf $first_path_2

	echo "OUT test over" >> /tmp/sd_log.txt
	j=3
	while [ $j -ge 0 ]
	do
		#echo "$j..."
		sleep 1
		j=$(($j-1))
	done
	k=$(($k+1))

	done
}

speed_test(){
	cd $2
	rand_path 1 10 1 10
	first_path_1=$g_first_filepath
	file_path_1=$g_filepath

	echo echo "$(date "+%H:%M:%S")" >> /tmp/sd_speed_log.txt
	echo "filepath1="$g_filepath"" >> /tmp/sd_speed_log.txt

	cd /tmp
	rand_path 1 10 1 10
	first_path_2=$g_first_filepath
	file_path_2=$g_filepath

	echo "filepath2="$g_filepath"" >> /tmp/sd_speed_log.txt

	count_test=$3
	blk_size=$4
	file_size=$(($3*$4))
	echo "count="$count_test" blk_size="$blk_size" file_size="$file_size"" >> /tmp/sd_speed_log.txt

	if [ $6 == 1 ] || [ "$5" == "speed_together" ];then
		cd $file_path_1
		#get the rand file name
		#create the rand file
		filename1=$(rand_filename 1 10 1 10)
		echo "filename1="$filename1"" >> /tmp/sd_speed_log.txt
		dd if=/dev/urandom of=$filename1 count=$count_test bs=$blk_size conv=fsync > /dev/null 2>&1
	fi

	if [ $6 == 2 ] || [ "$5" == "speed_together" ];then
		cd $file_path_2
		filename2=$(rand_filename 1 10 1 10)
		echo "filename2="$filename2"" >> /tmp/sd_speed_log.txt
		dd if=/dev/urandom of=$filename2 count=$count_test bs=$blk_size conv=fsync > /dev/null 2>&1
	fi

	cd
	umount $1
	mount -t vfat $1 $2

	if [ "$5" == "speed_alone" ];then
		i=$6
		#time_start=`cat /proc/uptime | sed "s/ .*$//"`

		cd /tmp

		if [ $i == 1 ];then
			time_start=`cat /proc/uptime | sed "s/ .*$//"`
			cp $file_path_1/$filename1 $file_path_2/
			sync
		else
			time_start=`cat /proc/uptime | sed "s/ .*$//"`
			cp $file_path_2/$filename2 $file_path_1/
			sync
		fi

		time_end=`cat /proc/uptime | sed "s/ .*$//"`

		time_move=$(awk -v end=$time_end -v start=$time_start 'BEGIN{print end-start}')
		echo "speed_test"$i" time_start="$time_start" time_end="$time_end" time_mode="$time_move"" >> /tmp/sd_speed_log.txt

		if [ $time_move != 0 ]; then
			speed=$(awk -v file=$file_size -v time=$time_move 'BEGIN{print file/time}')
			echo "speed_test"$i" speed="$speed"" >> /tmp/sd_speed_log.txt
			if [ $i == 1 ];then
				#g_read_speed = $speed;
				echo $speed >> /tmp/read_speed.txt
				echo "speed_test write and read alone read_speed="$speed"" >> /tmp/sd_speed_log.txt
			else
				#g_write_speed = $speed;
				echo $speed >> /tmp/write_speed.txt
				echo "speed_test write and read alone write_speed="$speed"" >> /tmp/sd_speed_log.txt
			fi
		else
			echo "the file defined is too small!" >> /tmp/sd_speed_log.txt
		fi

		rm -rf $first_path_1
		rm -rf $first_path_2

		umount $1
		mount -t vfat $1 $2
	else
		#read and write at the same time
		for i in `seq 2`
		do
		{
			time_start=`cat /proc/uptime | sed "s/ .*$//"`
			if [ $i == 1 ];then
				cp $file_path_1/$filename1 $file_path_2/
				sync
			else
				cp $file_path_2/$filename2 $file_path_1/
				sync
			fi

			time_end=`cat /proc/uptime | sed "s/ .*$//"`

			time_move=$(awk -v end=$time_end -v start=$time_start 'BEGIN{print end-start}')
			echo "speed_test"$i" time_start="$time_start" time_end="$time_end" time_mode="$time_move"" >> /tmp/sd_speed_log.txt

			if [ $time_move != 0 ]; then
				speed=$(awk -v file=$file_size -v time=$time_move 'BEGIN{print file/time}')

				if [ $i == 1 ];then
					echo $speed >> /tmp/read_speed.txt
					echo "speed_test write and read together read_speed="$speed"" >> /tmp/sd_speed_log.txt
				else
					echo $speed >> /tmp/write_speed.txt
					echo "speed_test write and read together write_speed="$speed"" >> /tmp/sd_speed_log.txt
				fi
			else
				echo "the file defined is too small!" >> /tmp/sd_speed_log.txt
			fi
		}&
		done
		wait
		rm -rf $first_path_1
		rm -rf $first_path_2

		umount $1
		mount -t vfat $1 $2
	fi
}

sd_speed_test(){
	count=1
	write_speed=0
	read_speed=0

	if [ "$7" = "speed_alone" ];then
		while [ $count -le 3 ]
		do
			speed_test $1 $2 $3 $4 $7 2
			count=$(($count+1))
		done
	fi

	count=1
    while [ $count -le 3 ]
    do
        speed_test $1 $2 $3 $4 $7 1
        count=$(($count+1))
    done

    while read speed
    do
        write_speed=$(awk -v sum=$write_speed -v speed=$speed 'BEGIN{print sum+speed}')
    done < /tmp/write_speed.txt

	while read speed
    do
		read_speed=$(awk -v sum=$read_speed -v speed=$speed 'BEGIN{print sum+speed}')
    done < /tmp/read_speed.txt

	write_speed=$(awk -v sum=$write_speed -v num=3 'BEGIN{print int(sum/num)}')
	read_speed=$(awk -v sum=$read_speed -v num=3 'BEGIN{print int(sum/num)}')

	if [ "$7" = "speed_alone" ];then
		echo "speed test alone : write_speed="$write_speed" , read_speed="$read_speed" " >> /tmp/sd_speed_log.txt
		if [ $read_speed -le $5 ];then
			echo "read speed test fail" >> /tmp/sd_speed_log.txt
		else
			echo "read speed test ok" >> /tmp/sd_speed_log.txt
		fi

		if [ $write_speed -le $6 ];then
			echo "write speed test fail " >> /tmp/sd_speed_log.txt
		else
			echo "write speed test ok " >> /tmp/sd_speed_log.txt
		fi
	else
		echo "speed test together : write_speed="$write_speed" , read_speed="$read_speed" " >> /tmp/sd_speed_log.txt
	fi

	rm /tmp/read_speed.txt /tmp/write_speed.txt
	echo "speed test over!"  >> /tmp/sd_speed_log.txt
}

speed_show_test(){
	cd $2

	file_size=614400000
	present_speed read 0 $file_size &
	time_start=`cat /proc/uptime | sed "s/ .*$//"`
	dd if=$1 of=/dev/zero count=600000 bs=1024
	time_end=`cat /proc/uptime | sed "s/ .*$//"`
	time_move=$(awk -v end=$time_end -v start=$time_start 'BEGIN{print end-start}')

	speed=$(awk -v file=$file_size -v time=$time_move 'BEGIN{print file/time}')

	sleep 3

	echo "average read speed="$speed""

	dd if=/dev/urandom of=/tmp/sd_test count=100000 bs=1024 conv=fsync

	file_size=102400000

	for i in `seq 5`
	do
	{
		present_speed write $file_size 0 &

		time_start=`cat /proc/uptime | sed "s/ .*$//"`
		mv /tmp/sd_test $2/
		sync
		time_end=`cat /proc/uptime | sed "s/ .*$//"`
		time_move=$(awk -v end=$time_end -v start=$time_start 'BEGIN{print end-start}')

		speed=$(awk -v file=$file_size -v time=$time_move 'BEGIN{print file/time}')

		sleep 3

		echo "average write speed="$speed""

		mv $2/sd_test /tmp/
		cd
		umount $1
		mount -t vfat $1 $2
	}
	done
	rm  /tmp/sd_test
}

echo "args in sd_test is ${@}"

if [ "$2" = "start" ]; then
	echo "start sd_test"
	#echo "start sd_test"
	#speed show
	speed_show_test $3 $4

	rm /tmp/sd_speed_log.txt
	echo "enter sd_speed_test speed_alone!"
	sd_speed_test $3 $4 $5 $6 $7 $8 speed_alone
	sleep 1
	echo "enter sd_speed_test speed_together!"
	sd_speed_test $3 $4 $5 $6 $7 $8 speed_together
	#/dev/mmcblk0p1 /mnt/mmcblk0p1 count30000 bs1000 read_speed10000000 write_speed5000000  
	sleep 1
	rm /tmp/sd_log.txt
	echo $$ >> /tmp/sd_log.txt
	echo "enter sd file move test!"
	sd_test $4 $4 $9 $6 $3
#elif [ "$2" = "check_filetest" ];then
	echo "check sd test result!"
	test_result=$(grep "fail" /tmp/sd_log.txt)
	if [ "$test_result" == "" ];then
		echo "sd_file_test success"
	else
		echo "sd_file_test fail"
	fi
#elif [ "$2" = "check_speedtest" ];then
	test_result=$(grep "fail" /tmp/sd_speed_log.txt)
	if [ "$test_result" == "" ];then
		echo "sd_speed_test success"
	else
		echo "sd_speed_test fail"
	fi
elif [ "$2" = "kill" ];then
	pid=$(head -n 1 /tmp/sd_log.txt)
	d=3
	while [ $d -ge 0 ]
	do
		if [ "`tail -n 1 /tmp/sd_log.txt`" == "OUT test over" ];then
			echo "kill now"
			kill $pid
			break
		else
			echo "wait"
		fi
	done
elif [ "$2" = "wait_timeout" ];then
	pid=$(head -n 1 /tmp/sd_log.txt)
	echo "kill the pid which waiting timeout"
	kill $pid
else
	echo "wrong command"
fi

exit 0
