#!/bin/bash

trap "echo -e \"\nPress X key to exit\"" 2
echo -e "\033[?25l"

refresh_interval=3
smartfan=0
sf_autotemp=55
sf_inauto=0

function calc_fanspd(){
	spd=$(($1-20))
	echo $spd
}

while true
do
	#edge_temp=`rocm-smi -t | grep "edge" | grep -o "[0-9]*.[0-9]$"`
	junction_temp=`rocm-smi -t | grep "junction" | grep -o "[0-9]*.[0-9]$"`
	vram_temp=`rocm-smi -t | grep "memory" | grep -o "[0-9]*.[0-9]$"`
	#fan_percent=`rocm-smi -f | grep -o "[0-9]*\%"`
	fan_rpm=`rocm-smi -f | grep "RPM" | grep -o "[0-9]*$"`
	#gpu_useage=`rocm-smi -u | grep -o "[0-9]*$"`
	#gpu_sclk=`rocm-smi -c | grep "sclk" | grep -o "[0-9]*Mhz"`
	#vram_total=`rocm-smi --showmeminfo vram | grep "Total Memory" | grep -o "[0-9]*$"`
	#vram_use=`rocm-smi --showmeminfo vram | grep "Used Memory" | grep -o "[0-9]*$"`
	
	sf_info="Smart fan mode : "
	if (($smartfan == "1"))
	then
		if ((${junction_temp%.*} <= $sf_autotemp))
		then
			if (($sf_inauto == "0"))
			then
				rocm-smi --resetfans > /dev/null
				sf_inauto=1
			fi
			sf_info=$sf_info"ON (Display driver control)"
		else
			sf_inauto=0
			fanspd=$(calc_fanspd ${junction_temp%.*})
			rocm-smi --setfan ${fanspd}"%" > /dev/null
			sf_info=$sf_info"ON (Set to ${fanspd}%)"
		fi
	else
		sf_info=$sf_info"OFF"
	fi
	
	sf_info=$sf_info"\nTrigger temperature : ${sf_autotemp}c\nRefresh interval : ${refresh_interval}s"
	
	clear
	rocm-smi | sed -n 4,7p

	echo -e "\n   Junction Temperature : ${junction_temp}c\n   VRAM Temperature : ${vram_temp}c\n   GPU Fan : ${fan_rpm:-"0"} RPM"
	
	echo -e "\n________________Set GPU fan speed________________\n\n   0-9 : 0%-90%\n   +/- : Change smart fan trigger temperature\n   [/] : Change info refresh interval\n   F : 100%\n   A : Auto control by display driver\n   S : Switch smart fan mode (ON/OFF)\n   Q : Set to driver control and exit\n   X : Exit\n"
	echo -e $sf_info
	
	if read -s -t $refresh_interval -n1 userinput
	then
		echo
		case $userinput in
		[aA])
			smartfan=0
			sf_inauto=0
			rocm-smi --resetfans > /dev/null
			;;
		[0-9])
			smartfan=0
			sf_inauto=0
			fanspd=$(($userinput*10))
			rocm-smi --setfan $fanspd"%" > /dev/null
			;;
		[sS])
			case $smartfan in
			0)
				smartfan=1
				;;
			1)
				smartfan=0
				rocm-smi --resetfans > /dev/null
				;;
			esac
			;;
		[fF])
			smartfan=0
			sf_inauto=0
			rocm-smi --setfan 100% > /dev/null
			;;
		[xX])
			break
			;;
		[qQ])
			rocm-smi --resetfans > /dev/null
			sf_insuto=1
			break
			;;
		[+=])
			((sf_autotemp+=5))
			;;
		-)
			((sf_autotemp-=5))
			;;
		[)
			if (($refresh_time > "1"))
			then
				((refresh_time-=1))
			fi
			;;
		])
			((refresh_time+=1))
			;;
		*)
			echo "Wrong input."
			;;
		esac
	fi
done
echo -e "\033[?25h"
