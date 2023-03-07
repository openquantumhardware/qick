#!/usr/bin/env python3
import logging
import argparse
import requests
import multiprocessing
import json
import tempfile
import shutil
import sys
import time
import gzip
import h5py
from oauthlib.oauth2 import BackendApplicationClient
from requests_oauthlib import OAuth2Session
from configparser import ConfigParser
try:
    from qick import QickSoc, QickProgram
    from qick.helpers import json2progs
except:
    pass

class DummySoc:
    def __init__(self):
        self._cfg = {"cfg_a": "foo"}

    def get_cfg(self):
        return self._cfg

    def dump_cfg(self):
        return json.dumps(self._cfg, indent=4)

class RefetchSession(OAuth2Session):
    # requests-oauthlib doesn't support automatically requesting a new token in the "client credentials" flow:
    # https://stackoverflow.com/questions/58697334/requests-oauthlib-auto-refresh-bearer-token-in-client-credentials-flow
    # this workaround is based on this:
    # https://github.com/requests/requests-oauthlib/issues/260
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        # define a no-op token_updater
        self.token_updater = lambda token: None

    def fetch_token(self, token_url, **kwargs):
        # cache the client secret (which is normally not stored)
        self._client_secret = kwargs['client_secret']
        # copy token_url to auto_refresh_url (which could be passed in the constructor, but this is easier)
        self.auto_refresh_url = token_url
        return super().fetch_token(token_url, **kwargs)

    def refresh_token(self, token_url, **kwargs):
        # use the previously cached client secret to fetch a fresh token
        return super().fetch_token(token_url, client_id=self.client_id, client_secret=self._client_secret)


class QickClient:

    def __init__(self, api_endpoint, dummy_mode=False):
        self.api_endpoint = api_endpoint
        self.session = requests
        self.cfg_path = "/etc/qick/config"
        self.cred_path = "/etc/qick/credentials"
        self.status = "ONLINE"
        self.timeout = 24 * 60 * 60  # Run a workload for 24 hours max
        if dummy_mode:
            self.soc = DummySoc()
        else:
            self.soc = QickSoc()

        self.soccfg = self.soc.get_cfg()

        clientcfg = ConfigParser()
        clientcfg.read(self.cfg_path)

        credcfg = ConfigParser()
        credcfg.read(self.cred_path)

        if self.api_endpoint is None:
            self.api_endpoint = clientcfg['service']['api_endpoint']
            token_url = clientcfg['service']['oauth_endpoint']

            self.devid = clientcfg['device']['id']
            self.devname = clientcfg['device']['name']

            # the OAuth ID is also used as the device ID
            self.authid = credcfg['credentials']['id']
            client_secret = credcfg['credentials']['secret']

            oauth_client = BackendApplicationClient(client_id=self.authid)
            self.session = RefetchSession(client=oauth_client)
            token = self.session.fetch_token(token_url=token_url+"/oauth2/token", client_id=self.authid,
                            client_secret=client_secret)
            logging.info(f"Got OAuth2 token, expires in {token['expires_in']} seconds")
            #force a token refetch
            #oauth_client._expires_at -= 3700


    def _s3put(self, s3url, payload):
        """payload can be byte string or open file handle
        """
        rsp = requests.put(s3url, data=payload, headers={'Content-Type': 'application/octet-stream'})
        if rsp.status_code == 200:
            logging.info(f"s3 upload success")
        else:
            logging.warning(f"s3 upload fail: {rsp.status_code}")

    def _s3get(self, s3url):
        """return an open file handle
        """
        with requests.get(s3url, stream=True) as rsp:
            if rsp.status_code == 200:
                getfile = tempfile.TemporaryFile()
                shutil.copyfileobj(rsp.raw, getfile)
                logging.info(f"s3 download success")
                getfile.seek(0)
                return getfile
            else:
                logging.warning(f"s3 download fail: {rsp.status_code}")
                return None

    def update_status(self, update_config=False):
        """
        Send the updated device status to the service. This is used as a heartbeat.
        """
        data = {
            "DeviceStatus": self.status,
            "DeviceConfigurationFileExtension": "json"
        }
        rsp = self.session.put(self.api_endpoint + "/devices/" + self.devid, json=data)
        if rsp.status_code == 200:
            logging.info(f"UpdateDevice with status {data['DeviceStatus']}")
            logging.debug(f"UpdateDevice request: {data}")
            rsp = rsp.json()
            logging.debug(f"UpdateDevice response: {rsp}")
            #logging.info(f"ID check: {rsp['DeviceId']} {self.devid}")
            # if you want to update the device config
            if update_config:
                logging.info(f"UpdateDevice: uploading soccfg")
                self._s3put(rsp['UploadUrl'], json.dumps(self.soccfg))
        else:
            logging.warning(f"UpdateDevice API error: {rsp.status_code}, {rsp.content}")

    def get_workload(self):
        rsp = self.session.get(self.api_endpoint + "/devices/" + self.devid + "/workload")
        if rsp.status_code == 200:
            rsp = rsp.json()
            logging.debug(f"GetDeviceWork response: {rsp}")
            if not rsp: # if no workload is available, the response will be an empty list
                logging.info(f"GetDeviceWork: no work for device")
                return None
            workid = rsp['WorkId']
            logging.info(f"GetDeviceWork: got work {workid}")
            workurl = rsp['WorkloadUrl']
            try:
                workfile = self._s3get(workurl)
                return {
                    "id": workid,
                    "workload": workfile
                }
            except Exception as e:
                logging.warning(f"GetDeviceWork S3 error: {e}")
                return None
        else:
            logging.warning(f"GetDeviceWork API error: {rsp.status_code}, {rsp.content}")
            return None

    def start_workload(self, workload):
        self.resultsfile = tempfile.TemporaryFile()
        logging.info("Started workload")
        proc = multiprocessing.Process(target=self._run_workload, daemon=True, args=(self.soc, workload, self.resultsfile))
        proc.start()
        return proc

    def _run_workload(self, soc, workfile, resultsfile):

        logging.info(f"Running workload")
        #self.soc.run_workload(workload, resultsfile)

        if isinstance(soc, DummySoc):
            workload = workfile.read()
            workfile.close()
            logging.info("DummySoc running workload: {workload}")
            resultsfile.write(b"test")
            resultsfile.seek(0)
            time.sleep(10)
        else:
            with gzip.GzipFile(fileobj=workfile, mode='rb') as f:
                proglist = json2progs(f)
                logging.info(f"unpacked {len(proglist)} programs from workload")
                with h5py.File(resultsfile,'w') as outf:
                    datagrp = outf.create_group("data", track_order=True)
                    newprog = QickProgram(soc)
                    for iProg, progdict in enumerate(proglist):
                        proggrp = datagrp.create_group(str(iProg))
                        newprog.load_prog(progdict)
                        if progdict['acqtype']=='accumulated':
                            d_buf, d_avg, d_shots = newprog.acquire(soc, progress=False)
                            proggrp.create_dataset("avg", data=d_avg)
                            if progdict['save_raw']:
                                proggrp.create_dataset("raw", data=d_buf, compression="lzf")
                            if progdict['save_shots']:
                                proggrp.create_dataset("shots", data=d_shots, compression="lzf")
                        elif progdict['acqtype']=='decimated':
                            d_dec = newprog.acquire_decimated(soc, progress=False)
                            proggrp.create_dataset("dec", data=d_dec)
                resultsfile.seek(0)
        logging.info(f"Workload complete")
        return
        
    def is_work_canceled(self, work_id):
        # not yet implemented on the service
        return False
        #rsp = requests.get(self.api_endpoint + "/IsWorkCanceled")
        #return rsp.json().get("IsCanceled")

    def upload_results(self, work_id):
        self.resultsfile.seek(0)
        logging.info(f"PutDeviceWork request for work {work_id}")
        rsp = self.session.put(self.api_endpoint + "/devices/" + self.devid + "/workloads/" + work_id)
        if rsp.status_code == 200:
            rsp = rsp.json()
            logging.debug(f"PutDeviceWork response: {rsp}")
            try:
                self._s3put(rsp['UploadUrl'], self.resultsfile)
                logging.info("Uploaded results")
                self.resultsfile.close()
            except Exception as e:
                logging.warning(f"PutDeviceWork S3 error: {e}")
        else:
            logging.warning(f"PutDeviceWork API error: {rsp.status_code}, {rsp.content}")
    
if __name__ == "__main__":
    #logging.getLogger().setLevel(logging.DEBUG)
    logging.getLogger().setLevel(logging.INFO)
    parser = argparse.ArgumentParser()
    parser.add_argument("--api", type=str, default=None, help="URL of API endpoint")
    parser.add_argument("-n", dest='interval', type=float, default=5.0, help="polling interval")
    parser.add_argument("-d", action='store_true', help="run in dummy mode (use DummySoc instead of QickSoc)")
    args = parser.parse_args()

    qick = QickClient(args.api, args.d)

    work = None
    qick.update_status(update_config=True)
    while True:
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
                qick.upload_results(work["id"]) # upload partial results file
                qick.status = "ONLINE"
            elif not work["process"].is_alive():
                logging.info(f"workload completed, exit code {work['process'].exitcode}")
                work["process"].close()
                qick.upload_results(work["id"])
                time.sleep(args.interval)  # sleep 5 seconds between polling TODO: this is a workaround
                qick.status = "ONLINE"
            else:
                time.sleep(args.interval)  # sleep 5 seconds between polling
        qick.update_status()
