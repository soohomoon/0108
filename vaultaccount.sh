#!/bin/bash
export VAULTED_ACCOUNTS=local-manager,local-user
export LOGIN_ROLES="System Administrator"
echo "post hook script started." >> /var/centrify/tmp/vaultaccount.log
Permissions=()
Field_Separator=$IFS
IFS=","
read -a roles <<< $LOGIN_ROLES
IFS=
for role in ${roles[@]} 
  do 
     Permissions=("${Permissions[@]}" "-p" "\"role:$role:View,Login,Checkout\"" )
done
IFS=","
sleep 10
for account in $VAULTED_ACCOUNTS; do
   export PASS=`openssl rand -base64 20`
   if id -u $account > /dev/null 2>&1; then
      echo $PASS | passwd --stdin $account
   else
      useradd -m $account -g sys
      echo $PASS | passwd --stdin $account
   fi
   IFS=
   echo "Vaulting password for $account" >> /var/centrify/tmp/vaultaccount.log 2>&1
   echo $PASS | /usr/sbin/csetaccount -V --stdin -m true ${Permissions[@]} $account >> /var/centrify/tmp/vaultaccount.log 2>&1
done
IFS=$Field_Separator
