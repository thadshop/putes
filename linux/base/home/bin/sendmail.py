#!/usr/bin/env python
import google_cloud
import sys

def main():
    if len(sys.argv) != 4:
        print('ERROR: "{}" requires exactly 3 positional arguments'.format(sys.argv[0]))
        sys.exit(1)

    gmail = google_cloud.Gmail()
    gmail.send_message(to_addr=sys.argv[1], subj=sys.argv[2], body=sys.argv[3])

if __name__ == '__main__':
    sys.exit(main())
