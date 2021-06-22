# provisioner-localvolume
An external dynamic provisioner for Kubernetes local persistent volumes.

[![Go Report Card](https://goreportcard.com/badge/github.com/kuttiproject/provisioner-localvolume)](https://goreportcard.com/report/github.com/kuttiproject/provisioner-localvolume)
![GitHub release (latest by date)](https://img.shields.io/github/v/release/kuttiproject/provisioner-localvolume?include_prereleases)

## Synopsis
The `local` volume driver, which went stable in Kubernetes 1.14, represents 
a mounted local storage device. It is meant to be used with PersistedVolumes,
and requires the volume to have a node affinity. This project provisions 
such volumes dynamically.

## Implementation
This project uses the [sig-storage-lib-external-provisioner](https://github.com/kubernetes-sigs/sig-storage-lib-external-provisioner) library. It implements the Provisioner 
interface defined in that library, and uses the supplied ProvisionController.

Like any other external provisioner, the project is an executable that runs
in a container provisioned by Kubernetes. It takes two configuration 
parameters: nodename, which is the name of the kubernetes node where it is
scheduled, and rootpath, which is a directory on that node. The project 
creates subdirectories under its rootpath, and exposes these to Kubernetes
as PersistentVolume objects. It attaches a nodeAffinity to these volumes,
using the nodename.

The parameters are passed via environment variables called KUTTI_NODE_NAME
and KUTTI_ROOT_PATH respectively. These are set via a Kubernetes manifest
while deploying this provisioner.

The provisioner adds some annotations to the PersistentVolume objects that
it creates. An instance of the provisioner on a node will only delete
a PersistentVolume that was created by the provisioner on the same node. So,
if the provisioner somehow gets rescheduled on a different node, any 
PersistentVolume objects created on the original node will not be deleted
dynamically. They will continue to work as normal, and may be manually deleted
as per the normal rules.

The reference implementation is published on the Docker Hub, as an image 
called kuttiproject/provisioner-localvolume:<version>. The corresponding
Kubernetes manifest file can be found in this repository, as 
deploy/provisioner-localvolume/provisioner.yaml.

## Manifest file notes
The manifest file includes a ClusterRole and a corresponding ClusterRoleBinding.
This is because the sig-storage-lib-external-provisioner library needs 
update permissions on EndPoint objects.

It uses a Deployment object to deploy the provisioner. The Deployment object
passes the hostname of the deployed node via the environment variable
KUTTI_NODE_NAME (using valueFrom). It also uses the `hostpath` driver to
mount a directory of the node into the container, and passes the path to 
that directory via the environment variable KUTTI_ROOT_PATH.

Finally, it includes two StorageClass objects, with volumeReclaimPolicies of
Delete and Retain, and marks the first one as default.
