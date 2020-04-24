#!/bin/env python
import json
import os
import sys
import urllib2


if len(sys.argv) != 6:
    sys.stderr.write('Wrong number of arguments:\n\t%s job_name state '
                     'details_url repository commit_sha\n' %
                     os.path.basename(sys.argv[0]))
    exit(1)

job_name, state, details_url, repository, commit_sha = sys.argv[1:]

# We receive gh-actions job status, which is different from old checks status
state = state.lower()
if state == 'cancelled':
    state = 'error'

url = 'https://api.github.com/repos/%s/statuses/%s' % (repository, commit_sha)
data = json.dumps({'context': job_name,
                   'state': state,
                   'target_url': details_url})
print('Sending %s to %s' % (data, url))
headers = {'Authorization': 'token ' + os.environ['TOKEN'],
           'Content-Type': 'application/json'}

req = urllib2.Request(url, data, headers)
error = None
try:
    response = urllib2.urlopen(req)
    result = response.read()
    try:
        result = json.dumps(json.loads(result), indent=4)
    except Exception:
        pass
    print(result)
    if response.code != 201:
        error = 'Status code is %s' % response.code
except Exception as exc:
    error = str(exc)

if error:
    sys.stderr.write('Error sending status change: %s\n' % error)
    exit(1)

print(response.read())
