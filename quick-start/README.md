# QICK quick-start guide 

***Have questions? Contact: sarafs@princeton.edu***

This guide will show you how to setup QICK after configuring your computer and RFSOC ZCU111 board on a local area network (LAN). By the end of this guide you will have run a QICK program in loopback mode (where signals loop back from an RF DAC directly into an RF ADC)! 

### Prerequisites
* A ZCU111 RFSOC evaluation board kit (available for purchase at www.avnet.com). In this guide you will connect the ZCU111 evaluation board to either the XM500 breakout board which comes with the ZCU111 evaluation board kit or the QICK RF board which was custom-designed at Fermilab. The kit includes:
  * A ZCU111 evaluation board
  * A XM500 breakout board
  * An SMA cable that you will use to connect the system in loopback mode
  * A power cable (12 volt, 50 watt) for the ZCU111
  * A micro SD card (16 GB) that you will flash the PYNQ 2.6.0 disk image onto
* A personal computer with an Ethernet port (this guide assumes a Windows PC with no command line interface so as to be accessible to users with little command line programming experience; contact sarafs@princeton.edu if you would like this guide to include support for other operating systems). 
  * The computer should have git installed. In this guide, Github Desktop is used. 
    * You can download Github Desktop here: https://desktop.github.com/
  * The computer should have either SSH or PuTTY/PSCP installed. PuTTY is an open-source SSH client for the Windows operating system. This guide uses PuTTY/PSCP for accessibility, as some users are not familiar with the command line. 
    * You can download PuTTY here: https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html (for instance `putty-64bit-0.76-installer.msi`). You can also download the PSCP executable from the same link (for instance `pscp.exe`). 
  * The computer should have the Win32DiskImager utility from the Sourceforge Project page installed. The Win32DiskImager utility is an open-source tool for writing image files to disks. You will use this utility to flash the PYNQ 2.6.0 image onto your micro SD card. 
    * You can download the Win32DiskImager utility here: https://sourceforge.net/projects/win32diskimager/
* A router (this guide used a standard Cisco RV160 VPN Router which is available for purchase at www.amazon.com). The router used in this guide has 4 LAN ports. For instance, in a typical qubit system setup you can connect one LAN port to your personal computer, a second LAN port to your ZCU111, and a third point to an Ethernet switch (for example the NETGEAR 24-Port Gigabit Ethernet Unmanaged Switch (JGS524) which is available for purchase at www.amazon.com). That Ethernet switch can place 24 more devices (such as external trigger sources, local oscillators, programmable attenuators or other lab equipment) on the router's subnet, making them accessible to your personal computer. 
* Two Ethernet cables that you will use to attach 1) your ZCU111 board and 2) your personal computer to the router.
* A micro SD card reader (such as IOGEAR SuperSpeed USB 3.0 SD/Micro SD Card Reader/Writer (GFR304SD) which is available for purchase at www.amazon.com). 

### Flashing the PYNQ 2.6.0 image onto your micro SD card
* Your ZCU111 RFSOC evaluation board kit comes with a micro SD card that is preloaded with a PYNQ image. The QICK hardware requires PYNQ 2.6.0, so let's update the micro SD card with this version of the PYNQ image. 
* First, download the PYNQ 2.6.0 image from this URL: http://www.pynq.io/board.html under the ZCU111 row: You will see that it's quite a large file of 6.86 GB. 

<p align="center">
 <img src="quick-start-guide-pics/largeimagefile.PNG" alt="The PYNQ 2.6.0 image file">
</p>

* Plug in your micro SD card to your personal computer via your micro SD card reader. If you look in the Windows File Explorer you will see a new disk drive pop up, for example in my case it was the `E:\` drive. This is the drive associated with your micro SD card. 
* Now, open the Win32DiskImager utility and configure 1) the image file to be your PYNQ 2.6.0 image file and 2) the device to be the `E:\` drive, as in the below picture. Before clicking `Write`, double check that you are not flashing the image file to the wrong drive (e.g. your personal computer hard drive)!

<p align="center">
 <img src="quick-start-guide-pics/writetoEdrive.PNG" alt="Writing the PYNQ 2.6.0 image onto the micro SD card">
</p>

* Click `Write`.  
* After the write completes, now look in the Windows File Explorer to see what is now contained in the `E:\` drive. You can see several files. `BOOT.BIN` allows the RFSOC to boot and includes the firmware design. `image.ub` stores the Linux kernel. There is also a Python file and an executable. The contents of the `E:\` drive are lightweight and there is plenty more space on the disk (about 6.8 GB!). So we are now ready to load this micro SD card into the ZCU111 board. 

<p align="center">
 <img src="quick-start-guide-pics/Eafterwrite.PNG" alt="The micro SD card drive after a successful write">
</p>


### Assembling and powering on your ZCU111 board
* 
* Connect a RF DAC channel (e.g.  to an RF ADC channel to be used in the QICK loopback test. To replicate the demo

<p align="center">
 <img src="quick-start-guide-pics/boardpic_cartoon.PNG" alt="An assembled ZCU111 board">
</p>

### Finding your RFSOC on the router's network
* Power on your 
* Connect your personal computer via Ethernet to a LAN port of the router
* Connect your ZCU111 evaluation board via Ethernet to another LAN 

<p align="center">
 <img src="quick-start-guide-pics/ciscorouter.PNG" alt="Devices found by the router">
</p>


### Connecting to your RFSOC via Jupyter and via SSH

#### Via Jupyter

<p align="center">
 <img src="quick-start-guide-pics/pynqstartup.PNG" alt="PYNQ startup">
</p>

#### Via SSH

<p align="center">
 <img src="quick-start-guide-pics/putty1.PNG" alt="Using PuTTY (1)">
</p>

<p align="center">
 <img src="quick-start-guide-pics/putty2.PNG" alt="Using PuTTY (2)">
</p>

<p align="center">
 <img src="quick-start-guide-pics/putty3.PNG" alt="Using PuTTY (3)">
</p>

### Moving the QICK tools onto your RFSOC's processor

<p align="center">
 <img src="quick-start-guide-pics/pscpfolderstructure.PNG" alt="Folder structure required for PSCP">
</p>

<p align="center">
 <img src="quick-start-guide-pics/pushingdatatotheboard.PNG" alt="Pushing data to the RFSOC with PSCP">
</p>

### Running a QICK program in loopback mode

<p align="center">
 <img src="quick-start-guide-pics/jupyternotebook1.PNG" alt="Jupyter notebook main folder">
</p>

<p align="center">
 <img src="quick-start-guide-pics/jupyternotebook2.PNG" alt="Jupyter notebook demo folder">
</p>

<p align="center">
 <img src="quick-start-guide-pics/correctpynqversion.PNG" alt="The correct PYNQ version">
</p>

### Moving data off of your RFSOC's processor onto your personal computer

<p align="center">
 <img src="quick-start-guide-pics/pullingdataofftheboard.PNG" alt="Pulling data off the RFSOC with PSCP">
</p>
