#!/bin/bash

butane_file=$1

FEDORA_VERSION="34.20210529.1.0-vmware.x86_64.ova"
VM_NAME='fcos-node01'
LIBRARY="$HOME/vmware"

sudo rm -rf $LIBRARY/$VM_NAME || true

butane --pretty --strict < $butane_file > butane.ign

BUTANE_CONFIG=$(cat butane.ign | base64 -w0 -)

docker run --rm -it -v $(pwd):/tmp -v $LIBRARY:/$LIBRARY ovftool:latest \
	--powerOffTarget \
	--overwrite \
	--acceptAllEulas \
	--name="${VM_NAME}" \
	--allowExtraConfig \
	--extraConfig:guestinfo.ignition.config.data.encoding="base64" \
    --extraConfig:guestinfo.ignition.config.data="${BUTANE_CONFIG}" \
    /tmp/ova/fedora-coreos-${FEDORA_VERSION} ${LIBRARY}

sudo chmod -R 777 $HOME/vmware/$VM_NAME
sudo chown -R $USER:$USER $HOME/vmware/$VM_NAME

vmrun -T ws upgradevm "$LIBRARY/$VM_NAME/$VM_NAME.vmx"

sed -i 's/rhel7-64/other5xlinux-64/g' $LIBRARY/$VM_NAME/$VM_NAME.vmx
sed -i 's/4096/2048/g' $LIBRARY/$VM_NAME/$VM_NAME.vmx

vmrun -T ws start "$LIBRARY/$VM_NAME/$VM_NAME.vmx"

sleep 25

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null rancher@192.168.226.134


#pwsh -c "Install-Module -Name vmxtoolkit -Force -AcceptLicense"
#pwsh -c "Get-VMX -Path $LIBRARY/$VM_NAME | Set-VMXmemory -Memory 2048"
# Changing guest os is currently missing: https://github.com/bottkars/vmxtoolkit/issues/25
# pwsh -c "Get-VMX -Path $LIBRARY/$VM_NAME | Set-VMXGuestOS -Name other5xlinux-64"