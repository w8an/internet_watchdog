-- internet_watchdog.lua 
-- written by Steven R. Stuart, 12-Sep-2017

--configure wifi network
wifi_cfg = {}
wifi_cfg.ssid = "Frontier8128"
wifi_cfg.pwd  = "2414563699"
net.dns.setdnsserver("74.40.74.40", 0) --Frontier
net.dns.setdnsserver("8.8.8.8", 1)     --Google
--wifi_cfg.save = true

--start network, access point is on the dsl modem
wifi.setmode(wifi.STATION)
wifi.sta.config(wifi_cfg)
--wifi.sta.connect()

--configure electromagnetic relay 
RELAY_PIN = 6  -- D6
RELAY_CLOSE = gpio.LOW
RELAY_OPEN = gpio.HIGH

--configure relay control port
gpio.mode(RELAY_PIN, gpio.OUTPUT)
gpio.write(RELAY_PIN, RELAY_CLOSE)

-- energize relay for 8 seconds
function RestartModem()
  gpio.write(RELAY_PIN, RELAY_OPEN)
  tmr.alarm(2, 8000, tmr.ALARM_AUTO, function()
    gpio.write(RELAY_PIN, RELAY_CLOSE)
    tmr.stop(2)
    end)
end

-- connect to network, dhcp
function WifiConnect()
  tmr.alarm(1, 5000, 1, function()
    if (wifi.sta.getip() == nil) then
      print("Connecting...")
    else
      tmr.stop(1)
      print("Connected, IP is "..wifi.sta.getip())
      print("DNS servers "..net.dns.getdnsserver(0)..", "..net.dns.getdnsserver(1))
    end
  end)
end

-- look up a domain address
function CheckDns(url)  -- returns true on successful lookup
  local resolved
  return function ()   
    net.dns.resolve(url, function(sk, ip)
      if (ip == nil) then --unresolved
        resolved = false
        print("Unresolved!")
      else 
        resolved = true
        print("Resolver:",ip)
      end
    end)
    return resolved
  end
end  

-- determine network status
function Connectivity()
  local i=1
  local failcount=0
  return function ()
    if ( _G.name[i]() ) then --CheckDns
      failcount = 0
    else
      failcount = failcount + 1
    end
    i = i + 1
    if (i > 4) then i = 1 end
    return failcount
  end
end

name = {}  --global array of CheckDns func instances
name[1] = CheckDns("symbolics.com") --first registered internet name
name[2] = CheckDns("httpbin.org")   --handy test site
name[3] = CheckDns("google.com")    --popular search tool
name[4] = CheckDns("godaddy.com")   --popular registrar

--   
FailCount = Connectivity() --initialize upvalues 
WifiConnect()              --start network

-- main program loop, once per minute
tmr.alarm(0, 60000, tmr.ALARM_AUTO, function()
  local fails = FailCount()
  print("Connectivity fail count:", fails )
  print("Heap:", node.heap())
  if ( fails > 5 ) then
    print("Restarting modem...")
    RestartModem()
    print("Waiting for wifi signal...")
    WifiConnect()
    FailCount = Connectivity() -- reset the upvalue
  end
end)  

