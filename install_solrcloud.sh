#!/bin/bash
set -e

#Variable you can adjust
JAVA_PACKAGE="java-1.7.0-openjdk.x86_64"
HOME_PATH="/u01/solrcloud"
SOLR_PACKAGE="http://mirrors.ukfast.co.uk/sites/ftp.apache.org/lucene/solr/5.2.1/solr-5.2.1.tgz"
ZOOKEEPER_PACKAGE="http://mirrors.ukfast.co.uk/sites/ftp.apache.org/zookeeper/zookeeper-3.4.6/zookeeper-3.4.6.tar.gz"
ZOOKEEPER_PORT=2181

#Server array, add as many as you need
SERVERS_IP[0]="172.20.153.141"
SERVERS_IP[1]="172.20.153.142"
SERVERS_IP[2]="172.20.153.21"

##------------------------------##
##DO NOT TOUCH BEYOND THIS POINT##
##------------------------------##
write_msg () {
   echo -e "--->$1"
}

create_folder () {
	if [ ! -d "$1" ]; then
		write_msg "Creating folder $1"
		mkdir -p $1
	fi
}

echo "Found ${#SERVERS_IP[@]} servers that belong to this collection, please run the script on all of those."
echo "Do you want to continue (y/n)?"
read answ
if [ "${answ,,}" != "y" ]; then
	echo "Exiting....."
	exit
fi

write_msg "Installing basic tools "
yum install $JAVA_PACKAGE wget -y

#Read variables
ZOOK_FILENAME="${ZOOKEEPER_PACKAGE##*/}"
ZOOK_DIR="$HOME_PATH/zookeeper"
SOLR_HOME_PATH="$HOME_PATH/solr"
JAVA_BIN=$(which java)

PACKAGES_FOLDER="$HOME_PATH/packages"
create_folder "$PACKAGES_FOLDER"

write_msg "Checking if installation path exists"
create_folder "$HOME_PATH"


write_msg "Cleaning folders"
rm -rf /tmp/zookeeper*
rm -rf /tmp/solr*

#Check if I have to install Zookeper
if [ ! -d $ZOOK_DIR ]; then

	#Download Zookeper
	write_msg "Checking if $ZOOK_FILENAME package was already downloaded"

	if [ ! -f "$PACKAGES_FOLDER/$ZOOK_FILENAME" ]; then
		write_msg "Downloading Zookeeper file ($ZOOK_FILENAME) to $ZOOK_DIR"
		wget -O $PACKAGES_FOLDER/$ZOOK_FILENAME $ZOOKEEPER_PACKAGE
	fi

	#Extracting Zookeper
	write_msg "Cleaning folders"
	rm -rf $ZOOK_DIR

	write_msg "Extracting Zookeeper"
	tar -C /tmp -zxf $PACKAGES_FOLDER/$ZOOK_FILENAME

	write_msg "Renaming Zookeeper home"
	cp -rf /tmp/zookeeper* $ZOOK_DIR

	write_msg "Creating data folder"
	create_folder "$ZOOK_DIR/data"

fi

write_msg "Copying config file to $ZOOK_DIR/conf"
create_folder "$ZOOK_DIR/conf"
cp zoo.cfg "$ZOOK_DIR/conf"

write_msg "Configuring zoo.cfg"
sed -i -e "s|replace_data_dir|$ZOOK_DIR/data|g" $ZOOK_DIR/conf/zoo.cfg
sed -i -e "s|replace_port|$ZOOKEEPER_PORT|g" $ZOOK_DIR/conf/zoo.cfg

write_msg "Get list of IP"
IP_LIST=$(ifconfig | perl -nle 's/dr:(\S+)/print $1/e')
write_msg "IP addresses found: \n$IP_LIST"

count=1
#Adding servers to config
for i in "${SERVERS_IP[@]}"
do
:
	echo "server.$count=$i:2888:3888" >> $ZOOK_DIR/conf/zoo.cfg

	#Writing myid number based on my ip	
	if [[ "${IP_LIST}" == *"${i}"* ]]; then
	    write_msg "Writing $count to myid file at $ZOOK_DIR/data/myid"
	    echo "$count" > $ZOOK_DIR/data/myid

	    MYIP=$i
	fi

	count=$((count+1))
done

write_msg "Set zookeeper to start at boot"
cp -fr zk.service /etc/init.d/zookeeper
sed -i -e "s|replace_with_zookeeper_dir|$ZOOK_DIR|g" /etc/init.d/zookeeper
chmod +x /etc/init.d/zookeeper
#chkconfig zookeeper on

#Start Zookeeper
write_msg "Restarting Zookeeper"
service zookeeper restart


#Check if I have to install Solr
if [ ! -d $SOLR_HOME_PATH ]; then

	#Download Solr
	SOLR_FILENAME="${SOLR_PACKAGE##*/}"
	write_msg "Checking if $SOLR_FILENAME package was already downloaded"
	if [ ! -f "$PACKAGES_FOLDER/$SOLR_FILENAME" ]; then
		write_msg "Downloading Solr file ($SOLR_FILENAME) to $SOLR_HOME_PATH"
		wget -O $PACKAGES_FOLDER/$SOLR_FILENAME $SOLR_PACKAGE
	fi


	#Extracting Solr
	write_msg "Creating Solr home $SOLR_HOME_PATH"
	create_folder "$SOLR_HOME_PATH"
	write_msg "Extracting Solr"
	tar -C /tmp -zxf $PACKAGES_FOLDER/$SOLR_FILENAME
	write_msg "Moving Solr to home $SOLR_HOME_PATH"
	cp -rf /tmp/solr*/* $SOLR_HOME_PATH/
	write_msg "Removing temp Solr folder"
	rm -rf /tmp/solr*

	#Start Solr
	#write_msg "Restarting Solr"
	#$JAVA_BIN -Dbootstrap_confdir=$SOLR_HOME_PATH/infom_coll/conf -Dcollection.configName=solr1 -DzkHost=$MYIP:2888 -DnumShards=${#SERVERS_IP[@]} -jar $SOLR_HOME_PATH/server/start.jar
	#$SOLR_HOME_PATH/bin/solr start -f -e cloud -z localhost:$ZOOKEEPER_PORT -noprompt

fi

#write_msg "Starting  Solr"
#$SOLR_HOME_PATH/bin/solr stop -all
#$SOLR_HOME_PATH/bin/solr start -c -z $MYIP:$ZOOKEEPER_PORT -noprompt