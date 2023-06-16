# QICK quick-start guide 

***Have questions? Contact: ``sarafs AT princeton.edu``***

This guide will show you how to set up QICK after configuring your computer and RFSOC ZCU111 board on a local area network (LAN). By the end of this guide you will have run a QICK program in loopback mode (where signals loop back from an RF DAC directly into an RF ADC)! 

### Prerequisites
* A ZCU111 RFSOC evaluation board kit (available for purchase at www.avnet.com). In this guide you will connect the ZCU111 evaluation board to either the XM500 breakout board which comes with the ZCU111 evaluation board kit or the QICK RF board which was custom-designed at Fermilab. The kit includes:
  * A ZCU111 evaluation board
  * A XM500 breakout board
  * An SMA cable that you will use to connect the system in loopback mode
  * A power cable (12 volt, 50 watt) for the ZCU111
  * A micro SD card (16 GB) that you will flash the PYNQ 2.6.0 disk image onto
  * A screwdriver, hex wrench, and associated screws
* A personal computer with an Ethernet port (this guide assumes a Windows PC with no additional command line tools so as to be accessible to users with little command line programming experience; contact sarafs@princeton.edu if you would like this guide to include support for other operating systems). 
  * The computer should have git installed. In this guide, Github Desktop is used. 
    * You can download Github Desktop here: https://desktop.github.com/
  * The computer should have either SSH or PuTTY/PSCP installed. PuTTY is an open-source SSH client for the Windows operating system. This guide uses PuTTY/PSCP for accessibility, as some users are not familiar with the command line. 
    * You can download PuTTY here: https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html (for instance `putty-64bit-0.76-installer.msi`). You can also download the PSCP executable from the same link (for instance `pscp.exe`). 
  * The computer should have the Win32DiskImager utility from the Sourceforge Project page installed. The Win32DiskImager utility is an open-source tool for writing image files to disks. You will use this utility to flash the PYNQ 2.6.0 image onto your micro SD card. 
    * You can download the Win32DiskImager utility here: https://sourceforge.net/projects/win32diskimager/
* A router (this guide used a standard Cisco RV160 VPN Router which is available for purchase at www.amazon.com). The router used in this guide has 4 LAN ports. For instance, in a typical qubit control setup you can connect one LAN port to your personal computer, a second LAN port to your ZCU111, and a third point to an Ethernet switch (for example the NETGEAR 24-Port Gigabit Ethernet Unmanaged Switch (JGS524) which is available for purchase at www.amazon.com). That Ethernet switch can place 24 more devices (such as external trigger sources, local oscillators, programmable attenuators or other lab equipment) on the router's subnet, making them accessible to your personal computer. 
* Two Ethernet cables that you will use to attach 1) your ZCU111 board and 2) your personal computer to the router.
* A micro SD card reader (such as IOGEAR SuperSpeed USB 3.0 SD/Micro SD Card Reader/Writer (GFR304SD) which is available for purchase at www.amazon.com). 
* A torque wrench for tightening SMA cables

### Flashing the PYNQ image onto your micro SD card
* Your ZCU111 RFSOC evaluation board kit comes with a micro SD card. The QICK requires an up-to-date PYNQ image (as of the writing of this guide, version 2.6.0 and 2.7 are supported), so let's update the micro SD card with this version of the PYNQ image. 
* First, download the current PYNQ image from this URL: http://www.pynq.io/board.html under the ZCU111 row. If you downloaded it as a .zip, you need to unzip it to get a .img file. You will see that it's quite a large file.

<p align="center">
 <img src="quick-start-guide-pics/largeimagefile.PNG" alt="The PYNQ 2.6.0 image file">
</p>

* Plug in your micro SD card to your personal computer via your micro SD card reader. If you look in the Windows File Explorer you will see a new disk drive pop up, for example in my case it was the `E:\` drive. This is the drive associated with your micro SD card. 
* Now, open the Win32DiskImager utility and configure 1) the image file to be your PYNQ image file and 2) the device to be the `E:\` drive, as in the below picture. Before clicking `Write`, double check that you are not flashing the image file to the wrong drive (e.g. your personal computer hard drive)!

<p align="center">
 <img src="quick-start-guide-pics/writetoEdrive.PNG" alt="Writing the PYNQ 2.6.0 image onto the micro SD card">
</p>

* Click `Write`.  
* After the write completes, now look in the Windows File Explorer to see what is now contained in the `E:\` drive. You can see several files. `BOOT.BIN` allows the RFSOC to boot and includes the firmware design. `image.ub` stores the Linux kernel. There is also a Python file and an executable. The contents of the `E:\` drive are lightweight and there is plenty more space on the disk (about 6.8 GB!). So we are now ready to load this micro SD card into the ZCU111 board. 

<p align="center">
 <img src="quick-start-guide-pics/Eafterwrite.PNG" alt="The micro SD card drive after a successful write">
</p>


### Assembling and powering on your ZCU111 board

* There are several nice resources on the internet that demonstrate how to assemble the ZCU111 board. For instance, here is a full video guide: https://www.youtube.com/watch?v=4JfKlv8kWhs. The assembly is done using the screwdriver, hex wrench, and associated screws that come with the ZCU111 kit. The recommended screwdriver to install screws is a JIS #1 screwdriver such as a Vessel 220. The 4 mm hex wrench is used to tighten the jackscrew nuts under the screws. 
* Use your torque wrench to wire an SMA cable between an RF DAC channel (for this upcoming demo, choose DAC 229 CH3) and an RF ADC channel (choose ADC 224 CH0). In the case of the XM500 breakout board the channel names are written on the board itself. For a more detailed connector mapping, consult pages 95-99 of this Xilinx document: https://www.xilinx.com/support/documentation/boards_and_kits/zcu111/ug1271-zcu111-eval-bd.pdf. 
* Slide your micro SD card into its slot on the ZCU111 board. Make sure that switch SW6 of the ZCU111 is in SD card mode according to Table 2-4 of this Xilinx document: https://www.xilinx.com/support/documentation/boards_and_kits/zcu111/ug1271-zcu111-eval-bd.pdf. 

<p align="center">
 <img src="quick-start-guide-pics/Bootmodeswitch.png" alt="Boot mode switch">
</p>

* Connect your Ethernet cable from a router LAN port to the ZCU111 Ethernet port. 
* Power up your router (note that you may have to contact your system administrator to register your router's MAC address to a wall outlet in your building/laboratory).  
* Connect the 12 V power cable to the ZCU111. Flip the ZCU111 power switch on (it's next to the power cable). You should hear the fan above the RFSOC chip begin to whir and you should see green LED lights blinking all over the board. You should also see a green LED blinking repeatedly above the ZCU111 Ethernet port to signal that it is connected to the router's network. 
* Your board setup should look something like the below cartoon:

<p align="center">
 <img src="quick-start-guide-pics/boardpic_cartoon.PNG" alt="An assembled ZCU111 board">
</p>

### Finding your RFSOC on the router's network
* In the last section, you powered your router on and you connected your ZCU111 board via an Ethernet cable to one of the router's LAN ports. You verified that a green LED was blinking repeatedly above the ZCU111 Ethernet port. 
* Now, connect your personal computer via Ethernet to a LAN port of the router. 
* Log into your router via a web browser. In the case of the router used in this guide, doing so is straightforward and is explained here: https://www.cisco.com/c/dam/en/us/td/docs/routers/csbr/RV160/Quick_Start_Guide/EN/RV160_qsg_en.pdf
* Look at the list of devices found by your router. You should see two devices; your PC and your ZCU111 (id `pynq`). Take note of the IP address that was assigned to the ZCU111 (in my case it was assigned the address `192.168.1.146`). 

<p align="center">
 <img src="quick-start-guide-pics/ciscorouter.PNG" alt="Devices found by the router">
</p>

### Finding your RFSOC via Serial connection
* The IP address of the RFSoC can also be directly obtained via serial connection. 
* Connect a PC to the board via the micro USB port. Under the Device Manager under COM ports the RFSoC should show up as a COM connection. Take note of the Port number.
* Using PuTTY, select "Serial" connection type, enter the port number (e.g. `COM12`), and the serial speed, which by default is `115200`.
* This will open a terminal that directly connects to the RFSoC CPU. `ifconfig` should give the assigned IP address.
* If connection problems persist, the default gateway may not be set; this can be checked with `ip route`. There should be an IP address marked as `default`. If this is not present, a default must be set using `sudo ip route add default via xxx.xxx.xxx.1`, replacing the IP address with the local network address.
* Finally, the RFSoC may need to be configured to properly access the internet. Open `/etc/resolv.conf` in a text editor such as `vim` or `nano`, and ensure that it contains `nameserver 8.8.8.8`, `options eth0`. Note that `resolv.conf` may be re-generated when the board is power-cycled.


### Connecting to your RFSOC via Jupyter and via SSH

#### Via Jupyter

* Now you are prepared to connect to your RFSOC. Before you clone the `qick` repository and copy it onto the RFSOC, let's see what is initially on the RFSOC's operating system (this was determined by the contents of the PYNQ image). To do so, simply enter the IP address assigned to the RFSOC into a web browser on your personal computer: `192.168.1.146`. The username and password for the ZCU111 are by default `xilinx` and `xilinx`, respectively. You can change those by entering `sudo` mode once you've logged into the RFSOC via SSH (you will log in via SSH in the next part of this guide).  
* You should see this default Jupyter notebook browser: 

<p align="center">
 <img src="quick-start-guide-pics/pynqstartup.PNG" alt="PYNQ startup">
</p>

* You can see that there are a few demo Jupyter notebooks already loaded onto the RFSOC which you can feel free to explore. But now let's connect to the RFSOC via SSH, where you will have more flexibility and control. For instance, only after you have established an SSH connection can you copy the `qick` repo onto the RFSOC and do the upcoming QICK loopback demo. 

#### Via SSH

* To connect via SSH, open the PuTTY application and input the IP address assigned to the RFSOC (`192.168.1.146`) as below: 
<p align="center">
 <img src="quick-start-guide-pics/putty1.PNG" alt="Using PuTTY (1)">
</p>

* Click `Open`. You will see the following login screen on a new terminal. The username and password for the ZCU111 are by default `xilinx` and `xilinx`, respectively. 

<p align="center">
 <img src="quick-start-guide-pics/putty2.PNG" alt="Using PuTTY (2)">
</p>

* After successfully logging in you will see a Linux terminal. You have now remotely logged on to the RFSOC. 

<p align="center">
 <img src="quick-start-guide-pics/putty3.PNG" alt="Using PuTTY (3)">
</p>

### Copy the QICK tools onto your RFSOC

* Use Github Desktop to clone the `qick` repo onto your personal computer (Google around for resources if you are not sure how to do this). 
* Now, copy the `pscp.exe` into the same directory as your cloned `qick` repo, as below: 

<p align="center">
 <img src="quick-start-guide-pics/pscpfolderstructure.PNG" alt="Folder structure required for PSCP">
</p>

* Open the Command Prompt application in Windows and, after navigating to the directory containing your cloned `qick` repo, type in the following command (substituting the IP address that was assigned to your RFSOC):

<p align="center">
 <img src="quick-start-guide-pics/pushingdatatotheboard.PNG" alt="Pushing data to the RFSOC with PSCP">
</p>

* This copied the `qick` repository into the `jupyter_notebooks` folder in the `/home/xilinx/` directory of the RFSOC. 
* Your Jupyter notebook browser has now updated to include the `qick` repository, as shown below: 

<p align="center">
 <img src="quick-start-guide-pics/jupyternotebook1.PNG" alt="Jupyter notebook main folder">
</p>

### Installing the `qick` Python package

<!--* Navigate to the `qick` directory and run: `sudo python3 -m pip install .`
This will install the qick Python package.
-->
* Navigate to the `qick_demos` subfolder within the `qick` directory and run the Jupyter notebook `000_Install_qick_package.ipynb`. This will walk you through installing and testing the `qick` package.

### Running a QICK program in loopback mode

* Open `00_Send_receive_pulse.ipynb` (also in the `qick_demos` directory) and run the Jupyter notebook cells in order. You should see very similar output to that posted here: https://github.com/openquantumhardware/qick/blob/main/qick_demos/00_Send_receive_pulse.ipynb. You are seeing pulses being sent out of the RFSOC RF DACs and looping back to the RFSOC RF ADCs! In future tutorials you will learn the meaning of all the variables and parameters defined within the Jupyter notebook cells. 
* You can also take the opportunity to check that you have flashed the correct PYNQ version: 

<p align="center">
 <img src="quick-start-guide-pics/correctpynqversion.PNG" alt="The correct PYNQ version">
</p>

### Copy data off of your RFSOC and onto your personal computer

* Let's say that you have created a `quick_start_demo` directory with your work and you want a local copy of the entire directory (for example, you exported your data to `.png` plots that are within the `quick_start_demo` directory on the RFSOC, and you want to move those plots back to your personal computer). To do this, you do something analogous to when you copied the `qick` repository onto the RFSOC earlier in this guide:
* Open the Command Prompt application in Windows and, after navigating to your local directory containing your `pscp.exe` executable, type in the following command (substituting the IP address that was assigned to your RFSOC):
 
<p align="center">
 <img src="quick-start-guide-pics/pullingdataofftheboard.PNG" alt="Pulling data off the RFSOC with PSCP">
</p>

* Now the `quick_start_demo` directory has been copied to your local directory which contains your `pscp.exe` executable. 

***Hopefully this guide was a helpful introduction to QICK!***
