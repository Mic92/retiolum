#!/usr/bin/env python3

import sys
import datetime
from collections import defaultdict
from typing import DefaultDict, Any

serial = datetime.datetime.now().strftime("%Y%M%d%h")

HEADER = f"""@ 3600 IN SOA r. root.r. {serial} 7200 3600 86400 3600
@ 3600 IN NS ns1
ns1 IN A 10.243.29.174
ns2 IN A 42:0:3c46:70c7:8526:2adf:7451:8bbb
"""


def main() -> None:
    dns: DefaultDict[str, Any] = defaultdict(lambda: defaultdict(dict))
    rdns = {}
    hostsfile = sys.argv[1]
    with open(hostsfile) as f:
        for line in f:
            columns = line.split(" ")
            rdns[columns[0]] = columns[1].strip()
            for name in columns[1:]:
                hostname, tld = name.strip().rsplit(".", 1)
                ip = columns[0]
                record = "AAAA" if ":" in ip else "A"
                dns[tld][hostname][record] = columns[0]

    for zone, hosts in dns.items():
        with open(f"{zone}.zone", "w") as f:
            f.write(HEADER)
            for name, record in hosts.items():
                for rtype, ip in record.items():
                    f.write(f"{name} IN {rtype} {ip}\n")

    with open("240.10.zone", "w") as f:
        f.write(HEADER)
        for ip, name in rdns.items():
            if "." in ip and ip.startswith("10.2"):
                f.write(f"{ip}. IN PTR {name}.\n")

    with open("42.zone", "w") as f:
        f.write(HEADER)
        for ip, name in rdns.items():
            if ":" in ip and ip.startswith("42:"):
                f.write(f"{ip}. IN PTR {name}.\n")


if __name__ == "__main__":
    main()
