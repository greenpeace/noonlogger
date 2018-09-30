
# cron job line to trigger every hour
# 58 * * * * /absolute/path/to/this/file

# edit editme.rb to set local information
require "/var/www/noonlogger/editme.rb"  
require "nmea_plus"  
require "socket"
require "json"
require 'pp'  

$decoder = NMEAPlus::Decoder.new
$nmeaSock = TCPSocket.new( $NMEA_SOCKET_IP, $NMEA_SOCKET_PORT )  

$t0 = Time.now
$log = {}
$noon = false
$filename = nil
begin
  $tz = JSON.parse(File.read("#{$WORKING_DIR}/data/tz.json"))["timedelta"]
rescue
  $tz = 0
end

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
        local = $t0 + $tz * 3600
        $filename = "#{local.strftime("%Y-%m-%d")}_#{$VESSEL_NAME}_NMEA.log"
        puts "#{local.hour}:#{local.minute}"
        $noon = true if local.hour == 11
      elsif mt == "VTG"
        $log["course"] = msg.track_degrees_true
      elsif mt == "GGA"
        $log["position"] = [msg.latitude,msg.longitude]
      end
    rescue => e
      puts "Parse error: #{sentence}"
    end
    if $log.keys.sort.join("") == "coursepositionwind_direction" and $filename
      break
    end
  end
  if $log.keys.sort.join("") == "coursepositionwind_direction" and $filename
    ais = JSON.parse(File.read("#{$WORKING_DIR}/data/ais.json"))
    $log["status"] = ais["status_name"] || ""
    if $noon
      File.open("#{$WORKING_DIR}/data/#{$filename}.json","w") do |file|
        file << $log.to_json
      end
    else
      File.open("#{$WORKING_DIR}/data/position.json","w") do |file|
        file << $log["position"].to_json
      end
    end
  elsif Time.now - $t0 < 300
    sleep 1
    receive_nmea
  end

end

receive_nmea

$nmeaSock.close


