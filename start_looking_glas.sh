#!/bin/bash

 ls -lh /dev/shm
 sudo chown $USER:kvm /dev/shm/looking-glass
 sudo chmod 660 /dev/shm/looking-glass
looking-glass-client -m KEY_RIGHTCTRL
