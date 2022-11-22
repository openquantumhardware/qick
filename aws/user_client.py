#!/usr/bin/env python3
# standard libraries
import logging
import argparse
import json
import base64
import getpass
import time
import datetime
import sys
import os
from configparser import ConfigParser
# dependencies
import requests
from fire import Fire

class CognitoAuth(requests.auth.AuthBase):
    TOKEN_PATH = os.path.expanduser('~/.cache/qick.tokens')
    def __init__(self):
        self.auth_url = None
        self.client_id = None
        self.username = None
        self.pool_id = None
        self.expire_time = None
        self.tokens = None

        if os.path.exists(self.TOKEN_PATH):
            with open(TOKEN_PATH, 'rt') as f:
                self.update_tokens(json.load(f), replace_tokens=True, write_tokens=False)

    def __call__(self, r):
        """This is called by the Session to set auth headers.
        """
        if self.tokens is None:
            self.initial_auth()

        # if we have less than 60 seconds till expiry, refresh tokens
        if self.expire_time - time.time() < 60:
            self.refresh_auth()

        r.headers['Authorization'] = self.auth_header
        return r

    def update_tokens(self, tokens, replace_tokens=False, write_tokens=True):
        if replace_tokens or self.tokens is None:
            self.tokens = tokens
        else:
            self.tokens.update(tokens)

        access_token = self.tokens['AccessToken']
        # unpack the JWT to get the expiry timestamp
        # JWT uses unpadded base64, need to add dummy padding:
        # https://stackoverflow.com/questions/2941995/python-ignore-incorrect-padding-error-when-base64-decoding
        payload = json.loads(base64.b64decode(access_token.split('.')[1] + '=='))
        self.expire_time = payload['exp']
        self.auth_header = ' '.join([self.tokens['TokenType'], access_token])

        if write_tokens:
            logging.info("writing updated tokens")
            with open(self.TOKEN_PATH, 'wt') as f:
                json.dump(tokens, f)

    def initial_auth(self):
        logging.info("initial auth")
        auth_response = self._do_auth_srp()
        #auth_response = self._do_auth_srp_warrant()
        #auth_response = self._do_auth_password()
        if 'AuthenticationResult' not in auth_response:
            raise RuntimeError("Login failed")
        self.update_tokens(auth_response['AuthenticationResult'], replace_tokens=True)

    def refresh_auth(self):
        logging.info("refreshing tokens")
        refresh_response = self._auth_refresh(self.tokens['RefreshToken'])
        if 'AuthenticationResult' not in refresh_response:
            raise RuntimeError("Login failed")
        # update tokens
        self.update_tokens(refresh_response['AuthenticationResult'])

    def _do_auth_srp(self):
        """this uses pysrp (standard SRP implementation) with patches from warrant (Cognito-specific)
        https://stackoverflow.com/questions/41526205/implementing-user-srp-auth-with-python-boto3-for-aws-cognito
        """
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
            raise RuntimeException(f"SRP auth error: {rsp.status_code}, {rsp.content}")

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
            raise RuntimeException(f"SRP challenge error: {rsp.status_code}, {rsp.content}")


    def _do_auth_srp_warrant(self):
        """this uses aws_srp.py from https://github.com/capless/warrant
        """
        from aws_srp import AWSSRP
        aws = AWSSRP(username=self.username, password=getpass.getpass(), pool_id=self.pool_id,
                             client_id=self.client_id, pool_region=self.pool_id.split('_')[0])
        return aws.authenticate_user()


    def _do_auth_password(self):
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
            raise RuntimeException(f"password authentication error: {rsp.status_code}, {rsp.content}")

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
            raise RuntimeException(f"token refresh error: {rsp.status_code}, {rsp.content}")


class UserClient():
    def __init__(self):
        configpaths = [os.path.expanduser('~/.config/qick/config'),
                '/etc/qick/config']

        self.config = ConfigParser()
        self.config.read(configpaths)


        auth = CognitoAuth()
        auth.client_id = self.config['service']['cognito_clientid']
        auth.username = self.config['user']['username']
        auth.auth_url = self.config['service']['cognito_url']
        auth.pool_id = self.config['service']['cognito_userpool'] # only needed for SRP

        self.api_url = self.config['service']['api_url']

        self.session = requests.Session()
        self.session.auth = auth

    def add_user(self, email, fullname):
        data = {
                "Email": email,
                "FullName": fullname
                }
        rsp = self.session.post(self.api_url + 'users', json=data)
        if rsp.status_code == 200:
            print("User successfully added! They should check their e-mail for a temporary password.")
        else:
            logging.warning(f"AddUser API error: {rsp.status_code}, {rsp.content}")

    def add_device(self, device_name, refresh_timeout=60):
        data = {
                "DeviceName": device_name,
                "RefreshTimeout": refresh_timeout
                }
        rsp = self.session.post(self.api_url + 'devices', json=data)
        if rsp.status_code == 201:
            rsp = rsp.json()
            print("Device successfully added!")
            print()
            print("Put the following in the config file:")
            print("[device]")
            print(f"name = {rsp['DeviceName']}")
            print(f"id = {rsp['DeviceId']}")
            print()
            print("Put the following in the device credentials file:")
            print("[credentials]")
            print(f"id = {rsp['ClientId']}")
            print(f"secret = {rsp['ClientSecret']}")
        else:
            logging.warning(f"AddDevice API error: {rsp.status_code}, {rsp.content}")

    def get_devices(self):
        rsp = self.session.get(self.api_url + 'devices')
        if rsp.status_code == 200:
            return rsp.json()
        else:
            logging.warning(f"GetDevices API error: {rsp.status_code}, {rsp.content}")
            return None


if __name__ == "__main__":
    logging.getLogger().setLevel(logging.WARNING)

    client = UserClient()
    Fire(client)
