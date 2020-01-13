motor_pin = 5
touch_pin1 = 4
touch_pin2 = 3
touch_pin3 = 2
VR_in_progress_flag = 0
ack_flag = 0
EVR_com_flag = 0
head_sensor_status = 1
tummy_sensor_status = 1
back_sensor_status = 1
log_vals = {}; --tbhv
function read_log_from_file(vals)
	file.open("log.txt", "r")
	for i = 1, 4 do
        vals[i] = tonumber((string.gsub(file.readline(), "\n", "")), 10)
    end
	file.close()
end
read_log_from_file(log_vals)
function write_log_to_file(vals)
    file.open("log.txt", "w+")
    for i = 1, 4 do
        file.writeline(vals[i])
    end
    file.close()
end
function inc_log(vals, idx)
	vals[idx] = vals[idx] + 1
	vals[4] = vals[4] + 1
	write_log_to_file(vals)
end
gpio.mode(touch_pin1, gpio.INT)
gpio.mode(touch_pin2, gpio.INT)
gpio.mode(touch_pin3, gpio.INT)
gpio.mode(motor_pin, gpio.OUTPUT)
gpio.write(motor_pin, gpio.LOW)
gpio.trig(touch_pin1, "down" ,function() if(tummy_sensor_status == 1) then inc_log(log_vals, 3) vibrate() end end)
gpio.trig(touch_pin2, "down" ,function() if(back_sensor_status == 1) then inc_log(log_vals, 2) vibrate() end end)
gpio.trig(touch_pin3, "down" ,function() if(head_sensor_status == 1) then inc_log(log_vals, 1) vibrate() end end)
wifi.setmode(wifi.SOFTAP)
cfg={}
cfg.ssid="ESP-AP"
cfg.pwd="12345678"
wifi.ap.config(cfg)
cfg = {ip="192.168.1.1", netmask="255.255.255.0", gateway="192.168.1.1"}
wifi.ap.setip(cfg)
wifi.sleeptype(wifi.LIGHT_SLEEP)
wifi.setphymode(wifi.PHYMODE_G)

function vibrate()
    gpio.write(motor_pin, gpio.HIGH)
    tmr.alarm(1, 500, tmr.ALARM_SINGLE, function() gpio.write(motor_pin, gpio.LOW) end)
end
function voice_rec_request()
    VR_in_progress_flag = 1;
    uart.write(0, "dB");
end
function establish_evr_com()    
    uart.setup( 0, 9600, 8, uart.PARITY_NONE, 1, 0)
    uart.on("data", 1, function(data)
		if(VR_in_progress_flag == 1) then
			VR_in_progress_flag = 0;
			if (ack_flag == 1) then
				ack_flag = 0
				if(data == "A") then uart.write(0, "p@AA");     
				elseif (data == "B") then uart.write(0, "p@CA");
				end
				
			elseif(data == "t") then uart.write(0, "p@BA");
			elseif (data == "e") then uart.write(0, "p@BA");
			elseif (data == "r") then
					VR_in_progress_flag = 1
					ack_flag = 1;
					uart.write(0, " ");
			end
		end
    end, 0)
end
function json_encoder(keys, values)
    pairs = {}
    n = table.getn(keys)
    for i = 1, n do
        pairs[keys[i]] = values[i]
    end
    
    ok, json = pcall(cjson.encode, pairs)
    if ok then
      return json
    else
      return nil
    end
end  

headers = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nConnection: close\r\n\r\n";
msg_list_keys = {"key_0", "key_1", "key_2", "key_3", "key_4", "key_5", "key_6", "key_7", "key_8", "key_9", "key_10",
				"key_11", "key_12", "key_13", "key_14", "key_15", "key_16", "key_17", "key_18", "key_19", "key_20",
				"key_21", "key_22", "key_23", "key_24", "key_25", "key_26", "key_27", "key_28", "key_29", "key_30", "key_31"};
msg_list_vals = {};
function read_table_from_file(vals)
	file.open("msgList.txt", "r")
	for i = 1, 32 do
        vals[i] = tonumber((string.gsub(file.readline(), "\n", "")), 10)
    end
	file.close()
end
read_table_from_file(msg_list_vals)
function write_table_to_file(vals)
    file.open("msgList.txt", "w+")
    for i = 1, 32 do
        file.writeline(vals[i])
    end
    file.close()
end

tmr.register(0, 5000, tmr.ALARM_AUTO, function() voice_rec_request() end)
srv=net.createServer(net.TCP, 10)
srv:listen(80,function(conn)
conn:on("receive", function(client,request)
    local _, _, method, path, vars = string.find(request, "([A-Z]+) (.+)?(.+) HTTP");
    if(method == nil)then 
        _, _, method, path = string.find(request, "([A-Z]+) (.+) HTTP"); 
    end
    local _GET = {}
    if (vars ~= nil)then 
        for k, v in string.gmatch(vars, "(%w+)=(%w+)&*") do 
            _GET[k] = v 
        end 
    end

	if(_GET.pin == "sensorQuery") then
		temp_key = {"key_0", "key_1", "key_2"}
        temp_val = {head_sensor_status, back_sensor_status, tummy_sensor_status}
        client:send(headers..json_encoder(temp_key, temp_val))
	elseif(_GET.pin == "syncQuery") then
		temp_key = {"key_0", "key_1", "key_2", "key_3"}
        temp_val = {log_vals[1], log_vals[2], log_vals[3], log_vals[4]}
        client:send(headers..json_encoder(temp_key, temp_val))
	elseif(_GET.pin == "rstLog") then
        log_vals = {0, 0, 0, 0}
        write_log_to_file(log_vals)
    elseif(_GET.pin == "msgQuery") then
		client:send(headers..json_encoder(msg_list_keys, msg_list_vals));
		
    elseif(string.find(_GET.pin, "playMsg") ~= nil) then -- playback
		local uart_cmd = "p@" .. string.char(tonumber(string.sub(_GET.pin, 8)) + 65) .. "A"
        uart.write(0, uart_cmd)
	elseif(string.find(_GET.pin, "eMsg") ~= nil) then -- erase
		local uart_cmd = "e@" .. string.char(tonumber(string.sub(_GET.pin, 5)) + 65)
		idx = tonumber(string.sub(_GET.pin, 5)) + 1
		msg_list_vals[idx] = 0 -- editing msg table
		write_table_to_file(msg_list_vals) -- saving file
		client:send(headers..json_encoder(msg_list_keys, msg_list_vals))
		uart.write(0, uart_cmd)
	elseif(string.find(_GET.pin, "rMsg") ~= nil) then -- record
		local uart_cmd = "r@" .. string.char(tonumber(string.sub(_GET.pin, 5)) + 65) .. "IA"
		uart.write(0, uart_cmd)
	elseif(string.find(_GET.pin, "stopMsg") ~= nil) then -- stop and save	
		idx = tonumber(string.sub(_GET.pin, 8)) + 1
		msg_list_vals[idx] = 1 -- editing msg table
		write_table_to_file(msg_list_vals) -- saving file
		client:send(headers..json_encoder(msg_list_keys, msg_list_vals));
		uart.write(0, "b")
          
    elseif(_GET.pin == "VR") then
          voice_rec_request();
    elseif(_GET.pin == "SAVR0") then --Stop Auto VR
        tmr.stop(0)
    elseif(_GET.pin == "SAVR1") then --Start Auto VR
        tmr.start(0)
    elseif(_GET.pin == "EVR") then
        if(EVR_com_flag == 0) then
            EVR_com_flag = 1
            establish_evr_com()
        end
    elseif(_GET.pin == "SL") then
        uart.write(0, "x")
    elseif(_GET.pin == "SHES1") then
		head_sensor_status = 1
    elseif(_GET.pin == "SHES0") then
        head_sensor_status = 0
    elseif(_GET.pin == "SBAS1") then
        back_sensor_status = 1
    elseif(_GET.pin == "SBAS0") then
        back_sensor_status = 0
    elseif(_GET.pin == "STUS1") then
        tummy_sensor_status = 1
    elseif(_GET.pin == "STUS0") then
        tummy_sensor_status = 0
    end	
    client:close();
end)
end)
EVR_com_flag = 1
establish_evr_com()
