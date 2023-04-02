package localprovisioner

import (
	"context"
	"os"
	"path"

	"github.com/pkg/errors"
	"golang.org/x/exp/slices"
	corev1 "k8s.io/api/core/v1"
	v1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
	"k8s.io/klog"
	"sigs.k8s.io/sig-storage-lib-external-provisioner/v9/controller"
)

const (
	provisionerName         = "kuttiproject/provisioner-localvolume"
	provisionedByAnnotation = "kuttiproject.org/provisionedBy"
	provisionedOnAnnotation = "kuttiproject.org/provisionedOn"
)

type kuttiLocalProvisioner struct {
	nodeName string // The hostname/nodename where the provisioner runs
	rootPath string // The directory under which volume directories will be created
}

func (p *kuttiLocalProvisioner) ShouldProvision(ctx context.Context, pvc *v1.PersistentVolumeClaim) bool {
	return slices.Contains(pvc.Spec.AccessModes, v1.ReadWriteOnce)
}

func (p *kuttiLocalProvisioner) Provision(ctx context.Context, options controller.ProvisionOptions) (*corev1.PersistentVolume, controller.ProvisioningState, error) {
	defer klog.Flush()

	hostname := p.nodeName

	klog.Infof("Request received for creating a PV called %s on node %s.", options.PVName, hostname)

	// Create a directory
	newvolumepath := path.Join(p.rootPath, options.PVName)
	if err := os.MkdirAll(newvolumepath, 0755); err != nil {
		klog.Errorf("Error creating directory '%v': %v", newvolumepath, err)
		return nil, controller.ProvisioningFinished, err
	}

	// Explicitly chmod created dir, so we know mode is set to 0755
	// regardless of umask
	if err := os.Chmod(newvolumepath, 0755); err != nil {
		klog.Errorf("Could not chmod 0755 directory '%v': %v", newvolumepath, err)
		return nil, controller.ProvisioningFinished, err
	}

	klog.Infof("Directory '%s' created. Now provisioning volume...", newvolumepath)

	// Create the PersistentVolume object with node affinity
	pv := &corev1.PersistentVolume{
		ObjectMeta: metav1.ObjectMeta{
			Name: options.PVName,
			Annotations: map[string]string{
				provisionedByAnnotation: provisionerName,
				provisionedOnAnnotation: hostname,
			},
		},
		Spec: corev1.PersistentVolumeSpec{
			PersistentVolumeReclaimPolicy: *options.StorageClass.ReclaimPolicy,
			AccessModes:                   options.PVC.Spec.AccessModes,
			Capacity: corev1.ResourceList{
				corev1.ResourceStorage: options.PVC.Spec.Resources.Requests[corev1.ResourceStorage],
			},
			PersistentVolumeSource: corev1.PersistentVolumeSource{
				Local: &corev1.LocalVolumeSource{
					Path: newvolumepath,
				},
			},
			NodeAffinity: &corev1.VolumeNodeAffinity{
				Required: &corev1.NodeSelector{
					NodeSelectorTerms: []corev1.NodeSelectorTerm{
						{
							MatchExpressions: []corev1.NodeSelectorRequirement{
								{
									Key:      "kubernetes.io/hostname",
									Operator: "In",
									Values:   []string{p.nodeName},
								},
							},
						},
					},
				},
			},
		},
	}

	klog.Infof("Volume %v created.", options.PVName)

	return pv, controller.ProvisioningFinished, nil
}

func (p *kuttiLocalProvisioner) Delete(ctx context.Context, volume *corev1.PersistentVolume) error {
	defer klog.Flush()

	hostname := p.nodeName

	klog.Infof("Request received for deleting a PV called %s on node %s.", volume.Name, hostname)

	// Sanity check the volume before removing underlying storage
	provisionedby, ok := volume.Annotations[provisionedByAnnotation]
	if !ok || provisionedby != provisionerName {
		klog.Errorf("The persistent volume %s was not created by Kutti Local Volume Dynamic Provisioner. Not deleting it.", volume.Name)
		return &controller.IgnoredError{
			Reason: "persistent volume was not created by Kutti Local Volume Dynamic Provisioner",
		}
	}

	provisionedon, ok := volume.Annotations[provisionedOnAnnotation]
	if !ok || provisionedon != hostname {
		klog.Errorf(
			"The persistent volume %s was created on node %s, but deletion request came to node %s. Not deleting it.",
			volume.Name,
			provisionedon,
			hostname,
		)
		return &controller.IgnoredError{
			Reason: "persistent volume was created on another node.",
		}
	}

	// Remove underlying storage
	volumepath := path.Join(p.rootPath, volume.Name)
	if err := os.RemoveAll(volumepath); err != nil {
		klog.Errorf("Problem removing PV underlying directory %s: %v", volumepath, err)
		return errors.Wrap(err, "problem removing PV source directory "+volumepath)
	}

	klog.Infof("Underlying storage for PV %s deleted.", volume.Name)
	return nil
}

// RunProvisioner creates and runs a provision controller.
func RunProvisioner(ctx context.Context, nodename string, rootpath string) error {
	klog.Infoln("Getting kube config and client...")

	// Get config
	// We will always be running in-cluster
	config, err := rest.InClusterConfig()
	if err != nil {
		klog.Errorln("Could not fetch kube config from cluster.")
		return errors.Wrap(err, "could not fetch kube config from cluster")
	}

	// Create a client from config
	kubeclient, err := kubernetes.NewForConfig(config)
	if err != nil {
		klog.Errorln("Could not create kube client from in-cluster config.")
		return errors.Wrap(err, "could not create kube client from in-cluster config")
	}

	localprovisioner := &kuttiLocalProvisioner{
		nodeName: nodename,
		rootPath: rootpath,
	}

	// Create a controller with provisioner
	pc := controller.NewProvisionController(
		kubeclient,
		provisionerName,
		localprovisioner,
	)

	klog.Infof("Controller created. Details:\n%+v\nRun commencing...", pc)
	klog.Flush()

	pc.Run(ctx)

	return nil
}
