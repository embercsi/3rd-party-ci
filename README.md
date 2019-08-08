# Ember-CSI 3rd party CI system

[Ember-CSI] is a CSI plugin to provision and manage storage for containers, supporting many different storage solutions.

It is impossible for the [Ember-CSI] team to test and validate all these drivers by themselves, and that is why 3rd party CIs are necessary.

Thanks to 3rd party CIs, vendors will be able to run the Ember-CSI gate tests using their own hardware and verify that any code proposed to the [Ember-CSI repository] works fine with their storage system.

## Objective of this repository

This repository will have the necessary documentation, tools, and scripts to provision a 3rd party CI system running on your own machine and with your own storage system that will connect to the [Ember-CSI repository] and be triggered for every pull request to run the tests and post the results on GitHub's pull request.

This 3rd party CI solution is built upon the following requirements:

- Be easy to deploy
- Deployment must be fast
- Require minimum maintenance
- Small footprint: Reduced disk, RAM, and CPU consumption
- CI job definitions in code
- Openness: No hidden pieces, easy to audit everything
- CI should not required a fixed IP
- CI won't require opening ports to the Internet
- No web server required to store and serve logs
- CI will only accept requests coming from GitHub: Signed requests with unique secret
- Low number of pull requests per week

## CI Setup

Setting a 3rd party CI system for Ember-CSI should be pretty straightforward and easy, but if you happen to run into an issue please contact the Ember-CSI team who will be happy to assist you.

There are 3 prerequisites to setup the CI:

- CentOS 7 machine: We recommend using a VM with enabled nested virtualization
- Internet connection
- Git installed: `sudo yum -y install git`

The setup consists of 4 steps:

- Getting the CI configuration
- Deploying the CI
- Testing everything works
- Report back to the Ember-CSI team

### CI configuration

New 3rd party CI systems need to be enabled by the Ember-CSI team, so the first thing you'll have to do is contact them and provide the necessary information for them to set things up.

The information you'll need to provide is:
  + What storage solution you'll be testing
  + A contact email
  + A GitHub Bot account id, if you want to use an existing one.  If one is not provided the team will create one ad hoc for your CI.

The team can be contacted on the [Freenode's #ember-csi IRC channel](https://kiwiirc.com/client/irc.freenode.net/ember-csi), in the [forum](https://groups.google.com/forum/#!forum/embercsi), or <a href="mailto:eng@ember-csi.io">by email at eng@ember-csi.io</a>.

Once the team has this information they will set the webhook, allow the bot account to report status on pull requests, setup the logging branch and give access to it to the bot account.

Once they have set up everything they will send you a couple of files:

- Success pull request webhook message
- Failure pull request webhook message
- CI setup configuration file named `config`

Provided webhook messages will be used to verify that the CI is up an running and can properly execute the tests, report the results, and publish the logs, on pull requests.  One of the pull request will result in a failed test run and the other in a successful test run.

The CI setup configuration file (`config`) is a template that is prefilled with all the information that could be filled by the team, but there is some parameters that only you can set.

- Github token: The token is necessary to send the status result of the test runs and to upload the test run logs. The `GH_TOKEN` will already be configured if the Ember-CSI team setup a bot account for your CI, if you will be using your own bot then [you need to generate a token](https://help.github.com/en/articles/creating-a-personal-access-token-for-the-command-line) with permissions for ` repo:status` and `public_repo`.

- Pre and post run scripts: Scripts to run on the host where the Ember-CSI container under tests is going to execute.  An example where this is useful is if you want to create a random pool in your storage backend specific for this test run as a pre-run step and then you want to delete the pool as a post-run step.  `PRE_RUN` and `POST_RUN` options can be set to a string with the script code itself or with the location of a local file that will be automatically uploaded to the VM running the tests. `POST_RUN` scripts will receive an argument specifying whether the test run was a success or not.

- Driver configuration: Your specific storage configuration for Ember-CSI and is set in the `DRIVER_CONFIG_1` parameter.  You can find more details on how to get the right JSON configuration string in the [Driver Validation article](https://ember-csi.io/post/validation/#driver-configuration-parameters).  There are cases where you may need to dynamically create the configuration (for example if you are creating a random test specific pool), and that is why `DRIVER_CONFIG_1` can be a local script file that will be uploaded sourced to get the driver configuration.  If `DRIVER_CONFIG_1` points to a script file this script must set a `DRIVER_CONFIG` environmental variable with the right JSON configuration string.

There are some useful sample configuration files in the project's repository that can be used as reference: [https://github.com/embercsi/3rd-party-ci/tree/master/examples](https://github.com/embercsi/3rd-party-ci/tree/master/examples).

After making sure that `GH_TOKEN`, `DRIVER_CONFIG_1`, `PRE_RUN_1`, and `POST_RUN_1` are setup to our liking we can proceed to deploy the CI system.

In most cases configuring just 1 backend will be enough, but there may be cases where we want to configure multiple backends, for example if we have an iSCSI and FC driver.  In those cases we can let the Ember team know about it and they will provide a configuration file with the `NUM_DRIVERS` parameter set to the number of drivers we want to run and the necessary `DRIVER_NAME_#` values.  In this case you'll also need to set `DRIVER_CONFIG_#`, `PRE_RUN_#` and `POST_RUN_#` like you did for the first backend.

By default the backends will be tested sequentially, since the default number of workers is 1, but you can make them run in parallel setting the `NUM_WORKERS` parameter to the number of different backend configurations we'll be testing.  Running tests in parallel will require more system resources.

Some drivers need additional files to be present in the running container.  For example the Ceph/RBD driver needs the Ceph cluster configuration file and the credentials.  To support this we must use a script as `DRIVER_CONFIG_#` and this script must create a tar file under `/tmp` and set variable `CSI_SYSTEM_FILES` with the location of this file.  The Ceph example is a good reference of how this can be done.

### Deployment

The current deployment tool is pretty rudimentary.  Only supports CentOS, runs most of the commands as root, builds the container for each pull request, and so on, so we recommend running it in a VM with nested virtualization until we address these limitations.

Setup is very straightforward. Assuming we have uploaded our `config` file and auxiliary scripts (pre-run, post-run, driver-config) to the `./my-config` directory, we would just run:

```
$ git clone --depth 1 https://github.com/embercsi/3rd-party-ci
$ cd 3rd-party-ci/master
$ sudo ./setup-host.sh ../../my-config/config
```

And wait until the setup completes.  It shouldn't take long.

The setup downloads the worker VM's image from dropbox, and you can see how this image has been built in the `3rd-party-ci/worker/create-worker-image.sh` script.  This is done to speed the setup process, as building the image is a slow process, but if you don't want to run an *unknown image* you can audit the build script and build the worker image yourself. The setup will use if it's in the right place.

Building the image can be accomplished like this:

```
$ sudo yum -y install qemu-kvm libvirt libguestfs-tools virt-install
$ sudo systemctl enable --now libvirtd
$ cd 3rd-party-ci/worker
$ sudo IMAGE_LOCATION=/buildbot ./create-worker-image.sh
$ sudo rm /buildbot/centos.qcow2
```

After the `setup-host.sh` script has completed we need to make sure that the webhook forwarder and the CI service are running:

```
$ systemctl status smee
● smee.service - Smee.io client
   Loaded: loaded (/etc/systemd/system/smee.service; static; vendor preset: disabled)
   Active: active (running) since jue 2019-07-25 08:58:34 UTC; 2h 28min ago
 Main PID: 5552 (pysmee)
    Tasks: 7
   CGroup: /system.slice/smee.service
           └─5552 /usr/bin/python3.6 /usr/local/bin/pysmee forward https://smee.io/e2DqiMEezevJYqMu http://localhost:8010/change_hook/github

$ systemctl status buildbot
● buildbot.service - Buildbot Master
   Loaded: loaded (/etc/systemd/system/buildbot.service; enabled; vendor preset: disabled)
   Active: active (running) since jue 2019-07-25 09:05:07 UTC; 2h 22min ago
 Main PID: 5708 (buildbot)
    Tasks: 9
   CGroup: /system.slice/buildbot.service
           ├─5708 /usr/bin/python3.6 /usr/local/bin/buildbot start --nodaemon
           ├─5999 git cat-file --batch-check
           └─6000 git cat-file --batch
```

If the services are not running properly we can check the systemd journal to see what's the issue and contact the Ember-CSI team if necessary:

```
$ sudo journalctl -u smee
$ sudo journalctl -u buildbot
```

We should verify that the buildbot CI web interface is accessible at *http://$CI_IP:8010*

### Testing

There are 2 pull requests in Ember-CSI that have been created with the sole purpose of testing the 3rd party CI systems:

- Proper code: [https://github.com/embercsi/ember-csi/pull/129](https://github.com/embercsi/ember-csi/pull/129)
- Broken code: [https://github.com/embercsi/ember-csi/pull/130](https://github.com/embercsi/ember-csi/pull/130)

Together with the `config` file you will have received two other files called `test-broken` and `test-ok`, which correspond to these 2 pull requests and have been specifically signed to be valid for your CI system.

We'll start with the proper code and send the message directly to the CI system.  Assuming we have the `test-ok` file in `./my-config` in the CI machine we can send it to the CI with: `pysmee send http://localhost:8010/change_hook/github  ./my-config/test-ok`.

Now that we've sent it we can go into the CI builders page at *http://$CI_IP:8010/#/builders* and see that the job has started.  Then we go to the corresponding [pull request](https://github.com/embercsi/ember-csi/pull/129) and confirm that the CI is reporting the status as *"Pending — Build started."*

Once the CI job finishes we should see the *"Build done."* message in the pull request with a *Details* like that includes the logs of the test run.

Now we repeat the process with the `test-broken` and broken code pull request.  In this case the result from the CI job in buildbot's web interface and the status reported to the pull request should be one of failure.

Once these 2 steps have been completed we know that the CI is running fine, now we need to confirm that the webhook forwarder is working fine as well.  For this we'll source the `config` file, send the `test-broken` message directly to the webhook endpoint, and confirm that the CI job has been triggered again:

```
$ bash -c '. .my-config/config; pysmee send https://smee.io/$SMEE_ID ./my-config/test-broken'
```

### Report back

Now that we have the CI up and running we should contact the Ember-CSI team to let them know our CI is ready and provide them with the `DRIVER_CONFIG_1` value we have used, masking all sensitive data such as usernames, passwords, IPs, etc. with somewhat meaningful names such as `"username"`, `"password"`, `"w.x.y.z"` like we have in the other CI configuration examples.

The team will use this information to update the project's documentation with a valid Ember-CSI configuration for your specific backend to serve as reference for users of your backend.

**And with this we are done!!**

## Disclaimer and current limitations

Current Ember-CSI 3rd party CI system is at an early proof of concept stage and as such has its limitations, but we are working to improve the system.

Some of the current limitations are:

- Only CentOS is supported
- Setup code is an ugly and non-robust bash script
- No support for manual job triggering via pull request comments
- Python code to handle jobs can be more robust and cleaner
- No auto-update of the worker VM image
- No CI log rotation
- Inefficient image build: Every jobs build it from scratch and download everything from Internet
- No support for custom requirements/dependencies in the Ember-CSI container

[Ember-CSI]: https://ember-csi.io
[Ember-CSI repository]: https://github.com/embercsi/ember-csi
