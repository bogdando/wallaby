#!/bin/bash

if [[ ! -d ~/ext/tripleo-ansible/roles/tripleo_nova_libvirt ]]; then
    echo "tripleo_nova_libvirt is missing from ~/ext/tripleo-ansible/roles"
    exit 1
fi

INV=~/ext/tripleo-ansible/tripleo_ansible/inventory
PLAY=~/ext/tripleo-ansible/tripleo_ansible/playbooks/deploy-overcloud-compute.yml

cp ansible.cfg ~/ansible.cfg
sudo cp ansible.cfg /root/ansible.cfg

# bash ../init/standalone_ceph_patches.sh nodown import libvirt update kolla
# --tags facts,tripleo_nova_compute

pushd ~
time sudo ansible-playbook -i $INV $PLAY
popd
