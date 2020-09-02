#!/bin/bash

# Logging function that will redirect to stderr with timestamp:
logerr() { echo "$(date) ERROR: $@" 1>&2; }
# Logging function that will redirect to stdout with timestamp
loginfo() { echo "$(date) INFO: $@" ;}

if [[ -z "$TKC_HTTP_PROXY" || -z "$TKC_HTTPS_PROXY" || -z "$TKC_NO_PROXY" ]]
  then
    logerr "missing environment vars"
    exit 2
fi

run_interval=${INTERVAL:=30}


function run()
{

  #get the machines
  machines=$(kubectl get virtualmachines -o json)

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
      loginfo "getting ssh key for ${cluster}"
      kubectl get secret ${cluster}-ssh -n ${ns} -o jsonpath="{.data.ssh-privatekey}" | base64 -d > /tmp/sshkey.pem
      chmod 400 /tmp/sshkey.pem

      loginfo "attempting ssh to ${ip}"
      ssh -q -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i /tmp/sshkey.pem vmware-system-user@${ip} << EOF
      sudo -i
      mkdir -p /etc/systemd/system/containerd.service.d
      touch /etc/systemd/system/containerd.service.d/http-proxy.conf
      touch /etc/sysconfig/proxy


      ctd_new_file="/etc/systemd/system/containerd.service.d/http-proxy.conf.new"
      ctd_file="/etc/systemd/system/containerd.service.d/http-proxy.conf"

      echo "creating temp containerd proxy file"

      echo '[Service]' > $ctd_new_file
      echo 'Environment="HTTP_PROXY='${TKC_HTTP_PROXY}'"' >> $ctd_new_file
      echo 'Environment="HTTPS_PROXY='${TKC_HTTPS_PROXY}'"' >> $ctd_new_file
      echo 'Environment="NO_PROXY='${TKC_NO_PROXY}'"' >> $ctd_new_file

      echo "comparing containerd proxy settings"
      if cmp -s "$ctd_new_file" "$ctd_file"; then
          echo "the containerd proxy is already set and unchanged"
      else
          echo "containerd proxy changed updating..."
          mv $ctd_new_file $ctd_file
          systemctl daemon-reload
          systemctl restart containerd
      fi


      sys_file="/etc/sysconfig/proxy"
      sys_new_file="/etc/sysconfig/proxy.new"

      echo "creating temp system proxy file"

      echo 'PROXY_ENABLED="yes"' > $sys_new_file
      echo 'HTTP_PROXY='"'${TKC_HTTP_PROXY}'" >> $sys_new_file
      echo 'HTTPS_PROXY='"'${TKC_HTTPS_PROXY}'" >> $sys_new_file
      echo 'NO_PROXY='"'${TKC_NO_PROXY}'" >> $sys_new_file

      echo "comparing system proxy settings"
      if cmp -s "$sys_file" "$sys_new_file"; then
          echo "the system proxy is already set and unchanged"
      else
          echo "system proxy changed updating..."
          mv $sys_new_file $sys_file
      fi

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
