# SideQICK: AWS-based workload management for QICK

SideQICK is a QICK interface to the [Cloud Queue for Quantum Devices](https://github.com/aws-samples/cloud-queue-for-quantum-devices), and was developed in collaboration with Amazon Web Services.

The Cloud Queue for Quantum Devices is a cloud-based application for managing queues of workloads to be executed on quantum devices.
The application is composed of standard AWS services and can be deployed to an AWS account using the open-source code and instructions at https://github.com/aws-samples/cloud-queue-for-quantum-devices.
Once an instance of the application is deployed, its administrator can create queues for devices and user accounts for experimenters.

Users use SideQICK to submit workloads (sets of programs to be executed by the QICK) to a queue, from which the QICK downloads them.
The QICK uploads results back to the queue, from which users can retrieve them at any time.
Workloads and results are stored securely and resiliently in AWS cloud storage.
SideQICK allows a QICK-based system to be shared with users anywhere in the world without allowing full remote access.

SideQICK provides two components which interface to the Cloud Queue application:
* A "user client," which is a library and CLI tool that you run on your computer to make requests to the cloud application. This is used for admin operations (adding new devices or users to the application) or queue operations (Python access to workloads as an alternative to the web UI). The user client also includes a WorkloadManager class which can be used to encapsulate QickPrograms into a workload and process the results.
* A "device client," which is a systemd service that runs on the QICK board and executes workloads downloaded from a cloud queue.

See the [demo notebook](aws_demo.ipynb) for an example of the user client in operation.

## User client setup (as an admin)
As part of the Cloud Queue application setup, you will have obtained a set of URLs and IDs for the application, and created an admin user with an e-mail address.
Copy the [config.template](config.template) file to `~/.config/qick.conf` or `/etc/qick/config`, and fill out the `[service]` and `[user]` blocks with those parameters.

## User client setup (as a user)
An admin will provide config parameters, to be copied to `~/.config/qick.conf` or `/etc/qick/config` on your computer.

## Installing the device client
An admin will provide config and credentials parameters for your device, to be copied to `/etc/qick/config` and `/etc/qick/credentials` on the QICK board.

* Follow instructions in [qick.service](qick.service) to install the systemd service.
