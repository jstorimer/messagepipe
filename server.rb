require 'rubygems'
require 'msgpack'
require 'benchmark'
require 'zmq'

class ZMQMessagePipeServer
      class EMTestXREPHandler
    attr_reader :received
    def initialize(&block)
      @received = []
      @on_writable_callback = block
    end
    def on_writable(socket)
      @on_writable_callback.call(socket) if @on_writable_callback
    end
    def on_readable(socket, messages)
      ident, delim, message = messages.map(&:copy_out_string)
      ident.should == "req1"
      @received += [ident, delim, message].map {|s| ZMQ::Message.new(s)}

      socket.send_msg(ident, delim, "re:#{message}")
    end
  end

  CMD_CALL = 0x01
  RET_OK   = 0x02
  RET_E    = 0x03

  def initialize(port = 5555)
    @ctx = EM::ZMQ::Context.new(1)
    @ctx.bind(ZMQ::XREP, 'tcp://127.0.0.1:5555', EMTestXREPHandler.new)
    #@inbound = @ctx.socket ZMQ::REP

    #@inbound.bind('tcp://127.0.0.1:5555')
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
