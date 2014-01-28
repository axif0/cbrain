
#
# CBRAIN Project
#
# Copyright (C) 2008-2012
# The Royal Institution for the Advancement of Learning
# McGill University
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

require 'spec_helper'

describe RemoteResource do
  let(:remote_resource) {Factory.create(:remote_resource)}

  describe "#spaced_dp_ignore_patterns" do
    it "should return the ignore patterns as a space-seperated string" do
      remote_resource.spaced_dp_ignore_patterns.should =~ /#{remote_resource.dp_ignore_patterns.join("\\s+")}/
    end
  end
  describe "#spaced_dp_ignore_patterns=" do
    it "should update the ignore patterns" do
      remote_resource.spaced_dp_ignore_patterns = "a b c"
      remote_resource.dp_ignore_patterns.should =~ ["a", "b", "c"]
    end
  end
  describe "#current_resource" do
    it "should return the resource representing the current app" do
      RemoteResource.current_resource.id.should == CBRAIN::SelfRemoteResourceId
    end
  end
  describe "#current_resource_db_config" do
    it "should return a hash with db configuration" do
      RemoteResource.current_resource_db_config.should have_key("database")
    end
  end
  describe "#site_affiliation" do
    it "should return the site affiliation" do
      remote_resource.site_affiliation.should == remote_resource.user.site
    end
  end
  describe "#after_destroy" do
    it "should destroy all associated sync statuses" do
      remote_resource.sync_status.create!
      lambda do
        remote_resource.destroy
      end.should change{ SyncStatus.count }.by(-1)
    end
  end
  describe "#proper_dp_ignore_patterns" do
    it "should be invalid if ignore patterns are not valid" do
      remote_resource.spaced_dp_ignore_patterns = "a * c"
      remote_resource.should have(1).error_on(:spaced_dp_ignore_patterns)
    end
    it "should be invalid if ignore patterns in improper format" do
      remote_resource.dp_ignore_patterns = "a * c"
      remote_resource.should have(1).error_on(:dp_ignore_patterns)
    end
    it "should allow saving if ignore patterns are valid" do
      remote_resource.spaced_dp_ignore_patterns = "a b c"
      remote_resource.should be_valid
    end
  end
  describe "#dp_cache_path_valid" do
    it "should be valid if the cache path is absolute" do
      remote_resource.dp_cache_dir = "/absolute_path"
      remote_resource.should be_valid
    end
    it "should be valid if the cache path hasn't been set yet" do
      remote_resource.dp_cache_dir = nil
      remote_resource.should be_valid
    end
    it "should prevent saving if the cache path is not absolute" do
      remote_resource.dp_cache_dir = "not/absolute"
      remote_resource.save
      remote_resource.should have(1).error_on(:dp_cache_dir)
    end
    context "on the Portal app" do
      let(:portal_resource) {RemoteResource.current_resource}
      before(:each) do
        portal_resource.stub!(:dp_cache_dir).and_return("path")
      end

      it "should be valid if the cache path is valid" do
        DataProvider.stub!(:this_is_a_proper_cache_dir!).and_return(true)
        portal_resource.stub!(:dp_cache_dir).and_return("/path")
        portal_resource.should be_valid
      end
      it "should be invalid if the cache path is invalid" do
        DataProvider.stub!(:this_is_a_proper_cache_dir!).and_return(false)
        portal_resource.save
        portal_resource.should have(1).error_on(:dp_cache_dir)
      end
      it "should be invalid if the cache dir check raises an exception" do
        DataProvider.stub!(:this_is_a_proper_cache_dir!).and_raise(StandardError)
        portal_resource.save
        portal_resource.should have(1).error_on(:dp_cache_dir)
      end
    end
  end
  describe "#ssh_master" do
    it "should create find or create an SSH master" do
      SshMaster.should_receive(:find_or_create)
      remote_resource.ssh_master
    end
  end
  describe "#start_tunnels" do
    let(:ssh_master) {double("ssh_master", :start => true, :is_alive? => false).as_null_object}
    before(:each) do
      remote_resource.stub!(:ssh_master).and_return(ssh_master)
      remote_resource.stub!(:has_ssh_control_info?).and_return(true)
      remote_resource.stub!(:has_db_tunnelling_info?).and_return(false)
      remote_resource.stub!(:has_actres_tunnelling_info?).and_return(false)
    end
    it "should return false if called on the Portal app" do
      portal_resource = RemoteResource.current_resource
      portal_resource.start_tunnels.should be_false
    end
    it "should return false if offline" do
      remote_resource.online = false
      remote_resource.start_tunnels.should be_false
    end
    it "should return false unless it has ssh control info" do
      remote_resource.stub!(:has_ssh_control_info?).and_return(false)
      remote_resource.start_tunnels.should be_false
    end
    it "should check if the master is alive" do
      ssh_master.should_receive(:is_alive?)
      remote_resource.start_tunnels
    end
    it "should return true if master is alive" do
      ssh_master.stub!(:is_alive?).and_return(true)
      remote_resource.start_tunnels.should be_true
    end
    it "should return false if ssh master start fails" do
      ssh_master.stub!(:start).and_return(false)
      remote_resource.start_tunnels.should be_false
    end
    it "should return true if all goes well" do
      remote_resource.start_tunnels.should be_true
    end
    it "should delete tunnels" do
      ssh_master.should_receive(:delete_tunnels).at_least(:once)
      remote_resource.start_tunnels
    end
    it "should add a tunnel when db tunneling info is available" do
      remote_resource.stub!(:has_db_tunnelling_info?).and_return(true)
      ssh_master.should_receive(:add_tunnel)
      remote_resource.start_tunnels
    end
    it "should add a tunnel when active resource tunneling info is available" do
      remote_resource.stub!(:has_actres_tunnelling_info?).and_return(true)
      ssh_master.should_receive(:add_tunnel)
      remote_resource.start_tunnels
    end
  end
  describe "#stop_tunnels" do
    before(:each) do
      remote_resource.stub!(:has_ssh_control_info?).and_return(true)
    end
    it "should return false if called on the Portal app" do
      portal_resource = RemoteResource.current_resource
      portal_resource.stop_tunnels.should be_false
    end
    it "should return false unless it has ssh control info" do
      remote_resource.stub!(:has_ssh_control_info?).and_return(false)
      remote_resource.stop_tunnels.should be_false
    end
    it "should stop the tunnels" do
      ssh_master = double("ssh_master")
      ssh_master.should_receive(:destroy)
      remote_resource.stub!(:ssh_master).and_return(ssh_master)
      remote_resource.stop_tunnels
    end
  end
  describe "#has_ssh_control_info?" do
    before(:each) do
      remote_resource.ssh_control_user = "user"
      remote_resource.ssh_control_host = "host"
    end
    it "should return false if user is blank" do
      remote_resource.ssh_control_user = ""
      remote_resource.should_not have_ssh_control_info
    end
    it "should return false if host is blank" do
      remote_resource.ssh_control_host = ""
      remote_resource.should_not have_ssh_control_info
    end
    it "should return true if user and host are present" do
      remote_resource.should have_ssh_control_info
    end
  end
  describe "#has_remote_control_info?" do
    before(:each) do
      remote_resource.stub!(:has_ssh_control_info?).and_return(true)
      remote_resource.ssh_control_rails_dir = "dir"
    end
    it "should return true if ssh control info and rails dir are defined" do
      remote_resource.should have_remote_control_info
    end
    it "should return false if no ssh control infor" do
      remote_resource.stub!(:has_ssh_control_info?).and_return(false)
      remote_resource.should_not have_remote_control_info
    end
    it "should return false if rails dir is blank" do
      remote_resource.ssh_control_rails_dir = ""
      remote_resource.should_not have_remote_control_info
    end
  end
  describe "#has_db_tunnelling_info?" do
    before(:each) do
      remote_resource.stub!(:has_ssh_control_info?).and_return(true)
      remote_resource.tunnel_mysql_port = "port"
    end
    it "should return true if ssh control infor and mysql port are defined" do
      remote_resource.should have_db_tunnelling_info
    end
    it "should return false if no ssh control infor" do
      remote_resource.stub!(:has_ssh_control_info?).and_return(false)
      remote_resource.should_not have_db_tunnelling_info
    end
    it "should return false if mysql port is blank" do
      remote_resource.tunnel_mysql_port = ""
      remote_resource.should_not have_db_tunnelling_info
    end
  end
  describe "#has_actres_tunnelling_info?" do
    before(:each) do
      remote_resource.stub!(:has_ssh_control_info?).and_return(true)
      remote_resource.tunnel_actres_port = "port"
    end
    it "should return true if ssh control infor and mysql port are defined" do
      remote_resource.should have_actres_tunnelling_info
    end
    it "should return false if no ssh control infor" do
      remote_resource.stub!(:has_ssh_control_info?).and_return(false)
      remote_resource.should_not have_actres_tunnelling_info
    end
    it "should return false if mysql port is blank" do
      remote_resource.tunnel_actres_port = ""
      remote_resource.should_not have_actres_tunnelling_info
    end
  end
  describe "#read_from_remote_shell_command" do
    let(:ssh_master) {double("ssh_master", :is_alive? => true, :remote_shell_command_reader => nil)}
    before(:each) do
      remote_resource.stub!(:ssh_master).and_return(ssh_master)
      remote_resource.stub!(:has_ssh_control_info?).and_return(true)
      remote_resource.stub!(:prepend_source_cbrain_bashrc)
    end
    it "should raise an exception if there is no ssh control info" do
      remote_resource.stub!(:has_ssh_control_info?).and_return(false)
      lambda{ remote_resource.read_from_remote_shell_command("bash_command") }.should raise_error
    end
    it "should raise an exception if ssh master is not alive" do
      ssh_master.stub!(:is_alive?).and_return(false)
      lambda{ remote_resource.read_from_remote_shell_command("bash_command") }.should raise_error
    end
    it "should prepare the bash command" do
      remote_resource.should_receive(:prepend_source_cbrain_bashrc)
      remote_resource.read_from_remote_shell_command("bash_command")
    end
    it "should write to ssh master" do
      ssh_master.should_receive(:remote_shell_command_reader)
      remote_resource.read_from_remote_shell_command("bash_command")
    end
  end
  describe "#write_to_remote_shell_command" do
    let(:ssh_master) {double("ssh_master", :is_alive? => true, :remote_shell_command_writer => nil)}
    before(:each) do
      remote_resource.stub!(:ssh_master).and_return(ssh_master)
      remote_resource.stub!(:has_ssh_control_info?).and_return(true)
      remote_resource.stub!(:prepend_source_cbrain_bashrc)
    end
    it "should raise an exception if there is no ssh control info" do
      remote_resource.stub!(:has_ssh_control_info?).and_return(false)
      lambda{ remote_resource.write_to_remote_shell_command("bash_command") }.should raise_error
    end
    it "should raise an exception if ssh master is not alive" do
      ssh_master.stub!(:is_alive?).and_return(false)
      lambda{ remote_resource.write_to_remote_shell_command("bash_command") }.should raise_error
    end
    it "should prepare the bash command" do
      remote_resource.should_receive(:prepend_source_cbrain_bashrc)
      remote_resource.write_to_remote_shell_command("bash_command")
    end
    it "should write to ssh master" do
      ssh_master.should_receive(:remote_shell_command_writer)
      remote_resource.write_to_remote_shell_command("bash_command")
    end
  end
  describe "#valid_token?" do
    before(:each) do
      remote_resource.update_attributes(:cache_md5 => "valid")
    end
    it "should return true if the token is valid" do
      RemoteResource.valid_token?("valid").should be_true
    end
    it "should return nil if the token is invalid" do
       RemoteResource.valid_token?("invalid").should be_nil
    end
  end
  describe "#auth_token" do
    it "should return the cache md5" do
      remote_resource.auth_token.should == remote_resource.cache_md5
    end
  end
  describe "#is_alive?" do
    let(:info_object) {double("info_object")}

    before(:each) do
      remote_resource.stub!(:remote_resource_info).and_return(info_object)
    end
    it "should return false if offline" do
      remote_resource.update_attributes(:online =>  false)
      remote_resource.is_alive?.should be_false
    end
    context "with a valid info object" do
      before(:each) do
        info_object.stub!(:name).and_return("rr")
      end
      it "should return true" do
        remote_resource.is_alive?.should be true
      end
      it "should set the time of death to nil" do
        remote_resource.update_attributes(:time_of_death => Time.now)
        remote_resource.is_alive?
        remote_resource.time_of_death.should be_nil
      end
    end
    context "with an invalid info object" do
      before(:each) do
        info_object.stub!(:name).and_return("???")
      end
      it "should return false" do
        remote_resource.is_alive?.should be_false
      end
      it "should set the time of death if it is not set" do
        remote_resource.is_alive?
        remote_resource.time_of_death.should_not be_nil
      end
      it "should set to offline if current time of death is whithin last minute" do
        remote_resource.update_attributes(:time_of_death  => 30.seconds.ago)
        remote_resource.is_alive?
        remote_resource.online.should be false
      end
      it "should reset the time of death flag if it's too old" do
        remote_resource.update_attributes(:time_of_death  => 1.day.ago)
        remote_resource.is_alive?
        (remote_resource.time_of_death-Time.now).should be < 1.minute
      end
      it "should leave the provider online if the previous time of death flag is too old" do
        remote_resource.update_attributes(:time_of_death  => 1.day.ago)
        remote_resource.is_alive?
        remote_resource.online.should be true
      end
    end

  end
  describe "#site" do
    before(:each) do
      remote_resource.actres_host = "host"
      remote_resource.actres_port = "port"
      remote_resource.actres_dir  = "dir"
    end
    it "should return a url" do
      remote_resource.site.should =~ /^http:\/\//
    end
    it "should return a 'localhost' url if ssh control and active resource tunnel info given" do
      remote_resource.stub!(:has_ssh_control_info?).and_return(true)
      remote_resource.stub!(:tunnel_actres_port).and_return(true)
      remote_resource.site.should =~ /^http:\/\/localhost/
    end
  end
  describe "#remote_resource_info (class method)" do
    before(:each) do
      Kernel.stub!(:`)
      Socket.stub!(:gethostname)
      Socket.stub!(:gethostbyname).and_raise(StandardError)
      IO.stub!(:popen)
      CbrainFileRevision.stub!(:cbrain_head_revinfo).and_return(double("head_info").as_null_object)
      CbrainFileRevision.stub!(:cbrain_head_tag).and_return(double("head_tag").as_null_object)
    end
    it "should get the host name" do
      Socket.should_receive(:gethostname)
      RemoteResource.remote_resource_info
    end
    it "should return the remote resource info" do
      portal_resource = RemoteResource.current_resource
      RemoteResource.remote_resource_info.should include(:id => portal_resource.id, :name => portal_resource.name)
    end
  end
  describe "#remote_resource_info (instance method)" do
    before(:each) do
      remote_resource.stub!(:ssh_master).and_return(true)
      remote_resource.stub_chain(:ssh_master, :is_alive?).and_return(true)
      remote_resource.stub!(:site).and_return("site")
    end
    it "should delegate to class method if called on model representing current app" do
      portal_resource = RemoteResource.current_resource
      portal_resource.class.should_receive(:remote_resource_info)
      portal_resource.remote_resource_info
    end
    it "should try to connect to the resource" do
      Control.should_receive(:find).and_return(double("control_info").as_null_object)
      remote_resource.remote_resource_info
    end
    it "should create a RemoteResourceInfo object if connention works" do
      Control.stub!(:find).and_return(double("control_info").as_null_object)
      RemoteResourceInfo.should_receive(:new).and_return({})
      remote_resource.remote_resource_info
    end
    it "should create a dummy RemoteResourceInfo object if connection fails" do
      Control.stub!(:find).and_raise(StandardError)
      remote_resource.remote_resource_info.should == RemoteResourceInfo.dummy_record
    end
  end
  describe "#info" do
    it "should delegate to class' #remote_resource_info method if called on model representing current app" do
      portal_resource = RemoteResource.current_resource
      portal_resource.class.should_receive(:remote_resource_info)
      portal_resource.info
    end
    it "should check if alive" do
      remote_resource.should_receive(:is_alive?).and_return(true)
      remote_resource.info
    end
    it "should return a dummy object if not alive" do
      remote_resource.stub!(:is_alive?).and_return(false)
      remote_resource.info.should == RemoteResourceInfo.dummy_record
    end
  end
  describe "#send_command_clean_cache" do
    let(:userfile_list) { [1,2,3] }
    let(:older_than)    { 1 }
    let(:younger_than)  { 2 }
    before(:each) do
      RemoteCommand.stub!(:new)
      remote_resource.stub!(:send_command)
    end
    it "should raise an exception if older_than is not a number or time" do
      lambda{ remote_resource.send_command_clean_cache(userfile_list, nil, younger_than) }.should raise_error(CbrainError)
    end
    it "should raise an exception if younger_than is not a number or time" do
      lambda{ remote_resource.send_command_clean_cache(userfile_list, older_than, nil) }.should raise_error(CbrainError)
    end
    it "should create a new clean_cache RemoteCommand" do
      RemoteCommand.should_receive(:new).with hash_including(:command => "clean_cache")
      remote_resource.send_command_clean_cache(userfile_list, older_than, younger_than)
    end
    it "should send the command" do
      remote_resource.should_receive(:send_command)
      remote_resource.send_command_clean_cache(userfile_list, older_than, younger_than)
    end
  end
  describe "#send_command_start_workers" do
    it "should create a new clean_cache RemoteCommand" do
      remote_resource.stub!(:send_command)
      RemoteCommand.should_receive(:new).with hash_including(:command => "start_workers")
      remote_resource.send_command_start_workers
    end
    it "should send the command" do
      RemoteCommand.stub!(:new)
      remote_resource.should_receive(:send_command)
      remote_resource.send_command_start_workers
    end
  end
  describe "#send_command_stop_workers" do
    it "should create a new clean_cache RemoteCommand" do
      remote_resource.stub!(:send_command)
      RemoteCommand.should_receive(:new).with hash_including(:command => "stop_workers")
      remote_resource.send_command_stop_workers
    end
    it "should send the command" do
      RemoteCommand.stub!(:new)
      remote_resource.should_receive(:send_command)
      remote_resource.send_command_stop_workers
    end
  end
  describe "#send_command_wakeup_workers" do
    it "should create a new clean_cache RemoteCommand" do
      remote_resource.stub!(:send_command)
      RemoteCommand.should_receive(:new).with hash_including(:command => "wakeup_workers")
      remote_resource.send_command_wakeup_workers
    end
    it "should send the command" do
      RemoteCommand.stub!(:new)
      remote_resource.should_receive(:send_command)
      remote_resource.send_command_wakeup_workers
    end
  end
  describe "#send_command" do
    let(:command) {double(RemoteCommand, :is_a? => true).as_null_object}
    before(:each) do
      remote_resource.stub!(:site)
      Control.stub!(:new).and_return(double("control").as_null_object)
    end
    it "should raise an exception if command is not a RemoteCommand" do
      lambda{remote_resource.send_command(nil)}.should raise_error(CbrainError)
    end
    it "should delegate to RemoteResource#process_command if called on model representing current app" do
      portal_resource = RemoteResource.current_resource
      portal_resource.class.should_receive(:process_command)
      portal_resource.send_command(command)
    end
    it "should send the command" do
      Control.should_receive(:new)
      remote_resource.send_command(command)
    end
    it "should return the command" do
      remote_resource.send_command(command).should be_instance_of(RemoteCommand)
    end
  end
  describe "#process_command" do
    let(:portal_resource) { RemoteResource.current_resource }
    before(:each) do
      portal_resource.stub!(:auth_token).and_return("auth_token")
      RemoteResource.stub!(:current_resource).and_return(portal_resource)
      Message.stub!(:send_message)
    end
    it "should raise an exception if command not given" do
      command = double("command", :command => nil)
      lambda{RemoteResource.process_command(command)}.should raise_error(CbrainError)
    end
    it "should send an error message if not given proper receiver token" do
      command = double("command", :command => "command", :receiver_token => "invalid").as_null_object
      Message.should_receive(:send_message)
      RemoteResource.process_command(command)
    end
    it "should send an error message if not given proper sender token" do
      command = double("command", :command => "command", :receiver_token => portal_resource.auth_token).as_null_object
      RemoteResource.stub!(:valid_token?).and_return(false)
      Message.should_receive(:send_message)
      RemoteResource.process_command(command)
    end
    it "should call the proper process_command_xxx method" do
      command = double("command", :command => "command", :receiver_token => portal_resource.auth_token).as_null_object
      RemoteResource.stub!(:valid_token?).and_return(true)
      RemoteResource.should_receive(:send).with(/^process_command_/, anything)
      RemoteResource.process_command(command)
    end
  end
  describe "#method_missing" do
    it "should raise a CbrainError if method has a 'process_command' prefix" do
      lambda{RemoteResource.process_command_invalid}.should raise_error(CbrainError)
    end
    it "should raise a MethodMissing exception otherwise" do
      lambda{RemoteResource.not_a_method}.should raise_error(NoMethodError)
    end
  end
end

