#!/bin/bash

ansible-playbook playbooks/update-myapp1-website.yaml -i inventory/hosts --key-file /path-to-my-keys/.ssh/id_rsa -K
