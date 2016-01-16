import iv.enet;
import iv.writer;


void runServer (string[] args, bool compress) {
  ENetAddress address;
  ENetHost* server;

  /* Bind the server to the default localhost. */
  /* A specific host address can be specified by */
  /* enet_address_set_host (& address, "x.x.x.x"); */
  address.host = ENET_HOST_ANY;
  /* Bind the server to port 1234. */
  address.port = 1234;
  server = enet_host_create(
    &address, /* the address to bind the server host to */
    32, /* allow up to 32 clients and/or outgoing connections */
    2, /* allow up to 2 channels to be used, 0 and 1 */
    0, /* assume any amount of incoming bandwidth */
    0, /* assume any amount of outgoing bandwidth */);
  if (server is null) throw new Exception("An error occurred while trying to create an ENet server host.");
  scope(exit) enet_host_destroy(server);
  if (compress) enet_host_compress_with_range_coder(server);

  for (;;) {
    /* main loop */
    ENetEvent event;
    /* Wait up to 1000 milliseconds for an event. */
    while (enet_host_service(server, &event, 1000) > 0) {
      switch (event.type) {
        case ENET_EVENT_TYPE_CONNECT:
          writefln!"A new client connected from %x:%s."(event.peer.address.host, event.peer.address.port);
          /* Store any relevant client information here. */
          event.peer.data = "Client information\0".dup.ptr;

          /* Create a reliable packet of size 7 containing "packet\0" */
          ENetPacket* packet = enet_packet_create("packet\0".ptr, 7, ENET_PACKET_FLAG_RELIABLE);
          /* Extend the packet so and append the string "foo", so it now */
          /* contains "packetfoo\0" */
          //enet_packet_resize(packet, strlen("packetfoo")+1);
          //strcpy(&packet.data[strlen("packet")], "foo");

          /* Send the packet to the peer over channel id 0. */
          /* One could also broadcast the packet by */
          /* enet_host_broadcast(host, 0, packet); */
          enet_peer_send(event.peer, 0, packet);

          /* One could just use enet_host_service() instead. */
          //enet_host_flush (host);
          break;
        case ENET_EVENT_TYPE_RECEIVE:
          writefln!"A packet of length %s containing %s was received from %s on channel %s."(event.packet.dataLength, event.packet.data, event.peer.data, event.channelID);
          write("  ["); for (int f = 0; f < event.packet.dataLength; ++f) write(cast(char)event.packet.data[f]); write("]\n");
          /* Clean up the packet now that we're done using it. */
          enet_packet_destroy(event.packet);
          break;
        case ENET_EVENT_TYPE_DISCONNECT:
          writefln!"%s disconnected."(event.peer.data);
          /* Reset the peer's client information. */
          event.peer.data = null;
          break;
        default: break;
      }
    }
  }
}


ENetPeer *connectToServer (ENetHost* client) {
  ENetAddress address;
  ENetEvent event;
  ENetPeer *peer;

  /* Connect to localhost:1234. */
  enet_address_set_host(&address, "localhost");
  address.port = 1234;
  /* Initiate the connection, allocating the two channels 0 and 1. */
  peer = enet_host_connect(client, &address, 2, 0);
  if (peer is null) throw new Exception("No available peers for initiating an ENet connection.");

  /* Wait up to 5 seconds for the connection attempt to succeed. */
  if (enet_host_service(client, &event, 5000) > 0 && event.type == ENET_EVENT_TYPE_CONNECT) {
    return peer;
  }

  /* Either the 5 seconds are up or a disconnect event was */
  /* received. Reset the peer in the event the 5 seconds */
  /* had run out without any significant event. */
  enet_peer_reset(peer);
  return null;
}


void runClient (string[] args, bool compress) {
  ENetHost* client;

  client = enet_host_create(
    null, /* create a client host */
    1, /* only allow 1 outgoing connection */
    2, /* allow up 2 channels to be used, 0 and 1 */
    57600/8, /* 56K modem with 56 Kbps downstream bandwidth */
    14400/8, /* 56K modem with 14 Kbps upstream bandwidth */);
  if (client is null) throw new Exception("An error occurred while trying to create an ENet client host.");
  scope(exit) enet_host_destroy(client);
  if (compress) enet_host_compress_with_range_coder(client);

  writeln("connecting to server...");
  auto peer = connectToServer(client);
  if (peer is null) {
    writeln("connection failed!");
    return;
  }

  /* Create a reliable packet of size 6 containing "hello\0" */
  ENetPacket* packet = enet_packet_create("hello\0".ptr, 6, ENET_PACKET_FLAG_RELIABLE);

  /* Send the packet to the peer over channel id 0. */
  enet_peer_send(peer, 0, packet);

  for (;;) {
    /* main loop */
    ENetEvent event;
    /* Wait up to 1000 milliseconds for an event. */
    while (enet_host_service(client, &event, 1000) > 0) {
      switch (event.type) {
        case ENET_EVENT_TYPE_CONNECT:
          // to client?!
          writefln!"WTF?! A new client connected from %x:%s."(event.peer.address.host, event.peer.address.port);
          /* Store any relevant client information here. */
          //event.peer.data = "Client information\0".dup.ptr;
          enet_peer_reset(event.peer);
          break;
        case ENET_EVENT_TYPE_RECEIVE:
          writefln!"A packet of length %s containing %s was received from %s on channel %s."(event.packet.dataLength, event.packet.data, event.peer.data, event.channelID);
          write("  ["); for (int f = 0; f < event.packet.dataLength; ++f) write(cast(char)event.packet.data[f]); write("]\n");
          /* Clean up the packet now that we're done using it. */
          enet_packet_destroy(event.packet);
          break;
        case ENET_EVENT_TYPE_DISCONNECT:
          writefln!"%s disconnected."(event.peer.data);
          /* Reset the peer's client information. */
          event.peer.data = null;
          break;
        default: break;
      }
    }
  }
}


void main (string[] args) {
  enum Mode { unknown, client, server }
  auto mode = Mode.unknown;
  bool compress = false;

  foreach (string arg; args[1..$]) {
    if (arg == "client") mode = Mode.client;
    else if (arg == "server") mode = Mode.server;
    else if (arg == "compress") compress = true;
    else throw new Exception("'"~arg~"': what?");
  }
  if (mode == Mode.unknown) throw new Exception("client or server?");
  if (enet_initialize() != 0) throw new Exception("An error occurred while initializing ENet.");
  scope(exit) enet_deinitialize();

  writeln("compression: ", (compress ? "tan" : "ona"));
  if (mode == Mode.client) runClient(args[2..$], compress);
  else runServer(args[2..$], compress);
}
