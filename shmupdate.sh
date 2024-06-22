#!/bin/bash
echo "
###############################################################################
### This is automated script to calculate and update the kernel parameters ####
###############################################################################"

read -p "Do you want to calculate and update the kernel parameters? (yes/no): " choice1
if [[ $choice1 == "yes" ]]; then


# Function to convert GB to bytes
convert_gb_to_bytes() {
    local gb="$1"
    local bytes=$(("gb * 1024 * 1024 * 1024" | bc))
    echo "$bytes"
}

# Ask the user for a GB value (including fractions)
read -p "Enter RAM value in GB (e.g., 20, 30, 32 ....): " gb_value

# Validate input (ensure it's a positive number)
   if [[ "$gb_value" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    shmmax=$(convert_gb_to_bytes "$gb_value")

    # Calculate shmall value (maximum number of shared memory segments in pages)
    page_size=$(getconf PAGE_SIZE)
    phys_pages=$(getconf _PHYS_PAGES)
    shmall=$((shmmax / page_size))
    nr_hugepages=$((shmmax / 2097152))

    echo "######################## calculated values ###################"
    echo "# Maximum shared segment size in bytes"
    echo "kernel.shmmax = $shmmax"
    echo "# Maximum number of shared memory segments in pages"
    echo "kernel.shmall = $shmall"
    echo "vm.nr_hugepages = $nr_hugepages"

    read -p "Please confirm to update new parameters as above in sysctl.conf file? (yes/no): " choice
    if [[ $choice == "yes" ]]; then

    cp /etc/sysctl.conf /etc/sysctl.conf_secure_bkp
    echo " file backup /etc/sysctl.conf_secure_bkp"
    echo "################### Comment out previous values ##################"
    sudo sed -i 's/^kernel.shmall/# kernel.shmall/' /etc/sysctl.conf
    sudo sed -i 's/^kernel.shmmax/# kernel.shmmax/' /etc/sysctl.conf
    sudo sed -i 's/^vm.hugetlb_shm_group/# vm.hugetlb_shm_group/' /etc/sysctl.conf
    sudo sed -i 's/^vm.nr_hugepages/# vm.nr_hugepages/' /etc/sysctl.conf

    echo "###################### updating /etc/sysctl.conf ####################"

    # Add new values to /etc/sysctl.conf
    echo -e "\n# Updated values for shared memory" | sudo tee -a /etc/sysctl.conf
    echo "kernel.shmmax = $shmmax" | sudo tee -a /etc/sysctl.conf
    echo "kernel.shmall = $shmall" | sudo tee -a /etc/sysctl.conf
    echo "vm.hugetlb_shm_group = 6002" | sudo tee -a /etc/sysctl.conf
    echo "vm.nr_hugepages = $nr_hugepages" | sudo tee -a /etc/sysctl.conf
    echo "/etc/sysctl.conf successful"

    else
    echo "No changes were made."
    fi
   else
     echo "Invalid input. Please enter a positive number."
   fi
else
   continue
fi

    # Ask for confirmation before disabling THP
    echo "###################################################################################"
    read -p "Do you want to disable Transparent Huge Pages (THP)? (yes/no): " thp_confirmation
    if [[ "$thp_confirmation" == "yes" ]]; then
        # Disable THP temporarily (runtime)
        echo "Disabling THP temporarily..."
        echo never > /sys/kernel/mm/transparent_hugepage/enabled
        echo "THP has been disabled temporarily."

        # Update grub configuration for permanent disablement
        grub_config="/etc/default/grub"
        if ! grep -q "transparent_hugepage=never" "$grub_config"; then
            sed -i 's/^GRUB_CMDLINE_LINUX="\(.*\)"/GRUB_CMDLINE_LINUX="\1 transparent_hugepage=never"/' "$grub_config"
            echo "Updated GRUB_CMDLINE_LINUX in $grub_config successful"
        else
            echo "transparent_hugepage=never line already exists in $grub_config. Skipping update."
        fi

        # Recreate grub.cfg (choose BIOS or EFI)
        if [ -d "/boot/efi" ]; then
            echo "Recreating grub.cfg for EFI..."
            grub2-mkconfig -o /boot/efi/EFI/redhat/grub.cfg
        else
            echo "Recreating grub.cfg for BIOS..."
            grub2-mkconfig -o /boot/grub2/grub.cfg
        fi

            echo "Grub configuration updated."

            echo "Reboot required..."


    else
        echo "THP remains unchanged."
    fi
echo "##############################################################"

read -p "Do you want to update the oracle.conf file? (yes/no): " update_choice
if [[ $update_choice == "yes" ]]; then

# Path to the Oracle configuration file
ORACLE_CONF="/etc/security/limits.d/oracle.conf"

# Function to comment out a line in the configuration file
comment_line() {
    local line="$1"
    sed -i "s/^$line/# $line/" "$ORACLE_CONF"
}

# Function to update a value in the configuration file
update_value() {
    local key="$1"
    local value="$2"
    sed -i "s/^$key.*/$key $value/" "$ORACLE_CONF"
}

    # Prompt user for new values
    read -p "Enter the new stack size [stack_size] (soft and hard limits in KB): " stack_size
    read -p "Enter the new maximum locked memory [memlock] (soft and hard limits in KB): " memlock
    read -p "Enter the new open file descriptors [nofile] (soft and hard limits): " nofile
    read -p "Enter the new number of processes [nproc] (soft and hard limits): " nproc

    # Comment out existing lines for @dba and oracle group
    sudo sed -i 's/^@dba /# @dba /' /etc/security/limits.d/oracle.conf
    sudo sed -i 's/^oracle /# oracle /' /etc/security/limits.d/oracle.conf

    # Update values for oracle user
    echo "oracle soft stack" "$stack_size" | sudo tee -a /etc/security/limits.d/oracle.conf
    echo "oracle hard stack" "$stack_size" | sudo tee -a /etc/security/limits.d/oracle.conf
    echo "oracle soft memlock" "$memlock" | sudo tee -a /etc/security/limits.d/oracle.conf
    echo "oracle hard memlock" "$memlock" | sudo tee -a /etc/security/limits.d/oracle.conf
    echo "oracle soft nofile" "$nofile" | sudo tee -a /etc/security/limits.d/oracle.conf
    echo "oracle hard nofile" "$nofile" | sudo tee -a /etc/security/limits.d/oracle.conf
    echo "oracle soft nproc" "$nproc" | sudo tee -a /etc/security/limits.d/oracle.conf
    echo "oracle hard nproc" "$nproc" | sudo tee -a /etc/security/limits.d/oracle.conf

    echo "Configuration updated in $ORACLE_CONF successful"
else
    echo "No changes were made."
fi


