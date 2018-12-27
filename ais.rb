
# cron job line to trigger every hour
# 50 * * * * /absolute/path/to/ruby /absolute/path/to/this/file

# edit editme.rb to set local information
require "./editme.rb"  
require "nmea_plus"  
require "socket"
require "json"
require 'pp'  

$decoder = NMEAPlus::Decoder.new
$aisSock = TCPSocket.new( $AIS_SOCKET_IP, $AIS_SOCKET_PORT )  

$t0 = Time.now
$log = {}
$freq = {}
$filename = "ais"

def receive_ais
  raw = $aisSock.recv(4096*2)
  source_decoder = NMEAPlus::SourceDecoder.new(raw)
  source_decoder.each_complete_message do |msg|
    begin
      if msg.ais.source_mmsi.to_s == $VESSEL_MMSI
        puts "\e[32mtime: #{Time.now}, mmsi: #{msg.ais.source_mmsi}, type: #{msg.ais.message_type}\e[0m"
      else
        #puts "\e[31mtime: #{Time.now}, mmsi: #{msg.ais.source_mmsi}, type: #{msg.ais.message_type}\e[0m"
      end
      $freq[msg.ais.source_mmsi] = 0 unless $freq.has_key?(msg.ais.source_mmsi)
      $freq[msg.ais.source_mmsi] += 1
      next unless [1,2,3].include?(msg.ais.message_type)
      # pp [msg.ais.source_mmsi, msg.ais.get_navigational_status_description(msg.ais.navigational_status)]
      next unless msg.ais.source_mmsi.to_s == $VESSEL_MMSI
      begin
        $log["status_id"] = msg.ais.navigational_status
        $log["status_name"] = msg.ais.get_navigational_status_description(msg.ais.navigational_status)
        $log["timestamp"] = Time.now.to_i
      rescue
      end
    rescue
      # pp "Error: #{msg}"
      # pp msg.ais.source_mmsi if msg
    end
  end
end

#while Time.now - $t0 < 300 and not $log.has_key? "status_name" 
while true
  begin
    sleep 0.1
    receive_ais
  rescue Interrupt
    puts
    pp $freq
    exit 0
  end
end

$aisSock.close  

File.open("#{$WORKING_DIR}/data/ais.json","w") do |file|
  file << $log.to_json
end

