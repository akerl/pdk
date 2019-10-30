require 'spec_helper'
require 'pdk/util/git'

describe PDK::Util::Git do
  describe '.repo?' do
    subject { described_class.repo?(maybe_repo) }

    let(:maybe_repo) { 'pdk-templates' }

    context 'when maybe_repo is a directory' do
      before(:each) do
        allow(File).to receive(:directory?).with(maybe_repo).and_return(true)
        allow(described_class).to receive(:git_with_env).with(hash_including('GIT_DIR' => maybe_repo), 'rev-parse', '--is-bare-repository').and_return(result)
      end

      context 'when `rev-parse --is-bare-repository` returns true' do
        let(:result) do
          { exit_code: 0, stdout: 'true' }
        end

        it { is_expected.to be_truthy }
      end

      context 'when `rev-parse --is-bare-repository` returns false' do
        let(:result) do
          { exit_code: 0, stdout: 'false' }
        end

        it { is_expected.to be_falsey }
      end

      context 'when `rev-parse --is-bare-repository` exits non-zero' do
        let(:result) do
          { exit_code: 1 }
        end

        it { is_expected.to be_falsey }
      end
    end

    context 'when maybe_repo is not a directory' do
      before(:each) do
        allow(File).to receive(:directory?).with(maybe_repo).and_return(false)
        allow(described_class).to receive(:git).with('ls-remote', '--exit-code', maybe_repo).and_return(result)
      end

      context 'when `ls-remote` exits zero' do
        let(:result) do
          { exit_code: 0 }
        end

        it { is_expected.to be_truthy }
      end

      context 'when `ls-remote` exits non-zero' do
        let(:result) do
          { exit_code: 2 }
        end

        it { is_expected.to be_falsey }
      end
    end
  end

  describe '.ls_remote' do
    subject { described_class.ls_remote(repo, ref) }

    let(:repo) { 'https://github.com/puppetlabs/pdk-templates' }
    let(:ref) { 'master' }

    before(:each) do
      allow(described_class).to receive(:git).with('ls-remote', '--refs', repo, ref).and_return(git_result)
    end

    context 'when the repo is unavailable' do
      let(:git_result) do
        {
          exit_code: 1,
          stdout:    'some stdout text',
          stderr:    'some stderr text',
        }
      end

      it 'raises an ExitWithError exception' do
        expect(logger).to receive(:error).with(git_result[:stdout])
        expect(logger).to receive(:error).with(git_result[:stderr])

        expect {
          described_class.ls_remote(repo, ref)
        }.to raise_error(PDK::CLI::ExitWithError, %r{unable to access the template repository}i)
      end
    end

    context 'when the repo is available' do
      let(:git_result) do
        {
          exit_code: 0,
          stdout:    [
            "master-sha\trefs/heads/master",
            "masterful-sha\trefs/heads/masterful",
          ].join("\n"),
        }
      end

      it 'returns only the SHA for the exact ref match' do
        is_expected.to eq('master-sha')
      end
    end
  end
end
