#!/usr/bin/env python3
import logging
import argparse
import requests
import multiprocessing
import json
import tempfile
import sys
import time
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

    def __init__(self, name, api):
        self.name = name
        self.api = api
        self.session = requests
        self.cfg_path = "/etc/qick/config"
        self.cred_path = "/etc/qick/credentials"
        self.status = "ONLINE"
        self.timeout = 24 * 60 * 60  # Run a workload for 24 hours max
        #self.soc = QickSoc()

        self.soc = DummySoc()
        self.soccfg = self.soc.get_cfg()

        clientcfg = ConfigParser()
        clientcfg.read(self.cfg_path)

        credcfg = ConfigParser()
        credcfg.read(self.cred_path)

        if self.api is None:
            self.api = clientcfg['service']['api_url']
            token_url = clientcfg['service']['auth_url']

            # the OAuth ID is also used as the device ID
            self.id = credcfg['credentials']['id']
            client_secret = credcfg['credentials']['secret']

            oauth_client = BackendApplicationClient(client_id=self.id)
            self.session = RefetchSession(client=oauth_client)
            token = self.session.fetch_token(token_url=token_url, client_id=self.id,
                            client_secret=client_secret)
            logging.info(f"Got OAuth2 token, expires in {token['expires_in']} seconds")
            #force a token refetch
            #oauth_client._expires_at -= 3700


    def update_status(self):
        data = {
            "DeviceStatus": self.status
        }
        rsp = self.session.put(self.api + "/devices/" + self.id, json=data)
        if rsp.status_code == 200:
            logging.info(f"UpdateDevice request: {data}")
            logging.info(f"UpdateDevice response: {rsp.json()}")

            # TODO: not sure what UploadUrl is for
            if False:
                uploadurl = rsp.json()['UploadUrl']
                rsp2 = requests.put(uploadurl, data=b'test upload', headers={'Content-Type': 'application/octet-stream'})
                logging.info(f"test upload response: {rsp2.status_code}")

            # TODO: GetDevice gives 401 error
            if False:
                rsp = self.session.get(self.api + '/devices/' + self.id)
                print(rsp.status_code)

    def get_workload(self):
        rsp = self.session.get(self.api + "/devicework")
        if rsp.status_code == 200:
            logging.info(f"GetDeviceWork response: {rsp.json()}")
            rsp = rsp.json()

            workid = rsp['WorkId']
            logging.info(f"Got work {workid}")
            workurl = rsp['WorkloadUrl']

            try:
                rsp_s3get = requests.get(workurl)
                if rsp_s3get.status_code == 200:
                    workload = rsp_s3get.content
                    return {
                        "id": workid,
                        "workload": workload,
                        "upload": None
                    }
            except Exception as e:
                print(e)
                return None

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
        # not yet implemented on the service
        return False
        #rsp = requests.get(self.api + "/IsWorkCanceled")
        #return rsp.json().get("IsCanceled")

    def upload_results(self, url):
        self.resultsfile.seek(0)
        # TODO: figure out upload flow
        if url is not None:
            requests.post(url, data=self.resultsfile.read())
            logging.info("Uploaded results")
        self.resultsfile.close()
    
if __name__ == "__main__":
    #logging.getLogger().setLevel(logging.DEBUG)
    logging.getLogger().setLevel(logging.INFO)
    parser = argparse.ArgumentParser()
    parser.add_argument("name", type=str, help="client name or device ID")
    parser.add_argument("--api", type=str, default=None, help="URL of API endpoint")
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
