# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GoodJob::CurrentThread do
  after { described_class.reset }

  [
    :cron_at,
    :cron_key,
    :error_on_discard,
    :error_on_retry,
    :error_on_retry_stopped,
    :execution_interrupted,
    :retried_job,
    :job,
  ].each do |accessor|
    describe ".#{accessor}" do
      it 'maintains value across threads' do
        described_class.send :"#{accessor}=", 'apple'

        Thread.new do
          described_class.send :"#{accessor}=", 'bear'
        end.join

        expect(described_class.send(accessor)).to eq 'apple'
      end

      it 'maintains value across Rails reloader wrapper' do
        Rails.application.reloader.wrap do
          described_class.send :"#{accessor}=", 'apple'
        end

        expect(described_class.send(accessor)).to eq 'apple'
      end

      it 'is resettable' do
        described_class.send :"#{accessor}=", 'apple'
        described_class.reset
        expect(described_class.send(accessor)).to be_nil
      end
    end
  end

  describe '.active_job_id' do
    let!(:job) { GoodJob::Job.create! active_job_id: SecureRandom.uuid }

    it 'delegates to good_job' do
      expect(described_class.active_job_id).to be_nil

      described_class.job = job
      expect(described_class.active_job_id).to eq job.active_job_id
    end
  end

  describe '.to_h' do
    it 'returns a hash' do
      value = {
        cron_at: 5.minutes.ago,
        cron_key: 'example',
        error_on_discard: false,
        error_on_retry: false,
        error_on_retry_stopped: nil,
        job: instance_double(GoodJob::Job),
        execution_interrupted: nil,
        retried_job: nil,
        retry_now: nil,
      }

      described_class.reset(value)
      expect(described_class.to_h).to eq value
    end
  end

  describe '.within' do
    it 'resets values after closing the block' do
      expect(described_class.cron_key).to be_nil

      described_class.within do
        described_class.cron_key = 'test'
      end

      expect(described_class.cron_key).to be_nil
    end

    it 'preserves values set outside of the block' do
      described_class.cron_key = 'before_test'

      described_class.within do
        expect(described_class.cron_key).to eq 'before_test'

        described_class.cron_key = 'test'
      end

      expect(described_class.cron_key).to eq 'before_test'
    end

    it 'returns the block value' do
      result = described_class.within { 'test_value' }
      expect(result).to eq 'test_value'
    end
  end
end
