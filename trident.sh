#!/bin/bash

sudo sed -i 's/^\(node.session.scan\).*/\1 = manual/' /etc/iscsi/iscsid.conf
sudo mpathconf --enable --with_multipathd y