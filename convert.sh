#!/bin/bash

butane_file=$1
now=$(date +%s)
download_again=false

if [[ $(find ./ova -type f -mtime +10 -print) ]]; then
	echo "File $filename exists and is older than 100 days. Removing"
	find ./ova -type f -mtime +10 -name '*.ova' -execdir rm -- '{}' \;   
	download_again=true
fi


if [[ $download_again == true ]]; then
    docker run -v $(pwd):/work --rm --pull=always quay.io/coreos/coreos-installer:release download -p vmware -f ova -s next -C /work/ova/
fi  


coreos_images=$(find ./ova -type f -name "*.ova")
image_mod_time=$(stat -c "%Y" $coreos_images)

FEDORA_VERSION="$(echo ${coreos_images} | cut -d "-" -f 3,4)"
# FEDORA_VERSION="33.20210328.3.0-vmware.x86_64.ova"
VM_NAME='fcos-node01'
LIBRARY="$HOME/vmware"

sudo rm -rf $LIBRARY/$VM_NAME || true

sudo rm -rf butane.ign
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

# sleep 25

# ssh -i ~/.ssh/rancher/id_ed25519 -o StrictHostKeyChecking=no rancher@192.168.226.134


#pwsh -c "Install-Module -Name vmxtoolkit -Force -AcceptLicense"
#pwsh -c "Get-VMX -Path $LIBRARY/$VM_NAME | Set-VMXmemory -Memory 2048"
# Changing guest os is currently missing: https://github.com/bottkars/vmxtoolkit/issues/25
# pwsh -c "Get-VMX -Path $LIBRARY/$VM_NAME | Set-VMXGuestOS -Name other5xlinux-64"
