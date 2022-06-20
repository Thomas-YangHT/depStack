DEBIAN_FRONTEND=noninteractive dpkg-preconfigure /var/cache/apt/archives/glance-api_2%3a17*.deb

DEBIAN_FRONTEND=noninteractive dpkg-preconfigure /var/cache/apt/archives/glance-common_2%3a17*.deb                   

cat <<- DEBCONF | debconf-set-selections 
glance glance/configure_api-endpoint seen true
glance glance/configure_ksat seen true
glance glance/configure_db seen true
glance glance/configure_rabbit seen true
DEBCONF
