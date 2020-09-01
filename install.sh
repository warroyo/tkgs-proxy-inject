#!/bin/bash
set -e

source env.sh


#get all supervisor ips, there may be a better way?
echo "getting supervisor vm creds"

/usr/lib/vmware-wcp/decryptK8Pwd.py > ./sv-info

sv_ip=$(cat ./sv-info | sed -n -e 's/^.*IP: //p')
sv_pass=$(cat ./sv-info| sed -n -e 's/^.*PWD: //p')

#loop over each sv and upload the image tar
set +e
for ip in ${SV_IPS//,/ }
do
echo "copying image tar to ${ip}"
sshpass -p "${sv_pass}" scp -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ./proxy-inject.tar.gz root@"${ip}":./proxy-inject.tar.gz >> /dev/null
if [ $? -eq 0 ] ;
then      
      echo "copied image tar successfully"
else
      echo "error copying image tar to supervisor node ${ip}"
      exit 2
fi
echo "importing image into local registry"
sshpass -p "${sv_pass}" ssh -t -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null  root@"${ip}"  << EOF
docker load -i proxy-inject.tar.gz
docker tag proxy-inject:1.0.0 localhost:5002/vmware/proxy-inject:1.0.0
docker push localhost:5002/vmware/proxy-inject:1.0.0
EOF
if [ $? -eq 0 ] ;
then      
      echo "image loaded successfully"
else
      echo "error loading image into to supervisor node ${ip}"
      exit 2
fi
echo "cleanup image tar"
sshpass -p "${sv_pass}" ssh -t -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null  root@"${ip}"  << EOF
rm ./proxy-inject.tar.gz
EOF
done

echo "injecting environment vars into manifest file"
envsubst < manifest.yml > newman.yml

echo "copying manifest file to supervisor node ${sv_ip}"
sshpass -p "${sv_pass}" scp -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ./newman.yml root@"${sv_ip}":./manifest.yml >> /dev/null
if [ $? -eq 0 ] ;
then      
      echo "manifest copied sucessfully"
else
      echo "error copying manifest into to supervisor node ${ip}"
      exit 2
fi



echo "creating k8s deployment in namespace ${DEPLOY_NS}"
sshpass -p "${sv_pass}" ssh -t -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null  root@"${sv_ip}"  << EOF
kubectl apply -f manifest.yml
EOF
if [ $? -eq 0 ] ;
then      
      echo "manifest applied successfully"
else
      echo "error applying manifest"
      exit 2
fi
