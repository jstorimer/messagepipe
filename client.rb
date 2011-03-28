require 'rubygems'
require 'msgpack'
require 'zmq'

class ZMQMessagePipe
    class RemoteError < StandardError
  end
class EMTestXREQHandler
    attr_reader :received
    def initialize
      @received = []
    end
    def on_readable(socket, messages)
      @received += messages
    end
  end



  CMD_CALL = 0x01
  RET_OK   = 0x02
  RET_E    = 0x03

  def initialize
    # create zeromq request / reply socket pair
    @ctx = EM::ZMQ::Context.new
     
    # connect sockets: notice that reply can connect first even with no server!
    # rep.connect('tcp://127.0.0.1:5555')
    @outbound.connect(ZMQ::XREQ, 'tcp://127.0.0.1:5555', EMTestXREQHandler)
  end

  def call(method, *args)
    @outbound.send_msg([CMD_CALL, method, args].to_msgpack)
    # 'hello' * (1024*1024))

    # puts @outbound.recv
    data = @outbound.recv
    resp = MessagePack.unpack(data)
            case resp.first
        when RET_E
          raise RemoteError, resp[1]
        when RET_OK
          return resp[1]
        else
          raise RemoteError, "recieved invalid message: #{msg.inspect}"
        end

  end
end

MessagePipe = ZMQMessagePipe
