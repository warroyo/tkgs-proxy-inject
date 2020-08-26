#!/bin/bash

# Logging function that will redirect to stderr with timestamp:
logerr() { echo "$(date) ERROR: $@" 1>&2; }
# Logging function that will redirect to stdout with timestamp
loginfo() { echo "$(date) INFO: $@" ;}

if [[ -z "$TKC_HTTP_PROXY" || -z "$TKC_HTTPS_PROXY" || -z "$TKC_NO_PROXY" || -z "$ALL_NAMESPACES" ]]
  then
    logerr "missing environment vars"
    exit 2
fi

all=""
if [  $ALL_NAMESPACES = "true" ]
  then
    all="-A"
fi

run_interval=${INTERVAL:=30}



function run()
{

  #get the machines
  machines=$(kubectl get virtualmachines ${all} -o json)

  for row in $(echo "${machines}" | jq -r '.items[] | @base64'); do
      _jq() {
      echo ${row} | base64 -d | jq -r ${1}
      }
      loginfo "-------------------"
      #get the namespace 
      ns=$(_jq '.metadata.namespace')
      loginfo "namespace: ${ns}"

      #get the cluster name for the machine
      cluster=$(_jq '.metadata.labels."capw.vmware.com/cluster.name"')
      loginfo "cluster: ${cluster}"

      #get the ip for the machine
      ip=$(_jq '.status.vmIp')
      loginfo "ip: ${ip}"

      #get the secret for the machine and create a file
      kubectl get secret ${cluster}-ssh -n ${ns} -o jsonpath="{.data.ssh-privatekey}" | base64 -d > /tmp/sshkey.pem
      chmod 400 /tmp/sshkey.pem


      ssh -q -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i /tmp/sshkey.pem vmware-system-user@${ip} << EOF
      whoami
      # if [ ! -f /etc/systemd/system/containerd.service.d/http-proxy.conf ]; then
      #     echo "no proxy set, configuring"

      #     sudo -i
      #     echo '[Service]' > /etc/systemd/system/containerd.service.d/http-proxy.conf
      #     echo 'Environment="HTTP_PROXY='${TKC_HTTP_PROXY}'"' >> /etc/systemd/system/containerd.service.d/http-proxy.conf
      #     echo 'Environment="HTTPS_PROXY='${TKC_HTTPS_PROXY}'"' >> /etc/systemd/system/containerd.service.d/http-proxy.conf
      #     echo 'Environment="NO_PROXY='${TKC_NO_PROXY}'"' >> /etc/systemd/system/containerd.service.d/http-proxy.conf
      #     echo 'PROXY_ENABLED="yes"' > /etc/sysconfig/proxy
      #     echo 'HTTP_PROXY="'${TKC_HTTP_PROXY}'"' >> /etc/sysconfig/proxy
      #     echo 'HTTPS_PROXY="'${TKC_HTTPS_PROXY}'"' >> /etc/sysconfig/proxy
      #     echo 'NO_PROXY="'${TKC_NO_PROXY}'"' >> /etc/sysconfig/proxy

      #     systemctl restart containerd

      # else
      #     echo "proxy already set"
      # fi

EOF

  if [ $? -eq 0 ] ;
  then  
        loginfo "Proxy added successfully!"
  else
        logerr "There was an error writing the proxy to /etc/systemd/system/containerd.service.d/http-proxy.conf Exiting..."
  fi
loginfo "-------------------"
  done
}

while true
do
    set +e
    echo "running script in a loop"
    run
    sleep $run_interval
done
