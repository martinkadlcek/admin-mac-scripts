#!/bin/sh
# HARDCODED VALUES ARE SET HERE, NEEDS TO CHANGE BY USER
Pass=""

# CHECK TO SEE IF VALUES WERE PASSED FOR $4, AND IF SO, ASSIGN THEM
if [ "$4" != "" ] && [ "$Pass" == "" ]; then 
Pass=$4
fi

# Check to make sure Pass variable was passed down from Casper
if [ "$Pass" == "" ]; then 
echo "Error: The parameter 'Pass' is blank. Please specify a value." 
exit 1 
fi

##Check if Mac is on the network
if ping -c 2 -o domaincontroller.company.com; then

    if [[ $(dsconfigad -show | awk '/Active Directory Domain/{ print $NF }') == "domaincontroller.company.com" ]]; then
        ADCompName=$(dsconfigad -show | awk '/Computer Account/{ print $NF }')
        ## Mac has correct dsconfigad info

            security find-generic-password -l "/Active Directory/Domain" | grep "Active Directory"
            if [ "$?" == "0" ]; then
                ## AD keychain entry exists

                dscl "/Active Directory/Domain/All Domains" read /Computers/"$ADCompName" | grep -i "$ADCompName"
                if [ "$?" == "0" ]; then
                    ## Found AD entry. Binding is good
                    res="Mac is already bound"
                else
                    res="Not bound"
                fi
            else
                res="Not bound"
            fi
    else
        res="Not bound"        
    fi
    else

        res="Not bound"
fi
    ## Mac is not on the network

echo "<result>$res</result>"

# reset the time from the domain, then force unbind if bound

if [[ $res == "Not bound" ]]; then

    /usr/sbin/systemsetup -setusingnetworktime off
    /usr/sbin/systemsetup -setnetworktimeserver "domaincontroller.company.com"
    /usr/sbin/systemsetup -setusingnetworktime on
    sleep 10

    /usr/sbin/dsconfigad -remove -force -username macimaging -password $4 
    sleep 10
    echo "Unbinding"
    killall opendirectoryd
    sleep 5

## Testing has shown that unbinding twice may be necessary. 
    /usr/sbin/dsconfigad -remove -force -username macimaging -password $4 &> /dev/null
    sleep 10
    echo "Unbinding twice just incase"

## Begin rebinding process

    #Basic variables
    computerid=`scutil --get LocalHostName`
    domain=domaincontroller.company.com
    udn=account
    ou="CN=Computers,DC=DOMAIN,DC=DOMAIN,DC=us"

    #Advanced variables
    alldomains="disable"
    localhome="enable"
    protocol="smb"
    mobile="enable"
    mobileconfirm="disable"
    user_shell="/bin/bash"
    admingroups="CorpHelpdesk"
    namespace="domain"
    packetsign="allow"
    packetencrypt="allow"
    useuncpath="disable"
    passinterval="90"

    # Bind to AD
    /usr/sbin/dsconfigad -add $domain -alldomains $alldomains -username $udn -password $4 -computer $computerid -ou "$ou" -force -packetencrypt $packetencrypt
    sleep 1
    echo "Rebinding to AD and setting advanced options"

    #set advanced options
    /usr/sbin/dsconfigad -localhome $localhome
    sleep 1
    /usr/sbin/dsconfigad -groups "$admingroups"
    sleep 1
    /usr/sbin/dsconfigad -mobile $mobile
    sleep 1
    /usr/sbin/dsconfigad -mobileconfirm $mobileconfirm
    sleep 1
    /usr/sbin/dsconfigad -alldomains $alldomains
    sleep 1
    /usr/sbin/dsconfigad -useuncpath "$useuncpath"
    sleep 1
    /usr/sbin/dsconfigad -protocol $protocol
    sleep 1
    /usr/sbin/dsconfigad -shell $user_shell
    sleep 1
    /usr/sbin/dsconfigad -passinterval $passinterval
    sleep 1

    #dsconfigad adds "All Domains"
    # Set the search paths to "custom"
    dscl /Search -create / SearchPolicy CSPSearchPath
    dscl /Search/Contacts -create / SearchPolicy CSPSearchPath

    sleep 1

    # Add the "XXXXX.us" search paths
    dscl /Search -append / CSPSearchPath "/Active Directory/CORP/domaincontroller.company.com"
    dscl /Search/Contacts -append / CSPSearchPath "/Active Directory/CORP/domaincontroller.company.com"

    sleep 1

    # Delete the "All Domains" search paths
    dscl /Search -delete / CSPSearchPath "/Active Directory/CORP/All Domains"
    dscl /Search/Contacts -delete / CSPSearchPath "/Active Directory/CORP/All Domains"

    sleep 1

    # Restart opendirectoryd
    killall opendirectoryd
    sleep 5
else
    echo "Mac is already bound. Exiting."
fi

exit 0