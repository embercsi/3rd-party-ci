import fnmatch
import os
import socket
import struct
import sys

import config

from twisted.application import service
from twisted.python.log import FileLogObserver
from twisted.python.log import ILogObserver

from buildbot_worker.bot import Worker


def get_gateway(interface=None):
    """Read the default gateway directly from /proc."""
    with open("/proc/net/route") as fh:
        for line in fh:
            fields = line.strip().split()
            if fields[1] != '00000000' or not int(fields[3], 16) & 2:
                continue
            if interface and interface != fields[0]:
                continue
            return socket.inet_ntoa(struct.pack("<L", int(fields[2], 16)))


# setup worker
basedir = '/root/buildbot'
application = service.Application('buildbot-worker')

application.setComponent(ILogObserver, FileLogObserver(sys.stdout).emit)
# and worker on the same process!
workername = getattr(config, 'WORKER_NAME', socket.gethostname())
buildmaster_host = getattr(config, 'ADDRESS', get_gateway('eth0'))
port = int(config.PORT)
passwd = config.PASSWORD

# delete the password from the environ so that it is not leaked in the log
blacklist = getattr(config, 'WORKER_ENVIRONMENT_BLACKLIST', 'WORKERPASS').split()
for name in list(os.environ.keys()):
    for toremove in blacklist:
        if fnmatch.fnmatch(name, toremove):
            del os.environ[name]

keepalive = 600
umask = None
maxdelay = 300
allow_shutdown = None
maxretries = 10

s = Worker(buildmaster_host, port, workername, passwd, basedir,
           keepalive, umask=umask, maxdelay=maxdelay,
           allow_shutdown=allow_shutdown, maxRetries=maxretries)
s.setServiceParent(application)
