#!/bin/bash

# Logging function that will redirect to stderr with timestamp:
logerr() { echo "$(date) ERROR: $@" 1>&2; }
# Logging function that will redirect to stdout with timestamp
loginfo() { echo "$(date) INFO: $@" ;}



run_interval=${INTERVAL:=30}


function inject_ca()
{
  touch /etc/ssl/certs/regcert.pem
  echo "checking if cert exists"
  if cmp -s "/etc/ssl/certs/regcert.pem.new" "/etc/ssl/certs/regcert.pem"; then
      echo "the cert already exists and has not changed"
  else
      echo "updating the certs"
      mv /etc/ssl/certs/regcert.pem.new /etc/ssl/certs/regcert.pem
      /usr/bin/rehash_ca_certificates.sh
      systemctl restart containerd
      echo "certs updated!"
  fi

}

# function insecure_reg() {
# #TODO
# }

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
      chmod 600 /tmp/sshkey.pem

      loginfo "attempting ssh to ${ip}"
      ssh -q -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i /tmp/sshkey.pem vmware-system-user@${ip} << EOF
      sudo -i
      if [[ -z "${TKC_HTTP_PROXY}" || -z "${TKC_HTTPS_PROXY}" || -z "${TKC_NO_PROXY}" ]]
      then
        echo no PROXY vars set skipping proxy...
      else
        mkdir -p /etc/systemd/system/containerd.service.d
        touch /etc/systemd/system/containerd.service.d/http-proxy.conf
        touch /etc/sysconfig/proxy


        echo "creating temp containerd proxy file"

        echo '[Service]' > /etc/systemd/system/containerd.service.d/http-proxy.conf.new
        echo 'Environment="HTTP_PROXY='${TKC_HTTP_PROXY}'"' >> /etc/systemd/system/containerd.service.d/http-proxy.conf.new
        echo 'Environment="HTTPS_PROXY='${TKC_HTTPS_PROXY}'"' >> /etc/systemd/system/containerd.service.d/http-proxy.conf.new
        echo 'Environment="NO_PROXY='${TKC_NO_PROXY}'"' >> /etc/systemd/system/containerd.service.d/http-proxy.conf.new

        echo "comparing containerd proxy settings"
        if cmp -s "/etc/systemd/system/containerd.service.d/http-proxy.conf.new" "/etc/systemd/system/containerd.service.d/http-proxy.conf"; then
            echo "the containerd proxy is already set and unchanged"
        else
            echo "containerd proxy changed updating..."
            mv /etc/systemd/system/containerd.service.d/http-proxy.conf.new /etc/systemd/system/containerd.service.d/http-proxy.conf
            systemctl daemon-reload
            systemctl restart containerd
        fi


        echo "creating temp system proxy file"

        echo 'PROXY_ENABLED="yes"' > /etc/sysconfig/proxy.new
        echo 'HTTP_PROXY='"'${TKC_HTTP_PROXY}'" >> /etc/sysconfig/proxy.new
        echo 'HTTPS_PROXY='"'${TKC_HTTPS_PROXY}'" >> /etc/sysconfig/proxy.new
        echo 'NO_PROXY='"'${TKC_NO_PROXY}'" >> /etc/sysconfig/proxy.new

        echo "comparing system proxy settings"
        if cmp -s "/etc/sysconfig/proxy" "/etc/sysconfig/proxy.new"; then
            echo "the system proxy is already set and unchanged"
        else
            echo "system proxy changed updating..."
            mv /etc/sysconfig/proxy.new /etc/sysconfig/proxy
        fi
      fi

      if [[ -z "${REG_CERT}" ]]
      then
        echo no CA cert providied skipping cert injection...
      else
       $(typeset -f inject_ca)
       echo "${REG_CERT}" | base64 -d > /etc/ssl/certs/regcert.pem.new
       inject_ca
      fi


EOF

  if [ $? -eq 0 ] ;
  then  
        loginfo "script ran successfully!"
  else
        logerr "There was an error running the script Exiting..."
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
