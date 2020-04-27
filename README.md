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
- Low number of pull requests per week

## Repository contents

Name | Description
---|---
`setup.sh` | Setup script for Centos 7
`ci-scripts` | Scripts used by the CI
`user-files` | Templates for CIs to setup their backend configurations
`images` | [Packer] configuration for the VMs used by the CI

[Ember-CSI]: https://ember-csi.io
[Ember-CSI repository]: https://github.com/embercsi/ember-csi
[Packer]: https://www.packer.io/
