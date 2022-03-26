#!/bin/bash

butane_file=$1
coreos_stream=$2

if [[ -z "$butane_file" ]]; then 
    echo "No butane file was passed."
    exit 1
fi

if [[ -z "$coreos_stream" ]]; then 
    echo "No coreos stream was passed."
    exit 1
fi

now=$(date +%s)

if [[ ! $(ls -A ./ova) ]]; then
    echo "No ova files exist. Downloading now..."
    mkdir -p ova
    docker run -v $(pwd):/work --rm --pull=always \
        quay.io/coreos/coreos-installer:release download -p vmware -f ova -s $coreos_stream -C /work/ova/

elif [[ $(find ./ova -type f -mtime +5 -print) ]]; then
    echo "File $filename exists and is older than 5 days. Removing..."
    find ./ova -type f -mtime +5 -name '*.ova*' -execdir rm -- '{}' \;   
    docker run -v $(pwd):/work --rm --pull=always \
        quay.io/coreos/coreos-installer:release download -p vmware -f ova -s $coreos_stream -C /work/ova/
fi

VM_NAME='fcos-node01'
LIBRARY="$HOME/vmware"

sudo rm -rf $LIBRARY/$VM_NAME || true
sudo rm -rf butane.base64
sudo rm -rf butane.ign

sed -e "s|inline: hostname|inline: $VM_NAME|g" $butane_file > ${butane_file}_temp.bu

docker run --rm -v $(pwd):/work --pull=always quay.io/coreos/butane:release --pretty --strict /work/${butane_file}_temp.bu > butane.ign

BUTANE_CONFIG=$(cat butane.ign | base64 -w0 -)
echo $BUTANE_CONFIG > butane.base64

COREOS_IMAGES=$(find ./ova -type f -name "*.ova")
FEDORA_VERSION="$(echo ${COREOS_IMAGES} | cut -d "-" -f 3,4)"

docker run --rm -it -v $(pwd):/tmp -v $LIBRARY:/$LIBRARY ovftool:latest \
    --powerOffTarget \
    --overwrite \
    --disableVerification \
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
sed -i 's/4096/3096/g' $LIBRARY/$VM_NAME/$VM_NAME.vmx

vmrun -T ws start "$LIBRARY/$VM_NAME/$VM_NAME.vmx"

# sudo rm -rf ${butane_file}_temp.bu

# sleep 25

# ssh -i ~/.ssh/rancher/id_ed25519 -o StrictHostKeyChecking=no rancher@192.168.226.134

