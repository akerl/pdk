require 'spec_helper'
require 'net/https'

describe PDK::Util::VendoredFile do
  describe '#read' do
    subject(:vendored_file_read) { described_class.new(file_name, url).read }

    let(:url) { 'https://test.com/test_file' }
    let(:file_name) { 'test_file' }

    let(:package_cachedir) { File.join('/', 'path', 'to', 'package', 'cachedir') }
    let(:package_vendored_path) { File.join(package_cachedir, file_name) }
    let(:package_vendored_content) { 'package file content' }

    let(:cachedir) { File.join('/', 'path', 'to', 'pdk', 'cachedir') }
    let(:gem_vendored_path) { File.join(cachedir, PDK::VERSION, file_name) }
    let(:gem_vendored_content) { 'gem file content' }

    before(:each) do
      allow(PDK::Util).to receive(:package_cachedir).and_return(package_cachedir)
      allow(PDK::Util).to receive(:cachedir).and_return(cachedir)
      allow(File).to receive(:read).with(package_vendored_path).and_return(package_vendored_content)
      allow(File).to receive(:read).with(gem_vendored_path).and_return(gem_vendored_content)
    end

    context 'when running from a package install' do
      before(:each) do
        allow(PDK::Util).to receive(:package_install?).and_return(true)
      end

      it 'returns the content of the file vendored in the package' do
        is_expected.to eq(package_vendored_content)
      end
    end

    context 'when not running from a package install' do
      before(:each) do
        allow(PDK::Util).to receive(:package_install?).and_return(false)
      end

      context 'and the file has already been cached on disk' do
        before(:each) do
          allow(File).to receive(:file?).with(gem_vendored_path).and_return(true)
        end

        it 'returns the content of the vendored file' do
          is_expected.to eq(gem_vendored_content)
        end
      end

      context 'and the file has not already been cached on disk' do
        before(:each) do
          allow(File).to receive(:file?).with(gem_vendored_path).and_return(false)
          allow(Net::HTTP::Get).to receive(:new).with(anything).and_return(mock_request)
          allow(Net::HTTP).to receive(:new).with(any_args).and_return(mock_http)
          allow(mock_http).to receive(:use_ssl=).with(anything)
          allow(mock_http).to receive(:verify_mode=).with(anything)
        end

        let(:download_error) { PDK::Util::VendoredFile::DownloadError }
        let(:mock_http) { instance_double(Net::HTTP) }
        let(:mock_request) { instance_double(Net::HTTP::Get) }
        let(:mock_response) { instance_double(Net::HTTPResponse) }

        context 'and the download succeeded' do
          before(:each) do
            allow(mock_http).to receive(:request).with(mock_request).and_return(mock_response)
            allow(mock_response).to receive(:code).and_return('200')
            allow(mock_response).to receive(:body).and_return(gem_vendored_content)
            allow(FileUtils).to receive(:mkdir_p).with(File.dirname(gem_vendored_path))
            allow(File).to receive(:open).with(any_args).and_call_original
            allow(File).to receive(:open).with(gem_vendored_path, 'wb').and_yield(cached_file)
          end

          let(:cached_file) { StringIO.new }

          it 'caches the download to disk' do
            vendored_file_read

            expect(cached_file.string).to eq(gem_vendored_content + "\n")
          end

          it 'returns the downloaded content' do
            is_expected.to eq(gem_vendored_content)
          end
        end

        context 'and the download failed' do
          before(:each) do
            allow(mock_http).to receive(:request).with(anything).and_return(mock_response)
            allow(mock_response).to receive(:code).and_return('404')
            allow(mock_response).to receive(:message).and_return('file not found')
          end

          it 'raises a DownloadError' do
            expect {
              vendored_file_read
            }.to raise_error(download_error, %r{unable to download.+\. 404: file not found}i)
          end
        end

        context 'and the connection to the remote server failed' do
          before(:each) do
            allow(mock_http).to receive(:request).with(anything).and_raise(Errno::ECONNREFUSED, 'some error')
          end

          it 'raises a DownloadError' do
            expect {
              vendored_file_read
            }.to raise_error(download_error, %r{check internet connectivity}i)
          end
        end
      end
    end
  end
end
