#!/usr/bin/ruby

$: << "../app"
$: << "/usr/share/ovirt-wui/app"

require 'rubygems'
require 'kerberos'
include Kerberos
require 'libvirt'
require 'active_record'
require 'erb'
require 'models/host.rb'
require 'models/hardware_pool.rb'
require 'models/permission.rb'
require 'socket'

ENV['KRB5CCNAME'] = '/usr/share/ovirt-wui/ovirt-cc'

def database_configuration
  YAML::load(ERB.new(IO.read('/usr/share/ovirt-wui/config/database.yml')).result)
end

def kadmin_local(command)
  # FIXME: we really should implement the ruby-kerberos bindings to do the
  # same thing as kadmin.local
  # FIXME: we should check the return value from the system() call and throw
  # an exception.
  # FIXME: we need to return the output back to the caller here
  system("/usr/kerberos/sbin/kadmin.local -q '" + command + "'")
end

def get_ip(hostname)
  ip = Socket::gethostbyname(hostname)[3].unpack('CCCC')
  addr = ''
  ip.each do |octet|
    addr += octet.to_s + '.'
  end

  return addr[0..-2]
end

if ARGV.length != 1
  exit
end

# make sure we get our credentials up-front
krb5 = Krb5.new
default_realm = krb5.get_default_realm
krb5.get_init_creds_keytab('libvirt/' + Socket::gethostname + '@' + default_realm, '/usr/share/ovirt-wui/ovirt.keytab')
krb5.cache(ENV['KRB5CCNAME'])

begin
  conn = Libvirt::open("qemu+tcp://" + ARGV[0] + "/system")
  info = conn.node_get_info
  conn.close
rescue
  # if we can't contact the host or get details for some reason, we just
  # don't do anything and don't add anything to the database
  exit
end

# we could destroy the credentials, but another process might be using them
# (in particular, the taskomatic).  Just leave them around, it shouldn't hurt

$dbconfig = database_configuration

$develdb = $dbconfig['development']

ActiveRecord::Base.establish_connection(
                                        :adapter  => $develdb['adapter'],
                                        :host     => $develdb['host'],
                                        :username => $develdb['username'],
                                        :password => $develdb['password'],
                                        :database => $develdb['database']
                                        )

# FIXME: we need a better way to get a UUID, rather than the hostname
$host = Host.find(:first, :conditions => [ "uuid = ?", ARGV[0]])

if $host == nil
  Host.new(
           "uuid" => ARGV[0],
           "hostname" => ARGV[0],
           "num_cpus" => info.cpus,
           "cpu_speed" => info.mhz,
           "arch" => info.model,
           "memory" => info.memory,
           "is_disabled" => 0,
           "hardware_pool" => MotorPool.find(:first)
           ).save

  ipaddr = get_ip(ARGV[0])

  libvirt_princ = 'libvirt/' + ARGV[0] + '@' + default_realm

  outname = '/var/www/html/' + ipaddr + '-libvirt.tab'

  # FIXME: in order for things to truly run automatically here, the freeipa
  # server needs to run on the same machine as the WUI.  We could fix this
  # by doing kadmin with some credentials, but that gets more complicated.  Punt
  kadmin_local('addprinc -randkey ' + libvirt_princ)
  kadmin_local('ktadd -k ' + outname + ' ' + libvirt_princ)
end
