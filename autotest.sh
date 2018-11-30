#!/bin/ash

logfile="result"
savelog(){
        sed "s/^/$(echo -n `date "+%Y-%m-%d %H:%M:%S"`)\t/" | tee -a $logfile
}

DIR="$( cd "$( dirname "$0" )" && pwd )"
SHELL_DIR=$DIR"/sh"
BIN_DIR=$DIR"/bin"
MOD_DIR=$DIR"/mod"
TESTLIST=$DIR"/test_list"
LOG_DIR=$DIR"/log"
export SHELL_DIR
export BIN_DIR
export MOD_DIR
export LOG_DIR
export MODULE_LOG

update_line(){
        local times
        local tmp
        tmp=`echo $1 | grep "^(.*)"`
        if [ $tmp ]; then
                times=`echo $1 | sed "s/(\(.*\))[a-zA-Z0-9].*/\1/"`
        else 
                times=""
        fi
        if [ "$times" == "loop" ]; then
                echo loop > /dev/null
                return 2
        elif [ "$times" == "" ] ; then
                sed -i "/$1/s/^/(0)/" $TESTLIST".tmp"
                return 1
        else
                if [ $times -gt 0 ]; then
                        sed -i "/$1/s/^($times)/($((times-1)))/" $TESTLIST".tmp"
                        return 1
                elif [ $times -eq 0 ]; then
                        sed -i "/$1/s/^($times)/($((times-1)))/" $TESTLIST".tmp"
                        return 0
                fi
        fi
        
}
continue=1

if [ ! -f "$TESTLIST" ]; then
        echo "Nothing to do!"
else
        cat $TESTLIST | sed "/^#/d; /^$/d; s/#.*$//g"  > $TESTLIST".tmp"
        while [ 1 ]
        do
                continue=0;
                while read line
                do
                        update_line $line
                        re=$?
                        continue=$((continue+re))
                        if [ $re -ne 0 ]; then
							content=`echo $line | sed "s/^(.*)//"`
							MODULE_LOG="${content%%.*}_$(echo -n `date "+%Y_%m_%d_%H_%M_%S"`).log"  
							touch "${LOG_DIR}/${MODULE_LOG}"
							#       chmod 755 $SHELL_DIR"/"${content%%.*}".sh"
							echo $content | grep "\&" > /dev/null
							if [ $? -eq 1 ]; then
								content=`echo $content | sed "s/\&//"`
								$SHELL_DIR"/"$content
								if [ $? -eq 0 ] ; then
									echo "${content%%.*} test success!" | savelog
								else
									echo "${content%%.*} test fail!" | savelog
								fi
							else
								content=`echo $content | sed "s/\&//"`
								$SHELL_DIR"/"$content &
								echo "${content%%.*} test run in the background!" | savelog
							fi
                        fi
                done < $TESTLIST".tmp"
        if [ $continue -eq 0 ]; then
                rm $TESTLIST".tmp"
                exit 0
        fi
        done
fi
