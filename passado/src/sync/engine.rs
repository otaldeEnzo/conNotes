use std::net::SocketAddr;
use std::sync::{Arc, Mutex};
use futures_util::StreamExt;
use tokio_tungstenite::accept_async;
use tokio_tungstenite::tungstenite::Message;

use crate::types::{FolderItem, NoteItem, OperationDelta, SyncMessage};

use std::collections::HashSet;

#[derive(Clone)]
pub struct SyncEngine {
    pub device_id: String,
    pub port: u16,
    pub latest_delta: Arc<Mutex<Option<OperationDelta>>>,
    pub trusted_peers: Arc<Mutex<HashSet<String>>>,
    pub current_pin: Arc<Mutex<Option<String>>>,
}

impl PartialEq for SyncEngine {
    fn eq(&self, other: &Self) -> bool {
        self.device_id == other.device_id && self.port == other.port
    }
}

impl SyncEngine {
    pub fn new(device_id: String, port: u16) -> Self {
        Self {
            device_id,
            port,
            latest_delta: Arc::new(Mutex::new(None)),
            trusted_peers: Arc::new(Mutex::new(HashSet::new())),
            current_pin: Arc::new(Mutex::new(None)),
        }
    }

    pub fn set_pin(&self, pin: String) {
        let mut p = self.current_pin.lock().unwrap();
        *p = Some(pin);
    }

    pub fn add_trusted_peer(&self, peer_id: String) {
        let mut peers = self.trusted_peers.lock().unwrap();
        peers.insert(peer_id);
    }

    pub fn is_trusted(&self, peer_id: &str) -> bool {
        let peers = self.trusted_peers.lock().unwrap();
        peers.contains(peer_id)
    }

    pub fn take_latest_delta(&self) -> Option<OperationDelta> {
        let mut data = self.latest_delta.lock().unwrap();
        data.take()
    }

    pub fn bind_listener(preferred_port: u16) -> (std::net::TcpListener, u16) {
        for p in preferred_port..preferred_port + 50 {
            if let Ok(listener) = std::net::TcpListener::bind(format!("0.0.0.0:{}", p)) {
                let _ = listener.set_nonblocking(true);
                return (listener, p);
            }
        }
        let listener = std::net::TcpListener::bind("0.0.0.0:0").expect("Failed to bind any port");
        let _ = listener.set_nonblocking(true);
        let port = listener.local_addr().map(|a| a.port()).unwrap_or(0);
        (listener, port)
    }

    pub fn start_server(&self, listener: std::net::TcpListener) {
        let engine = self.clone();
        tokio::spawn(async move {
            let listener = match tokio::net::TcpListener::from_std(listener) {
                Ok(l) => l,
                Err(e) => {
                    eprintln!("[SyncEngine] Failed to convert std TcpListener to tokio: {}", e);
                    return;
                }
            };
            while let Ok((stream, peer_addr)) = listener.accept().await {
                let engine_clone = engine.clone();
                tokio::spawn(async move {
                    engine_clone.handle_connection(stream, peer_addr).await;
                });
            }
        });
    }

    async fn handle_connection<S>(&self, stream: S, _peer_addr: SocketAddr)
    where
        S: tokio::io::AsyncRead + tokio::io::AsyncWrite + Unpin + Send + 'static,
    {
        let ws_stream = match accept_async(stream).await {
            Ok(ws) => ws,
            Err(_) => return,
        };

        let (mut write, mut read) = ws_stream.split();

        while let Some(msg) = read.next().await {
            match msg {
                Ok(Message::Text(text)) => {
                    if let Ok(sync_msg) = serde_json::from_str::<SyncMessage>(&text) {
                        if sync_msg.sender_id != self.device_id {
                            match &sync_msg.delta {
                                OperationDelta::PairingRequest { pin, device_id, device_name: _ } => {
                                    let active_pin = self.current_pin.lock().unwrap().clone();
                                    if let Some(valid_pin) = active_pin {
                                        let clean_incoming = pin.replace('-', "").replace(' ', "").trim().to_string();
                                        let clean_valid = valid_pin.replace('-', "").replace(' ', "").trim().to_string();
                                        if clean_incoming == clean_valid {
                                            println!("[SyncEngine] 🔑 Pairing Successful for device: {}", device_id);
                                            self.add_trusted_peer(device_id.clone());

                                            // Respond to peer that pairing is accepted
                                            let response_msg = SyncMessage {
                                                sender_id: self.device_id.clone(),
                                                delta: OperationDelta::PairingResponse { success: true, device_id: self.device_id.clone() },
                                            };
                                            if let Ok(json_resp) = serde_json::to_string(&response_msg) {
                                                let _ = futures_util::SinkExt::send(&mut write, Message::Text(json_resp)).await;
                                            }
                                        }
                                    }
                                }
                                OperationDelta::PairingResponse { success, device_id } => {
                                    if *success {
                                        println!("[SyncEngine] 🔑 Received Pairing Confirmation from device: {}", device_id);
                                        self.add_trusted_peer(device_id.clone());
                                    }
                                }
                                _ => {
                                    // Block unauthenticated sync deltas
                                    if self.is_trusted(&sync_msg.sender_id) {
                                        let mut data = self.latest_delta.lock().unwrap();
                                        *data = Some(sync_msg.delta);
                                    }
                                }
                            }
                        }
                    }
                }
                Ok(Message::Close(_)) => break,
                _ => {}
            }
        }
    }

    pub fn broadcast_delta(&self, peers: &[crate::sync::discovery::PeerInfo], delta: OperationDelta) {
        let sync_msg = SyncMessage {
            sender_id: self.device_id.clone(),
            delta,
        };

        let json_payload = match serde_json::to_string(&sync_msg) {
            Ok(p) => p,
            Err(_) => return,
        };

        for peer in peers.to_vec() {
            let payload = json_payload.clone();
            std::thread::spawn(move || {
                let rt = match tokio::runtime::Builder::new_current_thread().enable_all().build() {
                    Ok(r) => r,
                    Err(_) => return,
                };
                rt.block_on(async move {
                    let ws_url = format!("ws://{}:{}", peer.addr.ip(), peer.ws_port);
                    if let Ok((mut ws_stream, _)) = tokio_tungstenite::connect_async(&ws_url).await {
                        let _ = futures_util::SinkExt::send(&mut ws_stream, Message::Text(payload)).await;
                    }
                });
            });
        }
    }

    pub fn broadcast_to_peers(&self, peers: &[crate::sync::discovery::PeerInfo], folders: &[FolderItem], notes: &[NoteItem]) {
        self.broadcast_delta(peers, OperationDelta::FullSync {
            folders: folders.to_vec(),
            notes: notes.to_vec(),
        });
    }
}
