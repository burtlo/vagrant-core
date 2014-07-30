require 'uri'

module VagrantPlugins
  module Shell
    class Config < Vagrant.plugin("2", :config)
      attr_accessor :inline
      attr_accessor :path
      attr_accessor :upload_path
      attr_accessor :args
      attr_accessor :privileged
      attr_accessor :binary
      attr_accessor :keep_color

      def initialize
        @args        = UNSET_VALUE
        @inline      = UNSET_VALUE
        @path        = UNSET_VALUE
        @upload_path = UNSET_VALUE
        @privileged  = UNSET_VALUE
        @binary      = UNSET_VALUE
        @keep_color  = UNSET_VALUE
      end

      def finalize!
        @args        = nil if @args == UNSET_VALUE
        @inline      = nil if @inline == UNSET_VALUE
        @path        = nil if @path == UNSET_VALUE
        @upload_path = "/tmp/vagrant-shell" if @upload_path == UNSET_VALUE
        @privileged  = true if @privileged == UNSET_VALUE
        @binary      = false if @binary == UNSET_VALUE
        @keep_color  = false if @keep_color == UNSET_VALUE

        if @args && !@args.is_a?(Array) && args_valid?
          @args = @args.to_s
        end
      end

      def validate(machine)
        errors = _detected_errors

        # Validate that the parameters are properly set
        if path && inline
          errors << I18n.t("vagrant.provisioners.shell.path_and_inline_set")
        elsif !path && !inline
          errors << I18n.t("vagrant.provisioners.shell.no_path_or_inline")
        end

        # If it is not an URL, we validate the existence of a script to upload
        if path && !remote?
          expanded_path = Pathname.new(path).expand_path(machine.env.root_path)
          if !expanded_path.file?
            errors << I18n.t("vagrant.provisioners.shell.path_invalid",
                              path: expanded_path)
          else
            data = expanded_path.read(16)
            if data && !data.valid_encoding?
              errors << I18n.t(
                "vagrant.provisioners.shell.invalid_encoding",
                actual: data.encoding.to_s,
                default: Encoding.default_external.to_s,
                path: expanded_path.to_s)
            end
          end
        end

        # There needs to be a path to upload the script to
        if !upload_path
          errors << I18n.t("vagrant.provisioners.shell.upload_path_not_set")
        end

        if !args_valid?
          errors << I18n.t("vagrant.provisioners.shell.args_bad_type")
        end

        { "shell provisioner" => errors }
      end

      # Args are optional, but if they're provided we only support them as a
      # string or as an array.
      def args_valid?
        return true if !args
        return true if args.is_a?(String)
        return true if args.is_a?(Fixnum)
        if args.is_a?(Array)
          args.each do |a|
            return false if !a.kind_of?(String) && !a.kind_of?(Fixnum)
          end

          return true
        end
      end

      def remote?
        path =~ URI.regexp(["ftp", "http", "https"])
      end
    end
  end
end