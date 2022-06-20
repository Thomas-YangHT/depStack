DEBIAN_FRONTEND=noninteractive dpkg-preconfigure /var/cache/apt/archives/openstack-dashboard_3%3a14*.deb

DEBIAN_FRONTEND=noninteractive dpkg-preconfigure /var/cache/apt/archives/openstack-dashboard-apache_3%3a14*.deb


cat <<- DEBCONF | debconf-set-selections 
horizon horizon/allowed-hosts string *
horizon horizon/activate_vhost boolean true
horizon horizon/use_ssl boolean false
DEBCONF
