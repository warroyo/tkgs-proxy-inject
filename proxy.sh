#!/bin/bash
set -e

if [[ -z "$HTTP_PROXY" || -z "$HTTPS_PROXY" || -z "$NO_PROXY" ]]
  then
    echo "missing proxy environment vars"
    exit 2
fi

#get the machines
machines=$(kubectl get virtualmachines -A -o json)

for row in $(echo "${machines}" | jq -r '.items[] | @base64'); do
    _jq() {
     echo ${row} | base64 --decode | jq -r ${1}
    }

    #get the namespace 
    ns=$(_jq '.metadata.namespace')
    echo "namespace: ${ns}"

    #get the cluster name for the machine
    cluster=$(_jq '.metadata.labels."capw.vmware.com/cluster.name"')
    echo "cluster: ${cluster}"

    #get the ip for the machine
    ip=$(_jq '.status.vmIp')
    echo "ip: ${ip}"

    #get the secret for the machine and create a file
    kubectl get secret ${cluster}-ssh -n ${ns} -o jsonpath="{.data.ssh-privatekey}" | base64 --decode > /tmp/sshkey.pem
    chmod 400 /tmp/sshkey.pem

    set +e
    ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i /tmp/sshkey.pem vmware-system-user@${ip} << EOF
    
    if [ ! -f /etc/systemd/system/containerd.service.d/http-proxy.conf ]; then
        echo "no proxy set, configuring"

        sudo -i
        echo '[Service]' > /etc/systemd/system/containerd.service.d/http-proxy.conf
        echo 'Environment="HTTP_PROXY='${HTTP_PROXY}'"' >> /etc/systemd/system/containerd.service.d/http-proxy.conf
        echo 'Environment="HTTPS_PROXY='${HTTPS_PROXY}'"' >> /etc/systemd/system/containerd.service.d/http-proxy.conf
        echo 'Environment="NO_PROXY='${NO_PROXY}'"' >> /etc/systemd/system/containerd.service.d/http-proxy.conf
        echo 'PROXY_ENABLED="yes"' > /etc/sysconfig/proxy
        echo 'HTTP_PROXY="'${HTTP_PROXY}'"' >> /etc/sysconfig/proxy
        echo 'HTTPS_PROXY="'${HTTPS_PROXY}'"' >> /etc/sysconfig/proxy
        echo 'NO_PROXY="'${NO_PROXY}'"' >> /etc/sysconfig/proxy

        systemctl restart containerd

    else
        echo "proxy already set"
    fi

EOF

if [ $? -eq 0 ] ;
then  
      echo "Proxy added successfully!"
else
      echo "There was an error writing the proxy to /etc/systemd/system/containerd.service.d/http-proxy.conf Exiting..."
      exit 2
fi

done

