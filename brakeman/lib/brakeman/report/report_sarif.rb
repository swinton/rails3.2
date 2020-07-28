require 'brakeman/report/report_json'

class Brakeman::Report::SARIF < Brakeman::Report::JSON
  def generate_report
    sarif_log = {
      :version => '2.1.0',
      :$schema => 'https://schemastore.azurewebsites.net/schemas/json/sarif-2.1.0-rtm.4.json',
      :runs => runs,
    }
    JSON.pretty_generate sarif_log
  end

  def runs
    [
      {
        :tool => {
          :driver => {
            :name => 'Brakeman',
            :informationUri => 'https://brakemanscanner.org',
            :rules => rules,
          },
        },
        :artifacts => artifacts,
        :results => results,
      },
    ]
  end

  def rules
    @rules ||= unique_warnings.map do |warning|
      check_name = warning.check.gsub(/^Brakeman::Check/, '')
      check_description = check_descriptions[check_name]
      {
        :id => warning.warning_code.to_s,
        :name => warning.warning_type,
        :shortDescription => {
          :text => check_description,
        },
        :fullDescription => {
          :text => check_description,
        },
        :helpUri => warning.link,
        :properties => {
          :warningType => warning.warning_type,
          :checkName => check_name,
          :tags => [check_name],
        },
      }
    end
  end

  def artifacts
    @artifacts ||= unique_locations.map do |location|
      {
        :location => {
          :uri => location,
          :uriBaseId => '%SRCROOT%',
        }
      }
    end
  end

  def results
    @results ||= all_warnings.map do |warning|
      rule_id = warning.warning_code.to_s
      result = {
        :level => 'warning',
        :message => {
          :text => warning.message.to_s,
        },
        :locations => [
          :physicalLocation => {
            :artifactLocation => {
              :uri => warning.file.relative,
              :uriBaseId => '%SRCROOT%',
              :index => unique_locations.index { |l| l == warning.file.relative },
            },
          }
        ],
        :ruleId => rule_id,
        :ruleIndex => rules.index { |r| r[:id] == rule_id },
      }

      # Include region in location where applicable
      if warning.line.is_a? Integer
        # TODO: we may be able to derive startColumn based on user_input
        result[:locations][0][:physicalLocation][:region] = {
          :startLine => warning.line,
          :startColumn => 1,
        }
      end

      result
    end
  end

  # Returns a hash of all check descriptions, keyed by check namne
  def check_descriptions
    @check_descriptions ||= Brakeman::Checks.checks.map do |check|
      [check.name.gsub(/^Check/, ''), check.description]
    end.to_h
  end

  # Returns a de-duplicated set of warnings, used to generate rules
  def unique_warnings
    @unique_warnings ||= all_warnings.uniq { |w| w.warning_code }
  end

  def unique_locations
    @unique_locations ||= all_warnings.map { |w| w.file.relative }.uniq
  end
end
