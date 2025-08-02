#!/usr/bin/env python

import requests
import json
from datetime import datetime
import optparse
import sys
import keyring
import google_cloud

sensor_indices = {
    "Kai's house": "86279",
    "fox den": "85859"
}
notification_email = '4153126347@vtext.com'
work_days = range (0, 4)   # Monday to Friday
work_hours = range (8, 17) # 8 AM to 4:59 PM
work_email = 'thad.anders@autodesk.com'

def main():
    op = optparse.OptionParser()

    threshold_aqi = 12
    op.add_option("-t", "--threshold", action="store", dest="threshold", help="threshold AQI for alerting")
    op.add_option("-i", "--index", action="store", dest="index", help="sensor index to query")
    op.add_option("-s", "--sensor", action="store", dest="sensor", help="sensor name to query")
    (opt, arg) = op.parse_args()
    if opt.threshold:
        threshold_aqi = opt.threshold
        try:
            threshold_aqi = int(threshold_aqi)
        except ValueError:
            print(f'ERROR: Invalid threshold AQI value: {threshold_aqi}')
            sys.exit(1)
    else:
        threshold_aqi = None
    if opt.sensor:
        sensor_name = opt.sensor
        if sensor_name in sensor_indices:
            sensor_index = sensor_indices[sensor_name]
        else:
            print(f"ERROR: Unknown sensor name '{sensor_name}'. Valid names are: {sensor_indices.keys()}")
            sys.exit(1)
    else:
        if opt.index:
                sensor_index = opt.index
        else:
                sensor_index = "86279"
        sensor_name = next((k for k, v in sensor_indices.items() if v == sensor_index), None) or f'sensor index {sensor_index}'
    response = requests.get(
        url='https://api.purpleair.com/v1/sensors/' + sensor_index,
        headers={'X-API-Key': keyring.get_password('purpleair', 'x_api_key')},
        data={},
        params={'read_key': keyring.get_password('purpleair', 'read_key')}
    )
    timestamp = datetime.now()
    #print(f'DEBUG: response.txt: "{response.text}"')
    aqi = int(json.loads(response.text)["sensor"]["stats"]["pm2.5_10minute"])
    message = f'{timestamp.strftime("%Y/%m/%d %H:%M:%S")} {sensor_name} AQI: {aqi}'
    if threshold_aqi and aqi > threshold_aqi:
        message += f' exceeding threshold {threshold_aqi}'
        print(message)
        to_list = [notification_email]
        if timestamp.weekday() in work_days and timestamp.hour in work_hours:
            to_list.append(work_email)
        gmail = google_cloud.Gmail()
        gmail.send_message(
            to_addr=', '.join(to_list),
            subj=f'PurpleAir {sensor_name} AQI Exceeding Threshold',
            body=message
        )
    else:
         print(message)

if __name__ == '__main__':
    sys.exit(main())
