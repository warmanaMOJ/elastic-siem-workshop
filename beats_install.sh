#!/bin/bash                                                                                                                                                                                                                              
CONFIG_REPOSITORY_URL="https://raw.githubusercontent.com/mrebeschini/elastic-siem-workshop/master/" 

echo "Elastic Beats Installer"
echo "-----------------------"

if [[ $EUID -ne 0 ]]; then
   echo "Error: this script must be run as root." 
   exit 1
fi

echo "Enter your Elastic Cloud CLOUD_ID then press [ENTER]"
read CLOUD_ID
if [ -z "$CLOUD_ID" ]; then
    echo "Error: CLOUD_ID must be set to a non-empty value!"
    exit 1
fi
echo -e "Your CLOUD_ID is set to $CLOUD_ID\n"
echo "Enter you Elastic Cloud 'elastic' user password and then press [ENTER]"
read CLOUD_AUTH
if [ -z "$CLOUD_AUTH" ]; then
    echo "Error: CLOUD_AUTH must be set to a non-empty value!"
    exit 1
fi
echo -e "Your 'elastic' user password is set to $CLOUD_AUTH\n"
echo "Ready to Install? [y|n]"
read CONTINUE
case "$CONTINUE" in
 [Yy]) echo "Elastic Beats Installation Initiated";;
    *) echo "Installation aborted";exit;;
esac

echo -e "\nDownloading Elastic yum repo configuration..."
rpm --import https://packages.elastic.co/GPG-KEY-elasticsearch
wget -q -N $CONFIG_REPOSITORY_URL/elastic-7.x.repo -P /etc/yum.repos.d/

function install_beat() {
    BEAT_NAME=$1
    if [ $BEAT_NAME == "heartbeat" ]; then
        BEAT_PKG_NAME="heartbeat-elastic" 
    else
        BEAT_PKG_NAME=$BEAT_NAME
    fi 

    yum -q list installed $BEAT_NAME &> /dev/null
    if [ $? > 0 ]; then 
        echo "$BEAT_NAME was previously installed. Uninstalling first..."
        yum -y -q remove $BEAT_PKG_NAME 2>1 /dev/null
        rm -Rf /etc/$BEAT_NAME /var/lib/$BEAT_NAME /var/log/$BEAT_NAME
    fi

    echo -e "\n*** Installing $BEAT_NAME ****";
    yum -y install $BEAT_PKG_NAME
    echo "Downloading $BEAT_NAME config file..."
    wget -q -N $CONFIG_REPOSITORY_URL/$BEAT_NAME.yml -P /etc/$BEAT_NAME
    chmod go-w /etc/$BEAT_NAME/$BEAT_NAME.yml
    echo "Setting up $BEAT_NAME keystore with Elastic Cloud credentials"
    $BEAT_NAME keystore create --force
    echo $CLOUD_ID | $BEAT_NAME keystore add CLOUD_ID --stdin --force
    echo $CLOUD_AUTH | $BEAT_NAME keystore add --stdin CLOUD_AUTH --force
    
    case $BEAT_NAME in
        auditbeat)
            wget -q -N $CONFIG_REPOSITORY_URL/auditd-attack.rules.conf -P /etc/auditbeat/audit.rules.d
            echo "Stopping auditd deamon"
            service auditd stop > /dev/null
            chkconfig auditd off
            ;;
        filebeat)
            $beatname modules enable system
            ;;
    esac

    echo "Setting up $BEAT_NAME"
    $BEAT_NAME setup
    systemctl start $BEAT_NAME
    chkconfig --add $BEAT_NAME
    $BEAT_NAME test output
    echo -e "$BEAT_NAME setup complete"
}

install_beat "auditbeat"
install_beat "packetbeat"
install_beat "metricbeat"
install_beat "filebeat"
install_beat "heartbeat"

echo -e "\n\nSetup complete"
