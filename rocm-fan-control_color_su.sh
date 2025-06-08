#!/bin/bash

resize -s 26 122 > /dev/null
echo -e "\033]0;ROCM-Fan-Control\007"
trap "echo -e \"\n\033[31mPress X key to exit\033[0m\"" 2
echo -e "\033[?25l"

# 颜色定义 - 增强版
RED='\033[0;91m'        # 亮红色
GREEN='\033[0;92m'      # 亮绿色
YELLOW='\033[0;93m'     # 亮黄色
LIGHT_CYAN='\033[96m'   # 亮青色（替换原蓝色）
PURPLE='\033[0;95m'     # 亮紫色
CYAN='\033[0;36m'       # 青色（用于辅助信息）
NC='\033[0m'            # 重置颜色

refresh_interval=3
smartfan=0
sf_autotemp=55
sf_inauto=0


function calc_fanspd(){
    local tmp=$(( (4 * $1 - 99) / 3 ))
    if ((tmp > 100))
    then
        tmp=100
    fi
    echo $tmp
}

function temp_color() {
    if (($1 > 70)); then
        echo -e "${RED}$1${NC}"
    elif (($1 > 55)); then
        echo -e "${YELLOW}$1${NC}"
    else
        echo -e "${GREEN}$1${NC}"
    fi
}

while true
do
    junction_temp=`sudo rocm-smi -t | grep "junction" | grep -o "[0-9]*.[0-9]$"`
    vram_temp=`sudo rocm-smi -t | grep "memory" | grep -o "[0-9]*.[0-9]$"`
    fan_rpm=`sudo rocm-smi -f | grep "RPM" | grep -o "[0-9]*$"`
    
    sf_info="${CYAN}Smart fan mode : ${NC}"
    if (($smartfan == "1"))
    then
        if ((${junction_temp%.*} <= $sf_autotemp))
        then
            if (($sf_inauto == "0"))
            then
                sudo rocm-smi --resetfans > /dev/null
                sf_inauto=1
            fi
            sf_info=$sf_info"${GREEN}ON (Display driver control)${NC}"
        else
            sf_inauto=0
            fanspd=$(calc_fanspd ${junction_temp%.*})
            sudo rocm-smi --setfan ${fanspd}"%" > /dev/null
            sf_info=$sf_info"${YELLOW}ON (Set to ${fanspd}%)${NC}"
        fi
    else
        sf_info=$sf_info"${RED}OFF${NC}"
    fi
    
    sf_info=$sf_info"\n${CYAN}Trigger temperature : ${NC}${LIGHT_CYAN}${sf_autotemp}c${NC}\n${CYAN}Refresh interval : ${NC}${LIGHT_CYAN}${refresh_interval}s${NC}"
    
    clear
    sudo rocm-smi | sed -n 4,9p

    echo -e "\n   ${CYAN}Junction Temperature : ${NC}$(temp_color ${junction_temp%.*})c\n   ${CYAN}VRAM Temperature : ${NC}$(temp_color ${vram_temp%.*})c\n   ${CYAN}GPU Fan : ${NC}${PURPLE}${fan_rpm:-"0"} RPM${NC}"
    
    echo -e "\n${LIGHT_CYAN}________________Set GPU fan speed________________${NC}\n\n   ${GREEN}0${NC}-${GREEN}9${NC} : 0%-90%\n   ${GREEN}+${NC}/${GREEN}-${NC} : Change smart fan trigger temperature\n   ${GREEN}[${NC}/${GREEN}]${NC} : Change info refresh interval\n   ${GREEN}F${NC} : 100%\n   ${GREEN}A${NC} : Auto control by display driver\n   ${GREEN}S${NC} : Switch smart fan mode (ON/OFF)\n   ${GREEN}Q${NC} : Set to driver control and exit\n   ${GREEN}X${NC} : Exit\n"
    echo -e $sf_info
    
    if read -s -t $refresh_interval -n1 userinput
    then
        echo
        case $userinput in
        [aA])
            smartfan=0
            sf_inauto=0
            sudo rocm-smi --resetfans > /dev/null
            ;;
        [0-9])
            smartfan=0
            sf_inauto=0
            fanspd=$(($userinput*10))
            sudo rocm-smi --setfan $fanspd"%" > /dev/null
            ;;
        [sS])
            case $smartfan in
            0)
                smartfan=1
                ;;
            1)
                smartfan=0
                sudo rocm-smi --resetfans > /dev/null
                ;;
            esac
            ;;
        [fF])
            smartfan=0
            sf_inauto=0
            sudo rocm-smi --setfan 100% > /dev/null
            ;;
        [xX])
            break
            ;;
        [qQ])
            sudo rocm-smi --resetfans > /dev/null
            sf_inauto=1
            break
            ;;
        [+=])
            ((sf_autotemp+=5))
            ;;
        -)
            ((sf_autotemp-=5))
            ;;
        [)
            if (($refresh_interval > "1"))
            then
                ((refresh_interval-=1))
            fi
            ;;
        ])
            ((refresh_interval+=1))
            ;;
        *)
            echo -e "${RED}Wrong input.${NC}"
            ;;
        esac
    fi
done
echo -e "\033[?25h"
clear
