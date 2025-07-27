#!/usr/bin/env python

import requests
import json
from datetime import datetime
from email.mime.text import MIMEText
import smtplib
import optparse
import sys

def main():
    op = optparse.OptionParser()

    threshold_aqi = 12
    op.add_option("-t", "--threshold", action="store", dest="threshold", help="threshold AQI for alerting")
    (opt, arg) = op.parse_args()
    if opt.threshold:
        threshold_aqi = opt.threshold

    url = "https://api.purpleair.com/v1/sensors/86279?read_key=0NEE91YWQQYUTJCK"
    payload={}
    headers = {
    'X-API-Key': '3461DD66-5111-11EB-9893-42010A8001E8'
    }
    response = requests.request("GET", url, headers=headers, data=payload)
    timestamp = datetime.now()
    aqi = int(json.loads(response.text)["sensor"]["stats"]["pm2.5_10minute"])

    to_list = ['4153126347@vtext.com']
    if timestamp.weekday() in range (0, 4) and timestamp.hour in range (8, 17):
            to_list.append('thad.anders@autodesk.com')
    msg_text = 'AQI {} {{}} threshold {}'.format(aqi, threshold_aqi)
    if aqi > threshold_aqi:
            msg_text = msg_text.format('exceeding')
            print("WARN: {} Kai's House {} {}".format(timestamp.strftime("%Y/%m/%d %H:%M:%S"), msg_text, to_list))
            msg = MIMEText(msg_text)
            sender = 'thad@thad-HP-EliteBook-8540w'
            msg['From'] = sender
            msg['To'] = ', '.join(to_list)
            msg['Subject'] = "Kai's House"
            smtplib.SMTP('localhost').sendmail(sender, to_list, msg.as_string())
    else:
            msg_text = msg_text.format('not exceeding')
            print("INFO: {} Kai's House {}".format(timestamp.strftime("%Y/%m/%d %H:%M:%S"), msg_text))

if __name__ == '__main__':
    sys.exit(main())
