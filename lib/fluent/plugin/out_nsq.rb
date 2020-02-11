# coding: utf-8

require 'fluent/plugin/output'
require 'nsq'
require 'yajl'

module Fluent::Plugin
  class NSQOutput < Output
    Fluent::Plugin.register_output('nsq', self)

    config_param :topic, :string, default: nil
    config_param :nsqd, :array, default: nil

    config_section :buffer do
      config_set_default :chunk_keys, ['tag']
    end

    def configure(conf)
      super

      fail Fluent::ConfigError, 'Missing nsqd' unless @nsqd
      fail Fluent::ConfigError, 'Missing topic' unless @topic
    end

    def start
      super
      @producer = Nsq::Producer.new(
        nsqd: @nsqd,
        topic: @topic
      )
    end

    def shutdown
      @producer.terminate
      super
    end

    def write(chunk)
      return if chunk.empty?

      tag = chunk.metadata.tag
      chunk.each do |time, record|
        tagged_record = record.merge(
          :_key => tag,
          :_ts => time.to_f,
          :'@timestamp' => Time.at(time).iso8601(3) # kibana/elasticsearch friendly
        )
        begin
          @producer.write(Yajl.dump(tagged_record))
        rescue => e
          log.warn("nsq: #{e}")
        end
      end
    end
  end
end
