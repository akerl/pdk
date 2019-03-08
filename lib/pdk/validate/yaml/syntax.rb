require 'pdk'
require 'pdk/cli/exec'
require 'pdk/validate/base_validator'
require 'pdk/util'
require 'pathname'

module PDK
  module Validate
    class YAML
      class Syntax < BaseValidator
        IGNORE_DOTFILES = false
        YAML_WHITELISTED_CLASSES = [Symbol].freeze

        def self.name
          'yaml-syntax'
        end

        def self.pattern
          [
            '**/*.yaml',
            '*.yaml',
            '**/*.yml',
            '*.yml',
          ]
        end

        def self.spinner_text(_targets = [])
          _('Checking YAML syntax (%{targets}).') % {
            targets: pattern,
          }
        end

        def self.create_spinner(targets = [], options = {})
          return unless PDK::CLI::Util.interactive?
          options = options.merge(PDK::CLI::Util.spinner_opts_for_platform)

          exec_group = options[:exec_group]
          @spinner = if exec_group
                       exec_group.add_spinner(spinner_text(targets), options)
                     else
                       TTY::Spinner.new("[:spinner] #{spinner_text(targets)}", options)
                     end
          @spinner.auto_spin
        end

        def self.stop_spinner(exit_code)
          if exit_code.zero? && @spinner
            @spinner.success
          elsif @spinner
            @spinner.error
          end
        end

        def self.invoke(report, options = {})
          targets, skipped, invalid = parse_targets(options)

          process_skipped(report, skipped)
          process_invalid(report, invalid)

          return 0 if targets.empty?

          return_val = 0
          create_spinner(targets, options)

          targets.each do |target|
            next unless File.file?(target)

            unless File.readable?(target)
              report.add_event(
                file:     target,
                source:   name,
                state:    :failure,
                severity: 'error',
                message:  _('Could not be read.'),
              )
              return_val = 1
              next
            end

            begin
              ::YAML.safe_load(File.read(target), YAML_WHITELISTED_CLASSES, [], true)

              report.add_event(
                file:     target,
                source:   name,
                state:    :passed,
                severity: 'ok',
              )
            rescue Psych::SyntaxError => e
              report.add_event(
                file:     target,
                source:   name,
                state:    :failure,
                severity: 'error',
                line:     e.line,
                column:   e.column,
                message:  _('%{problem} %{context}') % {
                  problem: e.problem,
                  context: e.context,
                },
              )
              return_val = 1
            rescue Psych::DisallowedClass => e
              report.add_event(
                file:     target,
                source:   name,
                state:    :failure,
                severity: 'error',
                message:  _('Unsupported class: %{message}') % {
                  message: e.message,
                },
              )
              return_val = 1
            end
          end

          stop_spinner(return_val)
          return_val
        end
      end
    end
  end
end
