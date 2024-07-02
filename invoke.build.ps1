Param(
    $VersionMajor = (property VERSION_MAJOR "0"),
    $VersionMinor = (property VERSION_MINOR "2"),
    $BuildNumber  = (property BUILD_NUMBER  "1"),
    $PatchString  = (property PATCH_STRING  ""),
    $ImageTag     = (property IMAGE_TAG     ""),
    $RegistryUser = (property REGISTRY_USER "kuttiproject"),
    $Platforms    = (property PLATFORMS "linux/amd64,linux/arm,linux/arm64,linux/ppc64le,linux/s390x")
)


# Maintain semantic version in the parameters above
# Also change in cmd/kutti-localprovisioner/main.go
# and deploy/kubernetes/provisioner.yaml
# The README.md file will auto-populate from the GitHub release
$VersionString = "$($VersionMajor).$($VersionMinor).$($BuildNumber)$($PatchString)"
If ($ImageTag -eq "") {
    $ImageTag = $VersionString
}

$SourceFiles = (Get-Item "cmd/kutti-localprovisioner/main.go"), `
               (Get-Item "internal/pkg/localprovisioner/localprovisioner.go")

# Synopsis: Show Usage
task . {
	Write-Host "Usage: Invoke-Build provisioner|image|image-multistage|cleanlocal|rmi|clean"
}

# Synopsis: Build provisioner locally
task provisioner -Outputs "out/kutti-localprovisioner" -Inputs $($SourceFiles) {
    exec {
        $env:CGO_ENABLED="0"
        $env:GOOS="linux"
        $env:GOARCH="amd64"
        go build -o out/kutti-localprovisioner -ldflags "-X main.version=$($VersionString)" ./cmd/kutti-localprovisioner/
    }
}

# Synopsis: Package locally into container image
task image -Outputs "out/provisioner-localvolume-$($ImageTag).iid" `
           -Inputs (Get-Item build/package/container/singlestage.Dockerfile) `
           provisioner, {
    exec {
        docker build -t $RegistryUser/provisioner-localvolume:$ImageTag `
                     -f build/package/container/singlestage.Dockerfile `
                     --iidfile "out/provisioner-localvolume-$($ImageTag).iid" `
                     .
    }
}

# Synopsis: Build provisioner and image in docker
task image-multistage -Outputs "out/provisioner-localvolume-$($ImageTag).iid" `
                      -Inputs ($($SourceFiles)+(Get-Item build/package/container/multistage.Dockerfile)) {
    exec {
        docker build -t $RegistryUser/provisioner-localvolume:$ImageTag `
                     -f build/package/container/multistage.Dockerfile `
                     --build-arg VERSION_STRING=$($VersionString) `
                     --iidfile "out/provisioner-localvolume-$($ImageTag).iid" `
                     .
    }
}

# Synopsis: Build multi-arch provisioner image and push to registry
task publishimage -Outputs "out/provisioner-localvolume-$($ImageTag).iid" `
                  -Inputs ($($SourceFiles)+(Get-Item build/package/container/multistage.Dockerfile)) {
    exec {
        docker buildx build `
            --push `
            --platform=$Platforms `
            -t $RegistryUser/provisioner-localvolume:$ImageTag `
            -f build/package/container/multistage.Dockerfile `
            --build-arg VERSION_STRING=$($VersionString) `
            --iidfile "out/provisioner-localvolume-$($ImageTag).iid" `
            .
    }
}


# Synopsis: Clean locally built provisioner
task cleanlocal {
    Remove-Item -Recurse -Force -ErrorAction Ignore ./out
}

# Synopsis: Remove container image
task rmi {
    exec {
        docker image rm $RegistryUser/provisioner-localvolume:$ImageTag
    }
}

# Synopsis: Clean all
task clean cleanlocal, rmi
