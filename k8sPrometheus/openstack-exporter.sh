#! /bin/bash
source ../depstack.conf

tee admin.novarc <<EOF
OS_PROJECT_DOMAIN_NAME=Default
OS_USER_DOMAIN_NAME=Default
OS_PROJECT_NAME=admin
OS_USERNAME=admin
OS_PASSWORD=keystone
OS_IDENTITY_API_VERSION=3
OS_AUTH_URL=http://$controllerIP/identity/v3
EOF

##podmonitr: https://segmentfault.com/a/1190000040638474
tee pod-monitor.yaml <<EOF
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  labels:
    app: openstack-exporter
  name: openstack-exporter
  namespace: monitoring
spec:
  podMetricsEndpoints:
  - interval: 15s
    path: /metrics
    port: h-metrics
  namespaceSelector:
    matchNames:
    - monitoring
  selector:
    matchLabels:
      app: openstack-exporter
EOF
tee openstack-exporter-srv.yaml <<EOF
apiVersion: v1
kind: Service
metadata:
  labels:
    app: openstack-exporter
  name: openstack-exporter
  namespace: monitoring
spec:
  clusterIP: None
  ports:
  - name: h-metrics
    port: 9183
    targetPort: 9183
  selector:
    app: openstack-exporter
EOF
tee openstack-srv-monitor.yml <<EOF
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: openstack-exporter
  namespace: monitoring
  labels:
    release: mypro 
spec:
  endpoints:
  - port: h-metrics
    path: /metrics
    scheme: http
    scrapeTimeout: 30s
  selector:
    matchLabels:
      app: openstack-exporter
  namespaceSelector:
    matchNames:
    - monitoring
EOF

kubectl -n monitoring create configmap novarc --from-env-file admin.novarc
kubectl apply -f openstack-exporter.yml
kubectl apply -f pod-monitor.yaml
kubectl apply -f openstack-exporter-srv.yaml
kubectl apply -f openstack-srv-monitor.yml