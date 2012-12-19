#!/bin/bash

# ------------------------------------------------------------------------
# Author  : Guillaume COEUGNET (importepeu@free.fr)
# Date    : 18/12/12
# Version : 1.0
#  This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.

#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.

#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
# ------------------------------------------------------------------------

TMPFILE=/tmp/$(basename $0 .sh).log

function emergency()
{
	echo "Process in RAM"
	for file in $(grep -l VmRSS /proc/*/status)
	do
        	[ -f $file ] && echo -e "$(grep VmRSS $file 2>/dev/null | awk '{print $2}')\t kB in RAM for process $(grep Name $file 2>/dev/null | awk '{print $2}') ($(grep ^Pid $file 2>/dev/null | awk '{print $2}'))"
	done | sort -nr | head -10

	echo -e "\nProcess in Swap"
	for file in $(grep -l VmSwap /proc/*/status)
        do
                [ -f $file ] && echo -e "$(grep VmSwap $file 2>/dev/null | awk '{print $2}')\t kB in Swap for process $(grep Name $file 2>/dev/null | awk '{print $2}') ($(grep ^Pid $file 2>/dev/null | awk '{print $2}'))"
        done | sort -nr | head -10
}

function normal_check()
{
#	ARG 0 : sort field refering to the following table
#	Name;Pid;PPid;VmSize;VmRSS;VmLib;VmSwap
#	1   ;2  ;3   ;4     ;5    ;6    ;7

	for file in $(grep -l VmRSS /proc/*/status)
	do
		[ -f $file ] && echo "$(grep ^Name: $file | awk '{print $2}') $(grep ^Pid: $file | awk '{print $2}') $(grep ^PPid: $file | awk '{print $2}') $(grep ^VmSize: $file | awk '{print $2}') $(grep ^VmRSS: $file | awk '{print $2}') $(grep ^VmLib: $file | awk '{print $2}') $(grep ^VmSwap: $file | awk '{print $2}')" | xargs | tr " " ";" >> $TMPFILE
	done
	printf "\n%90s\n" | tr " " "-"
	printf "%20s%10s%10s%15s%15s%20s\n" "Process Name" "(Pid)" "PPid" "in RAM (kB)" "in Swap (kB)" "Shared Lib (kB)"
	printf "%90s\n" | tr " " "-"
	sort -rn -t";" -k$1 $TMPFILE | while read line
	do
		printf "%20s%10s%10s%'15d%'15d%'20d\n" "$(echo $line | cut -d";" -f1)" "($(echo $line | cut -d";" -f2))" "$(echo $line | cut -d";" -f3)" "$(echo $line | cut -d";" -f5)" "$(echo $line | cut -d";" -f7)" "$(echo $line | cut -d";" -f6)"
	done
	printf "\n"
}

function help()
{
	echo "mem.sh : Show memory usage by processes"
	echo "Usage  :"
	echo "		-h : This help page"
	echo "		-e : Emergency mode"
	echo "		-r : Show memory usage by Resident Set Size"
	echo "		-s : Show memory usage by Swap"
}

[ -f $TMPFILE ] && rm -f $TMPFILE
getopts hders opt
	case $opt in
		h)	help;;
		e)	emergency;;
		r)	normal_check 5;;
		s)	normal_check 7;;
		*)	help;;
	esac

exit 0
