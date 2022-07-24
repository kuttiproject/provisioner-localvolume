package main

import (
	"context"
	"flag"
	"os"

	"github.com/kuttiproject/provisioner-localvolume/internal/pkg/localprovisioner"
	"k8s.io/klog"
)

var version string

func main() {
	klog.InitFlags(nil)
	flag.Set("logtostderr", "true")
	flag.Set("stderrthreshold", "INFO")
	flag.Parse()

	klog.Infoln("Kutti Local Volume Dynamic Provisioner")
	klog.Infof("Version: %v", version)

	// Fetch and sanity-check nodename and rootpath
	//   from the environment variables KUTTI_NODE_NAME
	//   and KUTTI_ROOT_PATH respectively.
	nodename := os.Getenv("KUTTI_NODE_NAME")
	if nodename == "" {
		klog.Exit("Could not fetch node name from variable KUTTI_NODE_NAME. Cannot continue.")
	}

	rootpath := os.Getenv("KUTTI_ROOT_PATH")
	if rootpath == "" {
		klog.Exit("Could not fetch root path from variable KUTTI_ROOT_PATH. Cannot continue.")
	}

	if stat, err := os.Stat(rootpath); !(err == nil && stat.IsDir()) {
		klog.Exitf("Root path %s does not exist, or is not a directory.", rootpath)
	}

	// Start
	klog.Info("Starting local provisioner...")
	rootcontext := context.Background()
	err := localprovisioner.RunProvisioner(rootcontext, nodename, rootpath)
	if err != nil {
		klog.Fatalln(err)
	} else {
		klog.Exit("Kutti Local Volume Dynamic Provisioner stopped by itself. Something is not right.")
	}
}
