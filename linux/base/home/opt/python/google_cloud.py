"""https://developers.google.com/workspace/gmail/api/quickstart/python"""
import yaml
import os
import pickle
import keyring
# Gmail API utils
from googleapiclient.discovery import build
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request
# for encoding/decoding messages in base64
from base64 import urlsafe_b64encode
# for dealing with attachement MIME types
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.mime.image import MIMEImage
from email.mime.audio import MIMEAudio
from email.mime.base import MIMEBase
from mimetypes import guess_type as guess_mime_type

class Gmail:
    def __init__(self):
        with open(os.path.dirname(__file__) + '/google_cloud.config.yaml', 'r', encoding='utf-8') as config_file:
            self.cfg = yaml.safe_load(config_file)['Gmail']

    def authenticate(self):
        creds = None
        # token_pickle stores the user's access and refresh tokens, and is
        # created automatically when the authorization flow completes for the first time.
        if os.path.exists(self.cfg['token_pickle']):
            with open(self.cfg['token_pickle'], 'rb') as token:
                creds = pickle.load(token)
        # If there are no (valid) credentials, login via web browser shall be prompted.
        if not creds or not creds.valid:
            if creds and creds.expired and creds.refresh_token:
                creds.refresh(Request())
            else:
                flow = InstalledAppFlow.from_client_config(
                client_config={
                    'installed': {
                    'client_id': keyring.get_password(self.cfg['krg_svc'], 'client_id'),
                    'client_secret': keyring.get_password(self.cfg['krg_svc'], 'client_secret'),
                    'redirect_uris': self.cfg['redirect_uris'],
                    'auth_uri': self.cfg['auth_uri'],
                    'token_uri': self.cfg['token_uri']
                    }
                },
                scopes=self.cfg['scopes'])
                creds = flow.run_local_server(port=0)
            # save the credentials for the next run
            with open(self.cfg['token_pickle'], 'wb') as token:
                pickle.dump(creds, token)
        return build('gmail', 'v1', credentials=creds)

    def add_attachment(self, message, filename):
        content_type, encoding = guess_mime_type(filename)
        if content_type is None or encoding is not None:
            content_type = 'application/octet-stream'
        main_type, sub_type = content_type.split('/', 1)
        if main_type == 'text':
            fp = open(filename, 'rb')
            msg = MIMEText(fp.read().decode(), _subtype=sub_type)
            fp.close()
        elif main_type == 'image':
            fp = open(filename, 'rb')
            msg = MIMEImage(fp.read(), _subtype=sub_type)
            fp.close()
        elif main_type == 'audio':
            fp = open(filename, 'rb')
            msg = MIMEAudio(fp.read(), _subtype=sub_type)
            fp.close()
        else:
            fp = open(filename, 'rb')
            msg = MIMEBase(main_type, sub_type)
            msg.set_payload(fp.read())
            fp.close()
        filename = os.path.basename(filename)
        msg.add_header('Content-Disposition', 'attachment', filename=filename)
        message.attach(msg)

    def build_message(self, to_addr, subj, body, attachments=[]):
        if not attachments:
            message = MIMEText(body)
        else:
            message = MIMEMultipart()
            message.attach(MIMEText(body))
            for filename in attachments:
                self.add_attachment(message, filename)
        message['to'] = to_addr
        message['from'] = self.cfg['from_addr']
        message['subject'] = subj
        return {'raw': urlsafe_b64encode(message.as_bytes()).decode()}

    def send_message(self, to_addr, subj, body, attachments=[]):
        return self.authenticate().users().messages().send(
          userId="me",
          body=self.build_message(to_addr, subj, body, attachments)
        ).execute()
