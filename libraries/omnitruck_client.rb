#
# Copyright:: Copyright (c) 2012 Opscode, Inc.
# License:: Apache License, Version 2.0
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

require 'uri'
require 'json'

class OmnitruckClient
  CLIENT_LIST_URL = 'http://www.getchef.com/chef/full_client_list'
  PACKAGE_BASE_URL = 'https://opscode-omnibus-packages.s3.amazonaws.com'

  attr_reader :platform, :platform_version, :machine_architecture

  def initialize(node)
    @platform = node['platform_family'] == "rhel" ? "el" : node['platform']
    @platform_version = node['platform_family'] == "rhel" ? node['platform_version'].to_i : node['platform_version']
    @machine_architecture = node['kernel']['machine']
  end

  def package_for_version(version, prerelease=false, nightly=false)
    url = URI.parse(CLIENT_LIST_URL)
    response = Net::HTTP.new(url.host, url.port).get(url.request_uri, {})
    begin
      client_list = JSON.parse(response.body)
    rescue JSON::ParserError
      Chef::Log.error("Client list not found: #{url}")
      nil
    end

    begin
      releases = client_list[@platform][@platform_version][@machine_architecture]
      if version && version != :latest
        if releases.has_key?(version)
          package_url = "#{PACKAGE_BASE_URL}#{releases[version]}"
          Chef::Log.info("Downloading chef-server package from: #{package_url}")
          package_url
        else
          nil
        end
      else
        target_releases = releases.select do |package_version, path|
          if package_version.match(/g[0-9a-f]{7}/)
            nightly
          elsif package_version.match(/[a-zA-Z]/)
            prerelease
          else
            true
          end
        end
        location = target_releases.values.last
        if location
          package_url = "#{PACKAGE_BASE_URL}#{location}"
          Chef::Log.info("Downloading chef-server package from: #{package_url}")
          package_url
        else
          nil
        end
      end
    rescue NoMethodError
      nil
    end
  end
end
