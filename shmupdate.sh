#!/bin/bash
echo "
###############################################################################
### This is automated script to calculate and update the kernel parameters ####
###############################################################################"



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
            echo "Updated GRUB_CMDLINE_LINUX in $grub_config"
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
else
    echo "Invalid input. Please enter a positive number."
fi

