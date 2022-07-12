#kexec.sh
ct=$1
namespace=openstack
[ "$ct" = "" ] && \
kubectl get po -n $namespace| awk 'NR>1{print $1}' && \
read ct
[ -n "$ct" ] && kubectl -n $namespace exec -it  $ct -- bash
