# Lists out available kubernetes resources

echo '-------------------'
echo '  Pods'
echo '-------------------'
kubectl get pods --all-namespaces
echo $'\n'

echo '-------------------'
echo '  Services'
echo '-------------------'
kubectl get services --all-namespaces
echo $'\n'

echo '-------------------'
echo '  Deployments'
echo '-------------------'
kubectl get deployments --all-namespaces
echo $'\n'

echo '-------------------'
echo '  ClusterIssuers'
echo '-------------------'
kubectl get clusterissuers --all-namespaces
echo $'\n'

echo '-------------------'
echo '  Issuers'
echo '-------------------'
kubectl get issuers --all-namespaces
echo $'\n'

echo '-------------------'
echo '  Secrets'
echo '-------------------'
kubectl get secrets --all-namespaces
echo $'\n'

echo '-------------------'
echo '  Certificates'
echo '-------------------'
kubectl get certificates --all-namespaces
echo $'\n'

echo '-------------------'
echo '  Ingresses'
echo '-------------------'
kubectl get ingresses --all-namespaces
echo $'\n'

echo '-------------------'
echo '  Challenges'
echo '-------------------'
kubectl get challenges --all-namespaces

# echo '-------------------'
# echo '  ConfigMaps'
# echo '-------------------'
# kubectl get configmaps --all-namespaces
# echo $'\n'

# echo '-------------------'
# echo '  StatefulSets'
# echo '-------------------'
# kubectl get statefulsets --all-namespaces
# echo $'\n'

# echo '-------------------'
# echo '  DaemonSets'
# echo '-------------------'
# kubectl get daemonsets --all-namespaces
# echo $'\n'