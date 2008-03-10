# Kickstart file automatically generated by anaconda.

install
url --url http://download.fedora.redhat.com/pub/fedora/linux/releases/8/Fedora/i386/os/
lang en_US.UTF-8
keyboard us
network --device eth0 --bootproto dhcp
rootpw  --iscrypted $1$HNOucon/$m69RprODwQn4XjzVUi9TU0
firewall --disabled
authconfig --enableshadow --enablemd5
selinux --disabled
services --disabled=iptables,yum-updatesd,libvirtd,bluetooth,cups,gpm,pcscd --enabled=ntpd,dhcpd,xinetd,httpd,postgresql,ovirt-wui
timezone --utc America/New_York
text
bootloader --location=mbr --driveorder=sda
# The following is the partition information you requested
# Note that any partitions you deleted are not expressed
# here so unless you clear all partitions first, this is
# not guaranteed to work
zerombr
clearpart --all --drives=sda
part /boot --fstype ext3 --size=100 --ondisk=sda
part pv.2 --size=0 --grow --ondisk=sda
volgroup VolGroup00 --pesize=32768 pv.2
logvol swap --fstype swap --name=LogVol01 --vgname=VolGroup00 --size=512
logvol / --fstype ext3 --name=LogVol00 --vgname=VolGroup00 --size=1024 --grow

repo --name=f8 --mirrorlist=http://mirrors.fedoraproject.org/mirrorlist?repo=fedora-8&arch=i386
repo --name=f8-updates --mirrorlist=http://mirrors.fedoraproject.org/mirrorlist?repo=updates-released-f8&arch=i386
repo --name=freeipa --baseurl=http://freeipa.com/downloads/devel/rpms/F7/i386/ --includepkgs=ipa*
repo --name=ovirt-management --baseurl=http://ovirt.et.redhat.com/repos/ovirt-management-repo/i386/

%packages
@admin-tools
@editors
@system-tools
@text-internet
@core
@base
@hardware-support
@web-server
@sql-server
@development-libs
@legacy-fonts
@development-tools
radeontool
fuse
pax
imake
dhcp
tftp-server
tftp
dhclient
ipa-server
ipa-admintools
xinetd
libvirt
cyrus-sasl-gssapi
iscsi-initiator-utils
collectd
ruby-libvirt
ruby-postgres
ovirt-wui
firefox
xorg-x11-xauth
virt-viewer
bind
bind-chroot
-libgcj
-glib-java
-valgrind
-boost-devel
-frysk
-bittorrent
-fetchmail
-slrn
-cadaver
-mutt

%post

cat > /root/create_default_principals.py << \EOF
#!/usr/bin/python

import krbV
import os, string, re
import socket
import shutil

def kadmin_local(command):
        ret = os.system("/usr/kerberos/sbin/kadmin.local -q '" + command + "'")
        if ret != 0:
                raise

default_realm = krbV.Context().default_realm

# here, generate the libvirt/ principle for this machine, necessary
# for taskomatic and host-browser
this_libvirt_princ = 'libvirt/' + socket.gethostname() + '@' + default_realm
kadmin_local('addprinc -randkey +requires_preauth ' + this_libvirt_princ)
kadmin_local('ktadd -k /usr/share/ovirt-wui/ovirt.keytab ' + this_libvirt_princ)

# We need to replace the KrbAuthRealms in the ovirt-wui http configuration
# file to be the correct Realm (i.e. default_realm)
ovirtconfname = '/etc/httpd/conf.d/ovirt-wui.conf'
ipaconfname = '/etc/httpd/conf.d/ipa.conf'

# make sure we skip this on subsequent runs of this script
if string.find(file(ipaconfname, 'rb').read(), '<VirtualHost *:8089>') < 0:
    ipaconf = open(ipaconfname, 'r')
    ipatext = ipaconf.readlines()
    ipaconf.close()

    ipaconf2 = open(ipaconfname, 'w')
    print >>ipaconf2, "Listen 8089"
    print >>ipaconf2, "NameVirtualHost *:8089"
    print >>ipaconf2, "<VirtualHost *:8089>"
    for line in ipatext:
        newline = re.sub(r'(.*RewriteCond %{HTTP_HOST}.*)', r'#\1', line)
        newline = re.sub(r'(.*RewriteRule \^/\(.*\).*)', r'#\1', newline)
        newline = re.sub(r'(.*RewriteCond %{SERVER_PORT}.*)', r'#\1', newline)
        newline = re.sub(r'(.*RewriteCond %{REQUEST_URI}.*)', r'#\1', newline)
        ipaconf2.write(newline)
    print >>ipaconf2, "</VirtualHost>"
    ipaconf2.close()

if string.find(file(ovirtconfname, 'rb').read(), '<VirtualHost *:80>') < 0:
    ovirtconf = open(ovirtconfname, 'r')
    ovirttext = ovirtconf.readlines()
    ovirtconf.close()

    ovirtconf2 = open(ovirtconfname, 'w')
    print >>ovirtconf2, "NameVirtualHost *:80"
    print >>ovirtconf2, "<VirtualHost *:80>"
    for line in ovirttext:
        newline = re.sub(r'(.*)KrbAuthRealms.*', r'\1KrbAuthRealms ' + default_realm, line)
        newline = re.sub(r'(.*)Krb5KeyTab.*', r'\1Krb5KeyTab /etc/httpd/conf/ipa.keytab', newline)
        ovirtconf2.write(newline)
    print >>ovirtconf2, "</VirtualHost>"
    ovirtconf2.close()
EOF
chmod +x /root/create_default_principals.py

cat > /root/add_host_principal.py << \EOF
#!/usr/bin/python

import krbV
import os
import socket
import shutil
import sys

def kadmin_local(command):
        ret = os.system("/usr/kerberos/sbin/kadmin.local -q '" + command + "'")
        if ret != 0:
                raise

def get_ip(hostname):
        return socket.gethostbyname(hostname)

if len(sys.argv) != 2:
        print "Usage: add_host_principal.py <hostname>"
        sys.exit(1)


default_realm = krbV.Context().default_realm

ipaddr = get_ip(sys.argv[1])

libvirt_princ = 'libvirt/' + sys.argv[1] + '@' + default_realm
outname = '/usr/share/ipa/html/' + ipaddr + '-libvirt.tab'

# here, generate the libvirt/ principle for this machine, necessary
# for taskomatic and host-browser
kadmin_local('addprinc -randkey +requires_preauth ' + libvirt_princ)
kadmin_local('ktadd -k ' + outname + ' ' + libvirt_princ)

# make sure it is readable by apache
os.chmod(outname, 0644)
EOF
chmod +x /root/add_host_principal.py

cat > /usr/share/ovirt-wui/psql.cmds << \EOF
CREATE USER ovirt WITH PASSWORD 'v23zj59an';
CREATE DATABASE ovirt;
GRANT ALL PRIVILEGES ON DATABASE ovirt to ovirt;
CREATE DATABASE ovirt_test;
GRANT ALL PRIVILEGES ON DATABASE ovirt_test to ovirt;
EOF
chmod a+r /usr/share/ovirt-wui/psql.cmds

cat > /etc/init.d/ovirt-app-first-run << \EOF
#!/bin/bash
#
# ovirt-app-first-run First run configuration for Ovirt WUI appliance
#
# chkconfig: 3 99 01
# description: ovirt appliance first run configuration
#

# Source functions library
. /etc/init.d/functions

start() {
	service postgresql initdb
	echo "local all all trust" > /var/lib/pgsql/data/pg_hba.conf
	echo "host all all 127.0.0.1 255.255.255.0 trust" >> /var/lib/pgsql/data/pg_hba.conf
	service postgresql start

	su - postgres -c "/usr/bin/psql -f /usr/share/ovirt-wui/psql.cmds"

	cd /usr/share/ovirt-wui ; rake db:migrate
	/usr/bin/ovirt_grant_admin_privileges.sh admin
}

case "$1" in
  start)
        start
        ;;
  *)
        echo "Usage: ovirt {start}"
        exit 2
esac

chkconfig ovirt-app-first-run off
EOF
chmod +x /etc/init.d/ovirt-app-first-run
/sbin/chkconfig ovirt-app-first-run on

sed -i -e 's/\(.*\)disable\(.*\)= yes/\1disable\2= no/' /etc/xinetd.d/tftp

# set up the yum repos
cat > /etc/yum.repos.d/freeipa.repo << \EOF
[freeipa]
name=FreeIPA Development
baseurl=http://freeipa.com/downloads/devel/rpms/F7/i386/
enabled=1
gpgcheck=0
EOF

cat > /etc/yum.repos.d/ovirt-management.repo << \EOF
[ovirt-management]
name=ovirt-management
baseurl=http://ovirt.et.redhat.com/repos/ovirt-management-repo/i386/
enabled=1
gpgcheck=0
EOF

# pretty login screen..

echo -e "" > /etc/issue
echo -e "           888     888 \\033[0;32md8b\\033[0;39m         888    " >> /etc/issue
echo -e "           888     888 \\033[0;32mY8P\\033[0;39m         888    " >> /etc/issue
echo -e "           888     888             888    " >> /etc/issue
echo -e "   .d88b.  Y88b   d88P 888 888d888 888888 " >> /etc/issue
echo -e "  d88''88b  Y88b d88P  888 888P'   888    " >> /etc/issue
echo -e "  888  888   Y88o88P   888 888     888    " >> /etc/issue
echo -e "  Y88..88P    Y888P    888 888     Y88b.  " >> /etc/issue
echo -e "   'Y88P'      Y8P     888 888      'Y888 " >> /etc/issue
echo -e "" >> /etc/issue
echo -e "  Admin node \\\\n " >> /etc/issue
echo -e "" >> /etc/issue
echo -e "  Virtualization just got the \\033[0;32mGreen Light\\033[0;39m" >> /etc/issue
echo -e "" >> /etc/issue

cp /etc/issue /etc/issue.net

echo "0.fedora.pool.ntp.org" >> /etc/ntp/step-tickers

# with the new libvirt (0.4.0), make sure we we setup gssapi in the mech_list
sed -i -e 's/mech_list: digest-md5/#mech_list: digest-md5/' /etc/sasl2/libvirt.conf
sed -i -e 's/#mech_list: gssapi/mech_list: gssapi/' /etc/sasl2/libvirt.conf

# for firefox, we need to add the following to ~/.mozilla/firefox/zzzzz/prefs.js
#echo 'user_pref("network.negotiate-auth.delegation-uris", ".redhat.com");' >> ~/.mozilla/firefox/zzzz/prefs.js
#echo 'user_pref("network.negotiate-auth.trusted-uris", ".redhat.com");' >> ~/.mozilla/firefox/zzzz/prefs.js

%end
