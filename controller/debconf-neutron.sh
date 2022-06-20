source depstack.conf
DEBIAN_FRONTEND=noninteractive dpkg-preconfigure /var/cache/apt/archives/neutron-api_2%3a13*.deb

DEBIAN_FRONTEND=noninteractive dpkg-preconfigure /var/cache/apt/archives/neutron-common_2%3a13*.deb

DEBIAN_FRONTEND=noninteractive dpkg-preconfigure /var/cache/apt/archives/neutron-metadata-agent_2%3a13*.deb


cat <<- DEBCONF | debconf-set-selections   
neutron neutron/configure_api-endpoint seen true
neutron neutron/nova_service_password password
neutron neutron/nova_region string RegionOne
neutron neutron/configure_rabbit seen true
neutron neutron/nova_auth_url string http://$controllerIP:5000
neutron neutron/configure_ksat seen true
neutron neutron/configure_db seen true
neutron neutron-metadata/metadata_secret password
neutron neutron-metadata/nova_metadata_host string $controllerIP
DEBCONF
