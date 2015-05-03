--[[
gpio Sensors
 dB trigger: gpio.INT  (interupt), 	pin 2 (index 4)
 IR motion: gpio.INT  (interupt), 	pin 3 (index 9)
 Speaker (beep): gpio.OUTPUT, 		pin 4 (index 2)
]]

--[[
	Timer syntax (nodemcu)
		-- print "hello world" every 1000ms
		tmr.alarm(0, 1000, 1, function() print("hello world") end )
]]

currentState = "init"
showerUsedRecently = "0"
--map gpio index to names
for k,v in ipairs{3,10,4,9,2,1,nil,nil,nil,11,12,nil,6,7,5,8,0} do _G['GPIO'..k-1]=v end
gpio.mode(GPIO4, gpio.OUTPUT)
gpio.mode(GPIO2, gpio.INT)
gpio.mode(GPIO3, gpio.INT)
gpio.mode(GPIO5, gpio.INT)--kill switch

--returns an code that relates to the state
function getState()
-- map a dictionary (no need, just use binary....)
a = gpio.read(GPIO2)--dB trigger
b = gpio.read(GPIO3)--IR sens
return a..b
end

function stateTransition(newState)
--[[			STATES
	-- id	|desc					|sensors
	------------------------------------------------------------------------
	-- 00	|shower/bathroom not in use					|dB trigger: l, IR sens: l
	-- 01	|someone in bathroom, or just ended shower	|dB trigger: l, IR sens: h
	-- 10	|shower on, not in, running toget hot water?|dB trigger: h, IR sens: l
	-- 11	|in shower									|dB trigger: h, IR sens: h
--]]

--[[			TIMERS
	-- 0    | reserved
	-- 1	| alarm for being in the shower 2 minutes (1st, just beep)
	-- 2	| alarm for being in the shower 4 minutes (2nd, just beep)
	-- 3	| alarm for being in the shower 5 minutes (3rd, beep until state transition, and log event)
--]]

	previousState = currentState
	currentState = newState

	if newState ==     "00" then
		tmr.stop(0)
		tmr.stop(1)
		tmr.stop(2)
		tmr.stop(3)
		gpio.write(GPIO4, gpio.LOW)
	elseif newState == "01" then
		tmr.stop(0)
		tmr.stop(1)
		tmr.stop(2)
		tmr.stop(3)
		gpio.write(GPIO4, gpio.LOW)
	elseif newState == "10" then
		tmr.stop(0)
		tmr.stop(1)
		tmr.stop(2)
		tmr.stop(3)
		gpio.write(GPIO4, gpio.LOW)
	elseif newState == "11" then
		true
		tmr.alarm(1,(1000*120),0, beepBeep(2))
		tmr.alarm(2,(1000*240),0, beepBeep(4))
		tmr.alarm(3,(1000*300),0, thirdAlarm)
	end
end

function beepBeep(cnt)
	for i=0,cnt,1
		gpio.write(GPIO4, gpio.HIGH)
		tmr.delay(500000)
		gpio.write(GPIO4, gpio.LOW)
		tmr.delay(500000)
	end
end

function thirdAlarm()
	-- log to server
	writeToServer(">5m")
	-- alarm doesnt stop until a state transition (or kill switch)
	gpio.write(GPIO4, gpio.HIGH)
end

function onChange()
	stateTransition(getState())
end

function killSwitch()
	tmr.stop(0)
	tmr.stop(1)
	tmr.stop(2)
	tmr.stop(3)
	gpio.write(GPIO4, gpio.LOW)
	onChange()
end

-- MQTT

-- init mqtt client with keepalive timer 120sec (the open server im using here doesnt require authentication)
m = mqtt.Client("clientid", 120, "user", "password")
m:lwt("/lwt", "offline", 0, 0)
m:on("connect", function(con) print ("connected") end)
m:on("offline", function(con) print ("offline") end)

-- on publish message receive event
-- for debug purpose ~remove me after c++ server app written
m:on("message", function(conn, topic, data)
  print(topic .. ":" )
  if data ~= nil then
    print(data)
  end
end)

function writeToServer(msg)
	m:connect("iot.eclipse.org", 1883, 0, function(conn) print("connected") end)
	m:subscribe("/cab309eb-d5c1-47b3-b65f-90056d70d71d",0, function(conn) print("subscribe success") end)
	m:publish("/cab309eb-d5c1-47b3-b65f-90056d70d71d",msg,0,0, function(conn) print("sent") end)
	m:close();
end

-- end mqtt

gpio.trig(gpio2,'both',onChange)
gpio.trig(gpio3,'both',onChange)
gpio.trig(gpio5,'both',killSwitch)
