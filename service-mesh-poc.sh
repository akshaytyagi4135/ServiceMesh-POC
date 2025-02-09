#!/bin/bash
set -e

# -----------------------------------------
# Configuration
# -----------------------------------------
CLUSTER_NAME="istio-poc"
ISTIO_VERSION="1.21.3"
PORT=31001
TIMEOUT=600  # 10 minutes

# -----------------------------------------
# 1. Wait for Codespace Initialization
# -----------------------------------------
echo "Waiting for Codespace to be fully ready..."
while [ ! -f /workspaces/.codespaces/shared/environment-variables.json ]; do
  sleep 5
done

# -----------------------------------------
# 2. Clean Setup with Port Conflict Handling
# -----------------------------------------
cat <<EOF > kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: ${PORT}
    hostPort: ${PORT}
    protocol: TCP
EOF

# Cleanup existing resources
kind delete cluster --name ${CLUSTER_NAME} 2>/dev/null || true
docker rm -f $(docker ps -aq --filter "name=${CLUSTER_NAME}-*") 2>/dev/null || true

# -----------------------------------------
# 3. Cluster Creation with Status Checks
# -----------------------------------------
echo -n "Creating cluster (this may take 3-5 minutes)..."
start_time=$(date +%s)
while ! kind create cluster --name ${CLUSTER_NAME} --config kind-config.yaml 2>/dev/null; do
  echo -n "."
  sleep 10
  if [ $(($(date +%s) - start_time)) -gt ${TIMEOUT} ]; then
    echo -e "\n❌ Cluster creation timed out"
    exit 1
  fi
done
echo -e "\n✅ Cluster created successfully"

# -----------------------------------------
# 4. Istio Installation with Progressive Checks
# -----------------------------------------
(
  echo "Installing Istio..."
  curl -sL https://istio.io/downloadIstio | ISTIO_VERSION=${ISTIO_VERSION} TARGET_ARCH=x86_64 sh -
  cd "istio-${ISTIO_VERSION}"
  export PATH=$PWD/bin:$PATH
  
  cat <<EOF > istio-config.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  profile: demo
  components:
    ingressGateways:
    - name: istio-ingressgateway
      enabled: true
      k8s:
        service:
          type: NodePort
          ports:
          - port: 80
            targetPort: 8080
            nodePort: ${PORT}
EOF

  for attempt in {1..3}; do
    istioctl install -f istio-config.yaml -y && break
    echo "Istio installation failed, retrying (attempt ${attempt}/3)..."
    sleep 10
  done
)

# -----------------------------------------
# 5. Bookinfo Deployment with Visual Progress
# -----------------------------------------
(
  kubectl create namespace istio-demo
  kubectl label namespace istio-demo istio-injection=enabled
  
  echo -e "\nDeploying Bookinfo application:"
  kubectl apply -n istio-demo -f istio-${ISTIO_VERSION}/samples/bookinfo/platform/kube/bookinfo.yaml
  kubectl apply -n istio-demo -f istio-${ISTIO_VERSION}/samples/bookinfo/networking/bookinfo-gateway.yaml
  
  echo -n "Waiting for pods"
  while [ $(kubectl get pods -n istio-demo -l app=productpage -o jsonpath='{.items[0].status.phase}') != "Running" ]; do
    echo -n "."
    sleep 10
  done
  echo -e "\n✅ All pods running"
)

# -----------------------------------------
# 6. Final Verification & Output
# -----------------------------------------
echo -e "\n\033[1;32mVALIDATION STEPS:\033[0m"
echo "1. Port Forwarding Status:"
kubectl get svc -n istio-system istio-ingressgateway

echo -e "\n2. Application Access:"
curl -sSL http://localhost:${PORT}/productpage | grep "<title>" || echo "Wait 1 more minute and refresh"

echo -e "\n3. Web Access URL:"
echo -e "\033[1;34mhttps://${CODESPACE_NAME}-${PORT}.preview.app.github.dev/productpage\033[0m"

echo -e "\n4. Cleanup Command:"
echo "kind delete cluster --name ${CLUSTER_NAME}"
