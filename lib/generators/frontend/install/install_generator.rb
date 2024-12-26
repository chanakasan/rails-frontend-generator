# frozen_string_literal: true

require "yaml"
require "rails/generators"
require "rails/generators/base"

require_relative "helpers"
require_relative "js_package_manager"

module Frontend
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Helpers

      FRAMEWORKS = YAML.load_file(File.expand_path("./frameworks.yml", __dir__))

      source_root File.expand_path("./templates", __dir__)

      class_option :framework, type: :string,
                               desc: "The framework you want to install",
                               enum: FRAMEWORKS.keys,
                               default: nil

      class_option :typescript, type: :boolean, default: false,
                                desc: "Whether to use TypeScript"

      class_option :package_manager, type: :string, default: nil,
                                     enum: JSPackageManager.package_managers,
                                     desc: "The package manager you want to use to install npm packages"

      class_option :interactive, type: :boolean, default: true,
                                 desc: "Whether to prompt for optional installations"

      class_option :tailwind, type: :boolean, default: false,
                              desc: "Whether to install Tailwind CSS"
      class_option :vite, type: :boolean, default: false,
                          desc: "Whether to install Vite Ruby"
      class_option :example_page, type: :boolean, default: true,
                                  desc: "Whether to add an example page"

      class_option :verbose, type: :boolean, default: false,
                             desc: "Run the generator in verbose mode"

      remove_class_option :skip_namespace, :skip_collision_check

      def install
        say "Installing Frontend"

        install_vite unless ruby_vite_installed?
        install_typescript if typescript?
        install_tailwind if install_tailwind?
        install_framework
        install_example_page if options[:example_page]

        say "Copying bin/dev"
        copy_file "#{__dir__}/templates/dev", "bin/dev"
        chmod "bin/dev", 0o755, verbose: verbose?

        say "Frontend successfully installed", :green
      end

      private
      def install_framework_plugin
        return if react?

        unless File.read(vite_config_path).include?(FRAMEWORKS[framework]["vite_plugin_import"])
          say "Adding Vite plugin for #{framework}"
          insert_into_file vite_config_path, "\n    #{FRAMEWORKS[framework]['vite_plugin_call']},", after: "plugins: ["
          prepend_file vite_config_path, "#{FRAMEWORKS[framework]['vite_plugin_import']}\n"
        end
      end

      def install_framework
        say "Installing npm packages for #{framework}"

        add_dependencies(*FRAMEWORKS[framework]["packages"])
        install_framework_plugin

        say "Copying #{main_entrypoint} entrypoint"
        template "#{framework}/#{main_entrypoint}", js_file_path("entrypoints/#{main_entrypoint}")

        if application_layout.exist?
          say "Adding #{main_entrypoint} script tag to the application layout"
          headers = <<-ERB
    <%= #{vite_tag} "main" %>
          ERB
          insert_into_file application_layout.to_s, headers, after: "<%= vite_client_tag %>\n"

          if react? && !application_layout.read.include?("vite_react_refresh_tag")
            say "Adding Vite React Refresh tag to the application layout"
            insert_into_file application_layout.to_s, "<%= vite_react_refresh_tag %>\n    ",
                             before: "<%= vite_client_tag %>"
          end
        else
          say_error "Could not find the application layout file. Please add the following tags manually:", :red
          say_error "+  <%= vite_react_refresh_tag %>" if react?
          say_error "+  <%= #{vite_tag} \"main\" %>"
        end
      end

      def install_typescript
        say "Adding TypeScript support"

        add_dependencies(*FRAMEWORKS[framework]["packages_ts"])

        say "Copying adding scripts to package.json"
        run 'npm pkg set scripts.check="svelte-check --tsconfig ./tsconfig.json && tsc -p tsconfig.node.json"' if svelte?
        run 'npm pkg set scripts.check="vue-tsc -p tsconfig.app.json && tsc -p tsconfig.node.json"' if framework == "vue"
        run 'npm pkg set scripts.check="tsc -p tsconfig.app.json && tsc -p tsconfig.node.json"' if framework == "react"
      end

      def install_example_page
        say "Copying page assets"
        copy_files = FRAMEWORKS[framework]["copy_files"].merge(
          FRAMEWORKS[framework]["copy_files_#{typescript? ? 'ts' : 'js'}"]
        )
        copy_files.each do |source, destination|
          template "#{framework}/#{source}", file_path(format(destination, js_destination_path: js_destination_path))
        end
      end

      def install_tailwind
        say "Installing Tailwind CSS"
        add_dependencies(%w[tailwindcss postcss autoprefixer @tailwindcss/forms @tailwindcss/typography
                            @tailwindcss/container-queries])

        template "tailwind/tailwind.config.js", file_path("tailwind.config.js")
        copy_file "tailwind/postcss.config.js", file_path("postcss.config.js")
        copy_file "tailwind/application.css", js_file_path("entrypoints/application.css")

        if application_layout.exist?
          say "Adding Tailwind CSS to the application layout"
          insert_into_file application_layout.to_s, "<%= vite_stylesheet_tag \"application\" %>\n    ",
                           before: "<%= vite_client_tag %>"
        else
          say_error "Could not find the application layout file. Please add the following tags manually:", :red
          say_error '+  <%= vite_stylesheet_tag "application" %>' if install_tailwind?
        end
      end

      def install_vite
        unless install_vite?
          say_error "This generator only supports Ruby on Rails with Vite.", :red
          exit(false)
        end

        in_root do
          Bundler.with_original_env do
            if (capture = run("bundle add vite_rails", capture: !verbose?))
              say "Vite Rails gem successfully installed", :green
            else
              say capture
              say_error "Failed to install Vite Rails gem", :red
              exit(false)
            end
            if (capture = run("bundle exec vite install", capture: !verbose?))
              say "Vite Rails successfully installed", :green
            else
              say capture
              say_error "Failed to install Vite Rails", :red
              exit(false)
            end
          end
        end
      end

      def ruby_vite_installed?
        return true if package_manager.present? && ruby_vite?

        if !package_manager.present?
          say_status "Could not find a package.json file to install frontend framework.", nil
        elsif gem_installed?("webpacker") || gem_installed?("shakapacker")
          say "Webpacker or Shakapacker is installed.", :yellow
          say "Vite Ruby can work alongside Webpacker or Shakapacker, but it might cause issues.", :yellow
          say "Please see the Vite Ruby documentation for the migration guide:", :yellow
          say "https://vite-ruby.netlify.app/guide/migration.html#webpacker-%F0%9F%93%A6", :yellow
        else
          say_status "Could not find a Vite configuration files " \
                     "(`config/vite.json` & `vite.config.{ts,js,mjs,cjs,mts,cts}`).",
                     nil
        end
        false
      end

      def gem_installed?(name)
        regex = /^[^#]*gem\s+['"]#{name}['"]/
        File.read(file_path("Gemfile")).match?(regex)
      end

      def application_layout
        @application_layout ||= Pathname.new(file_path("app/views/layouts/application.html.erb"))
      end

      def ruby_vite?
        file?("config/vite.json") && vite_config_path
      end

      def package_manager
        @package_manager ||= JSPackageManager.new(self)
      end

      def add_dependencies(*packages)
        package_manager.add_dependencies(*packages)
      end

      def vite_config_path
        @vite_config_path ||= Dir.glob(file_path("vite.config.{ts,js,mjs,cjs,mts,cts}")).first
      end

      def install_vite?
        return @install_vite if defined?(@install_vite)

        @install_vite = options[:vite] || yes?("Would you like to install Vite Ruby? (y/n)", :green)
      end

      def install_tailwind?
        return @install_tailwind if defined?(@install_tailwind)

        @install_tailwind = options[:tailwind] || yes?("Would you like to install Tailwind CSS? (y/n)", :green)
      end

      def typescript?
        return @typescript if defined?(@typescript)

        @typescript = options[:typescript] || yes?("Would you like to use TypeScript? (y/n)", :green)
      end

      def main_entrypoint
        "main.#{typescript? ? 'ts' : 'js'}"
      end

      def vite_tag
        typescript? ? "vite_typescript_tag" : "vite_javascript_tag"
      end

      def verbose?
        options[:verbose]
      end

      def svelte?
        framework.start_with? "svelte"
      end

      def react?
        framework.start_with? "react"
      end

      def framework
        @framework ||= options[:framework] || ask("What framework do you want to use?", :green,
                                                  limited_to: FRAMEWORKS.keys, default: "react")
      end
    end
  end
end
