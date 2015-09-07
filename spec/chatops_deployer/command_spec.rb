require 'chatops_deployer/command'

describe ChatopsDeployer::Command do
  describe '.run' do
    let(:command_string) { 'echo "Hello\nWorld"' }
    let(:command) { ChatopsDeployer::Command.new }
    let(:fake_logger) { double('Logger') }

    before do
      expect(ChatopsDeployer::Command).to receive(:new).and_return(command)
      expect(fake_logger).to receive(:info).with("Running command: #{command_string.inspect}")
    end

    it 'runs the command' do
      allow(fake_logger).to receive(:info)
      command = ChatopsDeployer::Command.run(command: command_string, logger: fake_logger)
      expect(command.output).to eql "Hello\nWorld\n"
    end

    describe 'logging of stdout' do
      let(:command_string) { "echo Hello" }

      it 'logs the stdout of the command that gets run using INFO level' do
        expect(fake_logger).to receive(:info).with("Hello\n")
        command = ChatopsDeployer::Command.run(command: command_string, logger: fake_logger)
        expect(command.success?).to be_truthy
      end
    end

    describe 'logging of stderr' do
      let(:command_string) { "ls /nonexistent" }

      it 'logs the stderr of the command that gets run using INFO level' do
        expect(fake_logger).to receive(:info).with("ls: /nonexistent: No such file or directory\n")
        command = ChatopsDeployer::Command.run(command: "ls /nonexistent", logger: fake_logger)
        expect(command.success?).to be_falsey
      end
    end
  end
end
