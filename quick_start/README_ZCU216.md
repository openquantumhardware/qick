# QICK quick-start guide for the ZCU216 board

***Have questions? Contact: ``sarafs AT princeton.edu``***

This guide will show you how to set up QICK after configuring your computer and RFSOC ZCU216 board on a local area network (LAN). By the end of this guide you will have run a QICK program in loopback mode (where signals loop back from an RF DAC directly into an RF ADC)! 



### Prerequisites
* A ZCU216 RFSOC evaluation board kit (available for purchase at www.avnet.com). In this guide you will connect the ZCU216 eval board with 
  * A ZCU216 evaluation board (from the kit)
  * A CLK-104 clocking board (from the kit)
  * A XM655 breakout board (from the kit)
  * Two HC2-to-SMA cables (from the kit)
  * An SMA cable that you will use to connect the system in loopback mode (from the kit)
  * A power cable (12 volt, 50 watt) for the ZCU216 (from the kit)
  * A micro SD card (16 GB) that you will flash the PYNQ 2.7.0 disk image onto (from the kit)
  * A screwdriver, hex wrench, and associated screws (from the kit)
* A personal computer with an Ethernet port.
  * The computer should have git installed. In this guide, Github Desktop is used. 
    * You can download Github Desktop here: https://desktop.github.com/
  * The computer should have the Win32DiskImager utility from the Sourceforge Project page installed. The Win32DiskImager utility is an open-source tool for writing image files to disks. You will use this utility to flash the PYNQ 2.7.0 image onto your micro SD card. 
    * You can download the Win32DiskImager utility here: https://sourceforge.net/projects/win32diskimager/
* A router (this guide used a standard Cisco RV160 VPN Router which is available for purchase at www.amazon.com). The router used in this guide has 4 LAN ports. For instance, in a typical qubit control setup you can connect one LAN port to your personal computer, a second LAN port to your ZCU216, and a third point to an Ethernet switch (for example the NETGEAR 24-Port Gigabit Ethernet Unmanaged Switch (JGS524) which is available for purchase at www.amazon.com). That Ethernet switch can place 24 more devices (such as external trigger sources, local oscillators, programmable attenuators or other lab equipment) on the router's subnet, making them accessible to your personal computer. 
* Two Ethernet cables that you will use to attach 1) your ZCU216 board and 2) your personal computer to the router.
* A micro SD card reader (such as IOGEAR SuperSpeed USB 3.0 SD/Micro SD Card Reader/Writer (GFR304SD) which is available for purchase at www.amazon.com). 
* A torque wrench for tightening SMA cables

### Flashing the PYNQ 2.7.0 image onto your micro SD card
* Your ZCU216 RFSOC evaluation board kit comes with a micro SD card that is preloaded with a PYNQ image. The QICK hardware requires PYNQ 2.7.0, so let's update the micro SD card with this version of the PYNQ image. 
* First, download the PYNQ 2.7.0 image from the Google Drive link attached to this GitHub issue: https://github.com/sarafs1926/ZCU216-PYNQ/issues/1. You will see that it's quite a large file of approximately 10 GB. 

* Plug in your micro SD card to your personal computer via your micro SD card reader. If you look in the Windows File Explorer you will see a new disk drive pop up, for example in my case it was the `E:\` drive. This is the drive associated with your micro SD card. 
* Now, open the Win32DiskImager utility and configure 1) the image file to be your PYNQ 2.7.0 image file and 2) the device to be the `E:\` drive, as in the below picture. Before clicking `Write`, double check that you are not flashing the image file to the wrong drive (e.g. your personal computer hard drive)!

<p align="center">
 <img src="quick-start-guide-pics/writetoEdrive.PNG" alt="Writing the PYNQ 2.7.0 image onto the micro SD card">
</p>

* Click `Write`.  
* After the write completes, now look in the Windows File Explorer to see what is now contained in the `E:\` drive. You can see several files. `BOOT.BIN` allows the RFSOC to boot and includes the firmware design. `image.ub` stores the Linux kernel. There is also a Python file and an executable. So we are now ready to load this micro SD card into the ZCU216 board. 

<p align="center">
 <img src="quick-start-guide-pics/Eafterwrite.PNG" alt="The micro SD card drive after a successful write">
</p>


### Assembling and powering on your ZCU216 board

* There is a nice resource on the internet that demonstrates how to assemble the ZCU216 board: the basic assembly section of this webpage: https://xilinx-wiki.atlassian.net/wiki/spaces/A/pages/246153525/RF+DC+Evaluation+Tool+for+ZCU216+board+-+Quick+start. 
* After the CLK-104 and XM655 cards are attached to your board, connect the HC2-to-SMA cables to locations JHC3 and JHC7 and tighten with the hex key provided. With the standard QICK ZCU216 firmware, JHC connectors 3,4 and 7 are used to break out the DAC and ADC channels respectively, but the eval board kit only provides two HC2-to-SMA cables (more can be purchased on Digi-Key). 
* For detailed connector mapping, consult pages 71-79 of this Xilinx document: https://www.xilinx.com/content/dam/xilinx/support/documents/boards_and_kits/zcu216/ug1390-zcu216-eval-bd.pdf. 
* Now, tie the P/N differential SMAs of a DAC (lets say, DAC 6, which is in the below table labeled `2_231` on the XM655 card) to a low frequency balun (10 MHz-1 GHz) on the XM655 card. Also tie the P/N differential SMAs of an ADC (lets say, ADC 0 which is in the below table labeled `0_226` on the XM655 card) to another low frequency balun on the XM655 card. Now connect the balun outputs together to create a loopback from DAC 6 to ADC 0. When you initialize the RFSOC object in your loopback script you will see the mapping between QICK DAC and ADC channels and the tile numbers associated with the various JHC locations on the XM655 card. Here they are listed below, as well. 

* DAC-side
  * JHC 3 differential SMAs:
   * 2_231 <-> DAC 6
   * 0_231 <-> DAC 4
   * 2_230 <-> DAC 2
   * 0_230 <- DAC 0
  * JHC 4 differential SMAs:
   * 1_231 <-> DAC 5
   * 3_230 <-> DAC 3
   * 1_230 <-> DAC 1

* ADC-side
  * JHC 7 differential SMAs:
   * 2_226 <-> ADC 1
   * 0_226 <-> ADC 0

* Slide your micro SD card into its slot on the ZCU216 board. Make sure that switch SW2 of the ZCU216 is in SD card mode according to Table 5 of this Xilinx document: https://www.xilinx.com/content/dam/xilinx/support/documents/boards_and_kits/zcu216/ug1390-zcu216-eval-bd.pdf. 

* Connect your Ethernet cable from a router LAN port to the ZCU216 Ethernet port. 
* Power up your router (note that you may have to contact your system administrator to register your router's MAC address to a wall outlet in your building/laboratory).  
* Connect the 12 V power cable to the ZCU216. Flip the ZCU216 power switch on (it's next to the power cable). You should hear the fan above the RFSOC chip begin to whir and you should see green LED lights blinking all over the board. You should also see a green LED blinking repeatedly above the ZCU216 Ethernet port to signal that it is connected to the router's network. Note that at this point, you should see the 3 LEDs be as follows:

`PS_LED = flashing green`

`DONE LED = off`

`INT_B LED = red`

It is only after you initialize the QICK firmware that the FPGA has been loaded with its bitstream, so it makes sense that those LEDs are that "unfinished" color since you haven't loaded the firmware onto the FPGA yet. However, the RFSOC processor is running and so you can at this point connect to it via its IP address. So every single time you boot the RFSOC board you will see those same LED patterns that you describe, that is normal. The firmware is loaded later, using the QICK software, every time. The RFSOC processor (which runs Linux and has an IP address like a normal computer) is separate from the RFSOC FPGA. Once you see those LEDs, proceed to the next step.

### Finding your RFSOC on the router's network
* In the last section, you powered your router on and you connected your ZCU216 board via an Ethernet cable to one of the router's LAN ports. You verified that a green LED was blinking repeatedly above the ZCU216 Ethernet port. 
* Now, connect your personal computer via Ethernet to a LAN port of the router. 
* Look at the list of devices found by your router. You should see two devices; your PC and your ZCU216 (id `pynq`). One easy way of doing this on a Windows PC is to download the `Advanced IP scanner` tool (https://www.advanced-ip-scanner.com/). Take note of the IP address that was assigned to the ZCU216.

### Finding your RFSOC via Serial connection
* The IP address of the RFSoC can also be directly obtained via serial connection. 
* Connect a PC to the board via the micro USB port. Under the Device Manager under COM ports the RFSoC should show up as a COM connection. Take note of the Port number.
* Using PuTTY, select "Serial" connection type, enter the port number (e.g. `COM12`), and the serial speed, which by default is `115200`.
* This will open a terminal that directly connects to the RFSoC CPU. `ifconfig` should give the assigned IP address.
* If connection problems persist, the default gateway may not be set; this can be checked with `ip route`. There should be an IP address marked as `default`. If this is not present, a default must be set using `sudo ip route add default via xxx.xxx.xxx.1`, replacing the IP address with the local network address.
* Finally, the RFSoC may need to be configured to properly access the internet. Open `/etc/resolv.conf` in a text editor such as `vim` or `nano`, and ensure that it contains `nameserver 8.8.8.8`, `options eth0`. Note that `resolv.conf` may be re-generated when the board is power-cycled.

### Connecting to your RFSOC via Jupyter and via SSH

#### Via Jupyter

* Now you are prepared to connect to your RFSOC. Before you clone the `qick` repository and copy it onto the RFSOC, let's see what is initially on the RFSOC's operating system (this was determined by the contents of the PYNQ image). To do so, simply enter the IP address assigned to the RFSOC into a web browser on your personal computer, for instance it could be: `192.168.1.146`. The username and password for the ZCU216 are by default `xilinx` and `xilinx`, respectively. 
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

* Open `00_Send_receive_pulse.ipynb` (also in the `qick_demos` directory). Run the Jupyter notebook cells in order. You should see very similar output to that posted here: https://github.com/openquantumhardware/qick/blob/main/qick_demos/00_Send_receive_pulse.ipynb. You are seeing pulses being sent out of the RFSOC RF DACs and looping back to the RFSOC RF ADCs! In future tutorials you will learn the meaning of all the variables and parameters defined within the Jupyter notebook cells. 
* You can also take the opportunity to check that you have flashed the correct PYNQ version (2.7.0): 

<p align="center">
 <img src="quick-start-guide-pics/correctpynqversion.PNG" alt="The correct PYNQ version">
</p>

### Copy data off of your RFSOC and onto your personal computer

* Let's say that you have created a `quick_start_demo` directory with your work and you want a local copy of the entire directory (for example, you exported your data to `.png` plots that are within the `quick_start_demo` directory on the RFSOC, and you want to move those plots back to your personal computer). To do this, you can either store the data in a separate GitHub repo which you can then push back to GitHub so it is available for your download onto your local PC via your browser, or you can use the standard Linux `scp` command to securely copy data from the RFSOC back to the local PC.
* Open the Command Prompt application in Windows and, after navigating to your local directory containing your `pscp.exe` executable, type in the following command (substituting the IP address that was assigned to your RFSOC):
 
<p align="center">
 <img src="quick-start-guide-pics/pullingdataofftheboard.PNG" alt="Pulling data off the RFSOC with PSCP">
</p>

* Now the `quick_start_demo` directory has been copied to your local directory which contains your `pscp.exe` executable. 

***Hopefully this guide was a helpful introduction to QICK!***
