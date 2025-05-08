#!/usr/bin/bash

set -e

#python3 -m pip install --upgrade pip

if ! pip list | grep virtualenv; then
# install pip and virtualenv package
python3 -m pip install --user --upgrade pip
python3 -m pip install --user virtualenv
fi


if ! ls | grep venv; then
# create virtualenv
python3 -m venv venv

# activate virtualenv and install requirements
source venv/bin/activate
pip install --upgrade pip
pip install -e .
fi
