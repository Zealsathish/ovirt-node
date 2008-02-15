# 
# Copyright (C) 2008 Red Hat, Inc.
# Written by Scott Seago <sseago@redhat.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA  02110-1301, USA.  A copy of the GNU General Public License is
# also available at http://www.gnu.org/copyleft/gpl.html.

class CreateNics < ActiveRecord::Migration
  def self.up
    create_table :nics do |t|
      t.column :mac,         :string
      t.column :ip_addr,     :string
      t.column :usage_type,  :string
      t.column :bandwidth,   :integer
      t.column :host_id,     :integer, :null => false
    end

    execute "alter table nics add constraint fk_nic_hosts
             foreign key (host_id) references hosts(id)"

  end

  def self.down
    drop_table :nics
  end
end
