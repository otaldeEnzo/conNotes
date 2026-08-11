use std::collections::HashMap;
use std::net::{SocketAddr, UdpSocket};
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

#[derive(Clone, Debug)]
pub struct PeerInfo {
    pub device_id: String,
    pub addr: SocketAddr,
    pub ws_port: u16,
    pub last_seen: Instant,
}

#[derive(Clone)]
pub struct PeerDiscovery {
    pub device_id: String,
    pub ws_port: u16,
    pub peers: Arc<Mutex<HashMap<String, PeerInfo>>>,
}

impl PartialEq for PeerDiscovery {
    fn eq(&self, other: &Self) -> bool {
        self.device_id == other.device_id && self.ws_port == other.ws_port
    }
}

impl PeerDiscovery {
    pub fn new(device_id: String, ws_port: u16) -> Self {
        Self {
            device_id,
            ws_port,
            peers: Arc::new(Mutex::new(HashMap::new())),
        }
    }

    pub fn start(&self) {
        let discovery = self.clone();
        std::thread::spawn(move || {
            // Try binding ports from 44222 to 44230 so multiple instances on same host can receive UDP packets
            let mut bound_socket = None;
            for p in 44222..44232 {
                if let Ok(s) = UdpSocket::bind(format!("0.0.0.0:{}", p)) {
                    bound_socket = Some(s);
                    break;
                }
            }

            let socket = match bound_socket {
                Some(s) => s,
                None => match UdpSocket::bind("0.0.0.0:0") {
                    Ok(s) => s,
                    Err(e) => {
                        eprintln!("[Discovery] Failed to bind UDP socket: {}", e);
                        return;
                    }
                },
            };

            let _ = socket.set_broadcast(true);
            let _ = socket.set_read_timeout(Some(Duration::from_millis(200)));

            let beacon_msg = format!("CN_DISCOVERY:{}:{}", discovery.device_id, discovery.ws_port);
            let mut last_broadcast = Instant::now() - Duration::from_secs(10);
            let mut buf = [0u8; 512];

            loop {
                // Broadcast beacon every 1.5 seconds across UDP discovery range (44222..44232)
                if last_broadcast.elapsed() >= Duration::from_millis(1500) {
                    for target_port in 44222..44232 {
                        let _ = socket.send_to(beacon_msg.as_bytes(), format!("255.255.255.255:{}", target_port));
                        let _ = socket.send_to(beacon_msg.as_bytes(), format!("127.0.0.1:{}", target_port));
                    }
                    last_broadcast = Instant::now();
                }

                // Listen for incoming peer beacons
                if let Ok((len, src)) = socket.recv_from(&mut buf) {
                    if let Ok(text) = std::str::from_utf8(&buf[..len]) {
                        let parts: Vec<&str> = text.split(':').collect();
                        if parts.len() == 3 && parts[0] == "CN_DISCOVERY" {
                            let peer_id = parts[1].to_string();
                            let peer_ws_port: u16 = parts[2].parse().unwrap_or(44223);

                            if peer_id != discovery.device_id {
                                let mut peer_addr = src;
                                peer_addr.set_port(peer_ws_port);

                                // If discovery packet arrived from local interfaces or virtual VPN adapter on same machine, route via 127.0.0.1
                                if peer_addr.ip().is_loopback() || src.ip().to_string().starts_with("26.") || src.ip().to_string().starts_with("192.168.") {
                                    peer_addr.set_ip(std::net::IpAddr::V4(std::net::Ipv4Addr::new(127, 0, 0, 1)));
                                }

                                let mut peers_map = discovery.peers.lock().unwrap();
                                let is_new = !peers_map.contains_key(&peer_id);
                                peers_map.insert(
                                    peer_id.clone(),
                                    PeerInfo {
                                        device_id: peer_id.clone(),
                                        addr: peer_addr,
                                        ws_port: peer_ws_port,
                                        last_seen: Instant::now(),
                                    },
                                );
                                if is_new {
                                    println!("[Discovery] 📡 New Peer Discovered: {} @ {}", peer_id, peer_addr);
                                }
                            }
                        }
                    }
                }

                // Prune stale peers not seen for 10 seconds
                let mut peers_map = discovery.peers.lock().unwrap();
                peers_map.retain(|id, peer| {
                    let active = peer.last_seen.elapsed() < Duration::from_secs(10);
                    if !active {
                        println!("[Discovery] ❌ Peer disconnected/stale: {}", id);
                    }
                    active
                });

                std::thread::sleep(Duration::from_millis(50));
            }
        });
    }

    pub fn get_active_peers(&self) -> Vec<PeerInfo> {
        let peers_map = self.peers.lock().unwrap();
        peers_map.values().cloned().collect()
    }
}
