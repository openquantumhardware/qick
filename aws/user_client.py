#!/usr/bin/env python3
# standard libraries
import logging
import argparse
import json
import gzip
import base64
import getpass
import time
import datetime
import sys
import os
from configparser import ConfigParser
import tempfile
import shutil
# dependencies
import requests
# CLI dependency - not needed for the rest of the library
try:
    from fire import Fire
except:
    pass
# WorkloadManager dependencies - not needed for UserClient
try:
    import h5py
    from qick.helpers import progs2json
except:
    pass

class CognitoAuth(requests.auth.AuthBase):
    TOKEN_PATH = os.path.expanduser('~/.cache/qick.tokens')
    def __init__(self):
        self.auth_url = None
        self.client_id = None
        self.username = None
        self.pool_id = None
        self.tokens = None
        self.expire_time = None
        self.token_email = None

        if os.path.exists(self.TOKEN_PATH):
            with open(self.TOKEN_PATH, 'rt') as f:
                self.update_tokens(json.load(f), replace_tokens=True, write_tokens=False)

    def __call__(self, r):
        """This is called by the Session to set auth headers.
        """
        if self.tokens is None or self.token_email != self.username:
            self.initial_auth()

        # if we have less than 60 seconds till expiry, refresh tokens
        if self.expire_time - time.time() < 60:
            try:
                self.refresh_auth()
            except:
                # if anything goes wrong with refresh, re-auth from scratch
                # this should cover expired refresh tokens
                self.initial_auth()

        r.headers['Authorization'] = self.auth_header
        return r

    def update_tokens(self, new_tokens, replace_tokens=False, write_tokens=True):
        if replace_tokens or self.tokens is None:
            self.tokens = new_tokens
        else:
            self.tokens.update(new_tokens)

        # unpack the JWT to get the expiry timestamp
        # JWT uses unpadded base64, need to add dummy padding:
        # https://stackoverflow.com/questions/2941995/python-ignore-incorrect-padding-error-when-base64-decoding
        access_token = self.tokens['AccessToken']
        access_payload = json.loads(base64.b64decode(access_token.split('.')[1] + '=='))
        # the expiration time will tell us when to refresh
        self.expire_time = access_payload['exp']

        id_payload = json.loads(base64.b64decode(self.tokens['IdToken'].split('.')[1] + '=='))
        # the e-mail will be checked against the config username
        self.token_email = id_payload['email']
        logging.info(f"updated tokens: for user {self.token_email}, in groups {id_payload['cognito:groups']}")

        self.auth_header = ' '.join([self.tokens['TokenType'], access_token])

        if write_tokens:
            logging.info("writing updated tokens")
            with open(self.TOKEN_PATH, 'wt') as f:
                json.dump(self.tokens, f)

    def initial_auth(self):
        print(f"initial auth for {self.username}:")
        auth_response = self._do_auth_password()
        """
        try:
            auth_response = self._do_auth_srp()
            #auth_response = self._do_auth_srp_warrant()
        except:
            auth_response = self._do_auth_password()
        """
        if 'AuthenticationResult' not in auth_response:
            raise RuntimeError("Login failed")
        self.update_tokens(auth_response['AuthenticationResult'], replace_tokens=True)

    def refresh_auth(self):
        logging.info("refreshing tokens")
        refresh_response = self._auth_refresh(self.tokens['RefreshToken'])
        if 'AuthenticationResult' not in refresh_response:
            raise RuntimeError("Refresh failed")
        # update tokens
        self.update_tokens(refresh_response['AuthenticationResult'])

    def _do_auth_srp(self):
        """this uses pysrp (standard SRP implementation) with patches from warrant (Cognito-specific)
        https://stackoverflow.com/questions/41526205/implementing-user-srp-auth-with-python-boto3-for-aws-cognito
        """
        logging.info("using pysrp-based SRP for initial auth")
        import srp
        import six, hmac, hashlib
        def long_to_bytes(n):
            l = list()
            x = 0
            off = 0
            while x != n:
                b = (n >> off) & 0xFF
                l.append( chr(b) )
                x = x | (b << off)
                off += 8
            # weird Cognito padding logic
            if (b & 0x80) != 0:
                l.append(chr(0))
            l.reverse() 
            return six.b(''.join(l))

        def compute_hkdf(ikm, salt):
            """
            Standard hkdf algorithm
            :param {Buffer} ikm Input key material.
            :param {Buffer} salt Salt value.
            :return {Buffer} Strong key material.
            @private
            """
            info_bits = bytearray('Caldera Derived Key', 'utf-8')
            prk = hmac.new(salt, ikm, hashlib.sha256).digest()
            info_bits_update = info_bits + bytearray(chr(1), 'utf-8')
            hmac_hash = hmac.new(prk, info_bits_update, hashlib.sha256).digest()
            return hmac_hash[:16]

        def process_challenge(self, bytes_s, bytes_B):

            self.s = srp._pysrp.bytes_to_long( bytes_s )
            self.B = srp._pysrp.bytes_to_long( bytes_B )

            N = self.N
            g = self.g
            k = self.k

            hash_class = self.hash_class

            # SRP-6a safety check
            if (self.B % N) == 0:
                return None

            self.u = srp._pysrp.H( hash_class, self.A, self.B, width=len(long_to_bytes(N)) )

            # SRP-6a safety check
            if self.u == 0:
                return None

            self.x = srp._pysrp.gen_x( hash_class, self.s, self.I, self.p )
            self.v = pow(g, self.x, N)
            self.S = pow((self.B - k*self.v), (self.a + self.u*self.x), N)

            hkdf = compute_hkdf(long_to_bytes(self.S),
                                long_to_bytes(self.u))
            return hkdf

        # patch pysrp with our hacked-up functions
        srp._pysrp.long_to_bytes = long_to_bytes
        srp._pysrp.User.process_challenge = process_challenge

        custom_n = 'FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD1'\
        '29024E088A67CC74020BBEA63B139B22514A08798E3404DD' \
        'EF9519B3CD3A431B302B0A6DF25F14374FE1356D6D51C245' \
        'E485B576625E7EC6F44C42E9A637ED6B0BFF5CB6F406B7ED' \
        'EE386BFB5A899FA5AE9F24117C4B1FE649286651ECE45B3D' \
        'C2007CB8A163BF0598DA48361C55D39A69163FA8FD24CF5F' \
        '83655D23DCA3AD961C62F356208552BB9ED529077096966D' \
        '670C354E4ABC9804F1746C08CA18217C32905E462E36CE3B' \
        'E39E772C180E86039B2783A2EC07A28FB5C55DF06F4C52C9' \
        'DE2BCBF6955817183995497CEA956AE515D2261898FA0510' \
        '15728E5A8AAAC42DAD33170D04507A33A85521ABDF1CBA64' \
        'ECFB850458DBEF0A8AEA71575D060C7DB3970F85A6E1E4C7' \
        'ABF5AE8CDB0933D71E8C94E04A25619DCEE3D2261AD2EE6B' \
        'F12FFA06D98A0864D87602733EC86A64521F2B18177B200C' \
        'BBE117577A615D6C770988C0BAD946E208E24FA074E5AB31' \
        '43DB5BFCE0FD108E4B82D120A93AD2CAFFFFFFFFFFFFFFFF'
        custom_g = "2"

        usr = srp.User("dummy", getpass.getpass(), hash_alg=srp.SHA256, ng_type=srp.NG_CUSTOM,
                n_hex = custom_n,
                g_hex = custom_g)

        _, A = usr.start_authentication()
        data = {"AuthFlow": "USER_SRP_AUTH",
                "ClientId": self.client_id,
                "AuthParameters": {"USERNAME": self.username,
                    "SRP_A": A.hex()}
                }
        headers = {"X-Amz-Target": "AWSCognitoIdentityProviderService.InitiateAuth",
                "Content-Type": "application/x-amz-json-1.1"
                }
        rsp = requests.post(self.auth_url, headers=headers, json=data)
        if rsp.status_code == 200:
            rsp = rsp.json()
        else:
            raise RuntimeError(f"SRP auth error: {rsp.status_code}, {rsp.content}")

        assert rsp['ChallengeName']=="PASSWORD_VERIFIER"
        challenge = rsp['ChallengeParameters']

        user_id_for_srp = challenge['USER_ID_FOR_SRP']
        usr.I = self.pool_id.split('_')[1]+user_id_for_srp

        salt = challenge['SALT']
        srp_b = challenge['SRP_B']
        secret_block = challenge['SECRET_BLOCK']
        timestamp = datetime.datetime.now(tz=datetime.timezone.utc).strftime("%a %b %d %H:%M:%S %Z %Y")

        hkdf = usr.process_challenge(bytes.fromhex(salt.zfill(32)), bytes.fromhex(srp_b.zfill(768)))

        secret_block_bytes = base64.standard_b64decode(secret_block)
        msg = bytearray(self.pool_id.split('_')[1], 'utf-8') + bytearray(user_id_for_srp, 'utf-8') + \
            bytearray(secret_block_bytes) + bytearray(timestamp, 'utf-8')
        hmac_obj = hmac.new(hkdf, msg, digestmod=hashlib.sha256)
        signature_string = base64.standard_b64encode(hmac_obj.digest()).decode()

        data = {"ChallengeName": "PASSWORD_VERIFIER",
                "ClientId": self.client_id,
                "ChallengeResponses": {"USERNAME": challenge['USERNAME'],
                    "TIMESTAMP": timestamp,
                    "PASSWORD_CLAIM_SECRET_BLOCK": secret_block,
                    "PASSWORD_CLAIM_SIGNATURE": signature_string
                    }
                }
        headers["X-Amz-Target"] = "AWSCognitoIdentityProviderService.RespondToAuthChallenge"

        rsp = requests.post(self.auth_url, headers=headers, json=data)
        if rsp.status_code == 200:
            return rsp.json()
        else:
            raise RuntimeError(f"SRP challenge error: {rsp.status_code}, {rsp.content}")


    def _do_auth_srp_warrant(self):
        logging.info("using warrant-based SRP for initial auth")
        """this uses aws_srp.py from https://github.com/capless/warrant
        """
        from aws_srp import AWSSRP
        aws = AWSSRP(username=self.username, password=getpass.getpass(), pool_id=self.pool_id,
                             client_id=self.client_id, pool_region=self.pool_id.split('_')[0])
        return aws.authenticate_user()


    def _do_auth_password(self):
        logging.info("using password for initial auth")
        data = {"AuthFlow": "USER_PASSWORD_AUTH",
                "ClientId": self.client_id,
                "AuthParameters": {"USERNAME":self.username, "PASSWORD":getpass.getpass()}
                }
        headers = {"X-Amz-Target": "AWSCognitoIdentityProviderService.InitiateAuth",
                "Content-Type": "application/x-amz-json-1.1"
                }
        rsp = requests.post(self.auth_url, headers=headers, json=data)
        if rsp.status_code == 200:
            return rsp.json()
        else:
            raise RuntimeError(f"password authentication error: {rsp.status_code}, {rsp.content}")

    def _auth_refresh(self, refresh_token):
        data = {"AuthFlow": "REFRESH_TOKEN_AUTH",
                "ClientId": self.client_id,
                "AuthParameters": {"REFRESH_TOKEN": refresh_token}
                }
        headers = {"X-Amz-Target": "AWSCognitoIdentityProviderService.InitiateAuth",
                "Content-Type": "application/x-amz-json-1.1"
                }
        rsp = requests.post(self.auth_url, headers=headers, json=data)
        if rsp.status_code == 200:
            return rsp.json()
        else:
            raise RuntimeError(f"token refresh error: {rsp.status_code}, {rsp.content}")

class WorkloadManager():
    """A base class which allows you to encapsulate a list of programs as a workload.
    You should overload the do_stuff() method to handle the creation of programs and processing of results.

    Parameters
    ----------
    soccfg : QickConfig
        Configuration for the device this workload will run on.
    """
    def __init__(self, soccfg):
        self.soccfg = soccfg
        self.proglist = []
        self.progdicts = []
        self.results = None
        self._make_progs()

    def add_program(self, prog):
        """Add a program to the program list.
        This should be called inside do_stuff() when make_progs=True.

        Parameters
        ----------
        prog : QickProgram
            A program to add to the workload
        """
        self.proglist.append(prog)

    def add_acquire(self, prog, save_raw=False, save_shots=False):
        """Add accumulated readout of a program.
        This should be called inside do_stuff() when write_progs=True.

        Parameters
        ----------
        prog : QickProgram
            A program to execute
        save_raw : bool
            Save raw IQ values for each shot.
        save_shots : bool
            Save thresholded values for each shot.
        """
        dump = prog.dump_prog()
        dump['acqtype'] = "accumulated"
        dump['save_raw'] = save_raw
        dump['save_shots'] = save_shots
        self.progdicts.append(dump)

    def add_decimated(self, prog):
        """Add decimated readout of a program.
        This should be called inside do_stuff() when write_progs=True.
        """
        dump = prog.dump_prog()
        dump['acqtype'] = "decimated"
        self.progdicts.append(dump)

    def _make_progs(self):
        """Make all the programs.
        """
        self.do_stuff(make_progs=True)

    def _get_progs(self):
        """Generator function that returns datasets from a results file.
        """
        for prog in self.proglist:
            yield prog

    def write_progs(self, filepath=None):
        """Write all programs to a workload file.

        Parameters
        ----------
        filepath : str or None
            Path for the workload file.
            If provided, write and close the file.
            If None, create and return an open tempfile.

        Returns
        -------
        file or None
            Workload as a temporary file, if filepath was None.
        """
        if filepath is None:
            outfile = tempfile.TemporaryFile()
        else:
            outfile = open(filepath, 'wb')
        self.prog_iterator = self._get_progs()
        self.do_stuff(write_progs=True)
        with gzip.GzipFile(fileobj=outfile, mode='wb') as f:
            f.write(progs2json(self.progdicts).encode())
        if filepath is None:
            return outfile
        else:
            outfile.close()

    def _get_results(self, outf):
        """Generator function that returns datasets from a results file.

        Parameters
        ----------
        outf : h5py.File
            HDF5 results file.
        """
        datagrp = outf["data"]
        for name, proggrp in datagrp.items():
            yield proggrp

    def read_results(self, resultsfile):
        """Iterate through a results file.

        Parameters
        ----------
        resultsfile : str or file
            HDF5 results file path or file object.
        """
        self.prog_iterator = self._get_progs()
        with h5py.File(resultsfile,'r') as outf:
            self.result_iterator = self._get_results(outf)
            self.do_stuff(read_results=True)

    def do_stuff(self, make_progs=False, write_progs=False, read_results=False):
        """Initialize the workload and process results.
        You will not call this method directly; it is called internally at initialization and by write_progs() and read_results().
        For each program you run as part of this workload, you must do the following:

        * If make_progs is True, create a QickProgram and call add_program() to add it to the program list.
          If False, call next(self.prog_iterator) to pop a program from the program list.

        * If write_progs is True, call add_acquire() or add_decimated() to define how you want this program to be run.

        * If read_results is True, call next(self.result_iterator) to pop a dataset from the results file.
          Process the dataset as needed.

        Parameters
        ----------
        make_progs : bool
            Create program objects and fill the program list.
        write_progs : bool
            For each program in the program list, define how to run it and what results to save.
        read_results : bool
            Read and analyze the results file.
        """

class UserClient():
    """Provides a Python API to make requests to the cloud service.
    A configuration file (containing API URLs and a username) is expected at ~/.config/qick.conf or /etc/qick/config.
    A default device ID may also be included in the configuration file.
    """
    def __init__(self):
        configpaths = [os.path.expanduser('~/.config/qick.conf'),
                '/etc/qick/config']

        self.config = ConfigParser()
        self.config.read(configpaths)


        auth = CognitoAuth()
        auth.username = self.config['user']['username']
        auth.auth_url = self.config['service']['cognito_url']
        auth.client_id = self.config['service']['clientid']
        auth.pool_id = self.config['service']['cognito_userpool'] # only needed for SRP

        self.api_endpoint = self.config['service']['api_endpoint']

        self.session = requests.Session()
        self.session.auth = auth

    def add_user(self, email, fullname):
        """Create a user account on the cloud service.
        A suggested config file will be printed.
        The user will get an e-mail with a temporary password.

        Parameters
        ----------
        email : str
            A valid e-mail address for the user, required to be unique
        fullname : str
            A display name for the user, not required to be unique
        """
        data = {
                "Email": email,
                "FullName": fullname
                }
        rsp = self.session.post(self.api_endpoint + '/users', json=data)
        if rsp.status_code == 200:
            print("User successfully added! They should check their e-mail for a temporary password.")
            print()
            print("They should put the following in ~/.config/qick.conf:")
            print("[service]")
            print(f"api_endpoint = {self.api_endpoint}")
            print(f"cognito_url = {self.session.auth.auth_url}")
            print(f"clientid = {self.session.auth.client_id}")
            print(f"cognito_userpool = {self.session.auth.pool_id}")
            print("[user]")
            print(f"username = {email}")

        else:
            logging.warning(f"AddUser API error: {rsp.status_code}, {rsp.content}")

    def add_device(self, device_name, refresh_timeout=60):
        """Create a workload queue on the cloud service.
        Suggested config and credentials files will be printed.

        Parameters
        ----------
        device_name : str
            A display name for the device, not required to be unique
        refresh_timeout : int
            A timeout (in seconds), after which the service will decide the device is offline if it hasn't received a status update.
            The normal update interval for the device client is 5 seconds.
        """
        data = {
                "DeviceName": device_name,
                "RefreshTimeout": refresh_timeout
                }
        rsp = self.session.post(self.api_endpoint + '/devices', json=data)
        if rsp.status_code == 201:
            rsp = rsp.json()
            print("Device successfully added!")
            print()
            print("Put the following in the config file /etc/qick/config:")
            print("[service]")
            print(f"api_endpoint = {self.api_endpoint}")
            print(f"oauth_endpoint = {self.config['service']['oauth_endpoint']}")
            print("[device]")
            print(f"name = {rsp['DeviceName']}")
            print(f"id = {rsp['DeviceId']}")
            print()
            print("If using UserClient for workload submission, the [device] block is needed in the client config as well.")
            print()
            print("Put the following in the device credentials file /etc/qick/credentials:")
            print("[credentials]")
            print(f"id = {rsp['ClientId']}")
            print(f"secret = {rsp['ClientSecret']}")
        else:
            logging.warning(f"AddDevice API error: {rsp.status_code}, {rsp.content}")

    def get_devices(self):
        """Query the cloud service for a list of devices.

        Returns
        -------
        list of dict
            All devices
        """
        rsp = self.session.get(self.api_endpoint + '/devices')
        if rsp.status_code == 200:
            return rsp.json()
        else:
            logging.warning(f"GetDevices API error: {rsp.status_code}, {rsp.content}")
            return None

    def _s3put(self, s3url, payload):
        """Upload a payload to a pre-signed S3 PUT URL.

        Parameters
        ----------
        s3url : str
            Pre-signed S3 URL
        payload : file
            A file to be uplaoded
        """
        rsp = requests.put(s3url, data=payload, headers={'Content-Type': 'application/octet-stream'})
        if rsp.status_code == 200:
            logging.info(f"s3 upload success")
        else:
            logging.warning(f"s3 upload fail: {rsp.status_code}")

    def _s3get(self, s3url):
        """Download a pre-signed S3 GET URL.

        Parameters
        ----------
        s3url : str
            Pre-signed S3 URL

        Returns
        -------
        file
            The downloaded file, as a temporary file
        """
        with requests.get(s3url, stream=True) as rsp:
            if rsp.status_code == 200:
                getfile = tempfile.TemporaryFile()
                shutil.copyfileobj(rsp.raw, getfile)
                getfile.seek(0)
                return getfile
            else:
                logging.warning(f"s3 download fail: {rsp.status_code}")
                return None

    def get_soccfg(self, device_id=None):
        """Query the cloud service for the most recently uploaded configuration of a device.
        The config file is parsed as JSON.

        Parameters
        ----------
        device_id : str or None
            The unique ID of the device.
            If None, the device ID will be read from the user client configuration.

        Returns
        -------
        dict
            Device configuration, to be loaded into a QickCOnfig object
        """
        if device_id is None:
            device_id = self.config['device']['id']
        rsp = self.session.get(self.api_endpoint + '/devices/' + device_id)
        if rsp.status_code == 200:
            logging.info(f"GetDevice response: {rsp.json()}")
            rsp = rsp.json()
            deviceid = rsp['DeviceId']
            devicename = rsp['DeviceName']
            devicestatus = rsp['DeviceStatus']
            lastrefreshed = rsp['LastRefreshed']
            refreshtimeout = rsp['RefreshTimeout']
            configurl = rsp['DeviceConfigurationUrl']
            try:
                cfgfile = self._s3get(configurl)
                devcfg = json.load(cfgfile)
                cfgfile.close()
            except Exception as e:
                logging.warning(f"GetDevice S3 error: {e}")
                return None
            logging.info(f"GetDevice device config from S3: {devcfg}")
            return devcfg
        else:
            logging.warning(f"GetDevice API error: {rsp.status_code}, {rsp.content}")
            return None

    def create_work(self, workloadfile, device_id=None, priority="LOW"):
        """Upload a workload into a device queue on the cloud service.
        The config file is parsed as JSON.

        Parameters
        ----------
        workloadfile : file
            A file-like object to be uploaded to the queue.
        device_id : str or None
            The unique ID of the device.
            If None, the device ID will be read from the user client configuration.
        priority : str
            The priority to be assigned to this workload.
            The valid values are defined by the cloud service.

        Returns
        -------
        str
            Workload ID, for checking status and downloading results
        """
        workloadfile.seek(0)
        if device_id is None:
            device_id = self.config['device']['id']
        data = {
            "DeviceId": device_id,
            "Priority": priority
        }
        rsp = self.session.post(self.api_endpoint + "/workloads", json=data)
        if rsp.status_code == 201:
            logging.info(f"UpdateDevice request: {data}")
            logging.info(f"UpdateDevice response: {rsp.json()}")
            rsp = rsp.json()
            work_id = rsp['WorkId']
            upload_url = rsp['UploadUrl']
            try:
                self._s3put(rsp['UploadUrl'], workloadfile)
                logging.info("Uploaded workload")
                workloadfile.close()
            except Exception as e:
                logging.warning(f"CreateWork S3 error: {e}")
            return work_id
        else:
            logging.warning(f"CreateWork API error: {rsp.status_code}, {rsp.content}")
            return None

    def get_work(self, work_id):
        """Query the cloud service for the status of a workload.

        Parameters
        ----------
        work_id : str
            The workload ID.

        Returns
        -------
        dict
            Information about the workload.
        """
        rsp = self.session.get(self.api_endpoint + '/workloads/' + work_id)
        if rsp.status_code == 200:
            return rsp.json()
        else:
            logging.warning(f"GetWork API error: {rsp.status_code}, {rsp.content}")
            return None

    def wait_until_done(self, work_id, interval=1.0, progress=True):
        """Poll the cloud service until the workload reaches DONE status.

        Parameters
        ----------
        work_id : str
            The workload ID.
        progress : bool
            Print the workload status as it progresses.
        interval : float
            Polling interval (in seconds).
        """
        last_state = None
        while True:
            state = self.get_work(work_id)['WorkStatus']
            if state != last_state:
                if progress:
                    if last_state is not None:
                        print()
                    print("workload is " + state, end='')
                if state == 'DONE':
                    if progress: print()
                    break
            last_state = state
            time.sleep(interval)
            if progress: print('.', end='')

    def get_results(self, work_id):
        """Download workload results from the cloud service.
        If the workload is not in DONE status, raise an error.

        Parameters
        ----------
        work_id : str
            The workload ID.

        Returns
        -------
        file
            A temporary file with the workload results (typically an HDF5 file).
        """
        rsp = self.session.get(self.api_endpoint + '/workloads/' + work_id)
        if rsp.status_code == 200:
            rsp = rsp.json()
            if rsp['WorkStatus'] != 'DONE':
                raise RuntimeError("get_results error: workload is not in DONE status")
            try:
                resultsfile = self._s3get(rsp['WorkloadResultUrl'])
                return resultsfile
            except Exception as e:
                logging.warning(f"GetWork S3 error: {e}")
                return None
        else:
            logging.warning(f"GetWork API error: {rsp.status_code}, {rsp.content}")
            return None


if __name__ == "__main__":
    logging.getLogger().setLevel(logging.WARNING)

    client = UserClient()
    Fire(client)
