require 'spec_helper'

describe Jasmine::Headless::Report do
  include FakeFS::SpecHelpers

  let(:file) { 'report.txt' }

  describe '.load' do
    let(:report) { described_class.load(file) }

    context 'no file' do
      it 'should raise an exception' do
        expect { report }.to raise_error(Errno::ENOENT)
      end
    end

    context 'file' do
      before do
        File.open(file, 'wb') { |fh| fh.puts <<-REPORT }
PASS||Statement||One||file.js:23
FAIL||Statement||Two||file.js:23
CONSOLE||Yes
ERROR||Uh oh||file.js:23
TOTAL||1||2||3||T
REPORT
      end

      it 'should read the report file' do
        report.length.should == 5

        report[0].should == Jasmine::Headless::ReportMessage::Pass.new("Statement One", "file.js:23")
        report[1].should == Jasmine::Headless::ReportMessage::Fail.new("Statement Two", "file.js:23")
        report[2].should == Jasmine::Headless::ReportMessage::Console.new("Yes")
        report[3].should == Jasmine::Headless::ReportMessage::Error.new("Uh oh", "file.js:23")
        report[4].should == Jasmine::Headless::ReportMessage::Total.new(1, 2, 3, true)

        report.total.should == 1
        report.failed.should == 2
        report.should have_used_console
        report.time.should == 3.0

        report.should be_valid

        report.should have_failed_on("Statement Two")
      end
    end
  end
end

