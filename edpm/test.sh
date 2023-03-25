#!/bin/bash

OVERVIEW=1
CINDER=0
GLANCE=0
PRINET=0
VM=0
CONSOLE=0
PUBNET=0
FLOAT=0
SEC=0
SSH=0

if [ $OVERVIEW -eq 1 ]; then
   openstack endpoint list
   openstack hypervisor list
   openstack network agent list
   openstack compute service list
fi

if [ $CINDER -eq 1 ]; then
    # echo " --------- Ceph cinder volumes pool --------- "
    # run_on_mon "rbd -p volumes ls -l"
    openstack volume list

    echo "Creating 1 GB Cinder volume"
    openstack volume create --size 1 test-volume
    sleep 10

    echo "Listing Cinder Ceph Pool and Volume List"
    openstack volume list
    # run_on_mon "rbd -p volumes ls -l"
fi

if [ $GLANCE -eq 1 ]; then
    # make sure the glance HTTP service is available
    GLANCE_ENDPOINT=$(openstack endpoint list -f value -c "Service Name" -c "Interface" -c "URL" | grep glance | grep public | awk {'print $3'})
    if [[ $(curl -s $GLANCE_ENDPOINT | grep Unavailable | wc -l) -gt 0 ]]; then
        echo "curl $GLANCE_ENDPOINT returns unavailable (glance broken?)"
        curl -s $GLANCE_ENDPOINT
        exit 1
    fi

    IMG=cirros-0.5.2-x86_64-disk.img
    URL=http://download.cirros-cloud.net/0.5.2/$IMG
    RAW=$(echo $IMG | sed s/img/raw/g)
    if [ ! -f $RAW ]; then
	if [ ! -f $IMG ]; then
	    echo "Could not find qemu image $IMG; downloading a copy."
	    curl -L -# $URL > $IMG
	fi
	echo "Could not find raw image $RAW; converting."
        if [[ ! -e /bin/qemu-img ]]; then
            sudo dnf install qemu-img -y
        fi
	qemu-img convert -f qcow2 -O raw $IMG $RAW
    fi

    # echo " --------- Ceph images pool --------- "
    # echo "Listing Glance Ceph Pool and Image List"
    # run_on_mon "rbd -p images ls -l"
    openstack image list
    
    # echo "Importing $RAW image into Glance"
    # openstack image create cirros --disk-format=raw --container-format=bare < $RAW
    
    # Not using raw for now (no ceph)
    echo "Importing $IMG image into Glance"
    openstack image create cirros --disk-format=qcow2 --container-format=bare < $IMG
    if [ ! $? -eq 0 ]; then 
        echo "Could not import image. Aborting"; 
        exit 1;
    fi

    echo "Listing Glance Ceph Pool and Image List"
    # run_on_mon "rbd -p images ls -l"
    openstack image list
fi

if [ $PRINET -eq 1 ]; then
    openstack network create private --share
    openstack subnet create priv_sub --subnet-range 192.168.0.0/24 --network private
fi

if [ $VM -eq 1 ]; then
    FLAV_ID=$(openstack flavor show c1 -f value -c id)
    if [[ -z $FLAV_ID ]]; then
        openstack flavor create c1 --vcpus 1 --ram 256
    fi
    NOVA_ID=$(openstack server show vm1 -f value -c id)
    if [[ -z $NOVA_ID ]]; then
        openstack server create --flavor c1 --image cirros --nic net-id=private vm1
    fi
    openstack server list
    if [[ $(openstack server list -c Status -f value) == "BUILD" ]]; then
        echo "Waiting one 30 seconds for building server to boot"
        sleep 30
        openstack server list
    fi
    if [ $CONSOLE -eq 1 ]; then
        openstack console log show vm1
    fi
fi

if [ $PUBNET -eq 1 ]; then
    openstack network create public --external --provider-network-type flat --provider-physical-network datacentre
    openstack subnet create pub_sub --subnet-range 192.168.122.0/24 --allocation-pool start=192.168.122.200,end=192.168.122.210 --gateway 192.168.122.1 --no-dhcp --network public
    openstack router create priv_router
    openstack router add subnet priv_router priv_sub
    openstack router set priv_router --external-gateway public
fi

if [ $FLOAT -eq 1 ]; then
    IP=$(openstack floating ip list -f value -c "Floating IP Address")
    if [[ -z $IP ]]; then
        openstack floating ip create public
        IP=$(openstack floating ip list -f value -c "Floating IP Address")
        echo $IP
    else
        echo $IP
    fi
    if [[ -z $IP ]]; then
        openstack server add floating ip vm1 $IP
    fi
    openstack server show vm1
fi

if [ $SEC -eq 1 ]; then
    PROJECT_ID=$(openstack server show vm1 -c project_id -f value)
    if [[ -z $PROJECT_ID ]]; then
        SEC_ID=$(openstack security group list --project $PROJECT_ID -f value -c ID)
        openstack security group rule create \
                  --protocol tcp --ingress --dst-port 22 $SEC_ID
    fi
fi

if [ $SSH -eq 1 ]; then
    if [[ ! -f /usr/bin/sshpass ]]; then
        sudo dnf -y install sshpass
    fi
    IP=$(openstack floating ip list -f value -c "Floating IP Address")
    sshpass -p gocubsgo ssh cirros@$IP "uname -a"
    sshpass -p gocubsgo ssh cirros@$IP "lsblk"
fi
