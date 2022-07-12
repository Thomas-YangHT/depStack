
namespace=openstack
kubectl get po -n $namespace| awk 'NR>1{print $1}'
read ct
#ct=$1
[ -n "$ct" ] && kubectl -n $namespace logs  $ct | grep -i error 
[ -z "$ct" ] && \
for CT in `kubectl get po -n $namespace| awk 'NR>1{print $1}'|xargs`; do 
  echo -e "\033[31m $CT: \033[0m"
  kubectl -n $namespace logs  $CT | grep -i error
done
