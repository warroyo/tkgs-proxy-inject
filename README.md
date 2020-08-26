# TKGs Proxy Injector

This can be used to add a proxy to guest clusters automatically. This will run as a native pod in the supervsior cluster and continously ssh out to the guest cluster nodes and make sure they have a proxy configured. This will run on a per namespace basis due to some limitiations with the default firewall rules applied between namespaces with NSX-T.


## Usage

1. ssh to vcenter and hop into shell
2. copy this repo over to your vcenter 
3. grab the `proxy-inject.tar.gz` from the releases and upload it to your vcenter VM. you can do this scp or if you have internet connection out from vcenter just pull it down to the vm. copy it into the newly created repo directory
4. open `env.sh` and fill in the variables
5. execute `install.sh`


## Vars

all vars are set in `env.sh`

`SV_IPS` -  comma separated list of supervsior management IPs
`DEPLOY_NS` - namespace that the proxy pod will be deployed into
`TKC_HTTPS_PROXY` - valid http proxy that you want to use
`TKC_HTTP_PROXY` - valid https proxy that you want to use
`TKC_NO_PROXY` -  no proxy list
`INTERVAL` - interval to run the script

**NOTE: NOT TESTED FOR PRODUCTION USE**