#!/usr/bin/env python3
import logging
import requests
from multiprocessing import Process, Queue, Event
import subprocess
import sys
import time
from datetime import datetime
#from qick import QickSoc

class DummySoc:
    def run_workload(self, workload):
        pass

class QickClient:

    def __init__(self, name, api):
        self.name = name
        self.api = api
        self.cred_path = "/home/xilinx/.qick/credentials"
        self.conf_path = "/etc/qick/config"
        self.headers = {"Authorization": f"Bearer {self._get_auth_token()}"}
        self.status = "ONLINE"
        self.timeout = 24 * 60 * 60  # Run a workload for 24 hours max
        #self.soc = QickSoc()
        self.soc = DummySoc()

    def _get_auth_token(self):
        with open(self.cred_path) as f:
            return f.read().strip()

    def update_status(self):
        with open(self.conf_path) as f:
            config_data = f.read()
        data = {
            "DeviceId": self.name,
            "DeviceStatus": self.status,
            "DeviceData": config_data,
        }
        requests.put(self.api + "/UpdateDevice", data=data, headers=self.headers)
        logging.info(f"Updated status: {data}")

    def get_workload(self):
        rsp = requests.get(self.api + "/GetDeviceWork", headers=self.headers)
        if rsp.json():
            logging.info(f"Got work {rsp.json()['WorkId']}")
            return {
                "id": rsp.json()["WorkId"],
                "workload": requests.get(rsp.json()["WorkloadUrl"]),
                "upload": rsp.json()["UploadUrl"],
            }
        return None

    def run_workload(self, workload):
        # It is NOT RECOMMENDED to use files like this, it is just for the example
        with open("/tmp/workload", "w") as f:
            print(workload, file=f)
        logging.info("Started workload")
        return subprocess.Popen(
            ["/usr/bin/qick_runner.py", "/tmp/workload"],
            stdout="/tmp/workload.out",
            stderr=subprocess.STDOUT,
        )
        
    def is_work_canceled(self, work_id):
        rsp = requests.get(self.api + "/IsWorkCanceled", headers=self.headers)
        return rsp.json().get("IsCanceled")

    def upload_results(self, url):
        with open("/tmp/workload.out", "rb") as f:
            requests.post(url, data=f.read())
        logging.info("Uploaded results")
    
if __name__ == "__main__":
    qick = QickClient(sys.argv[1], sys.argv[2])
    logging.getLogger().setLevel(logging.DEBUG)
    while True:
        work = None
        qick.update_status()
        if qick.status == "ONLINE":
            work = qick.get_workload()
            if not work:
                time.sleep(5)  # sleep 5 seconds between polling
            else:
                qick.status = "BUSY"
                work["process"] = qick.run_workload(work["workload"])
                work["timeout"] = time.time() + qick.timeout
                time.sleep(5)  # sleep 5 seconds between polling
        elif qick.status == "BUSY":
            if qick.is_work_canceled(work["id"]) or time.time() > work["timeout"]:
                work["process"].terminate()
                qick.upload_results(work["upload"])
                qick.status = "ONLINE"
            elif work["process"].poll():
                qick.upload_results(work["upload"])
                qick.status = "ONLINE"
            else:
                time.sleep(5)  # sleep 5 seconds between polling
