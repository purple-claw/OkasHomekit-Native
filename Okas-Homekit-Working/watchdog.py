#!/usr/bin/env python3
"""
OKAS Service Watchdog - Auto-recovery for KNX Bridge and HomeKit services
"""

import json
import os
import subprocess
import sys
import time
from datetime import datetime

# Use paho-mqtt v2 callback API
from paho.mqtt import client as mqtt_client

# Configuration
MQTT_HOST = os.environ.get("MQTT_HOST", "localhost")
MQTT_PORT = int(os.environ.get("MQTT_PORT", "1883"))
CLIENT_ID = "heimdall"

# Topics
TPC_KNX_CONN = "okas/knx/conn"
TPC_WATCHDOG_STATUS = "okas/watchdog/status"
TPC_WATCHDOG_CMD = "okas/watchdog/cmd"

# Thresholds
# The bridge self-retries for 2 minutes; restarting at 10s was restart-storming the board.
DISCONNECT_THRESHOLD_SEC = 60  # Restart if disconnected for > 60 seconds
CHECK_INTERVAL_SEC = 5        # Check every 5 seconds

# Services to monitor/restart
SERVICES = ["callisto.service", "sirius.service", "mosquitto.service"]

class Watchdog:
    def __init__(self):
        self.knx_connected = None
        self.last_knx_status_time = time.time()
        self.last_status_publish = 0
        self.restart_in_progress = False
        self.start_time = time.time()
        
        # MQTT setup using callback API v2
        self.mqtt = mqtt_client.Client(client_id=CLIENT_ID)
        self.mqtt.on_connect = self._on_connect
        self.mqtt.on_message = self._on_message
        self.mqtt.on_disconnect = self._on_disconnect
        
        # Last will for watchdog status
        self.mqtt.will_set(TPC_WATCHDOG_STATUS, json.dumps({
            "status": "offline",
            "timestamp": datetime.now().isoformat()
        }), qos=1, retain=True)
        
        self._log("Watchdog starting...")
    
    def _log(self, msg):
        print(f"[WATCHDOG] {datetime.now().strftime('%H:%M:%S')} {msg}")
    
    def _on_connect(self, client, userdata, flags, reason_code):
        if reason_code == 0:
            self._log("MQTT connected")
            # Subscribe to topics
            client.subscribe(TPC_KNX_CONN, qos=1)
            client.subscribe(TPC_WATCHDOG_CMD, qos=1)
            self._publish_status("running", "connected")
        else:
            self._log(f"MQTT connect failed: {reason_code}")
    
    def _on_disconnect(self, client, userdata, reason_code):
        self._log(f"MQTT disconnected: {reason_code}")
    
    def _on_message(self, client, userdata, msg):
        try:
            topic = msg.topic
            payload = json.loads(msg.payload.decode())
            
            if topic == TPC_KNX_CONN:
                connected = payload.get("connected", False)
                prev_state = self.knx_connected
                self.knx_connected = connected
                self.last_knx_status_time = time.time()
                
                if prev_state != connected:
                    state_str = "connected" if connected else "disconnected"
                    self._log(f"KNX bridge {state_str}")
                    self._publish_status("running", "connected" if connected else "disconnected")
            
            elif topic == TPC_WATCHDOG_CMD:
                cmd = payload.get("cmd", "")
                if cmd == "restart":
                    reason = payload.get("reason", "remote")
                    self._log(f"Received restart command: {reason}")
                    self._restart_services(reason)
                elif cmd == "status":
                    self._publish_status("running", "connected" if self.knx_connected else "disconnected")
                elif cmd == "ping":
                    client.publish(TPC_WATCHDOG_STATUS, json.dumps({
                        "status": "pong",
                        "timestamp": datetime.now().isoformat()
                    }))
        
        except Exception as e:
            self._log(f"Error processing message: {e}")
    
    def _publish_status(self, status, knx_status):
        now = time.time()
        if now - self.last_status_publish < 10:  # Throttle to every 10 seconds
            return
        
        self.last_status_publish = now
        payload = {
            "status": status,
            "knx_connected": knx_status,
            "timestamp": datetime.now().isoformat(),
            "uptime": int(now - self.start_time)
        }
        self.mqtt.publish(TPC_WATCHDOG_STATUS, json.dumps(payload), qos=1, retain=True)
    
    def _restart_services(self, reason):
        if self.restart_in_progress:
            self._log("Restart already in progress, skipping")
            return
        
        self.restart_in_progress = True
        self._log(f"=== STARTING SERVICE RESTART (reason: {reason}) ===")
        
        # Publish restart status
        self._publish_status("restarting", "disconnected")
        
        # Stop services in order
        for svc in reversed(SERVICES):
            try:
                self._log(f"Stopping {svc}...")
                subprocess.run(["systemctl", "stop", svc], check=False, capture_output=True)
                time.sleep(2)
            except Exception as e:
                self._log(f"Error stopping {svc}: {e}")
        
        time.sleep(3)
        
        # Broker first; the others just connect to it.
        for svc in reversed(SERVICES):
            try:
                self._log(f"Starting {svc}...")
                subprocess.run(["systemctl", "start", svc], check=False, capture_output=True)
                time.sleep(3)
                
                # Check if service started
                result = subprocess.run(["systemctl", "is-active", svc], capture_output=True, text=True)
                if result.stdout.strip() == "active":
                    self._log(f"{svc} started successfully")
                else:
                    self._log(f"{svc} may not have started properly")
            except Exception as e:
                self._log(f"Error starting {svc}: {e}")
        
        self._log("=== SERVICE RESTART COMPLETE ===")
        self.restart_in_progress = False
        self._publish_status("running", "restarted")
    
    def _check_knx_connection(self):
        """Check if KNX bridge is still connected"""
        if self.knx_connected is None:
            return  # Haven't received status yet
        
        now = time.time()
        time_since_last_status = now - self.last_knx_status_time
        
        if not self.knx_connected and time_since_last_status > DISCONNECT_THRESHOLD_SEC:
            self._log(f"KNX disconnected for {int(time_since_last_status)}s > {DISCONNECT_THRESHOLD_SEC}s threshold")
            self._restart_services("auto-disconnect-timeout")
    
    def run(self):
        """Main loop"""
        # Connect to MQTT
        self._log(f"Connecting to MQTT at {MQTT_HOST}:{MQTT_PORT}...")
        try:
            self.mqtt.connect_async(MQTT_HOST, MQTT_PORT, keepalive=60)
            self.mqtt.loop_start()
        except Exception as e:
            self._log(f"Failed to connect to MQTT: {e}")
            return
        
        self._log("Watchdog running...")
        
        # Main monitoring loop
        try:
            while True:
                self._check_knx_connection()
                
                # Publish periodic status
                self._publish_status("running", "connected" if self.knx_connected else "disconnected")
                
                time.sleep(CHECK_INTERVAL_SEC)
                
        except KeyboardInterrupt:
            self._log("Watchdog stopped by user")
        finally:
            self.mqtt.loop_stop()
            self.mqtt.disconnect()

if __name__ == "__main__":
    watchdog = Watchdog()
    watchdog.run()
