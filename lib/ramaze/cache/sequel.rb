#          Copyright (c) 2009 Michael Fellinger m.fellinger@gmail.com
# All files in this distribution are subject to the terms of the Ruby license.
require 'sequel'

module Ramaze
  class Cache
    ##
    # Cache system that uses Sequel to store data in a database table named
    # "ramaze_cache". Values stored in the database will be automatically serialized/
    # unserialized using Marshal. Originally this cache system didn't work with Sequel 3
    # but this has been fixed by Yorick Peterse.
    #
    # @example
    #  # Define that we want to use the Sequel cache for sessions
    #  Ramaze.options.cache.session  = Ramaze::Cache::Sequel
    #
    #  # Store some data in the session
    #  session["framework"] = "Ramaze"
    #
    #  # Do something with the data
    #  session["framework"] += ", simply (r)amazing"
    #
    # @author Unknown, Yorick Peterse
    #
    class Sequel
      # I can haz API?
      include Cache::API

      ##
      # Model used for managing the data in the database.
      # All data stored in the "value" column will be serialized/unserialized by Sequel itself.
      # The structure of the table that belongs to this model looks like the following:
      #
      #   _________________________________________________________________
      #  |              |              |                |                  |
      #  | (integer) ID | (string) key | (string) value | (date) expires   |
      #  |______________|______________|________________|__________________|
      #
      #
      # Note that "key" is a unique field so double check to see if your application might try
      # to insert an already existing key as this will cause Sequel errors.
      #
      # @author Unknown, Yorick Peterse
      #
      class Table < ::Sequel::Model(:ramaze_cache)
        plugin :schema
        plugin :serialization, :marshal, :value

        # Define the schema for this model
        set_schema do
          primary_key :id
          
          String :key,   :null => false, :unique => true
          String :value, :text => true
          
          Time :expires
        end
      end

      ##
      # Create the cache table if it doesn't exist yet.
      # This cache does not yet support multiple applications unless you
      # give "app" an unique name.
      #
      # @author Unknown, Yorick Peterse
      # @example
      #  cache = Ramaze::Cache::Sequel.new
      #  cache.cache_setup 'my_server', 'chuck_norris', 'blog', 'articles'
      #
      # @param [String] host The hostname of the machine on which the application is running.
      # @param [String] user The user under which the application is running.
      # @param [String] app The name of the "application". For example, when using this cache
      # for session "app" will be set to "session".
      # @param [String] name The name for the row. When using sessions this will be set to the
      # user's session ID.
      #
      def cache_setup(host, user, app, name)
        @namespace = [host, user, app, name].compact.join(':')
        Table.create_table?
        @store = Table
      end

      ##
      # Wipe out _all_ data in the table, use with care!
      #
      # @author Unknown, Yorick Peterse
      # @example
      #  cache = Ramaze::Cache::Sequel.new
      #  cache.cache_clear
      #
      def cache_clear
        @store.delete
      end

      ##
      # Deletes a specific set of records based on the provided keys.
      #
      # @author Unknown, Yorick Peterse
      # @example
      #  # Delete everything where "key" is set to "chunky_bacon"
      #  cache = Ramaze::Cache::Sequel.new
      #  cache.cache_delete 'chunky_bacon'
      #
      # @param [String] *keys A set of keys that define which row has to be deleted.
      #
      def cache_delete(*keys)
        if keys
          keys.each do |key|
            record = @store[:key => namespaced(key)]
            record.delete if record  
          end
        end
      end

      ##
      # Retrieve the cache that belongs to the specified key.
      #
      # @author Unknown, Yorick Peterse
      # @example
      #  cache = Ramaze::Cache::Sequel.new
      #  data  = cache.cache_fetch 'chunky_bacon'
      #
      # @param  [String] key The key that defines what record to retrieve.
      # @param  [String] default The value to return in case no data could be found.
      # @return [String] The unserialized data from the "value" column.
      # @return [String]
      #
      def cache_fetch(key, default = nil)
        # Retrieve the data and return it
        record = @store[:key => namespaced(key)]
        record.value rescue default
      end

      ##
      # Store the specified key/value variables in the cache.
      #
      # @author Unknown, Yorick Peterse
      # @example
      #  cache = Ramaze::Cache::Sequel.new
      #  cache.cache_store 'name', 'Yorick Peterse', :ttl => 3600
      #
      # @param [String] key The name of the cache to store.
      # @param [String] value The actual data to cache.
      # @param [Hash] options Additional options such as the TTL.
      # @return [String]
      #
      def cache_store(key, value, options = {})
        key     = namespaced(key)
        ttl     = options[:ttl] rescue nil
        expires = Time.now + ttl if !ttl.nil?
        record  = @store[:key => key]

        # Figure out if the record is new or already exists
        if !record
          record = @store.create(:key => key, :value => value, :expires => expires)
          record.value
        else
          record = record.update(:value => value, :expires => expires)
          record.value
        end
      end

      ##
      # Generate the namespace for the cache.
      # Namespaces have the format of host:user:app:name:key.
      #
      # @author Unknown
      # @param [String] key The name of the cache key.
      # @return [String]
      #
      def namespaced(key)
        [@namespace, key].join(':')
      end
    end
  end
end
