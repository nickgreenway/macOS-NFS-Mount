# Automating NFS Share Mount on macOS

You can use a shell script combined with `launchd` to automate the entire process, including creating the mount point (if necessary) and running the mount command. This approach is flexible and avoids relying on `/etc/fstab`, which macOS doesn't fully support in all cases.

---

## 1. Create the Shell Script

1. Open a text editor to create the script:

   ```bash
   sudo nano /usr/local/bin/mount_europa.sh
   ```

2. Add the following script:

   ```bash
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
       mount -t nfs -o rw,noowners,nolock,hard,intr,proto=tcp,rsize=32768,wsize=32768,nfsvers=3 "$NFS_SERVER" "$MOUNT_POINT"
   fi
   ```

3. Save and exit (`CTRL + O`, then `CTRL + X`).

4. Make the script executable:

   ```bash
   sudo chmod +x /usr/local/bin/mount_europa.sh
   ```

---

## 2. Create a `launchd` Job

1. Create the `launchd` plist file:

   ```bash
   sudo nano /Library/LaunchDaemons/com.nickgreenway.mount_europa.plist
   ```

2. Add the following content to the plist file:

   ```xml
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
   ```

3. Save and exit (`CTRL + O`, then `CTRL + X`).

4. Set the correct permissions for the plist:

   ```bash
   sudo chmod 644 /Library/LaunchDaemons/com.nickgreenway.mount_europa.plist
   ```

5. Load the `launchd` job:

   ```bash
   sudo launchctl load /Library/LaunchDaemons/com.nickgreenway.mount_europa.plist
   ```

---

## 3. Test the Setup

1. Unmount the share if it's already mounted:

   ```bash
   sudo umount /Volumes/Europa
   ```

2. Trigger the `launchd` job manually:

   ```bash
   sudo launchctl start com.nickgreenway.mount_europa
   ```

3. Verify the mount:

   ```bash
   mount | grep Europa
   ```

---

## 4. Reboot and Verify

Reboot your Mac and confirm that the NFS share mounts automatically:

```bash
sudo reboot
```

After the system starts, check if the share is mounted:

```bash
mount | grep Europa
```

---

This method ensures the NFS share is mounted at startup without manual intervention. Let me know if you need any further help!
