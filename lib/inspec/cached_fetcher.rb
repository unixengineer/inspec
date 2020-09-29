require "inspec/fetcher"
require "forwardable"

module Inspec
  class CachedFetcher
    extend Forwardable

    attr_reader :cache, :target, :fetcher
    def initialize(target, cache)
      @target = target
      @fetcher = Inspec::Fetcher::Registry.resolve(target)

      if @fetcher.nil?
        raise("Could not fetch inspec profile in #{target.inspect}.")
      end

      @cache = cache
    end

    def resolved_source
      fetch
      @fetcher.resolved_source
    end

    def update_from_opts(_opts)
      false
    end

    def cache_key
      k = if target.is_a?(Hash)
            target[:sha256] || target[:ref]
          end

      if k.nil?
        fetcher.cache_key
      else
        k
      end
    end

    def fetch
      ##
      # Plain, local `inspec exec <my_profile>` would not set a cache_key. This
      # is set in other cases such as a versioned compliance run.
      if cache.exists?(cache_key) && compliance_versioned
        Inspec::Log.debug "Using cached dependency for #{target}"
        [cache.preferred_entry_for(cache_key), false]
      else
        Inspec::Log.debug "Dependency does not exist in the cache #{target}"
        fetcher.fetch(cache.base_path_for(fetcher.cache_key))
        assert_cache_sanity!
        [fetcher.archive_path, fetcher.writable?]
      end
    end

    def assert_cache_sanity!
      return unless target.respond_to?(:key?) && target.key?(:sha256)

      exception_message = <<~EOF
        The remote source #{fetcher} no longer has the requested content:

        Request Content Hash: #{target[:sha256]}
        Actual Content Hash: #{fetcher.resolved_source[:sha256]}

        For URL, supermarket, compliance, and other sources that do not
        provide versioned artifacts, this likely means that the remote source
        has changed since your lockfile was generated.
      EOF
      raise exception_message if fetcher.resolved_source[:sha256] != target[:sha256]
    end

    private

    ##
    # This resolves a bug on compliance whereby uploading new profiles to
    # automate (and not specifying a version number when running them) causes
    # old, cached profiles to run. This removes caching when passing a generic
    # profile name as a target.
    def compliance_versioned
      return true if target.match(/^compliance:\/\/.*#(\d|\.)+$/)
      return true if !target.include?("compliance")
      false
    end
  end
end
