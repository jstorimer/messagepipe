require 'rubygems'
require 'msgpack'
require 'benchmark'
require 'zmq'

class ZMQMessagePipeServer
  CMD_CALL = 0x01
  RET_OK   = 0x02
  RET_E    = 0x03

  def initialize(port = 5555)
    @ctx = ZMQ::Context.new(1)
    @inbound = @ctx.socket ZMQ::REP
     
    @inbound.bind('tcp://127.0.0.1:5555')
  end

  def start
   loop do
    data = @inbound.recv
    msg = MessagePack.unpack(data)

    response = nil
        secs = Benchmark.realtime do 
          response = begin 
            [RET_OK, receive_object(msg)]
          rescue => e
            [RET_E, "#{e.class.name}: #{e.message}"]
          end
        end

        @inbound.send response.to_msgpack
        
        puts "#{object_id} - #{msg[1]}(#{msg[2].length} args) - [%.4f ms] [#{response[0] == RET_OK ? 'ok' : 'error'}]" % [secs||0]
      end
  end

    def receive_object(msg)    
    cmd, method, args = *msg    

    if cmd != CMD_CALL
      # unbind
      raise 'Bad client'
    end
    
    if method and public_methods.include?(method)
      return __send__(method, *args)
    else
      raise NoMethodError, "no method #{method} found."
    end
  end
end

class TestServer < ZMQMessagePipeServer

  def add(a, b)
    a + b
  end

  def hi
    'hello'
  end

  def echo(string)
    string
  end


  def throw
    raise StandardError, 'hell'
  end

  private

  def private_method
    'oh no'
  end
end

TestServer.new.start
