#!/bin/bash

save=false
verbose=false
reset=false

while getopts svr args; do
    case $args in
    s) save=true;;
    v) verbose=true;;
    r) reset=true;;
    esac
done

get_rate () {
    curr=$1
    pullrate=$(wget -qO- https://currency-api.appspot.com/api/USD/$curr.json?amount=1)
    rate=$(echo "$pullrate" | awk -F, '{print $(NF-2)}')
    echo ${rate##*:}
}

find_gpu () {
    local gpu="nvidia-smi"
    eval $gpu
    NSMI=$(eval $gpu)
    #echo $NSMI
    if echo "$NSMI" | grep -q 'failed'; then
        echo "none"
    #    NO GPU's in system
    else
        if echo "$NSMI" | grep -q 'V100'; then
            echo "V100"
        fi
        if echo "$NSMI" | grep -q 'P100'; then
            echo "P100"
        fi
	    if echo "$NSMI" | grep -q 'K80'; then
            echo "K80"
	    fi
    fi
}

get_uptime () {
    local upt="awk '{print $1}' /proc/uptime"
    secondsup=$(eval $upt)
    secondsup=( $secondsup )
    seconds=${secondsup[0]}
    seconds=${seconds%%.*}
    var=$(awk -v s=$seconds 'BEGIN { print s / 3600 }')
    echo $var
}

gpu_costs () {
    local cost=0
    local costphr=0
    local gputype=$(find_gpu)
    gputype="$(echo $gputype | awk '{print $NF}')"
    if [ "$gputype" = "P100" ]; then
        costphr=$(awk -v rate=$exrate 'BEGIN { print 1.60 * rate }')
        cost=$(awk -v cpr=$costphr -v time=$uptime 'BEGIN { print cpr * time }')
        if $verbose; then 
            echo "GPU:                   P100"
        fi
    elif [ "$gputype" = "V100" ]; then
        costphr=$(awk -v rate=$exrate 'BEGIN { print 2.48 * rate }')
        cost=$(awk -v cpr=$costphr -v time=$uptime 'BEGIN { print cpr * time }')
        if $verbose; then 
            echo "GPU:                   V100"
        fi
    elif [ "$gputype" = "K80" ]; then
        if $verbose; then echo "GPU:                   K80"; fi
        costphr=$(awk -v rate=$exrate 'BEGIN { print 0.49 * rate }')
        cost=$(awk -v cpr=$costphr -v time=$uptime 'BEGIN { print cpr * time }')
        if $verbose; then 
            echo "GPU:                   K80"
        fi
    else
        cost=0
        if $verbose; then 
            echo "GPU:                   NO GPU Used"
        fi
    fi
    if $verbose; then  
        echo "GPU Cost:              $"$cost
    else   
        echo $cost
    fi
    
}

ssd_costs () {
    local cost=0
    local costphr=0
    lsblkcmd=$(lsblk -d | cut -d' ' -f11-)
    size=$(echo $lsblkcmd | awk '{print $1;}')
    size=$(echo ${size::-1})
    # 0 if SSD, 1 if HDD
    type=$(cat /sys/block/sda/queue/rotational)
    if [ $type = 0 ]; then
        costgbphr=0.000232876712
    else
        costgbphr=0.00005479452
    fi
    costphr=$(awk -v cgb=$costgbphr -v sz=$size 'BEGIN { print cgb * sz }')
    cost=$(awk -v cpr=$costphr -v time=$uptime 'BEGIN { print cpr * time }')
    echo $cost
    
}

system_costs () {
    local cost=0
    local costphr=0
    corenum="nproc --all"
    cores=$(eval $corenum)
    ram=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    ram=${ram//[^0-9]/}
    ram=$((ram / 1000000))
    cpuhrs=0.038410
    memhrs=0.005150
    
    memcost=$(awk -v mrs=$memhrs -v ramn=$ram 'BEGIN { print mrs * ramn }')
    corecost=$(awk -v cps=$cores -v cprs=$cpuhrs 'BEGIN { print cps * cprs }')
    syscost=$(awk -v mtot=$memcost -v ctot=$corecost -v ert=$exrate 'BEGIN { print (mtot + ctot) * ert }')
    cost=$(awk -v scpr=$syscost -v tm=$uptime 'BEGIN { print scpr * tm }')
    ssd=$(ssd_costs)
    totcost=$(awk -v sd=$ssd -v ct=$cost 'BEGIN { print sd + ct }')
    if $verbose; then
        echo "vCPU's:                "$cores
        echo "Ram:                   "$ram"GB"
        echo "CPU+mem Cost:          $"$cost
        echo "SSD cost:              $"$ssd
        echo "System cost:           $"$totcost
    else
        echo "$"$totcost
    fi
}

store_hist () {
    if [ ! -f $3 ]; then
        eval "sudo touch $3"
        eval "sudo chmod 777 $3"
    fi
    echo "$1 $""$2" >> $3
}

reset_hist (){
    >$1
}

fetch_hist () {
    loc=$3

    if $reset; then
        # erase past billing history
        reset_hist $loc
        echo "$"0
    elif $save; then
        # save session to histroy
        store_hist $1 $2 $loc
    else
        if [ -f $loc ]; then
            totalcost=0
            count=0
            while read -r line
            do
    		if (( $count > 0 )); then
                    name="$line"
                    set -- $name
                    timeup=$1
                    currcost=$2
                    costnum=${currcost:1}
                    totalcost=$(awk -v a=$totalcost -v b=$costnum 'BEGIN { print a + b }')
                    if $verbose; then echo $count" - Time: "$timeup"hrs, Cost: "$2; fi
                fi
                ((count++))
            done < "$loc"

            if $verbose; then
                printf "\n"
                echo "Past Bill Total:       $"$totalcost
            else
                echo "$"$totalcost
            fi
        else
            if $verbose; then
                echo "No file found, assumed no history"
                echo "Past Usage Total: $""0"
            else
                echo "$"0
            fi
        fi
    fi
}

filestore="/etc/init.d/gcecosts.log"

if [ ! -f $filestore ] || [ ! -s $filestore ]; then
    pwd='"'$(pwd)
    scrptname=$(basename -- "$0")'"'
    echo alias gcecosts="$pwd/$scrptname" >> ~/.bashrc
    
    read -p "Please initialize billing details. Set GCE credits limit: " credits
    read -p "Enter your currency for exchange rate (eg. USD, AUD): " currency
    
    printf "\nNice! Now add the metadata custom key to google cloud instance:\n"
    pwd=$(pwd)
    printf "Key: 'shutdown-script', Value: 'sudo $pwd/${scrptname::-1} -s'\n"
    eval "sudo touch $filestore"
    eval "sudo chmod 777 $filestore"
    echo $credits" "$currency > $filestore
else
    uinfo=$(head -n 1 $filestore)
    credits=$(echo $uinfo | cut -d' ' -f 1)
    currency=$(echo $uinfo | cut -d' ' -f 2)
fi

exrate=$(get_rate $currency)
uptime=$(get_uptime)
gpu_cost=$(gpu_costs)
syscosts=$(system_costs)

sys_totcost="$(echo $syscosts | awk '{print $NF}')"
sys_totcost="${sys_totcost:1}"
gpu_totcost="$(echo $gpu_cost | awk '{print $NF}')"
gpu_totcost="${gpu_totcost:1}"

total_syscost=$(awk -v syst=$sys_totcost -v gputc=$gpu_totcost 'BEGIN { print syst + gputc }')

chist_info=$(fetch_hist $uptime $total_syscost $filestore)
cost_hist="$(echo $chist_info | awk '{print $NF}')"
cost_hist="${cost_hist:1}"
totalsum=$(awk -v ch=$cost_hist -v tsc=$total_syscost 'BEGIN { print ch + tsc }')

if $reset; then
    printf "\n** Billing history erased **\n"
fi

if ! $save; then
    printf "\n"
    echo "--------- General Info  ---------"
    echo "Uptime:                "$uptime"hrs"

    if $verbose; then
        # Verbose mode
        echo "Exchange rate ($currency):   $"$exrate
        printf "\n------------- GPU -------------\n"
        echo "$gpu_cost"
        printf "\n------------ System ------------\n"
        echo "$syscosts"
        printf "\n----- Cost Usage History -----\n"
        echo "$chist_info"
    fi
    
    printf "\n---- Total Instance Usage ----\n"
    echo "Past Usage Cost:       $"$cost_hist
    echo "Current Usage Cost:    $"$total_syscost
    printf "\n"
    echo "Total Bill:            $"$totalsum

    remaining=$(awk -v crd=$credits -v tsum=$totalsum 'BEGIN { print crd - tsum }')
    echo "Remaining:             $"$remaining "of \$$credits"
    printf "\n"
fi


