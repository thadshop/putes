#!/usr/bin/env python

"""Use the PurpleAir API to query the AQI for a given sensor
and optionally alert if it exceeds a threshold."""

import json
from datetime import datetime
from argparse import ArgumentParser
import sys
import requests
import keyring
import google_cloud

sensor_indices = {
    "Kai's house": "86279",
    "fox den": "85859"
}
NOTIFICATION_EMAIL = '4153126347@vtext.com'
work_days = range (0, 4)   # Monday to Friday
work_hours = range (8, 17) # 8 AM to 4:59 PM
WORK_EMAIL = 'thad.anders@autodesk.com'

def main():
    """Main function to query AQI and send notifications if needed."""
    ap = ArgumentParser(description="Query PurpleAir sensor AQI "
        "and alert if it exceeds a threshold."
    )
    ap.add_argument("-i", "--index", action="store", dest="index",
        help="sensor index to query"
    )
    ap.add_argument("-s", "--sensor", action="store", dest="sensor",
        help="sensor name to query"
    )
    ap.add_argument("-t", "--threshold", action="store", dest="threshold",
        help="threshold AQI for alerting"
    )
    args = ap.parse_args()
    if args.threshold:
        threshold_aqi = args.threshold
        try:
            threshold_aqi = int(threshold_aqi)
        except ValueError:
            print(f'ERROR: Invalid threshold AQI value: {threshold_aqi}')
            sys.exit(1)
    else:
        threshold_aqi = None
    if args.sensor:
        sensor_name = args.sensor
        if sensor_name in sensor_indices:
            sensor_index = sensor_indices[sensor_name]
        else:
            print(f"ERROR: Unknown sensor name '{sensor_name}'. "
                "Valid names are: {sensor_indices.keys()}")
            sys.exit(1)
    else:
        if args.index:
            sensor_index = args.index
        else:
            sensor_index = "86279"
        sensor_name = next(
            (k for k, v in sensor_indices.items() if v == sensor_index), None
            or f'sensor index {sensor_index}'
        )
    response = requests.get(
        url='https://api.purpleair.com/v1/sensors/' + sensor_index,
        headers={'X-API-Key': keyring.get_password('purpleair', 'x_api_key')},
        data={},
        params={'read_key': keyring.get_password('purpleair', 'read_key')},
        timeout=15
    )
    timestamp = datetime.now()
    #print(f'DEBUG: response.txt: "{response.text}"')
    aqi = int(json.loads(response.text)["sensor"]["stats"]["pm2.5_10minute"])
    message = f'{timestamp.strftime("%Y/%m/%d %H:%M:%S")} {sensor_name} AQI: {aqi}'
    if threshold_aqi and aqi > threshold_aqi:
        message += f' exceeding threshold {threshold_aqi}'
        print(message)
        to_list = [NOTIFICATION_EMAIL]
        if timestamp.weekday() in work_days and timestamp.hour in work_hours:
            to_list.append(WORK_EMAIL)
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
