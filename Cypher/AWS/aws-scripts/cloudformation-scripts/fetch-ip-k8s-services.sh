#!/bin/bash

# Define contexts for the two clusters
CLUSTERS=("detect-master" "detect-worker")
OUTPUT_FILE="service-ips-with-ports.txt"

# Define service-specific ports
declare -A SERVICE_PORTS
SERVICE_PORTS=(
    ["detect"]="ui:80,swagger:8000,flower:5555,grafana:3000,prometheus:8080"
    ["detect-rabbitmq"]="rabbitmq:15672"
    ["detect-webserver"]="airflow:8080"
    ["master-graylog"]="ui:9000"
    ["worker-graylog"]="ui:9000"
)

# Clear the output file
> "$OUTPUT_FILE"

# Iterate over each cluster context
for CONTEXT in "${CLUSTERS[@]}"; do
    echo "Switching to context: $CONTEXT"
    kubectl config use-context "$CONTEXT" || { echo "Failed to switch to context $CONTEXT"; exit 1; }

    # Fetch namespace (default is 'default')
    NAMESPACE=${1:-default}
    echo "Fetching external IPs and ports for LoadBalancer services in namespace '$NAMESPACE' for cluster '$CONTEXT'..."

    # Get the list of services with their external IPs/Hostnames
    kubectl get svc -n "$NAMESPACE" -o json | jq -r '.items[] | select(.spec.type=="LoadBalancer") | [.metadata.name, .status.loadBalancer.ingress[0].hostname // .status.loadBalancer.ingress[0].ip] | @tsv' | while IFS=$'\t' read -r svc_name svc_dns; do
        # Rename graylog services based on context
        if [[ "$svc_name" == "graylog" ]]; then
            if [[ "$CONTEXT" == "detect-master" ]]; then
                svc_name="master-graylog"
            elif [[ "$CONTEXT" == "detect-worker" ]]; then
                svc_name="worker-graylog"
            fi
        fi

        if [ -z "$svc_dns" ]; then
            echo "Service: $svc_name - No external IP/hostname assigned yet."
        else
            # Resolve DNS to IP
            svc_ip=$(nslookup "$svc_dns" | awk '/^Address: / { print $2 }' | tail -n1)
            if [ -z "$svc_ip" ]; then
                echo "Service: $svc_name - Unable to resolve IP for Hostname: $svc_dns."
            else
                # Fetch ports for the service
                ports=${SERVICE_PORTS["$svc_name"]}
                if [ -z "$ports" ]; then
                    echo "Service: $svc_name - URL: http://$svc_ip"
                    echo "$svc_name: http://$svc_ip" >> "$OUTPUT_FILE"
                else
                    # Split ports into individual entries
                    IFS=',' read -ra PORT_LIST <<< "$ports"
                    for port_entry in "${PORT_LIST[@]}"; do
                        # Extract label and port
                        label=$(echo "$port_entry" | cut -d':' -f1)
                        port=$(echo "$port_entry" | cut -d':' -f2)
                        echo "Service: $svc_name - $label - URL: http://$svc_ip:$port"
                        echo "$svc_name - $label: http://$svc_ip:$port" >> "$OUTPUT_FILE"
                    done
                fi
            fi
        fi
    done

    echo "---------------------------------------------"
done

echo "All service IPs and ports saved to $OUTPUT_FILE."