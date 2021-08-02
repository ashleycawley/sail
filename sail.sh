#!/bin/bash

# A user friendly interface to a wget mirror with safety checking around file counts
# to see if .listing files match or exceed 5k, 10k etc.

# Colours
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Check user is root
if [ `whoami` != "root" ]
then
    echo "You are not root."
    exit 1
fi

# Check that wget is installed
type wget &>/dev/null
if [ "$?" != "0" ]
then
    echo "wget is not installed. Please install and try again."
    exit 2
fi

### Whiptail Menus Start ###

### Server IP
read -p "IP Address or Hostname of Source FTP Server: " SERVER_IP
# SERVER_IP=$(whiptail --inputbox "IP Address of the Source FTP Server:" 8 50 --title "Source IP" 3>&1 1>&2 2>&3)
#                                                                         # A trick to swap stdout and stderr.
# # Again, you can pack this inside if, but it seems really long for some 80-col terminal users.
# exitstatus=$?
# if [ $exitstatus = 0 ]; then
#     echo "Server: $SERVER_IP"
# else
#     exit 1
# fi

### FTP Username
read -p "FTP Username: " USERNAME
# USERNAME=$(whiptail --inputbox "FTP Username:" 8 50 --title "Username" 3>&1 1>&2 2>&3)
#                                                                         # A trick to swap stdout and stderr.
# # Again, you can pack this inside if, but it seems really long for some 80-col terminal users.
# exitstatus=$?
# if [ $exitstatus = 0 ]; then
#     echo "Username: $USERNAME"
# else
#     exit 1
# fi


### FTP Password
read -p "FTP Password: " PASSWORD
# PASSWORD=$(whiptail --passwordbox "FTP Password:" 8 50 --title "FTP Password" 3>&1 1>&2 2>&3)
#                                                                         # A trick to swap stdout and stderr.
# # Again, you can pack this inside if, but it seems really long for some 80-col terminal users.
# exitstatus=$?
# if [ $exitstatus == 0 ]; then
#     echo "Password: <hidden>"
# else
#     exit 1
# fi

### FTP Destination
read -p "Destination Full Path: (ie. /home/user/public_html ): " DESTINATION_PATH
# DESTINATION_PATH=$(whiptail --inputbox "Destination Full Path:" 8 50 --title "Destination" 3>&1 1>&2 2>&3)
#                                                                         # A trick to swap stdout and stderr.
# # Again, you can pack this inside if, but it seems really long for some 80-col terminal users.
# exitstatus=$?
# if [ $exitstatus = 0 ]; then
#     echo "Username: $DESTINATION_PATH"
# else
#     exit 1
# fi

### Whiptail Menus End ###

# If the supplied destination does not exist then create it
if [ ! -d "$DESTINATION_PATH" ]
then
    mkdir -p $DESTINATION_PATH
fi

# Test to see if the path contains a username /home/USER/* and extracts username for later chown
echo "$DESTINATION_PATH" | grep "/home/*" &>/dev/null
HOME_AND_USER_STATUS=$(echo $?)
if [ "$HOME_AND_USER_STATUS" == "0" ]
then
    OWNER=$(echo "$DESTINATION_PATH" | awk -F '/' '{print $3}')
fi

# WGET Command

echo
echo "Please be patient, FTP can be slow and your transfer could be large." && echo
echo "Remember: If you're handling large transfers it would be beneficial to do it within a session manager like tmux or screen."
echo
echo "Transferring files now..." && echo


wget --quiet -m -nH -P $DESTINATION_PATH --user=$USERNAME --password="$PASSWORD" ftp://$SERVER_IP/
WGET_STATUS=$(echo $?)

# Catching wget errors and exiting
if [ "$WGET_STATUS" != "0" ]
then
    echo "An error was encountered with wget, the exit code it gave was: $WGET_STATUS"
    exit 3
fi

# Successful wget run - process continuing...
if [ "$WGET_STATUS" == "0" ]
then
    echo "Congratulations, the wget mirror completed with exit code 0 (OK)." && echo
    echo "Now lets check to see if we encountered the 10k file limit some FTP Servers can have:" && echo
    sleep 3 && echo "Scanning files..." && echo

    # Loop that checks all .listing files generated by WGET Mirror to check none = 5000, 10000 or exceed 10k
    ARRAY_OF_DOT_LISTING_FILES=$(find $DESTINATION_PATH -type f -name ".listing" | sed ':a;N;$!ba;s/\n/ /g')
    for LISTING in $ARRAY_OF_DOT_LISTING_FILES
    do
        NUMBER_OF_FILES=$(cat $LISTING 2>/dev/null | wc -l)
        if [ "$NUMBER_OF_FILES" -gt "9999" ]
        then
            echo -e "${YELLOW}!! WARNING !!${NC}"
            echo -e "${YELLOW} $LISTING ${NC}"
            echo -e "${YELLOW} ... Exceeds 10,000 files!${NC}"
            echo
            echo -e "${YELLOW}Some FTP Servers do not allow you to retrieve a list of more than 10,000 files${NC}"
            echo -e "${YELLOW}Take note of that file / path and when this transfer is done inspect it with:${NC}"
            echo -e "${YELLOW}cat $LISTING | wc -l${NC}"
            echo -e "${YELLOW}To see how many lines or files it was able to list, if it is clearly in excess of the${NC}"
            echo -e "${YELLOW}10K threshold then it may be OK and a sign that the the source FTP Server was capable of${NC}"
            echo -e "${YELLOW}Listing folders which contained in exccess of 10K files in them, *BUT* if you see bang on${NC}"
            echo -e "${YELLOW}10000 then that is likely a sign that not all data was transferred successfully and other${NC}"
            echo -e "${YELLOW}transfer methods should be sought from that server that ** DO NOT involve FTP **${NC}"
            echo
            read -p "Press [Enter] to continue this migration || Or [CTRL] + C to cancel it ..."
        fi

        NUMBER_OF_FILES=$(cat $LISTING 2>/dev/null | wc -l)
        if [ "$NUMBER_OF_FILES" == "5000" ]
        then
            echo -e "${YELLOW}!! WARNING !!${NC}"
            echo -e "${YELLOW} $LISTING ${NC}"
            echo -e "${YELLOW} Contains a list of precisely 5,000 files files which looks suspicious to me${NC}"
            echo -e "${YELLOW} and is probably a sign that the source FTP Server is restricting the number of indexable${NC}"
            echo -e "${YELLOW} files to 5,000. Inspect the directory on both source and destination servers.${NC}"

            echo
            read -p "Press [Enter] to continue this migration || Or [CTRL] + C to cancel it ..."
        fi

        NUMBER_OF_FILES=$(cat $LISTING 2>/dev/null | wc -l)
        if [ "$NUMBER_OF_FILES" == "10000" ]
        then
            echo -e "${YELLOW}!! WARNING !!${NC}"
            echo -e "${YELLOW} $LISTING ${NC}"
            echo -e "${YELLOW} Contains a list of precisely 10,000 files files which looks suspicious${NC}"
            echo -e "${YELLOW} And is probably a sign that the source FTP Server is restricting the number of indexable${NC}"
            echo -e "${YELLOW} files to 10,000. Inspect the directory on both source and destination servers.${NC}"

            echo
            read -p "Press [Enter] to continue this migration || Or [CTRL] + C to cancel it ..."
        fi

    done

    echo -e "Transfer completed without error. Data Transferred: \c" && du -sh $DESTINATION_PATH
    
    echo "View of the Destination folder:"
    ls -lah $DESTINATION_PATH && echo

    sleep 2

    echo "Currently the files are owned by `whoami`" && sleep 3
    echo "Would you like me to update them so they're owned by $OWNER instead?" && sleep 3
    echo "If you would like I can run:" && sleep 1 && echo

    echo "chown -R $OWNER:$OWNER $DESTINATION_PATH" && echo && sleep 1

    read -p "Would you like to chown?  y/n : " CHOWNA

    if [ "$CHOWNA" == "y" ] || [ "$CHOWNA" == "yes" ]
    then
        chown -R $OWNER:$OWNER $DESTINATION_PATH
        echo && echo "chown complete."
    else
        echo && echo "No chown was performed."
    fi

fi

exit 0