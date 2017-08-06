#!/bin/bash

#Details of the cpanel you are getting the backup from
IP="127.0.0.1"
DOMAIN="example.com"
USER="example"
PASS='password'
DBarray=( example_wordpress example_wordpress2 ) #This is the full databasename/s
DBUserArray=( example_wpuser example_wpuser2 ) #This is the username of the database/s. It is used for the purpose of creating the user on the cpanel you are moving to.
DBPassArray=( Password123 Password123 ) #This is the password of the database/s.
#Details of the cpanel you are moveing to
CURRENT_CP_PASS='Password123'
CURRENT_CP_IP="172.0.0.2"
CURRENT_CP_USER="example"
CURRENT_CP_DOMAIN="example.com"


#Do not edit below

echo -e "\n\n######################################################################\nCpanel Backup Script By Nikola Sepentulevski\n######################################################################"

BACKUP_DIR="backup"
mkdir -p $BACKUP_DIR
cd $BACKUP_DIR
FECHA=`date +%-m-%-d-%Y`

##Attempting to log into cpanel where the backups are taken from

echo -e "\n\nAttempting log in to ${DOMAIN}"

REDIRECT=`curl  -f -o /dev/null  -w "%{redirect_url}" --insecure -c cookies.txt -d "user=${USER}&pass=${PASS}" https://${IP}:2083/login/`
CPSESS=`echo ${REDIRECT} | sed 's/.*\(cpsess[0-9]*\).*/\1/'`

if [ ${CPSESS} == '' ] &  [ "$?" -gt "0" ]; then
    echo -e "\n\n######################################################################\n   \e[31mFAILED: Could not log into ${DOMAIN} "@" ${IP} \e[39m\n######################################################################"
exit
else
##Getting the database backups
    echo -e "\n\n######################################################################\n \e[32mSUCCESS: Logged in to ${DOMAIN} "@" ${IP}, downloading backups\e[39m\n######################################################################"

for element in $(seq 0 $((${#DBarray[@]} - 1)))
do
        echo -e "\n\nAttempting to download database: ${DBarray[$element]}..."

        curl --silent -f -O -b cookies.txt --insecure https://${USER}:${PASS}@${IP}:2083/${CPSESS}/getsqlbackup/${DBarray[$element]}.sql.gz
        if [ "$?" -gt "0" ]; then
                echo -e "\n\n######################################################################\n\e[31mFAILED: downloading database: ${DBarray[$element]} \e[39m\n######################################################################"
        else
                echo -e "\n\n######################################################################\n\e[32mSUCCESS: downloading database: ${DBarray[$element]}\e[39m\n######################################################################"
        fi
done


        # #Download root folder backup
        echo -e "\n\nAttempting to download ${DOMAIN} "@" ${IP} backup..."
        curl  -f -O -b cookies.txt --insecure https://${IP}:2083/${CPSESS}/getbackup/backup-${DOMAIN}-${FECHA}.tar.gz
        if [ "$?" -gt "0" ]; then
            echo -e "\n\n######################################################################\n\e[31mFAILED: downloading ${DOMAIN} "@" ${IP} backup\e[39m\n######################################################################"
            exit 3;
        else
            echo -e "\n\n######################################################################\n\e[32mSUCCESS: downloading ${DOMAIN} "@" ${IP} backup\e[39m\n######################################################################\n"
        fi

        # # Cleanup login cookies
        rm -f cookies.txt
fi



#      UNCOMPRESS HOMEDIR

FILENAME="backup-${DOMAIN}-${FECHA}.tar.gz"

echo -e "\n\n######################################################################\nStarting to uncompress ${FILENAME}\n######################################################################"


tar -zxvf  $FILENAME -C .. > /dev/null 2>&1

if [ "$?" -gt "0" ]; then
        echo -e "\n\n######################################################################\n\e[31mFAILED: Uncompression of ${FILENAME}\e[39m\n######################################################################"

else
        echo -e "\n\n######################################################################\n\e[32mSUCCESS: Uncompressed ${FILENAME}\e[39m\n######################################################################\n"

fi



##Connect to current Cpanel to upload database
REDIRECT=`curl --silent -f -o /dev/null -w "%{redirect_url}" --insecure -c cookies.txt -d "user=${CURRENT_CP_USER}&pass=${CURRENT_CP_PASS}" https://${CURRENT_CP_IP}:2083/login/` > /dev/null 2>&1
CPSESS=`echo ${REDIRECT} | sed 's/.*\(cpsess[0-9]*\).*/\1/'` > /dev/null 2>&1


if [ $CPSESS == "" ]; then
        echo -e "\n\n######################################################################\n\e[31mFAILED: Connecting to current Cpanel\e[39m\n######################################################################"
exit
else

        ##Looping through databases to uncompress and restore
        for element in $(seq 0 $((${#DBarray[@]} - 1)) &  $((${#DBUserArray[@]} - 1)) &  $((${#DBPassArray[@]} - 1)))
        do
                ##Databae name = ${DBarray[$element]}
                ##Datbase user = ${DBUserArray[$element]}
                ##Dataase Pass = ${DBPassArray[$element]}
                ##Current cpanel user = ${CURRENT_CP_USER}

                echo -e "\n\nAttempting to uncompress  database: ${DBarray[$element]}..."
                gzip -d ${DBarray[$element]}.sql.gz

                if  [ "$?" -gt "0" ]; then
                        echo -e "\n\n######################################################################\n\e[31mFAILED: Uncompression of  ${DBarray[$element]}.sql.gz\e[39m\n######################################################################"
                else
                        echo -e "\n\n######################################################################\n\e[32mSUCCESS: Uncompressed ${DBarray[$element]}\e[39m\n######################################################################\n"
                fi


                ##Creating Database
                echo -e "CREATING DATABASE.........\n"
                curl -b cookies.txt  --insecure "https://${CURRENT_CP_IP}:2083/${CPSESS}/json-api/cpanel?user=${CURRENT_CP_USER}&cpanel_jsonapi_module=Mysql&cpanel_jsonapi_func=adddb&cpanel_jsonapi_apiversion=1&arg-0=${CURRENT_CP_USER}_${DBarray[$element]}" > /dev/null 2>&1
                echo -e "\n\n######################################################################\n\e[32mSUCCESS: Created Database ${CURRENT_CP_USER}_${DBarray[$element]}\e[39m\n######################################################################\n"

                #Creating user for database
                curl -b cookies.txt  --insecure "https://${CURRENT_CP_IP}:2083/${CPSESS}/json-api/cpanel?user=${CURRENT_CP_USER}&cpanel_jsonapi_module=Mysql&cpanel_jsonapi_func=adduser&cpanel_jsonapi_apiversion=1&arg-0=${CURRENT_CP_USER}_${DBUserArray[$element]}&arg-1=${DBPassArray[$element]}" > /dev/null 2>&1

                 echo -e "\n\n######################################################################\n\e[32mSUCCESS: Created User ${CURRENT_CP_USER}_${DBUserArray[$element]}\e[39m\n######################################################################\n"

                ##Assing User To Database
                echo -e  "ADDING USER TO DATABASE AND GRANTING ALL PERMISSIONS \n"
                curl -b cookies.txt  --insecure "https://${CURRENT_CP_IP}:2083/${CPSESS}/json-api/cpanel?user=${CURRENT_CP_USER}&cpanel_jsonapi_module=Mysql&cpanel_jsonapi_func=adduserdb&cpanel_jsonapi_apiversion=1&arg-0=${CURRENT_CP_USER}_${DBarray[$element]}&arg-1=${CURRENT_CP_USER}_${DBUserArray[$element]}&arg-2=all" > /dev/null 2>&1
                        echo -e "\n\n######################################################################\n\e[32mSUCCESS: Assigned user  ${CURRENT_CP_USER}_${DBUserArray[$element]} To Database ${CURRENT_CP_USER}_${DBarray[$element]}\e[39m\n######################################################################\n"

                echo -e "Restoring Database  ${DBarray[$element]}.sql.gz to ${CURRENT_CP_USER}_${DBarray[$element]}"

                ##Restore Databae Backup
                mysql -u ${CURRENT_CP_USER}_${DBUserArray[$element]} -h localhost -p"${DBPassArray[$element]}" ${CURRENT_CP_USER}_${DBarray[$element]} <  ${DBarray[$element]}.sql
                echo -e "\n\n######################################################################\n\e[32mSUCCESS: Database Restored\e[39m\n######################################################################\n"

        done
fi

##Cleaning cookies
rm -f cookies.txt

##Change Database Connection Strings
for element in $(seq 0 $((${#DBarray[@]} - 1)))
do
        echo "The database connection strings for ${DBarray[$element]} can be found in the following files"
        grep -wrl "${DBarray[$element]}" .
        echo -e "\n\n"

done

