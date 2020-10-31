# nap-demo

This docker-compose builds an NGINX instance in front of two Wordpress containers. The NGINX+ image used has been created based on a trial license. To get a free trial apply under: 

https://www.nginx.com/free-trial-request

To see how to build a NGINX+ image with the new App Protect WAF check my other repo:

https://github.com/dfs5/build-nap-container

--------------------------------------

# Demo Envirnonment

Ubuntu Server 18.04 VM running following docker containers:

- wordpress1 + mysql1 for publishing myapp1.de in Prod environment
- wordpress2 + mysql2 for publishing de.myapp1.de in Dev environment

NGINX steers traffic to the backend containers based on host name and restricts access to some administrative paths for the Prod environment.

NGINX App Protect (NAP) module in NNGINX is used to secure the application. For reference on administering NAP check the official NGINX docs:

https://docs.nginx.com/nginx-app-protect/configuration/

ELK Stack to visualise WAF events.

Optional - For updates or rollbacks between Dev and Prod Ansible playbooks can be run.

------------------------------------

# Preparations

1. Adjust your dns (e.g. hosts file) to access both apps via your VM's IP:
- myapp1.de
- dev.myapp1.de

2. Enable public key authentication for ssh to run Ansible playbooks

$ ssh-keygen

$ ssh-copy-id -i ~/.ssh/mykey user@host

3. Innstall docker pip packages to run Ansible playbooks

$ apt-get install python-pip

$ pip install --upgrade pip

$ pip install docker-compose

4. Allow docker commands to run without sudo

$ sudo groupadd docker

$ sudo usermod -aG docker $USER

Log out and log back in so that your group membership is re-evaluated. If testing on a virtual machine, it may be necessary to restart the virtual machine for changes to take effect.

5. Adjust virtual memory for ELK to start correctly.

max virtual memory areas vm.max_map_count [65530] is too low, increase to at least [262144]

$ sudo nano /etc/sysctl.conf

   vm.max_map_count=262144
   
$ sudo sysctl -p

------------------------------------

# Demo script

$ git clone https://github.com/dfs5/nap-demo.git

$ cd nap-demo

$ docker-compose up -d

$ docker ps

In browser open: https://dev.myapp1.de and follow the Wordpress installation steps.

In browser open: https://myapp1.de to demonstrate that setup has been done only in Dev environment. You should receive "no access for you!" message in your browser.

Now let's run ansible playbook to copy Dev to Prod. This is done from a separate host with Ansible installed. Ansible innstallation is not part of this guide. I have only added my Ansible structure and playbooks for reference.

Under ansible --> inventory -->host make sure you have the right IP and username set:

   xx.xx.xx.xx ansible_user=username    # xx.xx.xx.xx = docker-node-ip

You can run the ansible command from the script below after you updated "path-to-my-keys" in this script:

$ update_myapp1.sh

In browser open: https://myapp1.de to demonstrate that myapp1 has been initially updated.

Now let's verify that WAF policy is up and in blocking mode. You can find the configuration of the policy in waf_pol/wp_01.json

In browser open: https://myapp1.de/?p=<script>

You should see the ASM blocking page.

Finally we want add some visibility. For this we add Kibana dashboard based on this repo but updated to the last release:

https://github.com/MattDierick/f5-waf-elk-dashboards

$ cd f5-waf-elk-dashboards

$ nano logstash/conf.d/30-waf-logs-full-logstash.conf

   hosts => ['localhost:9200']
   
$ docker-compose up -d

It takes a while for ELK stack to get ready. You can verify the start process with:

$ docker logs f5-waf-elk-dashboards_elasticsearch_1

Adjust app_protect_security_log in nginx.conf to point to ELK stack

$ cd ..

$ nano nginx/nginx.conf 

   app_protect_security_log "/home/log_all.json" syslog:server=xx.xx.xx.xx:5144;  #where x = docker node's IP

$ docker-compose down

$ docker-compose up -d

In browser open: http://docker-node-ip:5601

Kibana GUI should load. Select Dashboards in Menue and import both *.ndjson files from Kibana folder
- false-positives-dashboards.ndjson
- overview-dashboard.ndjson

In browser open: https://myapp1.de and browse through the app to generate some traffic.

In browser open: https://myapp1.de/?p=<script> 
and refresh screen view times to generate some blocking events.

Switch bach to Kibana --> Overview --> Dashboards to see the events.

Congratulates!!! - You are done with the Demo

------------------------------------

# Possible Issues

Issue - Ansible playbooks don't run
"msg": "Unable to load docker-compose. Try `pip install docker-compose`.
https://nickjanetakis.com/blog/docker-tip-74-curl-vs-pip-for-installing-docker-compose
"If you use any of Ansible’s docker_* modules, they depend on having the docker and / or docker-compose PIP packages installed..."

$ apt-get install python-pip

$ pip install --upgrade pip

$ pip install docker-compose

------------

Issue - leverage user to sudo when running a playbook
"msg": "Destination nap-demo/nginx_wp/migrate/wp1 not writable"}
use switch -K to run ansible playbook as root

$ ansible-playbook playbooks/update-myapp1-homepage.yaml -i inventory/hosts --key-file /path-to-my-keys/.ssh/id_rsa -K

in playbook add

become: yes

-------------

Issue - lack of permissions to connect docker volume
>> docker logs 5649315d3cb7
bash: /var/log/app_protect/bd-socket-plugin.log: Permission denied
nginx: [error] APP_PROTECT { "event": "configuration_error", "error_message": "failed to open /var/log/app_protect/security.log (Permission denied)", "line_number": 22}

I made it works creating ./logs/app_protect with 777 permission in advance.

sudo chmod -R 777 logs/app_protect/

-------------

Issue - ELK

max virtual memory areas vm.max_map_count [65530] is too low, increase to at least [262144]

$ sudo nano /etc/sysctl.conf

   vm.max_map_count=262144
   
$ sudo sysctl -p

$ docker-compose down

$ docker-compose up -d

-----------------

Issue - ELK

max file descriptors [4096] for elasticsearch process is too low, increase to at least [65535]

The following already added to the docker-compose file:

    ulimits:

      nofile:

         soft: 65536

         hard: 65536
