# Fedora CoreOS @ VMware Workstation

`main.sh` downloads VMware OVA file with Fedora CoreOS and creates virtual machine for lab testing purposes.

Repository contains an ready-to-run example of `butane.bu` (ignition) file which boots up 1 single node VM on VMware Workstation, Virtual Box or Qemu.
Only VMware setup has been tested.

```{shell}
chmod +x main.sh 
./main.sh create --butane butane.bu --stream <testing,stage,next> --type <vmware|virtualbox|qemu>

./main.sh con
```

## Requirements

1. Installing VMware Workstation/VirtualBox/Qemu
2. (For VMware Workstation) Building OVFTools docker container
3. SSH Keys - dont use RSA type due to CoreOS (lack of) support for it.

## OVFTools

Building tools using <https://github.com/djui/docker-ovftool>

1. Download vmware ovftools binary to `ovftools` folder, from vmware support site.

<https://developer.vmware.com/web/tool/4.4.0/ovf>

Store `.bundle` file in `ovftools` folder.

2. Build using:

```
./main.sh build
```

# VMware Troubleshooting

See <https://github.com/mkubecek/vmware-host-modules/> for building host modules.

# Rancher with RKE 2

See `butane.bu` file.

# Ansible for ESXi Servers

Was just for some testing. Not ready for production use - may not work.

```
ansible-playbook ansible/main.yml -e 'vcenter_password=xxx'
```