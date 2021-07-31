#!/bin/bash

butane_file=$1

if [[ -z "$butane_file" ]]; then 
    echo "No butane file was passed."
    exit 1
fi

now=$(date +%s)

if [[ ! $(ls -A ./ova) ]]; then
    echo "No ova files exist. Downloading now..."
    docker run -v $(pwd):/work --rm --pull=always quay.io/coreos/coreos-installer:release download -p vmware -f ova -s next -C /work/ova/

elif [[ $(find ./ova -type f -mtime +10 -print) ]]; then
    echo "File $filename exists and is older than 100 days. Removing"
    find ./ova -type f -mtime +10 -name '*.ova' -execdir rm -- '{}' \;   
    docker run -v $(pwd):/work --rm --pull=always quay.io/coreos/coreos-installer:release download -p vmware -f ova -s next -C /work/ova/
fi

coreos_images=$(find ./ova -type f -name "*.ova")
image_mod_time=$(stat -c "%Y" $coreos_images)

FEDORA_VERSION="$(echo ${coreos_images} | cut -d "-" -f 3,4)"
VM_NAME='fcos-node01'
LIBRARY="$HOME/vmware"

sudo rm -rf $LIBRARY/$VM_NAME || true

sudo rm -rf butane.ign

docker run --rm -v $(pwd):/work --pull=missing quay.io/coreos/butane:release --pretty --strict /work/$butane_file > butane.ign

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

