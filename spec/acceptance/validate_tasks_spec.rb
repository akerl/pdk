require 'spec_helper_acceptance'

describe 'pdk validate tasks', module_command: true do
  let(:task_style_spinner) { %r{checking task metadata style}i }
  let(:task_name_spinner) { %r{checking task name}i }

  include_context 'with a fake TTY'

  context 'when run inside of a module' do
    include_context 'in a new module', 'validate_tasks'

    context 'with valid task' do
      before(:all) do
        File.open(File.join('tasks', 'valid.json'), 'w') do |f|
          f.puts <<-EOS
{
  "puppet_task_version": 1,
  "supports_noop": false,
  "description": "A short description of this task"
}
          EOS
        end
      end

      after(:all) do
        FileUtils.rm(File.join('tasks', 'valid.json'))
      end

      describe command('pdk validate tasks --format text:stdout --format junit:report.xml') do
        its(:exit_status) { is_expected.to eq(0) }
        its(:stderr) { is_expected.to match(task_name_spinner) }
        its(:stderr) { is_expected.to match(task_style_spinner) }

        describe file('report.xml') do
          its(:content) { is_expected.to contain_valid_junit_xml }
          its(:content) { is_expected.to have_junit_testsuite('task-metadata-lint') }
        end
      end
    end

    context 'with an invalid task name' do
      before(:all) do
        File.open(File.join('tasks', 'Invalid.json'), 'w') do |f|
          f.puts <<-EOS
{
  "puppet_task_version": 1,
  "supports_noop": "false",
  "description": "A short description of this task"
}
          EOS
        end
      end

      after(:all) do
        FileUtils.rm(File.join('tasks', 'Invalid.json'))
      end

      describe command('pdk validate tasks') do
        its(:exit_status) { is_expected.not_to eq(0) }
        its(:stderr) { is_expected.to match(task_name_spinner) }
        its(:stderr) { is_expected.not_to match(task_style_spinner) }
        its(:stdout) { is_expected.to match(%r{invalid task name}i) }
      end
    end

    context 'with invalid task metadata' do
      before(:all) do
        File.open(File.join('tasks', 'invalid.json'), 'w') do |f|
          f.puts <<-EOS
  {
    "puppet_task_version": 1,
    "supports_noop": "false",
    "description": "A short description of this task"
  }
          EOS
        end
      end

      after(:all) do
        FileUtils.rm(File.join('tasks', 'invalid.json'))
      end

      describe command('pdk validate tasks --format text:stdout --format junit:report.xml') do
        its(:exit_status) { is_expected.not_to eq(0) }
        its(:stderr) { is_expected.to match(task_name_spinner) }
        its(:stderr) { is_expected.to match(task_style_spinner) }
        its(:stdout) { is_expected.to match(%r{The property '#/supports_noop' of type string did not match the following type: boolean}i) }

        describe file('report.xml') do
          its(:content) { is_expected.to contain_valid_junit_xml }
          its(:content) do
            is_expected.to have_junit_testcase.in_testsuite('task-metadata-lint').with_attributes(
              'classname' => 'task-metadata-lint',
              'name'      => a_string_matching(%r{invalid.json}),
            ).that_failed(
              'type'    => a_string_matching(%r{error}i),
              'message' => a_string_matching(%r{The property '#/supports_noop' of type string did not match the following type: boolean}i),
            )
          end
        end
      end
    end
  end
end
