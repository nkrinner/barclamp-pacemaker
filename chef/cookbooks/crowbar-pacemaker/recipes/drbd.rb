#
# Cookbook Name:: crowbar-pacemaker
# Recipe:: drbd
#
# Copyright 2014, SUSE
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

claim_string = "LVM_DRBD"
lvm_group = "drbd"
lvm_disk = nil

unclaimed_disks = BarclampLibrary::Barclamp::Inventory::Disk.unclaimed(node).sort
claimed_disks = BarclampLibrary::Barclamp::Inventory::Disk.claimed(node, claim_string).sort

claimed_disks.each do |disk|
  Chef::Log.info("DEBUG DEBUK nkr: Claimed disk: #{disk}")
end

if claimed_disks.empty? and not unclaimed_disks.empty?
  unclaimed_disks.each do |disk|
    Chef::Log.info("DEBUG DEBUG nkr: disk found: #{disk.name}")
    if disk.claim(claim_string)
      Chef::Log.info("#{claim_string}: Claimed #{disk.name}")
      lvm_disk = disk
      break
    else
      Chef::Log.info("#{claim_string}: Ignoring #{disk.name}")
    end
  end
else
  lvm_disk = claimed_disks.first
  Chef::Log.info("DEBUG DEBUG nkr: lvm_disk: #{lvm_disk}")
end

if lvm_disk.nil?
  message = "There is no suitable disk for LVM for DRBD!"
  Chef::Log.fatal(message)
  raise message
end

# Make sure that LVM is setup on boot
if %w(suse).include? node.platform
  service "boot.lvm" do
    action [:enable]
  end
end

include_recipe "lvm::default"

lvm_physical_volume lvm_disk.name

lvm_volume_group lvm_group do
  physical_volumes [lvm_disk.name]
end

include_recipe "drbd::default"

crowbar_pacemaker_drbd_create_internal "create drbd resources" do
  lvm_group lvm_group
end
