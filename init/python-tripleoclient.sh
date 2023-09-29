#!/usr/bin/env bash

for D in tripleo-common python-tripleoclient ; do
    pushd ~/$D
    python3 setup.py bdist_egg
    sudo python3 setup.py install --verbose
    popd
done
