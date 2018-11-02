# cron job line to trigger every hour
# 55 * * * * /absolute/path/to/ruby /absolute/path/to/this/file

# edit editme.rb to set local information
require "/var/www/noonlogger/editme.rb"  
require "nmea_plus"  
require "socket"
require "json"
require 'pp'  

$decoder = NMEAPlus::Decoder.new
$nmeaSock = TCPSocket.new( $NMEA_SOCKET_IP, $NMEA_SOCKET_PORT )  
if $WIND_SOCKET_PORT and $WIND_SOCKET_PORT != ""
  $windSock = TCPSocket.new( $WIND_SOCKET_IP, $WIND_SOCKET_PORT )  
end

$t0 = Time.now
$log = {}
$noon = nil
$filename = nil
begin
  $tz = JSON.parse(File.read("#{$WORKING_DIR}/data/tz.json"))["timedelta"].to_i
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
        units = {"K"=>0.539957,"M"=>1.94384,"N"=>1}
        $log["wind_force"] = (msg.wind_speed * units[msg.wind_speed_units]).to_i
        $log["wind_direction"] = msg.wind_angle.to_i
      elsif mt == "ZDA"
        local = $t0 + $tz * 3600
        $filename = "#{local.strftime("%Y-%m-%d")}_#{$VESSEL_NAME}_NMEA"
        #puts "#{local.hour}:#{local.min}"
        $noon = true if local.hour.to_i % 24 == 11
      elsif mt == "HDT"
        $log["heading"] = msg.true_heading_degrees.to_f
      elsif mt == "VTG"
        $log["course"] = msg.track_degrees_true.to_i
      elsif ["GGA","RMC"].include?(mt)
        $log["positionLat"] = msg.latitude
        $log["positionLon"] = msg.longitude
      end
    rescue => e
      #puts "Parse error: #{sentence}"
      #puts e.backtrace
    end
  end
  if Time.now - $t0 > 60 and not $log.has_key?("wind_force")
    $log["wind_force"] = "-"
    $log["wind_direction"] = "-"
  end
end

def receive_wind
  raw = $windSock.recv(4096)
  cut = raw.match(/\r\n$/).nil?
  sentences = raw.split(/\r\n/)
  sentences.pop if cut
  sentences.reverse.each_with_index do |sentence|
    begin
      msg = $decoder.parse(sentence)
      mt = msg.message_type
      next if msg.talker == "AI"
      next if $log.has_key?(mt)
      if mt == "MWV"
        units = {"K"=>0.539957,"M"=>1.94384,"N"=>1}
        $log["wind_force"] = (msg.wind_speed * units[msg.wind_speed_units]).to_i
        if msg.wind_angle_reference == "T"
          $log["wind_direction"] = msg.wind_angle.to_i
        elsif $log.has_key?("heading")
          $log["wind_direction"] = ($log["heading"] + msg.wind_angle.to_f).to_i % 360
        end
      end
    rescue => e
      #puts "Parse error: #{sentence}"
      #puts e.backtrace
    end
  end
end

while $log.keys.sort.join("").downcase != "coursepositionlatpositionlonwind_directionwind_force" or $filename.nil?
  #puts "sleepin'"
  sleep 1
  receive_nmea
  if $WIND_SOCKET_PORT and $WIND_SOCKET_PORT != ""
    receive_wind
  end
end

ais = JSON.parse(File.read("#{$WORKING_DIR}/data/ais.json"))
$log["status"] = ais["status_name"] || ""
pp "NMEA"=>$log.except("heading"),"timestamp"=>Time.now.to_i
if $noon
  File.open("#{$WORKING_DIR}/reports/#{$filename}.json","w") do |file|
    file << {"NMEA"=>$log.except("heading"),"timestamp"=>Time.now.to_i}.to_json + "\n"
  end
else
  File.open("#{$WORKING_DIR}/data/position.json","w") do |file|
    file << [$log["positionLat"],$log["positionLon"]].to_json + "\n"
  end
end

$nmeaSock.close


