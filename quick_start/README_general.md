# QICK quick-start guide 

***Have questions? Contact us through any of the channels listed on [the main README](../README.md).***

This guide will show you how to set up QICK after configuring your computer and RFSoC board on a local area network (LAN). By the end of this guide you will have run a QICK program in loopback mode (where signals loop back from an RF-DAC directly into an RF-ADC)!

### Getting a board
The ZCU216, RFSoC4x2, and ZCU111 are all supported by QICK and have identical FPGA logic capabilities; the differences are in the RF DACs+ADCs and the design of the rest of the board.
For new purchases we generally recommend the current generation of RFSoC boards for the best high-frequency performance: the ZCU216 or RFSoC4x2. The ZCU216 has a higher channel count, allows for flexibility in AC- or DC-coupling your signals, and can be used with custom frontend boards; the RFSoC4x2 is available with academic pricing. But we highly recommend that you look at the board specifications yourself.

The Xilinx-produced ZCU216 and ZCU111 boards are available from most major electronics distributors - check the "Authorized Distributors" list on the board's Xilinx page:
* https://www.xilinx.com/products/boards-and-kits/zcu111.html
* https://www.xilinx.com/products/boards-and-kits/zcu216.html

The RealDigital-produced RFSoC4x2 board is available directly from RealDigital: https://www.realdigital.org/hardware/rfsoc-4x2. We recommend that when communicating with RealDigital or AMD/Xilinx, that you mention that you plan to use the board with QICK - this helps them understand your needs.

### Prerequisites
* Your RFSoC evaluation board kit, from which you will need the following:
  * The RFSoC board itself, and any daughterboards:
    * For the ZCU216, you'll need the CLK-104 clocking board and the XM655 frontend board.
    * For the ZCU111, you'll need the XM500 frontend board.
  * RF cables:
    * An SMA cable that you will use to connect the system in loopback mode.
    * For the ZCU216, you'll also need the two HC2-to-SMA patch cables to connect the RF-DAC and RF-ADCs to baluns.
  * Power brick
  * The micro-SD card (16 GB or larger) that you will flash the PYNQ OS image onto; an adapter for full-size SD is also included
  * Tools:
    * A 5/16" wrench for SMA connectors (a torque wrench is nice if you have one, but the wrench in the kit is fine for these first tests).
    * For ZCU216/ZCU111, a Phillips-head screwdriver (size #1) and 4 mm hex wrench to attach the daughterboard(s).
    * For ZCU216, an 0.050" hex wrench for the HC2 connectors.
  * Ethernet cable
  * Micro-USB cable (for debugging, or changing the network configuration)
* A personal computer, which should have:
  * An Ethernet port that you can free up temporarily
    * If you don't have a free port, you can buy a USB-Ethernet adapter - any reputable brand (TP-Link, StarTech) should be OK.
  * An SD or micro-SD card reader (such as IOGEAR SuperSpeed USB 3.0 SD/Micro SD Card Reader/Writer (GFR304SD) which is available for purchase at www.amazon.com). A reader that directly reads micro-SD cards is recommended, to avoid confusion with adapters.
  * This guide assumes a Windows PC with the following tools so as to be accessible to users with little command-line programming experience, but you can use whatever tools you're comfortable with. Linux and MacOS are also fine: you will be able to use their native SSH/SCP clients, but you will need to find your own utilities for writing SD card images.
    * The computer should have git installed. In this guide, Github Desktop is used.
      * You can download Github Desktop here: https://desktop.github.com/
    * The computer should have either SSH or PuTTY/PSCP installed. PuTTY is an open-source SSH client for the Windows operating system. This guide uses PuTTY/PSCP for accessibility, as some users are not familiar with the command line.
      * You can download PuTTY here: https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html (for instance `putty-64bit-0.76-installer.msi`). This installer will also install the `pscp` command.
    * The computer should have a utility for writing disk images to SD cards. We recommend the Win32DiskImager utility, which is an open-source tool for writing image files to disks. You will use this utility to flash the PYNQ OS image onto your micro-SD card.
      * You can download the Win32DiskImager utility here: https://sourceforge.net/projects/win32diskimager/
<!--
* A router (this guide used a standard Cisco RV160 VPN Router which is available for purchase at www.amazon.com). The router used in this guide has 4 LAN ports. For instance, in a typical qubit control setup you can connect one LAN port to your personal computer, a second LAN port to your ZCU111, and a third point to an Ethernet switch (for example the NETGEAR 24-Port Gigabit Ethernet Unmanaged Switch (JGS524) which is available for purchase at www.amazon.com). That Ethernet switch can place 24 more devices (such as external trigger sources, local oscillators, programmable attenuators or other lab equipment) on the router's subnet, making them accessible to your personal computer. 
* Two Ethernet cables that you will use to attach 1) your ZCU111 board and 2) your personal computer to the router.
-->

### Flashing the PYNQ operating system image onto your micro SD card
* Your RFSoC board kit comes with a micro SD card. QICK requires an up-to-date PYNQ image (v2.6 through v3.0.1), so let's update the micro SD card with this version of the PYNQ image. 
* First, download the PYNQ image:
  * For ZCU111 and RFSoC4x2, v3.0.1 is the current recommended version: http://www.pynq.io/boards.html
  * For ZCU216, download the v2.7.0 version from the link in https://github.com/sarafs1926/ZCU216-PYNQ/issues/1.
* If you downloaded it as a .zip, you need to unzip it to get a .img file. You will see that it's quite a large file.

<p align="center">
 <img src="quick-start-guide-pics/largeimagefile.PNG" alt="The PYNQ 2.6.0 image file">
</p>

* Plug your micro SD card into your computer. If you look in the Windows File Explorer you will see a new disk drive pop up, for example in my case it was the `E:\` drive. This is the drive associated with your micro SD card. 
* Now, open the Win32DiskImager utility and configure 1) the image file to be your PYNQ image file and 2) the device to be the `E:\` drive, as in the below picture. Before clicking `Write`, double check that you are not flashing the image file to the wrong drive (e.g. your personal computer hard drive)!

<p align="center">
 <img src="quick-start-guide-pics/writetoEdrive.PNG" alt="Writing the PYNQ 2.6.0 image onto the micro SD card">
</p>

* Click `Write`.  
* After the write completes, now look in the Windows File Explorer to see what is now contained in the `E:\` drive. You can see several files that are used to boot the RFSoC. The contents of the `E:\` drive are lightweight and there is plenty more space on the disk (about 6.8 GB!). So we are now ready to load this micro SD card into the RFSoC board.

<p align="center">
 <img src="quick-start-guide-pics/Eafterwrite.PNG" alt="The micro SD card drive after a successful write">
</p>


### Assembling and powering on your RFSoC board

* For the ZCU216 and ZCU111, assemble the board with daughterboard(s). The 4 mm hex wrench is used to tighten the jackscrew nuts under the frontend board screws, then the screwdriver is used to screw down the board. For both the frontend board and the ZCU216's CLK-104 board, be careful to align the high-density connector before screwing down the board. You may find these resources useful in addition to the kit documentation:
  * For the ZCU216 board, the basic assembly section of this webpage: https://xilinx-wiki.atlassian.net/wiki/spaces/A/pages/246153525/RF+DC+Evaluation+Tool+for+ZCU216+board+-+Quick+start. 
  * For the ZCU111 board, this video guide: https://www.youtube.com/watch?v=4JfKlv8kWhs
* Slide your micro SD card into its slot on the board.
* Make sure the board is in SD card boot mode.
  * For the RFSoC4x2, this is a simple slider switch with "SD" and "JTAG" labels.
  * For the ZCU216 and ZCU111, there's a 4-position DIP switch (SW2 on the ZCU216, SW6 on the ZCU111) which you must set as shown in the photo below (of a ZCU111, but the switch is the same on the ZCU216), with the first position set to "ON" and the rest to "OFF." Xilinx documentation: [ZCU216](https://docs.amd.com/r/en-US/ug1390-zcu216-eval-bd/Zynq-UltraScale-RFSoC-XCZU49DR-Configuration), [ZCU111](https://docs.amd.com/r/en-US/ug1271-zcu111-eval-bd/RFSoC-Device-Configuration).

<p align="center">
 <img src="quick-start-guide-pics/Bootmodeswitch.png" alt="Boot mode switch">
</p>

* Use your torque wrench to wire an SMA cable between an RF-DAC channel and an RF-ADC channel.
  * For the ZCU216, choose DAC 2_231 and ADC 0_226, which will be generator 6 and readout 0. This is a two-step process, because the XM655 directly exposes the differential ports of the RF-DACs and RF-ADCs, and you must patch these through to the baluns that convert them to regular (single-ended) signals:
    * First identify the gold HC2 connector you want; e.g. 2_231 is labeled next to connector JHC3. Connect an HC2-SMA cable and screw it down.
    * Now identify the P/N pair of SMA pigtails you want; e.g. the pair for 2_231 are the last two on this cable. Connect these to the P and N ports of an available low-frequency (10 MHz-1 GHz) balun. The third SMA connector next to this balun is the single-ended port; your SMA cable will connect the single-ended ports of the two baluns.
    * See also https://docs.amd.com/r/en-US/ug1390-zcu216-eval-bd/CoreHC2-Connector-Pinout-XM655-Only
  * For the RFSoC4x2, choose DAC_B and ADC_D, which will be generator 0 and readout 0. (You will need to change the generator number in the demo notebook later, since the demos assume generator 6.)
  * For the ZCU111, choose DAC 229 CH3 and ADC 224 CH0, which will be generator 6 and readout 0. These names are written directly on the XM500 breakout board. See also https://docs.amd.com/r/en-US/ug1271-zcu111-eval-bd/XM500-ADC/DAC-Data-and-Clock-SMA
* Connect an Ethernet cable or USB cable, and configure your computer, as specified in the next section.
* Connect the power cable to the RFSoC board. Flip the board power switch on (it's next to the power cable). You should hear the fan above the RFSoC chip begin to whir and you should see LED lights blinking all over the board. You should also see lit or blinking LEDs that indicate the Ethernet port is connected to your computer: two LEDs built into the face of the port and a third LED next to the port labeled "LINK."
* Your board setup should look something like the below cartoon:

<p align="center">
 <img src="quick-start-guide-pics/boardpic_cartoon.PNG" alt="An assembled ZCU111 board">
</p>

### Log in to the RFSoC and configure the network
You will normally connect to the RFSoC over a network connection, most typical setups are one of the following:
* Point-to-point: the RFSoC is always directly connected to the PC through a single Ethernet cable. This is the simplest but usually not a long-term solution, because it consumes an Ethernet port on the PC.
* Switch: the RFSoC, PC, and possibly other lab equipment are connected to a switch, which doesn't assign IP addresses. Each piece of equipment has a static IP configured internally.
* Router: the RFSoC, PC, and possibly other lab equipment are connected to a router, which assigns IP addresses automatically. Other lab equipment might be connected to the router as well. The router could additionally be configured as an Internet gateway, to allow the PC and RFSoC to access the Internet.
 * Your institution's network is probably capable of playing this role, but this is not recommended because problems are difficult to debug, and because this exposes the RFSoC to all other users on the network. Only do this if you have experience with Linux network configuration and security, and follow all of the security recommendations below.

The default network settings of the RFSoC are as follows:
* If it's connected to a router, it will use an assigned address.
* Otherwise it will use 192.168.2.99.

These settings are fine for point-to-point or router setups, but for a switch setup you will generally want a static IP other than 192.168.2.99, because your other equipment is unlikely to be using the 192.168.2.xxx IP range.
In that case you should make an initial connection to change the RFSoC's network settings. Below are three ways to do it (the first two double as ways to configure the point-to-point or router setups).

Once you have a terminal with root pirivileges, open `/etc/network/interfaces.d/eth0` in a text editor such as `vim` or `nano`. It will look like this:

```
auto eth0
iface eth0 inet dhcp

auto eth0:1
iface eth0:1 inet static
address 192.168.2.99
netmask 255.255.255.0
```

Change the `192.168.2.99` to the desired static IP address, and save the file. You can now close the terminal, power off the RFSoC board, and connect it to the switch.

### Recommended: via point-to-point Ethernet connection
* Connect your Ethernet cable from your computer to the RFSoC Ethernet port.
* Configure your computer's Ethernet port with a static IP in the 192.168.2.xxx range, similar to below:

<p align="center">
 <img src="quick-start-guide-pics/static_ip.png" alt="Setting a static IP in Windows">
</p>

* After powering up, connect to the board by navigating to `192.168.2.99` on your browser. This should open Jupyter. The default Jupyter password is `xilinx`. Now click the "New" button at the upper right and open a terminal.

### Alternative: using a router
Use a router (e.g. a Cisco RV160 VPN Router which is available for purchase at www.amazon.com), which will automatically assign an IP address to your RFSoC board. The router used in this guide has 4 LAN ports. For instance, in a typical qubit control setup you can connect one LAN port to your personal computer, a second LAN port to your ZCU216, and a third point to an Ethernet switch (for example the NETGEAR 24-Port Gigabit Ethernet Unmanaged Switch (JGS524) which is available for purchase at www.amazon.com). That Ethernet switch can place 24 more devices (such as external trigger sources, local oscillators, programmable attenuators or other lab equipment) on the router's subnet, making them accessible to your personal computer.

* Connect both your computer and the RFSoC to the router with Ethernet cables.
* Unlike the point-to-point case, you won't set a static IP on your computer's Ethernet port; you'll leave it on its default configuration, where it will let the router auto-configure its address.
* Log into your router via a web browser. In the case of the router used in this guide, doing so is straightforward and is explained here: https://www.cisco.com/c/dam/en/us/td/docs/routers/csbr/RV160/Quick_Start_Guide/EN/RV160_qsg_en.pdf
* Look at the list of devices found by your router. You should see two devices; your PC and your RFSoC (id `pynq`). Take note of the IP address that was assigned to the RFSoC (in my case it was assigned the address `192.168.1.146`).

<p align="center">
 <img src="quick-start-guide-pics/ciscorouter.PNG" alt="Devices found by the router">
</p>

* After powering up, connect to the board by navigating to `192.168.2.99` on your browser. This should open Jupyter. The default Jupyter password is `xilinx`. Now click the "New" button at the upper right and open a terminal.
* If you're going to use the router setup long-term: most routers will allow you to assign a permanent IP address to the RFSoC based on its MAC address (see https://github.com/openquantumhardware/qick/issues/182 for an extra step that's needed for some ZCU216 and ZCU111 setups).

### Alternative: via serial connection (also useful for debugging problems with the other methods)
* The IP address of the RFSoC can also be directly obtained via serial connection. 
* Connect a PC to the board via the micro USB port. Under the Device Manager under COM ports the RFSoC should show up as three COM connections. Usually, the port you should use is the first of those three.
* Power up the RFSoC board. It is important to boot the board after the micro USB has been connected between the board and your PC.
* Using PuTTY, select "Serial" connection type, enter the port number (e.g. `COM4`), and the serial speed, which by default is `115200`.
* This will open a terminal that directly connects to the RFSoC CPU. You may need to log in; the default username and password are both `xilinx`.
* For debugging network issues: `ifconfig` should give the assigned IP address.
<!--
* If connection problems persist, the default gateway may not be set; this can be checked with `ip route`. There should be an IP address marked as `default`. If this is not present, a default must be set using `sudo ip route add default via xxx.xxx.xxx.1`, replacing the IP address with the local network address.
* Finally, the RFSoC may need to be configured to properly access the internet. Open `/etc/resolv.conf` in a text editor such as `vim` or `nano`, and ensure that it contains `nameserver 8.8.8.8`, `options eth0`. Note that `resolv.conf` may be re-generated when the board is power-cycled.
-->

### Connecting to your RFSoC via Jupyter and via SSH
You can connect to the RFSoC over the network in two ways: through the RFSoC's Jupyter server, which you access using a web browser, and through the RFSoC's SSH server, which you access using SSH and SCP clients. Jupyter will probably be your main interface, and you will use it to run the QICK demos. SSH gives you a terminal and SCP is used for file transfers; you can also create terminals and upload/download files in Jupyter, but it's not as flexible. You will use SCP to upload the QICK software and firmware to the RFSoC.

The default access credentials are as follows:
* Jupyter: password is `xilinx`.
* SSH/SCP: user is `xilinx`, password is `xilinx`.



#### Via Jupyter

* Now you are prepared to connect to your RFSOC. Before you clone the `qick` repository and copy it onto the RFSOC, let's see what is initially on the RFSOC's operating system (this was determined by the contents of the PYNQ image). To do so, simply enter the IP address assigned to the RFSOC into a web browser on your personal computer: `192.168.1.146`. The username and password for the ZCU111 are by default `xilinx` and `xilinx`, respectively. You can change those by entering `sudo` mode once you've logged into the RFSOC via SSH (you will log in via SSH in the next part of this guide).  
* You should see this default Jupyter notebook browser: 

<p align="center">
 <img src="quick-start-guide-pics/pynqstartup.PNG" alt="PYNQ startup">
</p>

* You can see that there are a few demo Jupyter notebooks already loaded onto the RFSOC which you can feel free to explore. But now let's connect to the RFSOC via SSH, where you will have more flexibility and control. For instance, only after you have established an SSH connection can you copy the `qick` repo onto the RFSOC and do the upcoming QICK loopback demo.
* If you need to open a root terminal for changing network settings, click the "New" button at the upper right and open a terminal.

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

* If you need root privileges for changing network settings, run `sudo -s` and enter the user password again.

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

* Open `00_Send_receive_pulse.ipynb` (also in the `qick_demos` directory) and run the Jupyter notebook cells in order. You should see very similar output to that posted here: https://github.com/openquantumhardware/qick/blob/main/qick_demos/00_Send_receive_pulse.ipynb. You are seeing pulses being sent out of the RFSoC RF-DACs and looping back to the RFSoC RF-ADCs! In future tutorials you will learn the meaning of all the variables and parameters defined within the Jupyter notebook cells. 
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
