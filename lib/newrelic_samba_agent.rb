#! /usr/bin/env ruby

#
# This is a NewRelic agent which pushes Samba information.
#

require "rubygems"
require "bundler/setup"
require "newrelic_plugin"

module NewRelicSambaAgent
  class Agent < NewRelic::Plugin::Agent::Base
    agent_guid "com.kangacoders.samba"
    agent_version "0.1.0"
    agent_config_options :smbstatus_path
    agent_human_labels("Samba Agent") { ident }
    
    attr_reader :ident

    def poll_cycle
      [:total_users, :total_machines, :total_files, :average_files_user].each do |_type|
        name, unit, _output = metric(_type)
        report_metric name, unit, _output.call
      end
    end

    private

    def get_columns(_output, _c_index, _uniq = true, _total = true)
      result = _output.scan(/^\d+\s+(.+)$/).map{|_x| _x[0].split(/\s+/)[_c_index] }
      result = result.uniq if _uniq
      result = result.length if _total
      result
    end

    def metric(_type)
      metrics = {
        :total_users => ["Total/Users", "Users", lambda{get_columns(smb_cmd(:process), 0) }],
        :total_machines => ["Total/Machines", "Machines", lambda{get_columns(smb_cmd(:process), 3) }],
        :total_files => ["Total/Files", "Files", lambda{ get_columns(smb_cmd(:locks), 0, false) }],
        :average_files_user => ["Average/Files_User", "Files/User", lambda{get_columns(smb_cmd(:locks), 0, false) / get_columns(smb_cmd(:process), 0) rescue 0}],
      }
      metrics[_type]
    end

    def smb_cmd(_type)
      case _type
      when :process
        param = "-p"
      when :locks
        param = "-L"
      end
      `#{smbstatus_path} #{param}`
    end

  end

  def self.run
    NewRelic::Plugin::Config.config.agents.keys.each do |_agent|
      NewRelic::Plugin::Setup.install_agent _agent, NewRelicSambaAgent
    end

    NewRelic::Plugin::Run.setup_and_run
  end
end
