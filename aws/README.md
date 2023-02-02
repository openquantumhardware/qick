# SideQICK: AWS-based workload management for QICK

SideQICK is a cloud-based workload queueing service developed in collaboration with Amazon Web Services.

The code in this directory provides two components of the system:
* A "user client," which is a library and CLI tool that you run on your computer to make requests to the cloud service. Admin requests include creating new devices or users on the cloud service. User requests are analoguous to actions you can take in the web UI, and include submitting workloads and checking for results.
* A "device client," which is a systemd service that runs on the QICK board and allows the board to be controlled by the cloud service.

The code for the cloud service, which you can deploy to your AWS account, is soon to be released.

## Installing the user client

* Copy the {config.template} file to `~/.config/qick.conf` or `/etc/qick/config`, and enter the parameters that are required for the user client.

## Installing the device client
An admin will provide service config information and device credentials for your device.

* Follow instructions in {qick.service} to install the systemd service.
* Create the directory `/etc/qick`.
* Copy the {config.template} file to `/etc/qick/config`, and enter the parameters that are required for the device client.
* Create the file `/etc/qick/credentials` with device credentials.
