#!/bin/bash

# Create a directory to store the debug information
mkdir -p debug_info
cd debug_info

# Function to run a command and save its output to a file, limiting to ~5000 characters
run_and_save() {
    echo "Running: $1"
    $1 | head -c 5000 > "$2" 2>&1
    echo "Output saved to $2 (limited to ~5000 characters)"
    echo
}

# Function to get logs with character limit
get_logs() {
    kubectl logs $1 | head -c 5000 > "$2" 2>&1
    echo "Logs saved to $2 (limited to ~5000 characters)"
}

# Get general cluster information
run_and_save "kubectl cluster-info" "cluster_info.txt"
run_and_save "kubectl get nodes -o wide" "nodes_info.txt"

# Get information about all resources
run_and_save "kubectl get all --all-namespaces" "all_resources.txt"

# Get events
run_and_save "kubectl get events --sort-by=.metadata.creationTimestamp" "events.txt"

# Get information about specific resource types
for resource in pods services deployments ingress configmaps secrets; do
    run_and_save "kubectl get $resource" "${resource}_list.txt"
    run_and_save "kubectl describe $resource" "${resource}_describe.txt"
done

# Get logs for all containers in the webapp deployment
get_logs "deployment/webapp --all-containers=true" "webapp_logs.txt"

# Get logs for the Nginx Ingress controller
NGINX_POD=$(kubectl get pods -l app.kubernetes.io/name=ingress-nginx -o jsonpath='{.items[0].metadata.name}')
get_logs "$NGINX_POD" "nginx_ingress_logs.txt"

# Get detailed information about each pod
kubectl get pods -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | while read -r pod; do
    run_and_save "kubectl describe pod $pod" "pod_${pod}_describe.txt"
    get_logs "$pod" "pod_${pod}_logs.txt"
done

# Get information about persistent volumes and claims
run_and_save "kubectl get pv,pvc" "persistent_volumes.txt"
run_and_save "kubectl describe pv,pvc" "persistent_volumes_describe.txt"

# Get information about storage classes
run_and_save "kubectl get storageclass" "storage_classes.txt"
run_and_save "kubectl describe storageclass" "storage_classes_describe.txt"

# Get information about network policies
run_and_save "kubectl get networkpolicies" "network_policies.txt"
run_and_save "kubectl describe networkpolicies" "network_policies_describe.txt"

echo "Debug information collection complete. Check the 'debug_info' directory for all the files."

