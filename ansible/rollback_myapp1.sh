#!/bin/bash

ansible-playbook playbooks/rollback-myapp1-website.yaml -i inventory/hosts --key-file /path-to-my-keys/.ssh/id_rsa -K
