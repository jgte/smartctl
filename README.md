Smartctl wrapper
================

Usage:

`smartctl.sh <smartctl flags(s)>`

or:

`smartctl.sh routine`

or:

`smartctl.sh <device>`

In the first case, the smartctl program is run with the `<smartctl flags(s)>` on all known devices, as determined by the following command:

`sudo parted -l | grep Disk | awk '{print $2}' | sed 's/://g'`

The second case makes successive calls to `smartctl.sh <smartctl flags(s)>`, with the following flags (in this order): `--info`, `--capabilities`, `--health`, `--log=error`, `--log=selftest`, `--test=short` (every 10 days), `--test=long` (every 105 days). This is suitable for the root crontab, with (e.g.)
the following entry:

`export PATH=/usr/bin:/bin:/usr/sbin:/sbin; /some/path/smartctl.sh routine`

The third case runs `smartctl <flag>` sequentially, on the specified deviced, with the following flags (in this order): `--info`, `--capabilities`, `--health`, `--log=error`, `--log=selftest`. It is useful to (e.g.) get SMART information about a new hard drive.