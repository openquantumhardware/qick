#!/usr/bin/env python3
import logging
import argparse
import requests
import multiprocessing
import json
import tempfile
import sys
import time
#from oauthlib.oauth2 import DeviceClient
#from qick import QickSoc
from oauthlib.oauth2 import BackendApplicationClient
from requests_oauthlib import OAuth2Session
from configparser import ConfigParser


class DummySoc:
    def __init__(self):
        self._cfg = {"cfg_a": "foo"}
    def run_workload(self, workload, resultsfile):
        logging.info("DummySoc running workload")
        resultsfile.write(b"test")
        time.sleep(10)

    def get_cfg(self):
        return self._cfg

    def dump_cfg(self):
        return json.dumps(self._cfg, indent=4)

class QickClient:

    def __init__(self, name, api):
        self.name = name
        self.api = api
        self.cred_path = "/home/xilinx/.qick/credentials"
        self.cfg_path = "/etc/qick/config"
        self.headers = {"Authorization": f"Bearer {self._get_auth_token()}"}
        self.status = "ONLINE"
        self.timeout = 24 * 60 * 60  # Run a workload for 24 hours max
        #self.soc = QickSoc()

        self.soc = DummySoc()
        self.soccfg = self.soc.get_cfg()

        clientcfg = ConfigParser()
        clientcfg.read(self.cfg_path)

        token_url = clientcfg['credentials']['token_url']
        # the OAuth ID is also used as the device ID
        self.id = clientcfg['credentials']['id']
        client_secret = clientcfg['credentials']['secret']


        oauth_client = BackendApplicationClient(client_id=self.id)
        self.session = OAuth2Session(client=oauth_client)
        token = self.session.fetch_token(token_url=token_url, client_id=self.id,
                        client_secret=client_secret)
        print(token)
        print(token.keys())

        self.api_url = clientcfg['api']['url']

        rsp = self.session.get(self.api_url + '/devicework')
        print(rsp.json())
        data = {
            "DeviceStatus": self.status
            }
        print(json.dumps(data))
        rsp = self.session.put(self.api_url + '/devices/' + self.id, data=json.dumps(data))
        print(rsp.json())

    def _get_auth_token(self):
        with open(self.cred_path) as f:
            return f.read().strip()

    def update_status(self):
        with open(self.cfg_path) as f:
            config_data = f.read()
        data = {
            "DeviceId": self.name,
            "DeviceStatus": self.status,
            "DeviceData": config_data,
            "DeviceConfig": self.soccfg,
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
                "timeout": self.timeout
            }
        return None

    def start_workload(self, workload):
        self.resultsfile = tempfile.TemporaryFile()
        logging.info("Started workload")
        proc = multiprocessing.Process(target=self._run_workload, daemon=True, args=(workload, self.resultsfile))
        proc.start()
        return proc

    def _run_workload(self, workload, resultsfile):
        logging.info(f"Running workload: {workload}")
        self.soc.run_workload(workload, resultsfile)
        return
        
    def is_work_canceled(self, work_id):
        rsp = requests.get(self.api + "/IsWorkCanceled", headers=self.headers)
        return rsp.json().get("IsCanceled")

    def upload_results(self, url):
        self.resultsfile.seek(0)
        requests.post(url, data=self.resultsfile.read())
        self.resultsfile.close()
        logging.info("Uploaded results")
    
if __name__ == "__main__":
    logging.getLogger().setLevel(logging.DEBUG)
    parser = argparse.ArgumentParser()
    parser.add_argument("name", type=str, help="client name or device ID")
    parser.add_argument("api", type=str, help="URL of API endpoint")
    parser.add_argument("-n", dest='interval', type=float, default=5.0, help="polling interval")
    args = parser.parse_args()

    qick = QickClient(args.name, args.api)

    work = None
    while True:
        qick.update_status()
        if qick.status == "ONLINE":
            work = qick.get_workload()
            if work:
                qick.status = "BUSY"
                work["process"] = qick.start_workload(work["workload"])
                work["timeout"] = time.time() + qick.timeout
            time.sleep(args.interval)  # sleep 5 seconds between polling
        elif qick.status == "BUSY":
            if qick.is_work_canceled(work["id"]) or time.time() > work["timeout"]:
                logging.info("terminating workload due to cancel or timeout")
                work["process"].terminate()
                work["process"].join()
                work["process"].close()
                qick.upload_results(work["upload"]) # upload partial results file
                qick.status = "ONLINE"
            elif not work["process"].is_alive():
                logging.info(f"workload completed, exit code {work['process'].exitcode}")
                qick.upload_results(work["upload"])
                work["process"].close()
                qick.status = "ONLINE"
            else:
                time.sleep(args.interval)  # sleep 5 seconds between polling
