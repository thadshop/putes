#!/usr/bin/env python

import requests, json, google_cloud, optparse, sys,keyring
from datetime import datetime

def main():
    op = optparse.OptionParser()

    threshold_aqi = 12
    op.add_option("-t", "--threshold", action="store", dest="threshold", help="threshold AQI for alerting")
    (opt, arg) = op.parse_args()
    if opt.threshold:
        threshold_aqi = int(opt.threshold)

    response = requests.get(
        url='https://api.purpleair.com/v1/sensors/86279',
        params={'read_key': keyring.get_password('purpleair', 'read_key')},
        headers={'X-API-Key': keyring.get_password('purpleair', 'x_api_key')}
    )
    timestamp = datetime.now()
    aqi = int(json.loads(response.text)["sensor"]["stats"]["pm2.5_10minute"])

    to_list = ['4153126347@vtext.com', 'thadshop@gmail.com']
    if timestamp.weekday() in range (0, 4) and timestamp.hour in range (8, 17):
        to_list.append('thad.anders@autodesk.com')
    msg_text = 'AQI {} {{}} threshold {}'.format(aqi, threshold_aqi)
    if aqi > threshold_aqi:
        msg_text = msg_text.format('exceeding')
        print("WARN: {} Kai's House {} {}".format(timestamp.strftime("%Y/%m/%d %H:%M:%S"), msg_text, to_list))
        gmail = google_cloud.Gmail()
        gmail.send_message(', '.join(to_list), "Kai's House", msg_text)
    else:
        msg_text = msg_text.format('not exceeding')
        print("INFO: {} Kai's House {}".format(timestamp.strftime("%Y/%m/%d %H:%M:%S"), msg_text))


if __name__ == '__main__':
    sys.exit(main())
