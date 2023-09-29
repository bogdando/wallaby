#!/usr/bin/env bash
# Clones the repos that I am interested in.
# -------------------------------------------------------
WALLABY=0 # Tripleo-repos will be using Wallaby. But Tripleo must be Zed
gerrit_user='bogdando'
github_user='bogdando'
git config --global user.email "bdobreli@redhat.com"
git config --global user.name "Bohdan Dobrelia"
git config --global push.default simple
git config --global gitreview.username $gerrit_user
# -------------------------------------------------------
if [[ $1 == 'k8s' ]]; then
    pushd ~
    if [[ ! -d nova-operator ]]; then
        git clone git@github.com:$github_user/nova-operator.git
    fi
    popd
    exit 0
fi
# -------------------------------------------------------
if [[ $1 == 'ext' ]]; then
    sudo rm -rf ~/ext
    declare -a repos=(
                      'openstack/tripleo-ansible' \
                      'openstack/ansible-role-chrony' \
    );
fi
# -------------------------------------------------------
if [[ $# -eq 0 ]]; then
    # uncomment whatever you want
    declare -a repos=(
              # 'openstack/tripleo-heat-templates' \
              # 'openstack/tripleo-common'\
              'openstack/tripleo-ansible' \
              # 'openstack/tripleo-validations' \
              # 'openstack/python-tripleoclient' \
              # 'openstack/ansible-role-chrony' \
              # 'openstack-infra/tripleo-ci'\
              # 'openstack/tripleo-specs'\
              # 'openstack/tripleo-docs'\
              # 'openstack/tripleo-quickstart'\
              # 'openstack/tripleo-quickstart-extras'\
              # 'openstack/tripleo-repos'\
              # 'openstack/tripleo-operator-ansible' \
              # add the next repo here
    );
fi
# -------------------------------------------------------

git review --version
if [ $? -gt 0 ]; then
    echo "installing git-review and tox from pip"
    if [[ $(grep 8 /etc/redhat-release | wc -l) == 1 ]]; then
        if [[ ! -e /usr/bin/python3 ]]; then
            sudo dnf install python3 -y
        fi
    fi
    pip
    if [ $? -gt 0 ]; then
        V=$(python3 --version | awk {'print $2'} | awk 'BEGIN { FS = "." } ; { print $2 }')
        if [[ $V -eq "6" ]]; then
            curl https://bootstrap.pypa.io/pip/3.6/get-pip.py -o get-pip.py
        else
            curl https://bootstrap.pypa.io/pip/get-pip.py -o get-pip.py
        fi
        python3 get-pip.py
    fi
fi
pip install git-review tox

if [[ $1 == 'ext' ]]; then
    mkdir -p ~/ext
    pushd ~/ext
else
    pushd ~
fi
for repo in "${repos[@]}"; do
    dir=$(echo $repo | awk 'BEGIN { FS = "/" } ; { print $2 }')
    if [ ! -d $dir ]; then
        git clone https://git.openstack.org/$repo.git
        pushd $dir
        git remote add gerrit ssh://$gerrit_user@review.openstack.org:29418/$repo.git
        git review -s
        if [[ $WALLABY -eq 1 ]]; then
            git fetch origin
            git checkout -b wallaby_stable remotes/origin/stable/wallaby
        fi
        popd
    else
        pushd $dir
        git pull --ff-only origin master
        popd
    fi
done
popd
# -------------------------------------------------------
if [[ $1 == 'ext' ]]; then
    if [[ ! -e /usr/bin/jq ]]; then
        sudo dnf install jq -y
    fi

    # Install and link chrony
    if [[ ! -d ~/roles ]]; then mkdir ~/roles; fi
    ln -s ~/ext/ansible-role-chrony ~/roles/chrony;

    # use eth0, not eth1, for br-ex bridge (neutron_public_interface_name)
    sed -i ~/ext/tripleo-ansible/tripleo_ansible/inventory/02-computes \
        -e s/eth1/eth0/g
fi
