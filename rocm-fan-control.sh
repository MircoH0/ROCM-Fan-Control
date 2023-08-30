#!/bin/bash

trap "" 2

smartfan=0
sf_autotemp=60
sf_inauto=0

function calc_fanspd(){
	spd=`expr ${1} - 20`
	return $spd
}

while true
do
	#edge_temp=`rocm-smi -t | grep "edge" | grep -o "[0-9]*.[0-9]$"`
	junction_temp=`rocm-smi -t | grep "junction" | grep -o "[0-9]*.[0-9]$"`
	memory_temp=`rocm-smi -t | grep "memory" | grep -o "[0-9]*.[0-9]$"`
	#fan_percent=`rocm-smi -f | grep -o "[0-9]*\%"`
	fan_rpm=`rocm-smi -f | grep "RPM" | grep -o "[0-9]*$"`
	#gpu_useage=`rocm-smi -u |grep -o "[0-9]*$"`
	#gpu_sclk=`rocm-smi -c |grep "sclk"|grep -o "[0-9]*Mhz"`
	#memory_total=`rocm-smi --showmeminfo vram | grep "Total Memory"|grep -o "[0-9]*$"`
	#memory_use=`rocm-smi --showmeminfo vram | grep "Used Memory"|grep -o "[0-9]*$"`
	
	if (("$smartfan" == "1"))
	then
		if (("${junction_temp%.*}" <= "$sf_autotemp"))
		then
			if (("$sf_inauto" == "0"))
			then
				rocm-smi --resetfans
				sf_inauto=1
			fi
			sf_info="Smart fan mode : ON (Display driver control)"
		else
			sf_inauto=0
			calc_fanspd ${junction_temp%.*}
			#let fanspd=${junction_temp%.*}-20
			fanspd=${?}
			rocm-smi --setfan ${fanspd}"%"
			sf_info="Smart fan mode : ON (Set to ${fanspd}%)"
		fi
	else
		sf_info="Smart fan mode : OFF"
	fi
	
	clear
	rocm-smi
	#echo "GPU uesage : ${gpu_useage}%"
	#echo "DieEdge Temperature : ${edge_temp}c"
	echo -e "\nJunction Temperature : ${junction_temp}c\nVRAM Temperature : ${memory_temp}c"
	if [ ! $fan_rpm ]
	then
		echo "GPU Fan : 0 RPM"
	else
		echo "GPU Fan : ${fan_rpm} RPM"
	fi
	
	echo -e "\n____________Set GPU fan speed____________\n\n  0-9 : 0%-90%\n  F : 100%\n  A : Auto control by display driver\n  S : Switch smart fan mode (ON/OFF)\n  Q : Set to driver control and exit\n  X : Exit\n"
	echo $sf_info
	if read -t 3 -n1 userinput
	then
		echo
		case $userinput in
		[aA])
			smartfan=0
			sf_inauto=0
			rocm-smi --resetfans
			;;
		[0-9])
			smartfan=0
			sf_inauto=0
			let fanspd=$userinput*10
			rocm-smi --setfan ${fanspd}"%"
			;;
		[sS])
			case $smartfan in
			0)
				smartfan=1
				;;
			1)
				smartfan=0
				rocm-smi --resetfans
				;;
			esac
			;;
		[fF])
			smartfan=0
			sf_inauto=0
			rocm-smi --setfan 100%
			;;
		[xX])
			break
			;;
		[qQ])
			rocm-smi --resetfans
			sf_insuto=1
			break
			;;
		*)
			echo "Wrong input."
			;;
		esac
	fi
done