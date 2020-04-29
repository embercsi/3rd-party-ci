These are the VM images used by the Ember-CSI third party CI jobs.
They are built using packer.

Existing scripts:

./build-all.sh ==> Build all VM CI images
  ./build.sh ==> Builds the VM images

./upload.sh ==> Uploads all the images to vagrant cloud

Local inspection of images:
```
$ cd boxes
$ vagrant box add test ci-centos7-base.box
$ mkdir 1 && cd 1
$ vagrant init test
$ vagrant up
$ vagrant ssh

# After inspection we have to exit the VM

$ vagrant destroy -f
$ cd ..
$ rm -rf 1

vagrant box remove test
virsh vol-delete test_vagrant_box_image_0.img --pool default
```
