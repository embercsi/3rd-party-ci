#!/bin/bash
echo "Installing multipath"
sudo yum install -y device-mapper-multipath
sudo mpathconf --enable --with_multipathd y --user_friendly_names n --find_multipaths y
sudo systemctl enable multipathd
