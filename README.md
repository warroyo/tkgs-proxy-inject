# TKGs Proxy Injector

This can be used to add a proxy and/or a CA cert to guest clusters automatically. This will run as a native pod in the supervsior cluster and continously ssh out to the guest cluster nodes and make sure they have the proxy and cert configured.When using this with VDS networking the pod will run on the control plane since natiev pods are unavailable. This will run on a per namespace basis due to some limitiations with the default firewall rules applied between namespaces with NSX-T. This also leverages the `docker-registry` running in the supervisor cluster to store the `proxy-inject` docker image to reduce external dependencies on internal regsitries existing.


## Usage

1. ssh to vcenter and hop into shell
2. *** be sure to do a DCLI login otherwise the script will hang waiting for a password ***
3. copy this repo over to your vcenter 
4. grab the `proxy-inject.tar.gz` from the releases and upload it to your vcenter VM. you can do this scp or if you have internet connection out from vcenter just pull it down to the vm. copy it into the newly created repo directory
5. open `env.sh` and fill in the variables
   1. if you do not want to have a proxy installed and just want to add a cert you can remove the proxy specific vars and it will skip the proxy.
   2. if you do not want a cert to be added you can leave out the `REG_CERT` variable and it will be skipped.
6. execute `install.sh`

## Upgrading

1. ssh to vcenter and hop into shell
2. copy your `env.sh` out of the root repo folder
3. pull down the latest release of the code base to replace the existing one
4. pull down the latest release of `proxy-inject.tar.gz` to replace the existing one
5. copy your `env.sh` back into the root of the repo replacing the default one
6. update any new env vars
7. execute `install.sh`

## Vars

all vars are set in `env.sh`

* `VSPHERE_CLUSTER` -  the vsphere cluster name that wcp is enabled on
* `DEPLOY_NS` - namespace that the proxy pod will be deployed into
* `TKC_HTTPS_PROXY` - valid http proxy that you want to use
* `TKC_HTTP_PROXY` - valid https proxy that you want to use
* `TKC_NO_PROXY` -  no proxy list
* `REG_CERT` -  the registry ca cert to trust an untrusted registry
* `INTERVAL` - interval to run the script


## Authenticated proxies

if your proxy uses auth you can add the username and pass inline in the env var.
ex.

`TKC_HTTPS_PROXY='http://someuser:somepassword@proxy.com'`

if your proxy password has a `$` be sure to escape it. you will need to use `\\` since it needs to be escaped for the k8s manifest as well as for the environment.

ex.
 
`pa\\$sword`

**NOTE: NOT TESTED FOR PRODUCTION USE**