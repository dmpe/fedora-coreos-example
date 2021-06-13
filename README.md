# fedora-coreos-example

Fedora CoreOS ignition examples

```{shell}
chmod +x convert.sh
./convert.sh butane.bu

ssh -i ~/.ssh/rancher/id_rsa2 -o StrictHostKeyChecking=no rancher@192.168.226.134
ssh -i ~/.ssh/rancher/id_ed255519_3 -o StrictHostKeyChecking=no rancher@192.168.226.134
```

# Requirenments

1. Installing VMware Workstation
2. Building OVFTools docker container
3. SSH Keys - not the rsa type

# OVFTools

Building tools using <https://github.com/djui/docker-ovftool>

1. Download vmware ovftools binary to `ovftools` folder, from vmware support site

2. Build using:

```
cd ovftools
docker build -t ovftool .
```
