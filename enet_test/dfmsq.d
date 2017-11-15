// query Doom2D:Forever master server
module dfmsq is aliced;

import iv.enet;
import iv.vfs.io;


enum NET_CH_MAIN = 0;

enum NET_MSG_LIST = "\xca"; // 202


struct ServerInfo {
  char[256] ipstr = 0; // [0] is length
  ushort port;
  char[256] namestr = 0; // [0] is length
  char[256] mapstr = 0; // [0] is length
  ubyte mode;
  ubyte players;
  ubyte maxplayers;
  ubyte protover;
  ubyte haspass;

  @property const(char)[] ip () const pure nothrow @trusted @nogc { pragma(inline, true); return ipstr.ptr[1..1+cast(ubyte)ipstr.ptr[0]]; }
  @property const(char)[] name () const pure nothrow @trusted @nogc { pragma(inline, true); return namestr.ptr[1..1+cast(ubyte)namestr.ptr[0]]; }
  @property const(char)[] map () const pure nothrow @trusted @nogc { pragma(inline, true); return mapstr.ptr[1..1+cast(ubyte)mapstr.ptr[0]]; }

  const(ubyte)[] parse (const(ubyte)[] data) {
    if (data.length < 10) throw new Exception("out of data");

    ubyte getu8 () {
      if (data.length < 1) throw new Exception("out of data");
      ubyte res = data.ptr[0];
      data = data[1..$];
      return res;
    }

    ushort getu16 () {
      if (data.length < 2) throw new Exception("out of data");
      ushort res = cast(ushort)(data.ptr[0]|(data.ptr[1]<<16));
      data = data[2..$];
      return res;
    }

    void getstr (char[] st) {
      auto len = getu8();
      st[] = 0;
      st[0] = cast(char)len;
      if (len > 0) {
        if (data.length < len) throw new Exception("out of data");
        st[1..1+len] = (cast(const(char)[])data)[0..len];
        data = data[len..$];
      }
    }

    getstr(ipstr[]);
    port = getu16;
    getstr(namestr[]);
    getstr(mapstr[]);
    mode = getu8;
    players = getu8;
    maxplayers = getu8;
    protover = getu8;
    haspass = getu8;

    return data;
  }

  void dump () {
    writeln(name, " at ", ip, ":", port, ", map ", map, "; mode: ", mode, "; players: ", players, " of ", maxplayers, "; version is ", protover, "; protected: ", haspass);
  }
}


ENetPeer *connectToServer (ENetHost* client) {
  ENetAddress address;
  ENetEvent event;
  ENetPeer *peer;

  enet_address_set_host(&address, "mpms.doom2d.org");
  address.port = 25665;
  // Initiate the connection, allocating the two channels 0 and 1.
  peer = enet_host_connect(client, &address, 2, 0);
  if (peer is null) throw new Exception("No available peers for initiating an ENet connection.");

  // wait up to 5 seconds for the connection attempt to succeed.
  if (enet_host_service(client, &event, 5000) > 0 && event.type == ENET_EVENT_TYPE_CONNECT) {
    return peer;
  }

  // either the 5 seconds are up or a disconnect event was received
  // reset the peer in the event the 5 seconds had run out without any significant event
  enet_peer_reset(peer);
  return null;
}


void runClient (bool compress) {
  auto client = enet_host_create(
    null, // create a client host
    1, // only allow 1 outgoing connection
    2, // allow up 2 channels to be used, 0 and 1
    57600/8, // 56K modem with 56 Kbps downstream bandwidth
    14400/8, // 56K modem with 14 Kbps upstream bandwidth
  );
  if (client is null) throw new Exception("An error occurred while trying to create an ENet client host.");
  scope(exit) enet_host_destroy(client);
  if (compress) enet_host_compress_with_range_coder(client);

  writeln("connecting to server...");
  auto peer = connectToServer(client);
  if (peer is null) {
    writeln("connection failed!");
    return;
  }

  // create a reliable packet of size 1 with query
  auto packet = enet_packet_create(NET_MSG_LIST.ptr, 1, ENET_PACKET_FLAG_RELIABLE|ENET_PACKET_FLAG_NO_ALLOCATE);

  // Send the packet to the peer
  enet_peer_send(peer, NET_CH_MAIN, packet);

  mainloop: for (;;) {
    ENetEvent event;
    // wait up to 1000 milliseconds for an event
    while (enet_host_service(client, &event, 1000) > 0) {
      switch (event.type) {
        case ENET_EVENT_TYPE_CONNECT:
          // to client?!
          writefln("WTF?! A new client connected from %s:%s.", event.peer.address.host, event.peer.address.port);
          // store any relevant client information here
          //event.peer.data = "Client information\0".dup.ptr;
          enet_peer_reset(event.peer);
          break mainloop;
        case ENET_EVENT_TYPE_RECEIVE:
          //writefln("A packet of length %s was received on channel %s.", event.packet.dataLength, event.channelID);
          {
            scope(exit) enet_packet_destroy(event.packet);
            //write("  ["); for (int f = 0; f < event.packet.dataLength; ++f) write(cast(char)event.packet.data[f]); write("]\n");
            // clean up the packet now that we're done using it
            auto data = cast(const(ubyte)[])(event.packet.data[0..event.packet.dataLength]);
            if (data.length < 2) {
              writeln("  ERROR: received packed too small");
              break mainloop;
            }
            if (data[0] != cast(ubyte)NET_MSG_LIST[0]) {
              writeln("  ERROR: invalid reply received");
              break mainloop;
            }
            int count = data[1];
            writeln("server count: ", count);
            data = data[2..$];
            try {
              foreach (immutable sidx; 0..count) {
                ServerInfo si;
                data = si.parse(data);
                si.dump();
              }
            } catch (Exception e) {
              writeln("FATAL: invalid packed received!");
              break mainloop;
            }
          }
          enet_peer_disconnect_later(peer, 0);
          break;
        case ENET_EVENT_TYPE_DISCONNECT:
          writefln("disconnected.");
          // reset the peer's client information
          event.peer.data = null;
          break mainloop;
        default:
          break;
      }
    }
  }
}


void main (string[] args) {
  enum compress = false;
  if (enet_initialize() != 0) throw new Exception("An error occurred while initializing ENet.");
  scope(exit) enet_deinitialize();

  runClient(compress);
}
