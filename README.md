# fedora-coreos-example

Fedora CoreOS ignition examples

```{shell}
chmod +x convert.sh
./convert.sh butane.bu

ssh -i ~/.ssh/rancher/id_rsa2 -o StrictHostKeyChecking=no rancher@192.168.226.134
ssh -i ~/.ssh/rancher/id_ed255519_3 -o StrictHostKeyChecking=no rancher@192.168.226.134
```

# Requirements

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

# Rancher with RKE 2


```
helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
helm fetch rancher-latest/rancher
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm fetch jetstack/cert-manager --version v1.0.4
curl -L -o cert-manager/cert-manager-crd.yaml https://github.com/jetstack/cert-manager/releases/download/v1.0.4/cert-manager.crds.yaml
helm template cert-manager ./cert-manager-v1.0.4.tgz --output-dir . \
    --namespace cert-manager \
    --set image.repository=quay.io/jetstack/cert-manager-controller \
    --set webhook.image.repository=quay.io/jetstack/cert-manager-webhook \
    --set cainjector.image.repository=quay.io/jetstack/cert-manager-cainjector

sudo kubectl create namespace cert-manager
sudo kubectl apply -f cert-manager/cert-manager-crd.yaml
sudo kubectl apply -R -f ./cert-manager

helm template rancher ./rancher-2.5.8.tgz --output-dir . \
    --no-hooks \
    --namespace cattle-system \
    --set hostname=rancher.localhost \
    --set certmanager.version=v1.0.4 \
    --set rancherImage=rancher/rancher \
    --set useBundledSystemChart=true

sudo kubectl create namespace cattle-system
sudo kubectl -n cattle-system apply -R -f ./rancher
```

# Ansible

```
ansible-playbook ansible/main.yml -e 'vcenter_password=xxx'
```