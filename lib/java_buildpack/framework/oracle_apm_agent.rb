# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2020 the original author or authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'java_buildpack/component/versioned_dependency_component'
require 'java_buildpack/framework'

module JavaBuildpack
  module Framework

    # Enables APM support by adding the Oracle Java APM Agent.
    #
    # (see https://docs.oracle.com/en-us/iaas/application-performance-monitoring/doc/deploy-apm-java-agent.html)
    class OracleApmAgent < JavaBuildpack::Component::VersionedDependencyComponent

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        # Download the agent. Don't strip the top level directory while extracting
        download_tar(false)
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        service = @application.services.find_service(OCI_APM_SERVICE, [OCI_APM_PRIVATE_KEY, OCI_APM_ENDPOINT])
        apm_private_key = service['credentials'][OCI_APM_PRIVATE_KEY]
        apm_upload_endpoint = service['credentials'][OCI_APM_ENDPOINT]
        cf_app_name = @application.details['name']
        cf_space_name = @application.details['space_name'].upcase

        java_opts = @droplet.java_opts
        agent_path = File.join(@droplet.sandbox, APM_AGENT_DIR, 'bootstrap', 'ApmAgent.jar')
        java_opts.add_javaagent(Pathname.new(agent_path))
        java_opts.add_system_property('spring.jmx.enabled', true)
        java_opts.add_system_property('server.tomcat.mbeanregistry.enabled', true)
        java_opts.add_system_property('com.oracle.apm.agent.service.name', cf_app_name.concat('-', cf_space_name))
        java_opts.add_system_property('com.oracle.apm.agent.data.upload.endpoint', apm_upload_endpoint)
        java_opts.add_system_property('com.oracle.apm.agent.private.data.key', apm_private_key)
      end

      protected

      # This component is supported if the app is bound to a service that provides the OCI APM configuration.
      # Specifically, the private-key and the data-upload-endpoint should be configured in the service which contians
      # 'oci-apm' in the service name, label or, tag.
      #
      # (see JavaBuildpack::Component::Services#one_service?)
      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        @application.services.one_service? OCI_APM_SERVICE, [OCI_APM_PRIVATE_KEY, OCI_APM_ENDPOINT]
      end

      OCI_APM_SERVICE = /oci-apm/.freeze
      OCI_APM_PRIVATE_KEY = 'private-key'.freeze
      OCI_APM_ENDPOINT = 'data-upload-endpoint'.freeze
      APM_AGENT_DIR = 'oracle-apm-agent'.freeze

      private_constant :OCI_APM_SERVICE, :OCI_APM_PRIVATE_KEY, :OCI_APM_ENDPOINT, :APM_AGENT_DIR
    end

  end
end