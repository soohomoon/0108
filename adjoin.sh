#!/bin/bash
set -x
#  This script is used by systemd /usr/lib/systemd/system/centrifydc-adjoin.service

#. /etc/centrifydc/scripts/common.sh
#detect_os
# this function is copied from centrifydc.sh, use to setup hostname when start a stopped ec2 instance.
function generate_hostname()
{
    host_name=
    CENTRIFYDC_HOSTNAME_FORMAT=${CENTRIFYDC_HOSTNAME_FORMAT:-EXISTING}
    case "$CENTRIFYDC_HOSTNAME_FORMAT" in
    PRIVATE_IP)
        private_ip=`curl --fail -s http://169.254.169.254/latest/meta-data/local-ipv4`
        host_name="`echo $private_ip | sed -n 's/\./-/gp'`"
        ;;
    INSTANCE_ID)
        instance_id=`curl --fail -s http://169.254.169.254/latest/meta-data/instance-id`
        host_name=$instance_id
        ;;
    EXISTING)
        #host_name=${HOSTNAME%%.*}
        existing_hostname=`hostname`
        host_name="`echo $existing_hostname | cut -d. -f1`"
        ;;
    "")
        :
        ;;
    *)
        echo "$CENTRIFY_MSG_PREX: invalid hostname format: $CENTRIFYDC_HOSTNAME_FORMAT" && return 1
        ;;
    esac
    if [ "$host_name" = "" ];then
        echo "$CENTRIFY_MSG_PREX: cannot set host_name, an internal error happened!" && return 1
    fi
    # Why only 15? comment it out for now
    #if [ ${#host_name} -gt 15 ];then
        # Only leave the start 15 chars.
    #    host_name=`echo $host_name | sed -n 's/^\(.\{15,15\}\).*$/\1/p'`
    #fi
    echo "$host_name" | grep -E "[\._]" >/dev/null && host_name=`echo $host_name | sed -n 's/[\._]/-/gp'`
    # Setup hostname
    case "$OS_NAME" in
    rhel|amzn|centos)
     #   sed -i '/HOSTNAME=/d' /etc/sysconfig/network
      #  echo "HOSTNAME=$host_name" > /etc/sysconfig/network
        ;;
    *)
       # echo "$host_name" >/etc/hostname 
        ;;
    esac
    #hostname $host_name
    # Fix the bug that sudo cmd always complains 'sudo: unable to resolve host' on ubuntu.
    # Actually it is AWS who shall fix the bug.
    [ "$OS_NAME" = "ubuntu" ] && echo "127.0.0.1 $host_name" >> /etc/hosts
    return 0
}

function do_adedit()
{
    if [ -f /etc/centrifydc/centrifydc-adedit ];then
        existing_hostname=`hostname`
        host_name="`echo $existing_hostname | cut -d. -f1`"
        /etc/centrifydc/centrifydc-adedit $host_name
        r=$?
        [ $r -ne 0 ] && echo "$CENTRIFY_MSG_PREX: adedit script failed" && return 1
    fi
}

function vault()
{
	    
	VAULTED_ACCOUNTS=local-manager,local-user
	LOGIN_ROLES="System Administrator"
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
	   PASS=`openssl rand -base64 20`
	   if id -u $account > /dev/null 2>&1; then
	      echo $PASS | passwd --stdin $account
	   else
	      useradd -m $account -g sys
	      echo $PASS | passwd --stdin $account
	   fi
	   IFS=
	   echo "Vaulting password for $account" >> /tmp/vaultaccount.log 2>&1
	   echo $PASS | /usr/sbin/csetaccount -V --stdin -m true ${Permissions[@]} $account >> /tmp/vaultaccount.log 2>&1
	done
	IFS=$Field_Separator

}


# Comment this out since it doesn't make much sense to generate hostname during reboot
#generate_hostname

#r=$? && [ $r -ne 0 ] && exit $r

# leave the system from the domain if joined
/usr/sbin/adleave -r && sleep 3 || true

private_ip=`curl --fail -s http://169.254.169.254/latest/meta-data/local-ipv4`
host_name="`echo $private_ip | sed -n 's/\./-/gp'`"
#vault
/usr/sbin/adjoin $DOMAIN -z "$ZONE" --name "$host_name" -E /var/prestage_cache $ADDITIONAL_OPS

#cedit --set cli.hook.cenroll:/tmp/auto_centrify_deployment/centrifycc/vaultaccount.sh
#source /tmp/auto_centrify_deployment/centrifycc/vaultaccount.sh


#do_adedit
