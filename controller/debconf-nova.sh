source depstack.conf

DEBIAN_FRONTEND=noninteractive dpkg-preconfigure /var/cache/apt/archives/nova-api_2%3a18*.deb

DEBIAN_FRONTEND=noninteractive dpkg-preconfigure /var/cache/apt/archives/nova-common_2%3a18*.deb

DEBIAN_FRONTEND=noninteractive dpkg-preconfigure /var/cache/apt/archives/nova-placement-api_2%3a18*.deb


cat <<- DEBCONF | debconf-set-selections  
nova nova/configure_api-endpoint seen true
nova novaapi/configure_db seen true
nova nova/metadata_secret password
nova nova/neutron_admin_password password
nova nova/placement_admin_password password
nova nova/configure_ksat seen true
nova nova/active-api string osapi_compute, metadata
nova nova/my-ip string $controllerIP
nova nova/placement_admin_username string placement
nova nova/configure_db seen true
nova nova/configure_rabbit seen true
nova nova/cinder_os_region_name string RegionOne
nova nova/placement_admin_tenant_name string service
nova nova/glance_api_servers string http://controller:9292
nova nova/placement_os_region_name string RegionOne
nova nova/neutron_url string http://controller:9696
nova nova-placement-api/configure_db seen true
nova nova-placement-api/configure_api-endpoint seen true
DEBCONF
