# Lists out available kubernetes resources

# Output resource display names : Kubernetes command variable
resources=(
    "Ingresses : ingresses"
    "Services : services"
    "Deployments : deployments"
    "Pods : pods"
    "Storage Classes : storageclasses"
    "Persistent Volumes : persistentvolumes"
    "Persistent Volume Claims : persistentvolumeclaims"
    "Config Maps : configmaps"
    "Secrets : secrets"
    "Certificates : certificates"
    "Cluster Issuers : clusterissuers"
    "Issuers : issuers"
    # "Challenges : challenges"
    # "Stateful Sets : statefulsets"
    # "Daemon Sets : daemonsets"
)

# Manually parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -A|--all-namespaces)
            kubectl_flags="--all-namespaces"
            shift # Move past argument
            ;;
        -n|--namespace)
            if [[ -n $2 && ${2:0:1} != "-" ]]; then
                # Trim leading and trailing whitespaces in the namespace argument
                namespace=$(echo "$2" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                kubectl_flags="-n $namespace"
                shift 2 # Move past argument and its value
            else
                echo "Error: Argument for $1 is missing" >&2
                exit 1
            fi
        ;;
        *)
            echo "Invalid option: $1" >&2
            exit 1
            ;;
    esac
done

# Loop through the indexed array
for item in "${resources[@]}"; do
    # Split the item into display name and command variable using ':' as the delimiter and trim leading and trailing spaces using awk
    resource_name=$(echo "$item" | awk -F':' '{print $1}' | awk '{$1=$1};1')
    k8s_resource=$(echo "$item" | awk -F':' '{print $2}' | awk '{$1=$1};1')
    
    # Calculate the number of dashes to display (4 is added to account for the tab margin)
    dashes=$((4 + ${#resource_name}))
    
    # Print the header with dashes
    echo "$(printf '%0.s-' $(seq 1 $dashes))"
    echo "  $resource_name"
    echo "$(printf '%0.s-' $(seq 1 $dashes))"
    
    # Fetch and display the Kubernetes resources
    kubectl get "$k8s_resource" $kubectl_flags
    echo $'\n'  # Add a newline for spacing
done