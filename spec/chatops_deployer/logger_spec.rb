require 'chatops_deployer/logger'

describe ChatopsDeployer::Logger do
  include ChatopsDeployer::Logger
  context 'when using default logger' do
    it 'outputs logs to stdout' do
      expect { logger.error('test')} .to output(/ERROR -- : test/).to_stdout
    end
  end

  context 'when using MultiIO logger with file and stdout' do
    let(:log_file_path) { 'logger_test' }
    let(:string_io) { StringIO.new }
    before do
      log_file = File.open(log_file_path, 'a')
      logger = ::Logger.new(ChatopsDeployer::MultiIO.new(string_io, log_file))
      logger.error('test')
    end

    it 'outputs logs to StringIO' do
      expect(string_io.string).to match(/ERROR -- : test/)
    end
    it 'outputs logs to file' do
      expect(File.read(log_file_path)).to match(/ERROR -- : test/)
    end
  end
end
