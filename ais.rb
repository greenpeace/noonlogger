
# cron job line to trigger every hour
# */10 * * * * /absolute/path/to/this/file

# edit editme.rb to set local information
require "#{Dir.pwd}/editme.rb"  
require "nmea_plus"  
require "socket"
require "json"
require 'pp'  

$decoder = NMEAPlus::Decoder.new
$aisSock = TCPSocket.new( $AIS_SOCKET_IP, $AIS_SOCKET_PORT )  

$t0 = Time.now
$log = {}
$filename = "ais"

def receive_ais
  raw = $aisSock.recv(4096)
  source_decoder = NMEAPlus::SourceDecoder.new(raw)
  source_decoder.each_complete_message do |msg|
    begin
      next unless [1,2,3].include?(msg.ais.message_type)
      pp msg.ais.attributes
      next unless msg.ais.source_mmsi == $VESSEL_MMSI
      begin
        $log["status"] = msg.ais.get_navigational_status_description(msg.ais.navigational_status)
        break
      rescue
      end
    rescue
      pp "Error: #{msg}"
      pp msg.ais.source_mmsi if msg
    end
  end
  receive_ais unless $log.has_key? "status"
end

receive_ais

$aisSock.close  

File.open("#{Dir.pwd}/data/#{$filename}.json","w") do |file|
  file << $log.to_json
end

