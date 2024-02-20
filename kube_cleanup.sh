#!/bin/bash

## This custom script is used to safely clean up the kubernetes cluster and remove any leftover unwanted resources.

# Remove stopped containers
sudo crictl ps -a | grep -v Running | grep -v CONTAINER | awk '{print $1}' | xargs -r sudo crictl rm