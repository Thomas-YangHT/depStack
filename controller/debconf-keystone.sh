DEBIAN_FRONTEND=noninteractive dpkg-preconfigure /var/cache/apt/archives/keystone_2%3a14*.deb

cat <<- DEBCONF | debconf-set-selections
keystone keystone/register-endpoint seen true
keystone keystone/create-admin-tenant seen true
keystone keystone/configure_db seen true
DEBCONF


