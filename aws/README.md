# SideQICK: AWS-based workload management for QICK

SideQICK is a cloud-based workload queueing service developed in collaboration with Amazon Web Services.

The code in this directory provides two components of the system:
* A "user client," which is a library and CLI tool that you run on your computer to make requests to the cloud service. This is used for admin operations (adding new devices or users to the cloud service) or Python access to workloads as an alternative to the web UI. The user client also includes a WorkloadManager class which can be used to encapsulate QickPrograms into a workload and process the results.
* A "device client," which is a systemd service that runs on the QICK board and allows the board to be controlled by the cloud service.

The code for the cloud service, which you can deploy to your AWS account, is soon to be released.

See the [demo notebook](aws_demo.ipynb) for an example of the user client in operation.

## Installing the user client
An admin will provide config parameters, to be copied to `~/.config/qick.conf` or `/etc/qick/config` on your computer.
(If you deployed the cloud service, you will have obtained config parameters and an admin login in that process.)

* Copy the [config.template](config.template) file to `~/.config/qick.conf` or `/etc/qick/config`, and enter the parameters that are required for the user client.

## Installing the device client
An admin will provide config and credentials parameters for your device, to be copied to `/etc/qick/config` and `/etc/qick/credentials` on the QICK board.

* Follow instructions in [qick.service](qick.service) to install the systemd service.
