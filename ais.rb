
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
  raw = $aisSock.recv(4096*2)
  source_decoder = NMEAPlus::SourceDecoder.new(raw)
  source_decoder.each_complete_message do |msg|
    begin
      next unless [1,2,3].include?(msg.ais.message_type)
      pp msg.ais.attributes
      next unless msg.ais.source_mmsi == $VESSEL_MMSI
      begin
        $log["status_id"] = msg.ais.navigational_status
        $log["status_name"] = msg.ais.get_navigational_status_description(msg.ais.navigational_status)
        break
      rescue
      end
    rescue
      pp "Error: #{msg}"
      pp msg.ais.source_mmsi if msg
    end
  end
  if Time.now - $t0 < 300 and not $log.has_key? "status" 
    receive_ais
  end
end

receive_ais

$aisSock.close  

File.open("#{Dir.pwd}/data/ais.json","w") do |file|
  file << $log.to_json
end

