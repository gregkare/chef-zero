#
# Author:: John Keiser (<jkeiser@opscode.com>)
# Copyright:: Copyright (c) 2013 Opscode, Inc.
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

require 'chef_zero/data_store/data_already_exists_error'
require 'chef_zero/data_store/data_not_found_error'

module ChefZero
  module DataStore
    class MemoryStore
      def initialize
        clear
      end

      def clear
        @data = {}

        # Create containers
        create_dir([], 'clients')
        create_dir([], 'cookbooks')
        create_dir([], 'data')
        create_dir([], 'environments')
        create_dir([], 'file_store')
        create_dir([], 'nodes')
        create_dir([], 'roles')
        create_dir([], 'sandboxes')
        create_dir([], 'users')

        # Set defaults
        create(['clients'], 'chef-validator', '{ "validator": true }')
        create(['clients'], 'chef-webui', '{ "admin": true }')
        create(['environments'], '_default', '{ "description": "The default Chef environment" }')
        create(['users'], 'admin', '{ "admin": true }')
      end

      def create_dir(path, name, *options)
        parent = _get(path, options.include?(:recursive))

        if parent.has_key?(name)
          raise DataAlreadyExistsError.new(path + [name])
        end
        parent[name] = {}
      end

      def create(path, name, data, *options)
        if !data.is_a?(String)
          raise "set only works with strings"
        end

        parent = _get(path, options.include?(:create_dir))

        if parent.has_key?(name)
          raise DataAlreadyExistsError.new(path + [name])
        end
        parent[name] = data
      end

      def get(path)
        value = _get(path)
        if value.is_a?(Hash)
          raise "get() called on directory #{path.join('/')}"
        end
        value
      end

      def set(path, data, *options)
        if !data.is_a?(String)
          raise "set only works with strings: #{path} = #{data.inspect}"
        end

        # Get the parent
        parent = _get(path[0..-2], options.include?(:create_dir))

        if !options.include?(:create) && !parent[path[-1]]
          raise DataNotFoundError.new(path)
        end
        parent[path[-1]] = data
      end

      def delete(path)
        parent = _get(path[0,path.length-1])
        parent.delete(path[-1])
      end

      def list(path)
        dir = _get(path)
        if !dir.is_a? Hash
          raise "list only works with directories (#{path} = #{dir.class}"
        end
        dir.keys.sort
      end

      def exists?(path)
        begin
          get(path)
          return true
        rescue DataNotFoundError
          return false
        end
      end

      private

      def _get(path, create_dir=false)
        value = @data
        path.each_with_index do |path_part, index|
          if !value.has_key?(path_part)
            if create_dir
              value[path_part] = {}
            else
              raise DataNotFoundError.new(path[0,index+1])
            end
          end
          value = value[path_part]
        end
        value
      end
    end
  end
end