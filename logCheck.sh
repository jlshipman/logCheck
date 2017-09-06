#!/bin/sh
################email################
HOST=`hostname`
WHOM="jeffery.l.shipman@nasa.gov"
Subject=$HOST" Log Check from $HOST"
Subject2=$HOST" Log Check from $HOST - Warnings"

################directories################
baseConfig="/scripts/logCheck/"
baseLog=$baseConfig'Log/'
baseTemp=$baseConfig'Temp/'
baseList=$baseConfig'List/'
################files################
#log of script execution
logFile=$baseLog"`date +'%y-%m-%d-%T'| tr : _`.txt"
#one instance to run
check=$baseTemp'checkCheckSum'
systemLogList=$baseList'systemLogList.txt'

logList=$baseTemp'logList.txt'
logListKeep=$baseTemp"logListKeep.txt"
logListDelete=$baseTemp"logListDelete.txt"
tokenList=$baseList"tokens.txt"
logTemp=$baseTemp"logTemp.txt"
################variables################
logNum=5
##############create/check directories################
if [ ! -e $baseLog ]; then
   for dir in "$baseTemp $baseLog"; do
      if [ -e "$dir" ]; then
         echo "     $dir exist"
      else
         echo "     $dir does not exits, will be created"
         mkdir $dir
      fi
   done
fi 


################logging subroutines - begin ################
LOG () 
  { 
     echo " $*" | tee -a $logFile;  
  }

WARN () 
  { 
     LOG "WARNING: $*" 1>&2 ; 
  }

ABORT () 
  { 
     LOG "ABORT: $*" 1>&2 ; 
     /usr/bin/mail -s "$Subject2" $WHOM < $*
     exit 1; 
  }
  
LOG "  Log Check script"


checkfor ()
	{
		local checkLog=$1
		local needle=`echo $2 | tr "#" " "`
		#LOG "needle:  _${needle}_"
		if [ -e "$checkLog" ]; then
			cat $checkLog | egrep "$needle" > $logTemp
			if [ $? -eq 0 ] ; then
			 WARN "===================== $needle ============"
			fi 
			cat $checkLog | egrep "$needle" >> $logFile
		fi
	}
##############Log ################
#keep only proscribe number (logNum) of logs
checkLogNum=`ls -1 $baseLog | grep -v '^\.'| wc -l`
if [ $checkLogNum -gt $logNum ] ; then
   LOG "    There are more than $logNum logs"
   ls -1 $baseLog | grep -v '^\.' > $logList
   numToDelete=$((checkLogNum-logNum)) 
   LOG "    numToDelete:  $numToDelete"
   numTail=$((checkLogNum-numToDelete)) 
   LOG "    numTail:  $numTail"
   head -$numToDelete $logList > $logListDelete
   tail -$logNum $logList > $logListKeep
   cat $logListDelete | while read d;
   do
      fullPathLog="$baseLog$d"
      LOG "fullPathLog:  $fullPathLog"
      rm $baseLog$d
      if [ $? -ne 0 ]; then
        WARN "       could delete $d"
        cat ${baseTemp}stderr >>$logFile
        cat ${baseTemp}stderr 1>&2
      fi
   done
fi


#create log file
touch $logFile

if [ -e $check ]; then
   ABORT "double run script check file exists $check"
fi

#create check file
touch $check


#if script dies on hang up, interrupt, quit, or terminate rm check file
trap "rm $check" 0 1 2 15


div="==========> log files <=============="
echo $div >> $logFile

cd /var/log 
cat $systemLogList | while read log;
do
	div="==> $log <=="
	echo $div >> $logFile
	
	cat $tokenList  | while read token;
	do
		#LOG "token:  _${token}_"
		checkfor $log $token
	done
done

#force rotate logs
/usr/sbin/newsyslog -F

if [ $? -ne 0 ] ; then
     WARN "log rotation was not performed"
fi
#if file is not of size zero => there is something to send out
if [ -s $logFile ]; then

    if cat $logFile | grep -iq 'WARN' || cat $logFile | grep -iq 'ABORT' ; then
       /usr/bin/mail -s "$Subject2" $WHOM < $logFile  
    else
       /usr/bin/mail -s "$Subject" $WHOM < $logFile 
    fi
fi