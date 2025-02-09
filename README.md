# Service Mesh POC

This script automates the setup of a Kubernetes cluster using `kind`, installs Istio, and deploys the Bookinfo sample application within GitHub Codespaces.

## Prerequisites
Ensure the following are installed in your GitHub Codespace:
- [Docker](https://docs.docker.com/get-docker/)
- [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/)

## Usage
Run the script using:
```sh
bash service-mesh-poc.sh
```

## What This Script Does
1. **Waits for GitHub Codespaces initialization**
2. **Creates a kind cluster** named `istio-poc` with a custom port mapping
3. **Installs Istio** (version `1.21.3` by default)
4. **Deploys the Bookinfo sample application**
5. **Provides a validation checklist** and web access URL

## Accessing the Application
After successful execution, access the application at:
```
https://${CODESPACE_NAME}-31001.preview.app.github.dev/productpage
```

## Cleanup
To remove the cluster, run:
```sh
kind delete cluster --name istio-poc
```

## Notes
- The script includes a timeout mechanism to avoid infinite waiting.
- The Istio installation has a retry mechanism to handle failures.
- The Bookinfo application is deployed under the `istio-demo` namespace.

Enjoy experimenting with Istio on GitHub Codespaces! 🚀
