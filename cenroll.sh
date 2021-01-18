#!/bin/bash

#  This script is used by systemd /usr/lib/systemd/system/centrifycc-enroll.service

function prepare_for_cenroll()
{
    r=1
    NETWORK_ADDR_TYPE=${NETWORK_ADDR_TYPE:-PublicIP}
    case "$NETWORK_ADDR_TYPE" in
    PublicIP)
        CENTRIFYCC_NETWORK_ADDR=`curl --fail -s http://169.254.169.254/latest/meta-data/public-ipv4`
        r=$?
        ;; 
    PrivateIP)
        CENTRIFYCC_NETWORK_ADDR=`curl --fail -s http://169.254.169.254/latest/meta-data/local-ipv4`
        r=$?
        ;;
    HostName)
        CENTRIFYCC_NETWORK_ADDR=`hostname --fqdn`
		if [ "$CENTRIFYCC_NETWORK_ADDR" = "" ] ; then
			CENTRIFYCC_NETWORK_ADDR=`hostname`
		fi
        r=$?
        ;;
    esac
    if [ $r -ne 0 ];then
        return $r
    fi
    return $r
}

function generate_computer_name()
{
    case "$COMPUTER_NAME_FORMAT" in
    HOSTNAME)
        #host_name=`hostname`
        existing_hostname=`hostname`
        host_name="`echo $existing_hostname | cut -d. -f1`"
        if [ "$COMPUTER_NAME_PREFIX" = "" ];then
            COMPUTER_NAME="$host_name"
        else
            COMPUTER_NAME="$COMPUTER_NAME_PREFIX-$host_name"
        fi
        ;;
    INSTANCE_ID)
        instance_id=`curl --fail -s http://169.254.169.254/latest/meta-data/instance-id`
        r=$?
        if [ $r -ne 0 ];then
            echo "$CENTRIFY_MSG_PREX: cannot get instance id" && return $r
        fi
        if [ "$COMPUTER_NAME_PREFIX" = "" ];then
            COMPUTER_NAME="$instance_id"
        else
            COMPUTER_NAME="$COMPUTER_NAME_PREFIX-$instance_id"
        fi
        ;;
    *)
        echo "$CENTRIFY_MSG_PREX: invalid computer name format: $COMPUTER_NAME_FORMAT" && return 1
        ;;
    esac
    return 0
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

prepare_for_cenroll
r=$?
if [ $r -ne 0 ];then
  exit $r
fi

generate_computer_name
r=$?
if [ $r -ne 0 ];then
  exit $r
fi

#CMDPARAMARRAY=($CMDPARAM)
# Need special handling. Simply reading CMDPARAM doesn't work for element with whitespace
IFS="|" read -a CMDPARAMARRAY <<< "$CMDPARAM"

CPARAMS=()
for i in $(echo ${!CMDPARAMARRAY[@]}); do
    VAR=${CMDPARAMARRAY[$i]}
    CPARAMS=("${CPARAMS[@]}" "$VAR")
done

/usr/sbin/cenroll  \
    --tenant "$TENANT_URL" \
    --code "$ENROLLMENT_CODE" \
    --features "$FEATURES" \
    --name "$COMPUTER_NAME" \
    --address "$CENTRIFYCC_NETWORK_ADDR" \
    "${CPARAMS[@]}"
    #"${CMDPARAMARRAY[@]}"
    
    
    vault
