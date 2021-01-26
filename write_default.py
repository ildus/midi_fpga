#!/usr/bin/env python3

import sys
from struct import pack

with open(sys.argv[1], 'rb+') as f:
    f.seek(0x1ffd80)
    f.write(pack("<BBBB", *bytearray([0xB0, 0x2E, 0x7F, 0x1E])))
    f.write(pack("<BBBB", *bytearray([0xB0, 0x2F, 0x7F, 0x1E])))
    f.write(pack("<BBBB", *bytearray([0xB0, 0x30, 0x7F, 0x1E])))
    f.write(pack("<BBBB", *bytearray([0xB0, 0x31, 0x7F, 0x1E])))
