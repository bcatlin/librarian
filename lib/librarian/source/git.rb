require 'fileutils'
require 'pathname'
require 'digest'

require 'librarian/source/git/repository'

module Librarian
  module Source
    class Git

      DEFAULTS = {
        :ref => 'master'
      }

      attr_reader :uri, :ref

      def initialize(uri, options = {})
        @uri = uri
        @ref = options[:ref]
        @repository = nil
        @repository_cache_path = nil
      end

      def to_s
        "#{uri} at #{ref || DEFAULTS[:ref]}"
      end

      def cache!(dependencies)
        unless repository.git?
          repository.path.rmtree if repository.path.exist?
          repository.path.mkpath
          repository.clone!(uri)
        end
        repository.checkout!(ref || DEFAULTS[:ref])
      end

      def repository_cache_path
        @repository_cache_path ||= begin
          dir = Digest::MD5.hexdigest(uri)
          Librarian.cache_path.join("source/git/#{dir}")
        end
      end

      def repository
        @repository ||= begin
          Repository.new(repository_cache_path)
        end
      end

      def manifest_search_paths(dependency)
        paths = [repository.path, repository.path.join(dependency.name)]
        paths.select{|s| s.exist?}
      end

      def manifest?(dependency)
        manifest_search_paths(dependency).any?{|s| dependency.manifest?(s)}
      end

      def dependency_cache_path(dependency)
        manifest_search_paths(dependency).select{|s| dependency.manifest?(s)}.first
      end

      def dependency_install_path(dependency)
        Librarian.install_path.join(dependency.name)
      end

      def install!(dependency)
        cache_path = dependency_cache_path(dependency)
        install_path = dependency_install_path(dependency)
        if install_path.exist?
          debug { "Deleting #{relative_path_to(install_path)}" }
          install_path.rmtree
        end
        debug { "Copying #{relative_path_to(cache_path)} to #{relative_path_to(install_path)}" }
        FileUtils.cp_r(cache_path, install_path)
      end

    private

      def relative_path_to(path)
        Librarian.project_relative_path_to(path)
      end

      def debug
        Librarian.ui.debug "[Librarian] #{yield}"
      end

    end
  end
end