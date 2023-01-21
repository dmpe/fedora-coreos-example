#!/bin/bash
set -eo pipefail

base="$(dirname $(readlink -f "$BASH_SOURCE[0]"))"

_info() {
  # 4 = blue background
  echo "$(tput setab 4)"$1"$(tput sgr0)"
}

_abort() {
  echo "$(tput bold)$(tput setab 4)"$2"$(tput sgr0)"
  exit "$1"
}

_connect(){
  ssh -i ~/.ssh/rancher/id_ed25519 -o StrictHostKeyChecking=no "core@${ip}"
}

_info "Script location: $base"

_usage() {
cat << EOF 
  "${BASH_SOURCE[0]}" <action> <parameters>

actions:
  create --type --butane --stream              Create and start CoreOS image.
  build                                        Create docker image wit ovftools for --type vmware
  con                                          Connect using SSH to the CoreOS image

parameters:
  --type          <vmware|virtualbox|qemu>     Start image using Workstation, VirtBox, or Qemu emulator
  --stream        <testing|next|stable>        CoreOS stream: 
  --butane                                     Location to the Butane file
  --ip                                         Pass IP address to connect to the VM
EOF
  exit "$1"
}

_setup() {

  declare -g vm_name library now dc_butane dc_installer dc_ovtftool action
  declare -g butane_file coreos_stream virt_type ip
  declare -g -a docker_dwn
  docker_dwn=("-C /work/ova/")
  
  vm_name='fcos-node01'
  library="$HOME/vmware"
  now=$(date +%s)
  dc_butane="quay.io/coreos/butane:release"
  dc_installer="quay.io/coreos/coreos-installer:release"
  dc_ovtftool="ovftool:latest"

}

_check_args() {
  while [[ $# -gt 0 ]]; do
    case "${1}" in
      --type) virt_type="$2"; shift;;
    --stream) coreos_stream="$2"; shift;;
    --butane) butane_file="$2"; shift;;
        --ip) ip="$2"; shift;;
   -h|--help) _usage 0;;
       build|\
         con|\
      create) action="$1";;
           *) _abort 1 "Unsupported action";;
    esac
    [[ $# -gt 0 ]] && shift
  done

  trap _clean EXIT
  true
}

_ovftool() {
  _info "Assumes that ovftools were already downloaded from VMware"
  mkdir -p $base/ovftools
  docker build $base/ovftools -t $dc_ovtftool
}

_clean() {
  sudo rm -rf $base/${butane_file}_temp.bu
}

_abort_if_params_missing() {
  if [[ -z "$butane_file" ]]; then 
    _abort 1 "No butane file was passed."
  fi

  if [[ -z "$coreos_stream" ]]; then 
    _abort 1 "No coreos stream was passed."
  fi

  if [[ -z "$virt_type" ]]; then 
    _abort 1 "Select VMware (vm) or VirtualBox (vb) environment."
  fi
}

_create_image() {
  _abort_if_params_missing

  if [[ "$virt_type" == "vmware" ]] || [[ "$virt_type" == "virtualbox" ]]; then
    form="ova"
  elif [[ "$virt_type" == "qemu" ]]; then
    form="qcow2.xz"
    docker_dwn+=("--decompress")
  else 
    _abort 1 "Aborting"
  fi

  _check_download_image "$virt_type" "$form"
  _convert_butane

  if [[ "${virt_type}" == "vmware" ]]; then
    _vm
  elif [[ "${virt_type}" == "virtualbox" ]]; then
    _vb
  elif [[ "${virt_type}" == "qemu" ]]; then
    _qu
  fi
}

_check_download_image() {
  local _ova_path=$base/ova
  mkdir -p $_ova_path

  if [[ ! $(ls -A $_ova_path/*.${2}) ]]; then
    _info "No ova files exist. Downloading now..."
    docker run -v $base:/work --rm --pull=always \
      $dc_installer download -p ${1} -f ${2} -s $coreos_stream $(echo "${docker_dwn[@]}")

  elif [[ $(find $_ova_path/*.${2##.xz} -type f -mtime +5 -print) ]]; then
    _info "File $filename exists and is older than 5 days. Removing..."
    find $base/ova -type f -mtime +5 ! \( -name "*.ova*" -o -name "*.qcoqw2.*" \) -execdir rm -- '{}' \;   
    docker run -v $base:/work --rm --pull=always \
      $dc_installer download -p ${1} -f ${2} -s $coreos_stream $(echo "${docker_dwn[@]}")

  fi
}

_convert_butane() {
  _info "Converting $butane_file into ignition file."

  sudo rm -rf $library/$vm_name || true
  sudo rm -rf $base/butane.base64
  sudo rm -rf $base/butane.ign

  sed -e "s|inline: hostname|inline: $vm_name|g" $base/$butane_file > "$base/${butane_file}_temp.bu"

  docker run --rm -v $base:/work --pull=always $dc_butane \
    --pretty --strict /work/${butane_file}_temp.bu > $base/butane.ign

  butane_config=$(cat $base/butane.ign | base64 -w0 -)
  echo $butane_config > $base/butane.base64

  coreos_images=$(find ./ova -type f ! \( -name "*.ova.sig" -o -name "*.qcoqw2.sig" \))
  echo $coreos_images
}

_vm() {
  _info "Creating VMware variant"
  local _fedora_version
  _fedora_version="$(echo ${coreos_images} | cut -d "-" -f 3,4)"

  docker run --rm -it -v $base:/tmp -v $library:/$library $dc_ovtftool \
    --powerOffTarget \
    --overwrite \
    --disableVerification \
    --acceptAllEulas \
    --name="${vm_name}" \
    --allowExtraConfig \
    --extraConfig:guestinfo.ignition.config.data.encoding="base64" \
    --extraConfig:guestinfo.ignition.config.data="${butane_config}" \
    /tmp/ova/fedora-coreos-${_fedora_version} ${library}

  sudo chmod -R 777 $HOME/vmware/$vm_name
  sudo chown -R $USER:$USER $HOME/vmware/$vm_name

  vmrun -T ws upgradevm "$library/$vm_name/$vm_name.vmx"

  sed -i 's/4096/2096/g' $library/$vm_name/$vm_name.vmx

  vmrun -T ws start "$library/$vm_name/$vm_name.vmx"
}

_vb(){
  _info "Creating Virtual Box - not tested"
  # https://docs.fedoraproject.org/en-US/fedora-coreos/provisioning-virtualbox/
  VBoxManage import --vsys 0 --vmname "$vm_name" ${coreos_images}
  VBoxManage guestproperty set "$vm_name" /Ignition/Config "$(cat $base/butane.ign)"
  VBoxManage modifyvm "$vm_name" --natpf1 "guestssh,tcp,,2222,,22"
  VBoxManage startvm "$vm_name"
}

_qu() {
  _info "Creating Qemu Image - not tested"
  # qemu-img create -f qcow2 -b "${coreos_images}" "${vm_name}.qcow2"
  sudo qemu-system-x86_64 -m 2048 -cpu max -nographic \
    -drive if=virtio,file=${coreos_images} \
    -fw_cfg name=opt/com.coreos/config,file=$base/butane.ign \
    -nic user,model=virtio,hostfwd=tcp::2222-:22
}

_main() {
  _setup 
  _check_args "$@"

  case "$action" in 
    create) _create_image;;
       con) _connect;;
     build) _ovftool;;
  esac

}

_main "$@"

exit 0
