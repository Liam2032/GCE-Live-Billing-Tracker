    #!/bin/bash

    # ////////////////////////////////////////////////////// 
    #
    # Author: Liam Mellor
    # 
    # Description: This calculates usage costs of your GCE instances 
    # automatically and seamlessly. Using google drive cloud storage,
    # you can sync real-time usage costs to see what your real billing
    # cost is of used services, no estimation used.
    # 
    # License: Give credit where it's due, this took a while to make...
    #
    # ////////////////////////////////////////////////////// 

    # ----- Set abort function for program errors -----

    abort()
    {
        echo >&2 '

    *** ABORTED ***
    '
        echo -e 'Exited program.  If issues persist, remove drive file 
        \nand gce_billing directory to start fresh.' >&2
        exit 1
    }

    trap 'abort' 0
    set -e

    # --------------------------------------------------

    # ----- Case statement for user input -----

    save=false
    verbose=false
    run_startup=false
    reset=false

    pwd=$HOME

    while getopts svzr args; do
        case $args in
        s) save=true;;
        v) verbose=true;;
        z) run_startup=true;;
        r) reset=true;;
        esac
    done

    # -----------------------------------------

    get_gdrive() {
        if [ ! -f $pwd/drive ]; then
            read -p "First time running this? [y/N]:  " new_run

            case "$new_run" in
                [yY][eE][sS]|[yY]) 
                    echo -e '\n If this is your first time running this, authentication will\n'
                    echo -e 'required. Please follow authentication link and sign into drive\n'
                    echo -e 'account you would like to use for cloud storage.\n'
                    sudo wget -q --no-check-certificate 'https://docs.google.com/uc?export=download&id=0B3X9GlR6EmbnQ0FtZmJJUXEyRTA' \
                    -O $pwd/drive && sudo chmod 777 $pwd/drive && $pwd/drive about
                    ;;
                *)
                    echo "no gdrive file was found in location $pwd/drive. \
                    Ensure correct permissions are set and file is there."
                    exit 1
                    ;;
            esac
        fi
    }

    init_env() {

        if [ ! -f $pwd/drive ]; then
            echo "***ERROR: gdrive not found. Please re-run with appropriate permissions. ***"
            exit 1
        fi
        instance_name=$(hostname)
        drive="$pwd/drive"
        
        bill_dir="/etc/init.d/gce_billing"

        if [ ! -d "$bill_dir" ]; then
            eval "sudo mkdir $bill_dir"
            eval "sudo chmod 777 $bill_dir"
        fi
        
        local_file="${bill_dir}/${instance_name}-bill-history.log"
        remote_file="${bill_dir}/all_costs.log"
        
        if [ ! -f $local_file ] || [ ! -s $local_file ]; then
            scrptname=$(basename -- "$0")'"'
            alias gcecosts=$pwd/$scrptname
            echo alias gcecosts="$pwd/$scrptname" >> ~/.bashrc
            cron_file="/etc/cron.hourly/${instance_name}-run-hourly"
    
            echo -e '\nNo local file found. Initialize desired billing details.\n'
            read -p "Set GCE credits limit for your account: $" credits
            read -p "Enter your currency for exchange rate (eg. USD, AUD): " currency
            
            printf "\nNow add this metadata custom key to this google cloud instance:\n\n"
            printf "Key: 'shutdown-script'\nValue: 'sudo $pwd/${scrptname::-1} -z'\n"
            echo -e '\nThats it, you are all set! Run using: gce_billing [options].'
            echo -e 'Options: \n [-s] to pull/push latest billing copies'
            echo -e ' [-v] to view a verbose stdout output. \n\nNOTE: syncing from cloud will take place every 30MIN.\n'
            eval "sudo touch $local_file"
            eval "sudo chmod 777 $local_file"
            echo "-- "$instance_name": "$credits" "$currency > $local_file
        else
            uinfo=$(head -n 1 $local_file)
            credits=$(echo $uinfo | cut -d' ' -f 3)
            currency=$(echo $uinfo | cut -d' ' -f 4)
        fi

        if [ ! -f $remote_file ]; then
            echo "Creating local copy of all gce costs history from cloud..."
            eval "sudo touch $remote_file"
            eval "sudo chmod 777 $remote_file"
            sync_drive
            # get list of all instance files in directory that is not current instance
        fi  

        gcedir_id=$($drive list --no-header --query "name contains 'gce_billing' and \
        trashed = false and mimeType = 'application/vnd.google-apps.folder'" | awk '{ print $1}')
        if [ -z "$gcedir_id" ]; then 
            echo -e 'No google drive directory found. Creating...\n'
            $drive mkdir gce_billing &> /dev/null
            gcedir_id=$($drive list --no-header --query "name contains 'gce_billing' and \
            trashed = false and mimeType = 'application/vnd.google-apps.folder'" | awk '{ print $1}')
            sync_drive
        fi

        if [ ! -f $cron_file ] || [ ! -s $cron_file ]; then
            echo "Creating automatic script to push local billing status to cloud..."
            if [ -f $local_file ]; then
                eval "sudo touch $cron_file"
                eval "sudo chmod 777 $cron_file"
                echo -e "#\0041/bin/bash\n$drive sync upload $bill_dir $gcedir_id" >> $cron_file
            else
                echo "issue with creating local file. Needs to be fixed before continue."
            fi
        fi

    


    }

    check_modified() {
        if [ `stat --format=%Y $remote_file` -le $(( `date +%s` - 1800 )) ]; then 
            echo 1 
        else
            echo 0
        fi
    }

    sync_drive() {
        gcedir_id=$($drive list --no-header --query "name contains 'gce_billing' and \
        trashed = false and mimeType = 'application/vnd.google-apps.folder'" | awk '{ print $1}')

        list=$($drive list --no-header --query "name contains 'bill-history.log' and trashed = false \
        and mimeType != 'application/vnd.google-apps.folder'" | grep -v $instance_name \
        | awk '{ print $1}')
        
        if [ ! -z "$list" ]; then   
            >$remote_file
            echo "$list" | while read line;   
            do 
                # download and concat to current remote file
                $drive download --stdout $line >> $remote_file
            done
        else
            echo "No other instance billing history found at this time"
        fi

        echo "Pushing latest gce usage and pulling latest bill from cloud..."
        
        if [ $gcedir_id ]; then
            $drive sync upload $bill_dir $gcedir_id &> /dev/null

            clean_all_costs=$($drive list --no-header --query "name = 'all_costs.log' and trashed = false and \
            mimeType != 'application/vnd.google-apps.folder'" | awk '{ print $1}')
            
            if [ ! -z "$clean_all_costs" ]; then 
                echo "$clean_all_costs" | while read line;   
                do 
                    $drive delete $line &> /dev/null
                done
            else
                echo "no other instance billing history found"
            fi
        else
            echo -e '\nFolder gce_billing not found on google drive.\n'
        fi
    }

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
            elif echo "$NSMI" | grep -q 'P100'; then
                echo "P100"
            elif echo "$NSMI" | grep -q 'K80'; then
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
            echo "$"$cost
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

    print_hist() {
        while read -r line;
        do
            if [[ $line == "--"* ]]; then
                name=$(echo $line | awk '{print $2}')
                printf "\nVM $count: $name\n"
                ((count++))
            else
                name="$line"
                set -- $name
                timeup=$1   
                currcost=$2
                costnum=${currcost:1}
                totalcost=$(awk -v a=$totalcost -v b=$costnum 'BEGIN { print a + b }')
                if $verbose; then echo "- Time: "$timeup"hrs, Cost: "$2; fi
            fi
        done < "$1"
    }
    hist_costs () {
        rem=$3
        loc=$4
        if [ -f $rem ]; then
            count=1
            totalcost=0
            print_hist $loc
            echo -e '\nOther VMs Billing history:'
            print_hist $rem
            if $verbose; then
                printf "\n"
                echo "Total Past Billing Cost:       $"$totalcost
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
    }

    # ----- Run Gdrive functions ------

    get_gdrive
    init_env

    #----------------------------------

    # ----- Initialize and run  GCE cost calculation dependencies ----- 

    exrate=$(get_rate $currency)
    uptime=$(get_uptime)
    gpu_cost=$(gpu_costs)
    syscosts=$(system_costs)

    sys_totcost="$(echo $syscosts | awk '{print $NF}')"
    sys_totcost="${sys_totcost:1}"
    gpu_totcost="$(echo $gpu_cost | awk '{print $NF}')"
    gpu_totcost="${gpu_totcost:1}"

    total_syscost=$(awk -v syst=$sys_totcost -v gputc=$gpu_totcost 'BEGIN { print syst + gputc }')

    chist_info=$(hist_costs $uptime $total_syscost $remote_file $local_file)

    cost_hist="$(echo $chist_info | awk '{print $NF}')"
    cost_hist="${cost_hist:1}"
    totalsum=$(awk -v ch=$cost_hist -v tsc=$total_syscost 'BEGIN { print ch + tsc }')

    #------------------------------------------------------------------

    # --------------- Save local copy on shutdown --------------

    if $run_startup; then
        if [ ! -f $local_file ]; then
            eval "sudo touch $3"
            eval "sudo chmod 777 $3"
        fi

        echo "$uptime $""$total_syscost" >> $local_file
    fi
    #------------------------------------------------

    # --------------- Check sync state --------------

    do_sync=$(check_modified)

    if [ "$do_sync" -eq 1 ] || $save; then
        echo -e '\nUpdating local billing file...'
        sync_drive
    fi

    #------------------------------------------------

    # --------------- Print to stdout --------------
    if ! $run_startup && ! $save; then
        printf "\n"
        echo "--------- $instance_name Info  ---------"
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
        
        printf "\n---- Total $instance_name Usage ----\n"
        echo "Past Usage Cost:       $"$cost_hist
        echo "Current Usage Cost:    $"$total_syscost
        printf "\n"
        echo "Total Bill:            $"$totalsum

        remaining=$(awk -v crd=$credits -v tsum=$totalsum 'BEGIN { print crd - tsum }')
        echo "Remaining:             $"$remaining "of \$$credits"
        printf "\n"
    fi
    #------------------------------------------------------------------

    if $reset; then
        read -p "Are you sure you want to reset? You will lose ALL local and cloud billing history [YES]: " new_run
        if [ "$new_run" == "YES" ]; then
            echo "Deleted local history directory..."
            eval "sudo rm -r $bill_dir"

            echo "Deleted google drive gce_billing folder..."
            gcedir_id=$($drive list --no-header --query "name contains 'gce_billing' and \
            trashed = false and mimeType = 'application/vnd.google-apps.folder'" | awk '{ print $1}')
            if [ "$gcedir_id" ]; then 
                $drive delete -r $gcedir_id
            fi
        fi
    fi


    trap : 0
