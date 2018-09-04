
# cron job line to trigger every hour
# * * * * 58 /absolute/path/to/this/file

# edit editme.rb to set local information
require "#{Dir.pwd}/editme.rb"  
require "nmea_plus"  
require "socket"
require "json"
require 'pp'  

$decoder = NMEAPlus::Decoder.new
$nmeaSock = TCPSocket.new( $NMEA_SOCKET_IP, $NMEA_SOCKET_PORT )  
$aisSock = TCPSocket.new( $AIS_SOCKET_IP, $AIS_SOCKET_PORT )  

$t0 = Time.now
$log = {}
$noon = false
$filename = nil

def receive_nmea
  raw = $nmeaSock.recv(4096)
  cut = raw.match(/\r\n$/).nil?
  sentences = raw.split(/\r\n/)
  sentences.pop if cut
  sentences.reverse.each_with_index do |sentence|
    begin
      msg = $decoder.parse(sentence)
      mt = msg.message_type
      next if msg.talker == "AI"
      next if $log.has_key?(mt)
      if mt == "MWV" and msg.wind_angle_reference == "T"
        $log["wind_direction"] = msg.wind_angle
      elsif mt == "ZDA"
        tz_delta = msg.fields[-2].to_i * 60 * 60
        local = $t0 + tz_delta
        $filename = "#{local.strftime("%Y-%m-%d")}_#{$VESSEL_NAME}_NMEA.log"
        $noon = true if local.hour == 11
      elsif mt == "VTG"
        $log["course"] = msg.track_degrees_true
      elsif mt == "GGA"
      end
    rescue => e
      #puts "Parse error: #{sentence}"
    end
    if $log.keys.sort.join("") == "coursepositionwind_direction" and $filename
      break
    end
  end
end

receive_nmea

$nmeaSock.close  

def receive_ais
  raw = $aisSock.recv(4096)
  cut = raw.match(/\r\n$/).nil?
  sentences = raw.split(/\r\n/)
  sentences.pop if cut
  sentences.reverse.each_with_index do |sentence|
    begin
      msg = $decoder.parse(sentence)
      mt = msg.message_type
      next unless msg.ais.source_mmsi == $VESSEL_MMSI
      next unless [1,2,3].include?(msg.ais.message_type)
      next if $log.has_key?()
      begin
        $log["status"] = msg.ais.get_navigational_status_description(msg.ais.navigational_status)
        break
      rescue
      end
    end
  end
end

receive_ais

$aisSock.close  

if $log.keys.sort.join("") == "coursepositionstatuswind_direction" and $filename and $noon
  File.open("#{Dir.pwd}/data/#{$filename}.json","w") do |file|
    file << $log.to_json
  end
end


