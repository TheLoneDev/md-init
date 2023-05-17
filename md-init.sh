#!/bin/bash

SCRIPT_VER=1

main()
{
    echo "md-init v$SCRIPT_VER"

    check_requirements
    if [ $? -eq 0 ]; then
        return 1
    fi

    local raid_lvl
    read -p "Which RAID level would you like to setup?:" raid_lvl

    if ! [[ $raid_lvl =~ ^-?[0-9]+$ ]]; then
        echo "Invalid number"
        return 2
    fi
        
    # Not using switch, since I want to check when not to continue.
    # Makes more sense to me with my style (C-like?)
    if [ $raid_lvl -ne 0 ] && [ $raid_lvl -ne 1 ]  && \
       [ $raid_lvl -ne 4 ] && [ $raid_lvl -ne 5 ]  && \
       [ $raid_lvl -ne 6 ] && [ $raid_lvl -ne 10 ]; 
    then
        echo "Invalid raid level"
        return 3
    fi

    local num_drives
    read -p "How many drives do you need to add?:" num_drives

    if ! [[ $num_drives =~ ^-?[0-9]+$ ]]; then
        echo "Invalid number"
        return 4
    fi


    local drives=()
    echo "Lets add the drives:"
    for ((i=1; i<=num_drives;i++ ))
    do
        read -p "Drive no.$i:" disk_name
        check_disk $disk_name
        if [ $? -eq 0 ]; then
            echo "Invalid drive ($disk_name)"
            return 5
        else
            drives+=($disk_name)
        fi
    done

    echo "${#drives[@]} drives were added to the list:"

    for drive in "${drives[@]}"
    do
        echo $drive
    done
    
    local confirm_data_destroy
    read -p "This process will destroy all data on disks, continue?(y/n):" confirm_data_destroy

    if [[ "${confirm_data_destroy:0:1}" != "y" ]]; then
        echo "Cancelled due to user choice"
        return 6
    fi

    format_drives "${drives[@]}"

    echo "Done formatting drives"

    create_raid $raid_lvl "${drives[@]}"
    
    if [ $? -eq 0 ]; then
      echo "Raid creation failed"
      return 7
    fi
    
    md_stat=$(grep -i finish /proc/mdstat)

    while [[ $md_stat =~ "finish" ]]; 
    do
      echo "$md_stat"
      md_stat=$(grep -i finish /proc/mdstat)
    done

    echo -e "Finished setting up the md raid!\nIt is recommended to update the initramfs"

}

create_raid()
{
    local raid_lvl=$1
    local drives=("${@:2}")

    echo "Creating RAID $raid_lvl"

    # just to make sure, remove superblocks (if it came from previous raids)
    
    mdadm --zero-superblock "${drives[@]}" > /dev/null 2>&1

    echo "yes" | mdadm --create /dev/md0 --level=$raid_lvl --raid-devices="${#drives[@]}" "${drives[@]}" > /dev/null 2>&1
    
    if [ $? -ne 0 ]; then
      return 0
    fi
     
    echo "Saving RAID configuration.."

    if [ ! -d "/etc/mdadm" ]; then
      mkdir /etc/mdadm
    fi

    mdadm --detail --scan /dev/md0 > /etc/mdadm/mdadm.conf

    return 1
}

format_drives()
{
    local drives=("$@")

    for i in "${drives[@]}"
    do
        echo "Formatting $i...."
        parted -s $i mklabel gpt
        # add check if gpt creation is successful
        parted -s $i mkpart primary 0% 100%
        # add check if primary partition creation is successful
        parted -s $i set 1 raid on
        # add check if raid flag set is successful
        echo "Done!"
    done
}

check_requirements()
{
    if ! command -v parted >/dev/null 2>&1; then
        echo "'parted' is missing, please install it."
        return 0
    elif ! command -v mdadm >/dev/null 2>&1; then
        echo "'mdadm' is missing, please install it."
        return 0
    fi

    return 1
}

#detect_pkgmgr() # implement only when supporting auto installing packages
#{
#    local os_name_line=$(cat /etc/*release* | grep "^NAME=")
#    if [[ ${os_name_line,,} =~ "arch" ]]; then
#        echo "Good!"
#    fi
#    
#    echo $os_name_line
#}

detect_dist()
{
    local os_id=$(cat /etc/*release* | grep "^ID=")
    local os_id_like=$(cat /etc/*release* | grep "^ID_LIKE=")

    if [[ ${os_id,,} =~ "arch" ]]; then
        echo "arch"
    elif [[ ${os_id_like,,} =~ "debian" ]]; then
        echo debian
    elif [[ ${os_id_like,,} =~ "fedora" ]]; then
        echo fedora
    else
        echo ""
    fi
}

check_disk()
{
    local disk=$1

    if [[ "${disk:0:5}" != "/dev/" ]]; then
        return 0
    fi
    
    if [ ! -e $disk ]; then
        return 0
    fi
    
    return 1
}


# Call main function
main 

exit $?
