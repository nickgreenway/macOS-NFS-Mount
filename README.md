Yes, you can use a shell script combined with launchd to automate the entire process, including creating the mount point (if necessary) and running the mount command. This approach is flexible and avoids relying on /etc/fstab, which macOS doesnt fully support in all cases.

1. Create the Shell Script
	1.	Open a text editor to create the script:

sudo nano /usr/local/bin/mount_europa.sh


	2.	Add the following script:

#!/bin/bash

# Mount point
MOUNT_POINT="/Volumes/Europa"
NFS_SERVER="10.0.0.4:/volume1/Europa"

# Check if the mount point exists; create it if not
if [ ! -d "$MOUNT_POINT" ]; then
    mkdir -p "$MOUNT_POINT"
fi

# Check if already mounted; if not, mount the NFS share
if ! mount | grep -q "$MOUNT_POINT"; then
    mount -t nfs -o rw,hard,intr,proto=tcp,rsize=65536,wsize=65536,nfsvers=4 "$NFS_SERVER" "$MOUNT_POINT"
fi


	3.	Save and exit (CTRL + O, then CTRL + X).
	4.	Make the script executable:

sudo chmod +x /usr/local/bin/mount_europa.sh

2. Create a launchd Job
	1.	Create the launchd plist file:

sudo nano /Library/LaunchDaemons/com.nickgreenway.mount_europa.plist


	2.	Add the following content to the plist file:

<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.nickgreenway.mount_europa</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/mount_europa.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
</dict>
</plist>


	3.	Save and exit (CTRL + O, then CTRL + X).
	4.	Set the correct permissions for the plist:

sudo chmod 644 /Library/LaunchDaemons/com.nickgreenway.mount_europa.plist


	5.	Load the launchd job:

sudo launchctl load /Library/LaunchDaemons/com.nickgreenway.mount_europa.plist

3. Test the Setup
	1.	Unmount the share if its already mounted:

sudo umount /Volumes/Europa


	2.	Trigger the launchd job manually:

sudo launchctl start com.nickgreenway.mount_europa


	3.	Verify the mount:

mount | grep Europa

4. Reboot and Verify

Reboot your Mac and confirm that the NFS share mounts automatically:

sudo reboot

After the system starts, check if the share is mounted:

mount | grep Europa

This method ensures the NFS share is mounted at startup without manual intervention. Let me know if you need any further help!
