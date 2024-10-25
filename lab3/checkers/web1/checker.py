#!/usr/bin/env python3

import os
import sys
import copy
from checklib import *

argv = copy.deepcopy(sys.argv)
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

### Import backend will lose 1 argument so we need to deepcopy first ###
# from backend import *

class Checker(BaseChecker):
    def __init__(self, *args, **kwargs):
        super(Checker, self).__init__(*args, **kwargs)
        self.cm = CheckMachine(self)

    def action(self, action, *args, **kwargs):
        try:
            super(Checker, self).action(action, *args, **kwargs)
        except:
            self.cquit(Status.DOWN, "Connection refused", "Connection refused")

    def check(self):
        self.cquit(Status.OK)

    def put(self, flag_id: str, flag: str, vuln: str):
        self.cquit(Status.OK)

    def get(self, flag_id: str, flag: str, vuln: str):
        self.cquit(Status.OK)


if __name__ == '__main__':
    c = Checker(argv[2])

    try:
        c.action(argv[1], *argv[3:])
    except c.get_check_finished_exception():
        cquit(Status(c.status), c.public, c.private)