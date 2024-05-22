#!/bin/bash

# This script relies on an export to QICK_SECURITY_LEVEL - default is '0', but there is another. 
# You can set this with:
# export QICK_SECURITY_LEVEL=0
# They can be summarised as follows:
# * '0' - this is just changing the default password to something long and random, generating a key, and then adding that to authorized keys. 
# * '1' - does everything at level 0, and then proceeds to edit the SSHD config file to prevent root login and prevent password login. 
# With security level 1 you MUST have downloaded the SSH private keyfile 'id_rsa' in order to successfully log back in!

SecurityVar="${QICK_SECURITY_LEVEL:-0}" # default is '0' if QICK_SECURITY_LEVEL isn't set. -MC

sec_lvl_0 () {
    echo "$SecurityVar"
    # reset Password
    pass=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 24;)
    echo "[!] Generated Password: ${pass}"
    # set the new password - but only if it's the bad one. -MC
    echo "[i] Changing 'xilinx' user password..."
    echo -e "xilinx\n$pass\n$pass" | passwd
    if [[ $? -eq 0 ]]; then
        echo "[!] Password Successfully Changed!!"
        echo
        echo
        echo "========= WRITE THIS DOWN! ========="
        echo
        echo "[!] New Password: ${pass}"
        echo
        echo "===== THIS IS YOUR NEW PASSWORD!===="
        echo
        echo
        echo "NB - don't write this down on a whiteboard/post-it! Please use"
        echo "something like a notebook that you keep somewhere safe."
    else
        echo
        echo "[i] Password Not Changed! Ignore the above string."
        echo
    fi
    # GENERATE SSH keys
    if [ ! -f ./id_rsa ]; then
        echo "[i] Generating SSH keys. Private key is in the file 'id_rsa' and"
        echo "    the public key is in 'id_rsa.pub'. You will need 'id_rsa'"
        echo "    locally accessible to access the server with that key."
        ssh-keygen -t rsa -b 4096 -C "Qick server" -f ./id_rsa -N ""
        cat ./id_rsa.pub >> ~/.ssh/authorized_keys
    fi
}

sec_lvl_1 () {
    echo "[i] Editing /etc/ssh/sshd_config, with backup at sshd_config.bak"
    cd /etc/ssh
    sudo cp sshd_config sshd_config.bak
    sudo sed -E -i 's/(#\s*PermitRootLogin.*|PermitRootLogin yes)/PermitRootLogin no/g' sshd_config
    sudo sed -E -i 's/(#\s*PasswordAuthentication.*|PasswordAuthentication yes)/PasswordAuthentication no/g' sshd_config
}

case $SecurityVar in

  "0")
    sec_lvl_0;
    ;;

  "1")
    sec_lvl_0;
    sec_lvl_1;
    ;;

  *)
    echo "Something has gone wrong... You shouldn't be here. Seek help!"
    ;;
esac
