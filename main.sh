#!/bin/bash

base="$(dirname "$BASH_SOURCE[0]")"

echo $base

_usage() {

  


}

_setup() {
  
  declare -g vm_name library now dc_butane dc_installer dc_ovtftool
  declare -g butane_file coreos_stream virt_type
  declare -a docker_dwn
  docker_dwn=("-C /work/ova/")

  vm_name='fcos-node01'
  library="$HOME/vmware"
  now=$(date +%s)
  dc_butane="quay.io/coreos/butane:release"
  dc_installer="quay.io/coreos/coreos-installer:release"
  dc_ovtftool="ovftool:latest"

  while [ "$#" -ge 0 ]; do
    
      --type) virt_type="$2"; shift;;
    --stream) coreos_stream="$2"; shift;;
    --butane) butane_file="$2"; shift;;
       build|
         con|
      create|\
        action="$2"
  done


  trap _clean

}

_check_download_image() {
  mkdir -p $base/ova  

  if [[ ! $(ls -A ./${form}) ]]; then
      _info "No ova files exist. Downloading now..."
      docker run -v $(base):/work --rm --pull=always \
        $dc_installer download -p ${tp} -f ${form} -s $coreos_stream $(echo ${docker_dwn[@]})

  elif [[ $(find ./${form##.xz} -type f -mtime +5 -print) ]]; then
      _info "File $filename exists and is older than 5 days. Removing..."
      find $base/ova -type f -mtime +5 ! \( -name "*.ova*" -o -name "*.qcoqw2.*" \) -execdir rm -- '{}' \;   
      docker run -v $(base):/work --rm --pull=always \
        $dc_installer download -p ${tp} -f ${form} -s $coreos_stream $(echo ${docker_dwn[@]})
  fi

}



if [[ -z "$butane_file" ]]; then 
    echo "No butane file was passed."
    exit 1
fi

if [[ -z "$coreos_stream" ]]; then 
    echo "No coreos stream was passed."
    exit 1
fi

if [[ -z "$virt_type" ]]; then 
    echo "Select VMware (vm) or VirtualBox (vb) environment."
    exit 1
fi

if [[ "$virt_type" == "vm" ]]; then 
    tp="vmware"
    form="ova"
elif [[ "$virt_type" == "vb" ]]; then
    tp="virtualbox"
    form="ova"
elif [[ "$virt_type" == "qu" ]]; then
    tp="qemu"
    form="qcow2.xz"
    docker_dwn+=("--decompress")

else 
    echo "Aborting"
    exit 1

fi




_convert_butane() {
  sudo rm -rf $library/$vm_name || true
  sudo rm -rf $base/butane.base64
  sudo rm -rf $base/butane.ign

  sed -e "s|inline: hostname|inline: $vm_name|g" $base/$butane_file > "$base/${butane_file}_temp.bu"

  docker run --rm -v $(base):/work --pull=always $dc_butane --pretty --strict /work/${butane_file}_temp.bu > $base/butane.ign

  BUTANE_CONFIG=$(cat $base/butane.ign | base64 -w0 -)
  echo $BUTANE_CONFIG > butane.base64

  COREOS_IMAGES=$(find ./ova -type f ! \( -name "*.ova.sig" -o -name "*.qcoqw2.sig" \))
  echo $COREOS_IMAGES
  FEDORA_VERSION="$(echo ${COREOS_IMAGES} | cut -d "-" -f 3,4)"
}

_vm() {
  _info "Creating VMware variant"
  docker run --rm -it -v $(base):/tmp -v $library:/$library $dc_ovtftool \
    --powerOffTarget \
    --overwrite \
    --disableVerification \
    --acceptAllEulas \
    --name="${vm_name}" \
    --allowExtraConfig \
    --extraConfig:guestinfo.ignition.config.data.encoding="base64" \
    --extraConfig:guestinfo.ignition.config.data="${BUTANE_CONFIG}" \
    /tmp/ova/fedora-coreos-${FEDORA_VERSION} ${library}

  sudo chmod -R 777 $HOME/vmware/$vm_name
  sudo chown -R $USER:$USER $HOME/vmware/$vm_name

  vmrun -T ws upgradevm "$library/$vm_name/$vm_name.vmx"

  sed -i 's/rhel7-64/other5xlinux-64/g' $library/$vm_name/$vm_name.vmx
  sed -i 's/4096/3096/g' $library/$vm_name/$vm_name.vmx

  vmrun -T ws start "$library/$vm_name/$vm_name.vmx"
}

_vb(){
  _info "Creating Virtual Box"
  # https://docs.fedoraproject.org/en-US/fedora-coreos/provisioning-virtualbox/
  VBoxManage import --vsys 0 --vmname "$vm_name" ${COREOS_IMAGES}
  VBoxManage guestproperty set "$vm_name" /Ignition/Config "$(cat $base/butane.ign)"
  VBoxManage modifyvm "$vm_name" --natpf1 "guestssh,tcp,,2222,,22"
  VBoxManage startvm "$vm_name"
}

_qu() {
  _info "Creating Qemu Image"
  # qemu-img create -f qcow2 -b "${COREOS_IMAGES}" "${vm_name}.qcow2"
  sudo qemu-system-x86_64 -m 2048 -cpu max -nographic \
    -drive if=virtio,file=${COREOS_IMAGES} \
    -fw_cfg name=opt/com.coreos/config,file=$base/butane.ign \
    -nic user,model=virtio,hostfwd=tcp::2222-:22
}

_create_image() {

  if [[ "${virt_type}" == "vm" ]]; then
    _vm
  elif [[ "${virt_type}" == "vb" ]]; then
    _vb
  elif [[ "${virt_type}" == "qu" ]]; then
    _qu
  fi
}

_info() {
  # 4= blue
  echo "$(tput setab 4)"$1"$(tput sgr0)"
}

_abort() {
  echo "$(tput bold)$(tput setab 4)"$1"$(tput sgr0)"
  exit 1
}

_connect(){
  ssh -i ~/.ssh/rancher/id_ed25519 -o StrictHostKeyChecking=no rancher@192.168.226.134
}

_ovftool() {
  _info "Assumes that ovftools were already downloaded from VMware"
  mkdir -p $base/ovftools
  docker build $base/ovftools -t $dc_ovtftool
}

_clean() {
  sudo rm -rf $base/${butane_file}_temp.bu
}

_main() {
  _setup "$@"
  _check_download_image

  case "$action" in 
    create) _create_image;;
       con) _connect;;
     build) _ovftool;;
  esac

}

_main "$@"

exit 0