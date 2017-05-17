/*
 * Copyright (c) 2002-2015 Lee Salzman
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to permit
 * persons to whom the Software is furnished to do so, subject to the
 * following conditions:
 *
 * The above copyright notice and this permission notice shall be included
 * in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
 * OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN
 * NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
 * DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
 * OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE
 * USE OR OTHER DEALINGS IN THE SOFTWARE.
 */
/*
 * D translation by Ketmar // Invisible Vector
 * This port is licenced under the following GNU GPL.
 * Keep using wrappers, you suckers. Or go GPL.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */
module iv.enet /*is aliced*/;

import iv.alice;


version(BigEndian) {
  ushort ENET_HOST_TO_NET_16 (ushort x) @safe pure @nogc nothrow {
    pragma(inline, true);
    return x;
  }

  uint ENET_HOST_TO_NET_32 (uint x) @safe pure @nogc nothrow {
    pragma(inline, true);
    return x;
  }
} else version(LittleEndian) {
  ushort ENET_HOST_TO_NET_16 (ushort x) @safe pure @nogc nothrow {
    pragma(inline, true);
    return ((x&255)<<8)|(x>>8);
  }

  uint ENET_HOST_TO_NET_32 (uint x) @safe pure @nogc nothrow {
    pragma(inline, true);
    import core.bitop : bswap;
    return bswap(x);
  }
} else {
  static assert(false, "Compiling on another planet!");
}


alias ENET_NET_TO_HOST_16 = ENET_HOST_TO_NET_16;
alias ENET_NET_TO_HOST_32 = ENET_HOST_TO_NET_32;


version(Windows) {
  version(X86_64) {
    alias SOCKET = ulong;
  } else {
    alias SOCKET = uint;
  }

  alias ENetSocket = SOCKET;

  enum ENET_SOCKET_NULL = ~0;

  align(1) struct ENetBuffer {
  align(1):
    usize dataLength;
    void *data;
  }

  enum FD_SETSIZE = 64;

  struct fd_set {
    uint fd_count; // how many are SET?
    SOCKET[FD_SETSIZE] fd_array; // an array of SOCKETs
  }

  alias fd_set ENetSocketSet;

  void ENET_SOCKETSET_EMPTY() (ref ENetSocketSet sockset) {
    sockset.fd_count = 0;
  }

  void ENET_SOCKETSET_ADD() (ref ENetSocketSet sockset, ENetSocket socket) {
    foreach (immutable i; 0..sockset.fd_count) if (sockset.fd_array[i] == socket) return;
    if (sockset.fd_count < FD_SETSIZE) {
      sockset.fd_array[i] = socket;
      ++sockset.fd_count;
    }
  }

  bool ENET_SOCKETSET_CHECK() (ref ENetSocketSet sockset, ENetSocket socket) {
    foreach (immutable i; 0..sockset.fd_count) if (sockset.fd_array[i] == socket) return true;
    return false;
  }

  void ENET_SOCKETSET_REMOVE() (ref ENetSocketSet sockset, ENetSocket socket) {
    foreach (usize i; 0..sockset.fd_count) {
      if (sockset.fd_array[i] == socket) {
        while (i < sockset.fd_count-1) {
          sockset.fd_array[i] = sockset.fd_array[i+1];
          ++i;
        }
        --sockset.fd_count;
        return;
      }
    }
  }
} else {
  static import core.sys.posix.sys.select; // fd_set

  alias ENetSocket = int;
  enum ENET_SOCKET_NULL = -1;

  alias ENetSocketSet = core.sys.posix.sys.select.fd_set;

  align(1) struct ENetBuffer {
  align(1):
    void* data;
    usize dataLength;
  }
}


// types.h
alias enet_uint8 = ubyte;
alias enet_uint16 = ushort;
alias enet_uint32 = uint;


// protocol.h
enum {
  ENET_PROTOCOL_MINIMUM_MTU             = 576,
  ENET_PROTOCOL_MAXIMUM_MTU             = 4096,
  ENET_PROTOCOL_MAXIMUM_PACKET_COMMANDS = 32,
  ENET_PROTOCOL_MINIMUM_WINDOW_SIZE     = 4096,

  // Warning when using this constant, it depends on the linked library version:
  // - enet <= 1.3.9 defines ENET_PROTOCOL_MAXIMUM_WINDOW_SIZE as 32768
  // - enet >= 1.3.9 defines ENET_PROTOCOL_MAXIMUM_WINDOW_SIZE as 65536
  ENET_PROTOCOL_MAXIMUM_WINDOW_SIZE     = 65536,

  ENET_PROTOCOL_MINIMUM_CHANNEL_COUNT   = 1,
  ENET_PROTOCOL_MAXIMUM_CHANNEL_COUNT   = 255,
  ENET_PROTOCOL_MAXIMUM_PEER_ID         = 0xFFF,
  ENET_PROTOCOL_MAXIMUM_PACKET_SIZE     = 1024*1024*1024,
  ENET_PROTOCOL_MAXIMUM_FRAGMENT_COUNT  = 1024*1024,
}

alias ENetProtocolCommand = int;
enum : ENetProtocolCommand {
  ENET_PROTOCOL_COMMAND_NONE               = 0,
  ENET_PROTOCOL_COMMAND_ACKNOWLEDGE        = 1,
  ENET_PROTOCOL_COMMAND_CONNECT            = 2,
  ENET_PROTOCOL_COMMAND_VERIFY_CONNECT     = 3,
  ENET_PROTOCOL_COMMAND_DISCONNECT         = 4,
  ENET_PROTOCOL_COMMAND_PING               = 5,
  ENET_PROTOCOL_COMMAND_SEND_RELIABLE      = 6,
  ENET_PROTOCOL_COMMAND_SEND_UNRELIABLE    = 7,
  ENET_PROTOCOL_COMMAND_SEND_FRAGMENT      = 8,
  ENET_PROTOCOL_COMMAND_SEND_UNSEQUENCED   = 9,
  ENET_PROTOCOL_COMMAND_BANDWIDTH_LIMIT    = 10,
  ENET_PROTOCOL_COMMAND_THROTTLE_CONFIGURE = 11,
  ENET_PROTOCOL_COMMAND_SEND_UNRELIABLE_FRAGMENT = 12,
  ENET_PROTOCOL_COMMAND_COUNT              = 13,

  ENET_PROTOCOL_COMMAND_MASK               = 0x0F,
}

alias ENetProtocolFlag = int;
enum : ENetProtocolFlag {
  ENET_PROTOCOL_COMMAND_FLAG_ACKNOWLEDGE = (1 << 7),
  ENET_PROTOCOL_COMMAND_FLAG_UNSEQUENCED = (1 << 6),

  ENET_PROTOCOL_HEADER_FLAG_COMPRESSED   = (1 << 14),
  ENET_PROTOCOL_HEADER_FLAG_SENT_TIME    = (1 << 15),
  ENET_PROTOCOL_HEADER_FLAG_MASK         = ENET_PROTOCOL_HEADER_FLAG_COMPRESSED|ENET_PROTOCOL_HEADER_FLAG_SENT_TIME,

  ENET_PROTOCOL_HEADER_SESSION_MASK      = (3 << 12),
  ENET_PROTOCOL_HEADER_SESSION_SHIFT     = 12,
}

align(1) struct ENetProtocolHeader {
align(1):
  enet_uint16 peerID;
  enet_uint16 sentTime;
}

align(1) struct ENetProtocolCommandHeader {
align(1):
  enet_uint8 command;
  enet_uint8 channelID;
  enet_uint16 reliableSequenceNumber;
}

align(1) struct ENetProtocolAcknowledge {
align(1):
   ENetProtocolCommandHeader header;
   enet_uint16 receivedReliableSequenceNumber;
   enet_uint16 receivedSentTime;
}

align(1) struct ENetProtocolConnect {
align(1):
  ENetProtocolCommandHeader header;
  enet_uint16 outgoingPeerID;
  enet_uint8  incomingSessionID;
  enet_uint8  outgoingSessionID;
  enet_uint32 mtu;
  enet_uint32 windowSize;
  enet_uint32 channelCount;
  enet_uint32 incomingBandwidth;
  enet_uint32 outgoingBandwidth;
  enet_uint32 packetThrottleInterval;
  enet_uint32 packetThrottleAcceleration;
  enet_uint32 packetThrottleDeceleration;
  enet_uint32 connectID;
  enet_uint32 data;
}

align(1) struct ENetProtocolVerifyConnect {
align(1):
  ENetProtocolCommandHeader header;
  enet_uint16 outgoingPeerID;
  enet_uint8  incomingSessionID;
  enet_uint8  outgoingSessionID;
  enet_uint32 mtu;
  enet_uint32 windowSize;
  enet_uint32 channelCount;
  enet_uint32 incomingBandwidth;
  enet_uint32 outgoingBandwidth;
  enet_uint32 packetThrottleInterval;
  enet_uint32 packetThrottleAcceleration;
  enet_uint32 packetThrottleDeceleration;
  enet_uint32 connectID;
}

align(1) struct ENetProtocolBandwidthLimit {
align(1):
  ENetProtocolCommandHeader header;
  enet_uint32 incomingBandwidth;
  enet_uint32 outgoingBandwidth;
}

align(1) struct ENetProtocolThrottleConfigure {
align(1):
  ENetProtocolCommandHeader header;
  enet_uint32 packetThrottleInterval;
  enet_uint32 packetThrottleAcceleration;
  enet_uint32 packetThrottleDeceleration;
}

align(1) struct ENetProtocolDisconnect {
align(1):
  ENetProtocolCommandHeader header;
  enet_uint32 data;
}

align(1) struct ENetProtocolPing {
align(1):
  ENetProtocolCommandHeader header;
}

align(1) struct ENetProtocolSendReliable {
align(1):
  ENetProtocolCommandHeader header;
  enet_uint16 dataLength;
}

align(1) struct ENetProtocolSendUnreliable {
align(1):
  ENetProtocolCommandHeader header;
  enet_uint16 unreliableSequenceNumber;
  enet_uint16 dataLength;
}

align(1) struct ENetProtocolSendUnsequenced {
align(1):
  ENetProtocolCommandHeader header;
  enet_uint16 unsequencedGroup;
  enet_uint16 dataLength;
}

align(1) struct ENetProtocolSendFragment {
align(1):
  ENetProtocolCommandHeader header;
  enet_uint16 startSequenceNumber;
  enet_uint16 dataLength;
  enet_uint32 fragmentCount;
  enet_uint32 fragmentNumber;
  enet_uint32 totalLength;
  enet_uint32 fragmentOffset;
}

align(1) union ENetProtocol {
align(1):
  ENetProtocolCommandHeader header;
  ENetProtocolAcknowledge acknowledge;
  ENetProtocolConnect connect;
  ENetProtocolVerifyConnect verifyConnect;
  ENetProtocolDisconnect disconnect;
  ENetProtocolPing ping;
  ENetProtocolSendReliable sendReliable;
  ENetProtocolSendUnreliable sendUnreliable;
  ENetProtocolSendUnsequenced sendUnsequenced;
  ENetProtocolSendFragment sendFragment;
  ENetProtocolBandwidthLimit bandwidthLimit;
  ENetProtocolThrottleConfigure throttleConfigure;
}


// list.h
struct ENetListNode {
  ENetListNode* next;
  ENetListNode* previous;
}

struct ENetList {
  ENetListNode sentinel;
}


// callbacks.h
struct ENetCallbacks {
extern(C) nothrow:
  void* function (usize size) malloc;
  void function (void* memory) free;
  void function () no_memory;
}

//extern(C) void* enet_malloc (usize) nothrow @trusted;
//extern(C) void enet_free (void*) nothrow @trusted;


// enet.h
enum {
  ENET_VERSION_MAJOR = 1,
  ENET_VERSION_MINOR = 3,
  ENET_VERSION_PATCH = 13,
}

int ENET_VERSION_CREATE() (int major, int minor, int patch) pure nothrow @safe @nogc {
  pragma(inline, true);
  return (major << 16) | (minor << 8) | patch;
}

int ENET_VERSION_GET_MAJOR() (int version_) pure nothrow @safe @nogc {
  pragma(inline, true);
  return (version_ >> 16) & 0xFF;
}

int ENET_VERSION_GET_MINOR() (int version_) pure nothrow @safe @nogc {
  pragma(inline, true);
  return (version_ >> 8) & 0xFF;
}

int ENET_VERSION_GET_PATCH() (int version_) pure nothrow @safe @nogc {
  pragma(inline, true);
  return version_ & 0xFF;
}

enum ENET_VERSION = ENET_VERSION_CREATE(ENET_VERSION_MAJOR, ENET_VERSION_MINOR, ENET_VERSION_PATCH);

alias ENetVersion = enet_uint32;

alias ENetSocketType = int;
enum : ENetSocketType {
  ENET_SOCKET_TYPE_STREAM   = 1,
  ENET_SOCKET_TYPE_DATAGRAM = 2,
}

alias ENetSocketWait = int;
enum : ENetSocketWait {
  ENET_SOCKET_WAIT_NONE      = 0,
  ENET_SOCKET_WAIT_SEND      = (1<<0),
  ENET_SOCKET_WAIT_RECEIVE   = (1<<1),
  ENET_SOCKET_WAIT_INTERRUPT = (1<<2),
}

alias ENetSocketOption = int;
enum : ENetSocketOption {
  ENET_SOCKOPT_NONBLOCK  = 1,
  ENET_SOCKOPT_BROADCAST = 2,
  ENET_SOCKOPT_RCVBUF    = 3,
  ENET_SOCKOPT_SNDBUF    = 4,
  ENET_SOCKOPT_REUSEADDR = 5,
  ENET_SOCKOPT_RCVTIMEO  = 6,
  ENET_SOCKOPT_SNDTIMEO  = 7,
  ENET_SOCKOPT_ERROR     = 8,
  ENET_SOCKOPT_NODELAY   = 9,
}

alias ENetSocketShutdown = int;
enum : ENetSocketShutdown {
  ENET_SOCKET_SHUTDOWN_READ       = 0,
  ENET_SOCKET_SHUTDOWN_WRITE      = 1,
  ENET_SOCKET_SHUTDOWN_READ_WRITE = 2,
}

enum {
  ENET_HOST_ANY = 0,
  ENET_HOST_BROADCAST = 0xFFFFFFFFU,
  ENET_PORT_ANY = 0,
}


/**
 * Portable internet address structure.
 *
 * The host must be specified in network byte-order, and the port must be in host
 * byte-order. The constant ENET_HOST_ANY may be used to specify the default
 * server host. The constant ENET_HOST_BROADCAST may be used to specify the
 * broadcast address (255.255.255.255).  This makes sense for enet_host_connect,
 * but not for enet_host_create.  Once a server responds to a broadcast, the
 * address is updated from ENET_HOST_BROADCAST to the server's actual IP address.
 */
struct ENetAddress {
  enet_uint32 host;
  enet_uint16 port;
}

/**
 * Packet flag bit constants.
 *
 * The host must be specified in network byte-order, and the port must be in
 * host byte-order. The constant ENET_HOST_ANY may be used to specify the
 * default server host.
 */
alias ENetPacketFlag = int;
enum : ENetPacketFlag {
  /** packet must be received by the target peer and resend attempts should be
    * made until the packet is delivered */
  ENET_PACKET_FLAG_RELIABLE    = (1 << 0),
  /** packet will not be sequenced with other packets
    * not supported for reliable packets
    */
  ENET_PACKET_FLAG_UNSEQUENCED = (1 << 1),
  /** packet will not allocate data, and user must supply it instead */
  ENET_PACKET_FLAG_NO_ALLOCATE = (1 << 2),
  /** packet will be fragmented using unreliable (instead of reliable) sends
    * if it exceeds the MTU */
  ENET_PACKET_FLAG_UNRELIABLE_FRAGMENT = (1 << 3),

  /** whether the packet has been sent from all queues it has been entered into */
  ENET_PACKET_FLAG_SENT = (1<<8),
}

alias extern(C) nothrow void function (ENetPacket *) ENetPacketFreeCallback;

/**
 * ENet packet structure.
 *
 * An ENet data packet that may be sent to or received from a peer. The shown
 * fields should only be read and never modified. The data field contains the
 * allocated data for the packet. The dataLength fields specifies the length
 * of the allocated data.  The flags field is either 0 (specifying no flags),
 * or a bitwise-or of any combination of the following flags:
 *
 *    ENET_PACKET_FLAG_RELIABLE - packet must be received by the target peer
 *    and resend attempts should be made until the packet is delivered
 *
 *    ENET_PACKET_FLAG_UNSEQUENCED - packet will not be sequenced with other packets
 *    (not supported for reliable packets)
 *
 *    ENET_PACKET_FLAG_NO_ALLOCATE - packet will not allocate data, and user must supply it instead
 *
 *    ENET_PACKET_FLAG_UNRELIABLE_FRAGMENT - packet will be fragmented using unreliable
 *    (instead of reliable) sends if it exceeds the MTU
 *
 *    ENET_PACKET_FLAG_SENT - whether the packet has been sent from all queues it has been entered into
 */
struct ENetPacket {
  usize referenceCount;               /** internal use only */
  enet_uint32 flags;                   /** bitwise-or of ENetPacketFlag constants */
  enet_uint8* data;                    /** allocated data for packet */
  usize dataLength;                   /** length of data */
  ENetPacketFreeCallback freeCallback; /** function to be called when the packet is no longer in use */
  void* userData;                      /** application private data, may be freely modified */
}

struct ENetAcknowledgement {
  ENetListNode acknowledgementList;
  enet_uint32  sentTime;
  ENetProtocol command;
}

struct ENetOutgoingCommand {
  ENetListNode outgoingCommandList;
  enet_uint16 reliableSequenceNumber;
  enet_uint16 unreliableSequenceNumber;
  enet_uint32 sentTime;
  enet_uint32 roundTripTimeout;
  enet_uint32 roundTripTimeoutLimit;
  enet_uint32 fragmentOffset;
  enet_uint16 fragmentLength;
  enet_uint16 sendAttempts;
  ENetProtocol command;
  ENetPacket* packet;
}

struct ENetIncomingCommand {
  ENetListNode incomingCommandList;
  enet_uint16 reliableSequenceNumber;
  enet_uint16 unreliableSequenceNumber;
  ENetProtocol command;
  enet_uint32 fragmentCount;
  enet_uint32 fragmentsRemaining;
  enet_uint32* fragments;
  ENetPacket* packet;
}

alias ENetPeerState = int;
enum : ENetPeerState {
  ENET_PEER_STATE_DISCONNECTED             = 0,
  ENET_PEER_STATE_CONNECTING               = 1,
  ENET_PEER_STATE_ACKNOWLEDGING_CONNECT    = 2,
  ENET_PEER_STATE_CONNECTION_PENDING       = 3,
  ENET_PEER_STATE_CONNECTION_SUCCEEDED     = 4,
  ENET_PEER_STATE_CONNECTED                = 5,
  ENET_PEER_STATE_DISCONNECT_LATER         = 6,
  ENET_PEER_STATE_DISCONNECTING            = 7,
  ENET_PEER_STATE_ACKNOWLEDGING_DISCONNECT = 8,
  ENET_PEER_STATE_ZOMBIE                   = 9,
}

enum ENET_BUFFER_MAXIMUM = 1+2*ENET_PROTOCOL_MAXIMUM_PACKET_COMMANDS;

enum : int {
  ENET_HOST_RECEIVE_BUFFER_SIZE          = 256*1024,
  ENET_HOST_SEND_BUFFER_SIZE             = 256*1024,
  ENET_HOST_BANDWIDTH_THROTTLE_INTERVAL  = 1000,
  ENET_HOST_DEFAULT_MTU                  = 1400,
  ENET_HOST_DEFAULT_MAXIMUM_PACKET_SIZE  = 32*1024*1024,
  ENET_HOST_DEFAULT_MAXIMUM_WAITING_DATA = 32*1024*1024,

  ENET_PEER_DEFAULT_ROUND_TRIP_TIME      = 500,
  ENET_PEER_DEFAULT_PACKET_THROTTLE      = 32,
  ENET_PEER_PACKET_THROTTLE_SCALE        = 32,
  ENET_PEER_PACKET_THROTTLE_COUNTER      = 7,
  ENET_PEER_PACKET_THROTTLE_ACCELERATION = 2,
  ENET_PEER_PACKET_THROTTLE_DECELERATION = 2,
  ENET_PEER_PACKET_THROTTLE_INTERVAL     = 5000,
  ENET_PEER_PACKET_LOSS_SCALE            = (1 << 16),
  ENET_PEER_PACKET_LOSS_INTERVAL         = 10000,
  ENET_PEER_WINDOW_SIZE_SCALE            = 64 * 1024,
  ENET_PEER_TIMEOUT_LIMIT                = 32,
  ENET_PEER_TIMEOUT_MINIMUM              = 5000,
  ENET_PEER_TIMEOUT_MAXIMUM              = 30000,
  ENET_PEER_PING_INTERVAL                = 500,
  ENET_PEER_UNSEQUENCED_WINDOWS          = 64,
  ENET_PEER_UNSEQUENCED_WINDOW_SIZE      = 1024,
  ENET_PEER_FREE_UNSEQUENCED_WINDOWS     = 32,
  ENET_PEER_RELIABLE_WINDOWS             = 16,
  ENET_PEER_RELIABLE_WINDOW_SIZE         = 0x1000,
  ENET_PEER_FREE_RELIABLE_WINDOWS        = 8,
}

struct ENetChannel {
  enet_uint16 outgoingReliableSequenceNumber;
  enet_uint16 outgoingUnreliableSequenceNumber;
  enet_uint16 usedReliableWindows;
  enet_uint16[ENET_PEER_RELIABLE_WINDOWS] reliableWindows;
  enet_uint16 incomingReliableSequenceNumber;
  enet_uint16 incomingUnreliableSequenceNumber;
  ENetList incomingReliableCommands;
  ENetList incomingUnreliableCommands;
}

/**
 * An ENet peer which data packets may be sent or received from.
 *
 * No fields should be modified unless otherwise specified.
 */
struct ENetPeer {
  ENetListNode dispatchList;
  ENetHost* host;
  enet_uint16 outgoingPeerID;
  enet_uint16 incomingPeerID;
  enet_uint32 connectID;
  enet_uint8 outgoingSessionID;
  enet_uint8 incomingSessionID;
  ENetAddress address;           /** Internet address of the peer */
  void* data;                    /** Application private data, may be freely modified */
  ENetPeerState state;
  ENetChannel* channels;
  usize channelCount;           /** Number of channels allocated for communication with peer */
  enet_uint32 incomingBandwidth; /** Downstream bandwidth of the client in bytes/second */
  enet_uint32 outgoingBandwidth; /** Upstream bandwidth of the client in bytes/second */
  enet_uint32 incomingBandwidthThrottleEpoch;
  enet_uint32 outgoingBandwidthThrottleEpoch;
  enet_uint32 incomingDataTotal;
  enet_uint32 outgoingDataTotal;
  enet_uint32 lastSendTime;
  enet_uint32 lastReceiveTime;
  enet_uint32 nextTimeout;
  enet_uint32 earliestTimeout;
  enet_uint32 packetLossEpoch;
  enet_uint32 packetsSent;
  enet_uint32 packetsLost;
  enet_uint32 packetLoss; /** mean packet loss of reliable packets as a ratio with respect to the constant ENET_PEER_PACKET_LOSS_SCALE */
  enet_uint32 packetLossVariance;
  enet_uint32 packetThrottle;
  enet_uint32 packetThrottleLimit;
  enet_uint32 packetThrottleCounter;
  enet_uint32 packetThrottleEpoch;
  enet_uint32 packetThrottleAcceleration;
  enet_uint32 packetThrottleDeceleration;
  enet_uint32 packetThrottleInterval;
  enet_uint32 pingInterval;
  enet_uint32 timeoutLimit;
  enet_uint32 timeoutMinimum;
  enet_uint32 timeoutMaximum;
  enet_uint32 lastRoundTripTime;
  enet_uint32 lowestRoundTripTime;
  enet_uint32 lastRoundTripTimeVariance;
  enet_uint32 highestRoundTripTimeVariance;
  enet_uint32 roundTripTime; /** mean round trip time (RTT), in milliseconds, between sending a reliable packet and receiving its acknowledgement */
  enet_uint32 roundTripTimeVariance;
  enet_uint32 mtu;
  enet_uint32 windowSize;
  enet_uint32 reliableDataInTransit;
  enet_uint16 outgoingReliableSequenceNumber;
  ENetList acknowledgements;
  ENetList sentReliableCommands;
  ENetList sentUnreliableCommands;
  ENetList outgoingReliableCommands;
  ENetList outgoingUnreliableCommands;
  ENetList dispatchedCommands;
  bool needsDispatch;
  enet_uint16 incomingUnsequencedGroup;
  enet_uint16 outgoingUnsequencedGroup;
  enet_uint32[ENET_PEER_UNSEQUENCED_WINDOW_SIZE/32] unsequencedWindow;
  enet_uint32 eventData;
  usize totalWaitingData;
}

/** An ENet packet compressor for compressing UDP packets before socket sends or receives.
 */
struct ENetCompressor {
  /** Context data for the compressor. Must be non-null. */
  void* context;
extern(C) nothrow @trusted:
  /** Compresses from inBuffers[0:inBufferCount-1], containing inLimit bytes, to outData, outputting at most outLimit bytes. Should return 0 on failure. */
  usize function (void* context, const(ENetBuffer)* inBuffers, usize inBufferCount, usize inLimit, enet_uint8* outData, usize outLimit) @nogc compress;
  /** Decompresses from inData, containing inLimit bytes, to outData, outputting at most outLimit bytes. Should return 0 on failure. */
  usize function (void* context, const(enet_uint8)* inData, usize inLimit, enet_uint8* outData, usize outLimit) @nogc decompress;
  /** Destroys the context when compression is disabled or the host is destroyed. May be null. */
  void function (void* context) destroy;
}

/** Callback that computes the checksum of the data held in buffers[0:bufferCount-1] */
extern(C) nothrow @trusted @nogc {
alias ENetChecksumCallback = enet_uint32 function (const(ENetBuffer)* buffers, usize bufferCount);

/** Callback for intercepting received raw UDP packets. Should return 1 to intercept, 0 to ignore, or -1 to propagate an error. */
alias ENetInterceptCallback = int function (ENetHost* host, ENetEvent* event);
}

/** An ENet host for communicating with peers.
  *
  * No fields should be modified unless otherwise stated.

    @sa enet_host_create()
    @sa enet_host_destroy()
    @sa enet_host_connect()
    @sa enet_host_service()
    @sa enet_host_flush()
    @sa enet_host_broadcast()
    @sa enet_host_compress()
    @sa enet_host_compress_with_range_coder()
    @sa enet_host_channel_limit()
    @sa enet_host_bandwidth_limit()
    @sa enet_host_bandwidth_throttle()
  */
struct ENetHost {
  ENetSocket socket;
  ENetAddress address;           /** Internet address of the host */
  enet_uint32 incomingBandwidth; /** downstream bandwidth of the host */
  enet_uint32 outgoingBandwidth; /** upstream bandwidth of the host */
  enet_uint32 bandwidthThrottleEpoch;
  enet_uint32 mtu;
  enet_uint32 randomSeed;
  int recalculateBandwidthLimits;
  ENetPeer* peers;     /** array of peers allocated for this host */
  usize peerCount;    /** number of peers allocated for this host */
  usize channelLimit; /** maximum number of channels allowed for connected peers */
  enet_uint32 serviceTime;
  ENetList dispatchQueue;
  int continueSending;
  usize packetSize;
  enet_uint16 headerFlags;
  ENetProtocol[ENET_PROTOCOL_MAXIMUM_PACKET_COMMANDS] commands;
  usize commandCount;
  ENetBuffer[ENET_BUFFER_MAXIMUM] buffers;
  usize bufferCount;
  ENetChecksumCallback checksum; /** callback the user can set to enable packet checksums for this host */
  ENetCompressor compressor;
  enet_uint8[ENET_PROTOCOL_MAXIMUM_MTU][2] packetData;
  ENetAddress receivedAddress;
  enet_uint8* receivedData;
  usize receivedDataLength;
  enet_uint32 totalSentData;        /** total data sent, user should reset to 0 as needed to prevent overflow */
  enet_uint32 totalSentPackets;     /** total UDP packets sent, user should reset to 0 as needed to prevent overflow */
  enet_uint32 totalReceivedData;    /** total data received, user should reset to 0 as needed to prevent overflow */
  enet_uint32 totalReceivedPackets; /** total UDP packets received, user should reset to 0 as needed to prevent overflow */
  ENetInterceptCallback intercept;  /** callback the user can set to intercept received raw UDP packets */
  usize connectedPeers;
  usize bandwidthLimitedPeers;
  usize duplicatePeers;     /** optional number of allowed peers from duplicate IPs, defaults to ENET_PROTOCOL_MAXIMUM_PEER_ID */
  usize maximumPacketSize;  /** the maximum allowable packet size that may be sent or received on a peer */
  usize maximumWaitingData; /** the maximum aggregate amount of buffer space a peer may use waiting for packets to be delivered */
}

/**
 * An ENet event type, as specified in @ref ENetEvent.
 */
alias ENetEventType = int;
enum : ENetEventType {
  /** no event occurred within the specified time limit */
  ENET_EVENT_TYPE_NONE = 0,

  /** a connection request initiated by enet_host_connect has completed.
    * The peer field contains the peer which successfully connected.
    */
  ENET_EVENT_TYPE_CONNECT = 1,

  /** a peer has disconnected.  This event is generated on a successful
    * completion of a disconnect initiated by enet_pper_disconnect, if
    * a peer has timed out, or if a connection request intialized by
    * enet_host_connect has timed out.  The peer field contains the peer
    * which disconnected. The data field contains user supplied data
    * describing the disconnection, or 0, if none is available.
    */
  ENET_EVENT_TYPE_DISCONNECT = 2,

  /** a packet has been received from a peer.  The peer field specifies the
    * peer which sent the packet.  The channelID field specifies the channel
    * number upon which the packet was received.  The packet field contains
    * the packet that was received; this packet must be destroyed with
    * enet_packet_destroy after use.
    */
  ENET_EVENT_TYPE_RECEIVE = 3,
}

/**
 * An ENet event as returned by enet_host_service().
 */
struct ENetEvent {
  ENetEventType type;   /** type of the event */
  ENetPeer* peer;       /** peer that generated a connect, disconnect or receive event */
  enet_uint8 channelID; /** channel on the peer that generated the event, if appropriate */
  enet_uint32 data;     /** data associated with the event, if appropriate */
  ENetPacket* packet;   /** packet associated with the event, if appropriate */
}


version(Windows) {
  static assert(0, "windoze socket module is not here");
} else extern(C) nothrow @nogc {
  // unix.c
  static import core.sys.posix.sys.select; // FD_XXX


  private __gshared enet_uint32 timeBase = 0;


  auto ENET_SOCKETSET_EMPTY (ref ENetSocketSet sockset) {
    pragma(inline, true);
    core.sys.posix.sys.select.FD_ZERO(&sockset);
  }

  auto ENET_SOCKETSET_ADD (ref ENetSocketSet sockset, ENetSocket socket) {
    pragma(inline, true);
    core.sys.posix.sys.select.FD_SET(socket, &sockset);
  }

  auto ENET_SOCKETSET_REMOVE (ref ENetSocketSet sockset, ENetSocket socket) {
    pragma(inline, true);
    core.sys.posix.sys.select.FD_CLR(socket, &sockset);
  }

  auto ENET_SOCKETSET_CHECK (ref ENetSocketSet sockset, ENetSocket socket) {
    pragma(inline, true);
    return !!core.sys.posix.sys.select.FD_ISSET(socket, &sockset);
  }


  int enet_initialize () {
    return 0;
  }


  void enet_deinitialize () {
  }


  enet_uint32 enet_host_random_seed () {
    import core.stdc.time : time;
    return cast(enet_uint32)time(null);
  }


  enet_uint32 enet_time_get () {
    import core.sys.posix.sys.time : gettimeofday, timeval;
    timeval timeVal = void;
    gettimeofday(&timeVal, null);
    return cast(uint)(timeVal.tv_sec*1000+timeVal.tv_usec/1000-timeBase);
  }


  void enet_time_set (enet_uint32 newTimeBase) {
    import core.sys.posix.sys.time : gettimeofday, timeval;
    timeval timeVal = void;
    gettimeofday(&timeVal, null);
    timeBase = cast(uint)(timeVal.tv_sec*1000+timeVal.tv_usec/1000-newTimeBase);
  }


  int enet_address_set_host (ENetAddress* address, const(char)* name) {
    import core.stdc.string : memset;
    import core.sys.posix.arpa.inet : inet_pton;
    import core.sys.posix.netdb : addrinfo, getaddrinfo, freeaddrinfo;
    import core.sys.posix.netinet.in_ : sockaddr_in;
    import core.sys.posix.sys.socket : AF_INET;

    addrinfo hints = void;
    addrinfo* resultList = null, result = null;

    memset(&hints, 0, hints.sizeof);
    hints.ai_family = AF_INET;

    if (getaddrinfo(name, null, null, &resultList) != 0) return -1;

    for (result = resultList; result !is null; result = result.ai_next) {
      if (result.ai_family == AF_INET && result.ai_addr !is null && result.ai_addrlen >= sockaddr_in.sizeof) {
        sockaddr_in* sin = cast(sockaddr_in*)result.ai_addr;
        address.host = sin.sin_addr.s_addr;
        freeaddrinfo(resultList);
        return 0;
      }
    }

    if (resultList !is null) freeaddrinfo(resultList);

    if (!inet_pton(AF_INET, name, &address.host)) return -1;

    return 0;
  }


  int enet_address_get_host_ip (const ENetAddress* address, char* name, usize nameLength) {
    import core.sys.posix.arpa.inet : inet_ntop;
    import core.sys.posix.sys.socket : AF_INET;

    if (inet_ntop(AF_INET, &address.host, name, cast(uint)nameLength) is null) return -1; // crude x86_64 fix
    return 0;
  }


  int enet_address_get_host (const ENetAddress* address, char* name, usize nameLength) {
    import core.stdc.string : memchr, memset;
    import core.sys.posix.netdb : EAI_NONAME, NI_NAMEREQD, getnameinfo;
    import core.sys.posix.netinet.in_ : sockaddr_in;
    import core.sys.posix.sys.socket : AF_INET;
    import core.sys.posix.sys.socket : sockaddr;

    int err;
    sockaddr_in sin = void;
    memset(&sin, 0, sockaddr_in.sizeof);
    sin.sin_family = AF_INET;
    sin.sin_port = ENET_HOST_TO_NET_16(address.port);
    sin.sin_addr.s_addr = address.host;
    err = getnameinfo(cast(sockaddr*)&sin, sin.sizeof, name, cast(uint)nameLength, null, 0, NI_NAMEREQD); // crude x86_64 fix
    if (!err) {
      if (name !is null && nameLength > 0 && !memchr(name, 0, nameLength)) return -1;
      return 0;
    }
    if (err != EAI_NONAME) return 0;
    return enet_address_get_host_ip(address, name, nameLength);
  }


  int enet_socket_bind (ENetSocket socket, const ENetAddress* address) {
    import core.stdc.string : memset;
    import core.sys.posix.netinet.in_ : INADDR_ANY, sockaddr_in;
    import core.sys.posix.sys.socket : AF_INET, bind, sockaddr;

    sockaddr_in sin = void;
    memset(&sin, 0, sockaddr_in.sizeof);
    sin.sin_family = AF_INET;
    if (address !is null) {
      sin.sin_port = ENET_HOST_TO_NET_16(address.port);
      sin.sin_addr.s_addr = address.host;
    } else {
      sin.sin_port = 0;
      sin.sin_addr.s_addr = INADDR_ANY;
    }
    return bind(socket, cast(sockaddr*)&sin, sockaddr_in.sizeof);
  }


  int enet_socket_get_address (ENetSocket socket, ENetAddress* address) {
    import core.sys.posix.netinet.in_ : sockaddr_in;
    import core.sys.posix.sys.socket : getsockname, sockaddr, socklen_t;

    sockaddr_in sin = void;
    socklen_t sinLength = sockaddr_in.sizeof;
    if (getsockname(socket, cast(sockaddr*)&sin, &sinLength) == -1) return -1;
    address.host = cast(enet_uint32)sin.sin_addr.s_addr;
    address.port = ENET_NET_TO_HOST_16(sin.sin_port);
    return 0;
  }


  int enet_socket_listen (ENetSocket socket, int backlog) {
    import core.sys.posix.sys.socket : SOMAXCONN, listen;
    return listen(socket, (backlog < 0 ? SOMAXCONN : backlog));
  }


  ENetSocket enet_socket_create (ENetSocketType type) {
    import core.sys.posix.sys.socket : AF_INET, SOCK_DGRAM, SOCK_STREAM, socket;
    return socket(AF_INET, (type == ENET_SOCKET_TYPE_DATAGRAM ? SOCK_DGRAM : SOCK_STREAM), 0);
  }


  int enet_socket_set_option (ENetSocket socket, ENetSocketOption option, int value) {
    import core.sys.posix.fcntl : F_GETFL, F_SETFL, O_NONBLOCK, fcntl;
    import core.sys.posix.netinet.in_ : IPPROTO_TCP;
    import core.sys.posix.netinet.tcp : TCP_NODELAY;
    import core.sys.posix.sys.socket : SOL_SOCKET, SO_BROADCAST, SO_REUSEADDR, SO_RCVBUF, SO_SNDBUF,
      SO_RCVTIMEO, SO_SNDTIMEO, setsockopt;
    import core.sys.posix.sys.time : timeval;

    timeval timeVal = void;
    int result = -1;
    switch (option) {
      case ENET_SOCKOPT_NONBLOCK:
        result = fcntl(socket, F_SETFL, (value ? O_NONBLOCK : 0)|(fcntl(socket, F_GETFL)&~O_NONBLOCK));
        break;
      case ENET_SOCKOPT_BROADCAST:
        result = setsockopt(socket, SOL_SOCKET, SO_BROADCAST, cast(void*)&value, int.sizeof);
        break;
      case ENET_SOCKOPT_REUSEADDR:
        result = setsockopt(socket, SOL_SOCKET, SO_REUSEADDR, cast(void*)&value, int.sizeof);
        break;
      case ENET_SOCKOPT_RCVBUF:
        result = setsockopt(socket, SOL_SOCKET, SO_RCVBUF, cast(void*)&value, int.sizeof);
        break;
      case ENET_SOCKOPT_SNDBUF:
        result = setsockopt(socket, SOL_SOCKET, SO_SNDBUF, cast(void*)&value, int.sizeof);
        break;
      case ENET_SOCKOPT_RCVTIMEO:
        timeVal.tv_sec = value/1000;
        timeVal.tv_usec = (value%1000)*1000;
        result = setsockopt(socket, SOL_SOCKET, SO_RCVTIMEO, cast(void*)&timeVal, timeval.sizeof);
        break;
      case ENET_SOCKOPT_SNDTIMEO:
        timeVal.tv_sec = value/1000;
        timeVal.tv_usec = (value%1000)*1000;
        result = setsockopt(socket, SOL_SOCKET, SO_SNDTIMEO, cast(void*)&timeVal, timeval.sizeof);
        break;
      case ENET_SOCKOPT_NODELAY:
        result = setsockopt(socket, IPPROTO_TCP, TCP_NODELAY, cast(void*)&value, int.sizeof);
        break;
      default:
        break;
    }
    return (result == -1 ? -1 : 0);
  }


  int enet_socket_get_option (ENetSocket socket, ENetSocketOption option, int* value) {
    import core.sys.posix.sys.socket : SO_ERROR, SOL_SOCKET, getsockopt, socklen_t;
    socklen_t len;
    int result = -1;
    switch (option) {
      case ENET_SOCKOPT_ERROR:
        len = int.sizeof;
        result = getsockopt(socket, SOL_SOCKET, SO_ERROR, value, &len);
        break;
      default:
        break;
    }
    return (result == -1 ? -1 : 0);
  }


  int enet_socket_connect (ENetSocket socket, const ENetAddress* address) {
    import core.stdc.string : memset;
    import core.sys.posix.netinet.in_ : sockaddr_in;
    import core.sys.posix.sys.socket : AF_INET, connect, sockaddr;

    int result;
    sockaddr_in sin = void;
    memset(&sin, 0, sockaddr_in.sizeof);

    sin.sin_family = AF_INET;
    sin.sin_port = ENET_HOST_TO_NET_16(address.port);
    sin.sin_addr.s_addr = address.host;

    result = connect(socket, cast(sockaddr*)&sin, sockaddr_in.sizeof);
    if (result == -1) {
      import core.stdc.errno : errno, EINPROGRESS;
      if (errno == EINPROGRESS) return 0;
    }

    return result;
  }


  ENetSocket enet_socket_accept (ENetSocket socket, ENetAddress* address) {
    import core.sys.posix.netinet.in_ : sockaddr_in;
    import core.sys.posix.sys.socket : AF_INET, accept, sockaddr, socklen_t;

    int result;
    sockaddr_in sin = void;
    socklen_t sinLength = sockaddr_in.sizeof;

    result = accept(socket, (address !is null ? cast(sockaddr*)&sin : null), (address !is null ? &sinLength : null));
    if (result == -1) return ENET_SOCKET_NULL;

    if (address !is null) {
      address.host = cast(enet_uint32)sin.sin_addr.s_addr;
      address.port = ENET_NET_TO_HOST_16(sin.sin_port);
    }

    return result;
  }


  int enet_socket_shutdown (ENetSocket socket, ENetSocketShutdown how) {
    import core.sys.posix.sys.socket : shutdown;
    return shutdown(socket, cast(int)how);
  }


  void enet_socket_destroy (ENetSocket socket) {
    import core.sys.posix.unistd : close;
    if (socket >= 0) close(socket);
  }


  int enet_socket_send (ENetSocket socket, const ENetAddress* address, const(ENetBuffer)* buffers, usize bufferCount) {
    import core.stdc.string : memset;
    import core.sys.posix.netinet.in_ : sockaddr_in;
    import core.sys.posix.sys.socket : AF_INET, MSG_NOSIGNAL, msghdr, sendmsg;
    import core.sys.posix.sys.uio : iovec;

    msghdr msgHdr = void;
    sockaddr_in sin = void;
    int sentLength;

    memset(& msgHdr, 0, msghdr.sizeof);
    if (address !is null) {
      memset(&sin, 0, sockaddr_in.sizeof);

      sin.sin_family = AF_INET;
      sin.sin_port = ENET_HOST_TO_NET_16(address.port);
      sin.sin_addr.s_addr = address.host;

      msgHdr.msg_name = &sin;
      msgHdr.msg_namelen = sockaddr_in.sizeof;
    }

    msgHdr.msg_iov = cast(iovec*)buffers;
    msgHdr.msg_iovlen = bufferCount;

    sentLength = cast(uint)sendmsg(socket, &msgHdr, MSG_NOSIGNAL); // crude x86_64 fix

    if (sentLength == -1) {
      import core.stdc.errno : errno, EWOULDBLOCK;
      if (errno == EWOULDBLOCK) return 0;
      return -1;
    }

    return sentLength;
  }


  int enet_socket_receive (ENetSocket socket, ENetAddress* address, ENetBuffer* buffers, usize bufferCount) {
    import core.stdc.string : memset;
    import core.sys.posix.netinet.in_ : sockaddr_in;
    import core.sys.posix.sys.socket : MSG_NOSIGNAL, MSG_TRUNC, msghdr, recvmsg;
    import core.sys.posix.sys.uio : iovec;

    msghdr msgHdr = void;
    sockaddr_in sin;
    int recvLength;

    memset(&msgHdr, 0, msghdr.sizeof);

    if (address !is null) {
      msgHdr.msg_name = &sin;
      msgHdr.msg_namelen = sockaddr_in.sizeof;
    }

    msgHdr.msg_iov = cast(iovec*)buffers;
    msgHdr.msg_iovlen = bufferCount;

    recvLength = cast(uint)recvmsg(socket, &msgHdr, MSG_NOSIGNAL); // crude x86_64 fix

    if (recvLength == -1) {
      import core.stdc.errno : errno, EWOULDBLOCK;
      if (errno == EWOULDBLOCK) return 0;
      return -1;
    }

    if (msgHdr.msg_flags&MSG_TRUNC) return -1;

    if (address !is null) {
      address.host = cast(enet_uint32)sin.sin_addr.s_addr;
      address.port = ENET_NET_TO_HOST_16(sin.sin_port);
    }

    return recvLength;
  }


  int enet_socketset_select (ENetSocket maxSocket, ENetSocketSet* readSet, ENetSocketSet* writeSet, enet_uint32 timeout) {
    import core.sys.posix.sys.time : timeval;
    import core.sys.posix.sys.select : select;

    timeval timeVal = void;
    timeVal.tv_sec = timeout/1000;
    timeVal.tv_usec = (timeout%1000)*1000;
    return select(maxSocket+1, readSet, writeSet, null, &timeVal);
  }


  int enet_socket_wait (ENetSocket socket, enet_uint32 * condition, enet_uint32 timeout) {
    import core.sys.posix.poll : POLLIN, POLLOUT, poll, pollfd;

    pollfd pollSocket = void;
    int pollCount;

    pollSocket.fd = socket;
    pollSocket.events = 0;

    if ((*condition)&ENET_SOCKET_WAIT_SEND) pollSocket.events |= POLLOUT;
    if ((*condition)&ENET_SOCKET_WAIT_RECEIVE) pollSocket.events |= POLLIN;

    pollCount = poll(&pollSocket, 1, timeout);

    if (pollCount < 0) {
      import core.stdc.errno : errno, EINTR;
      if (errno == EINTR && (*condition)&ENET_SOCKET_WAIT_INTERRUPT) {
        *condition = ENET_SOCKET_WAIT_INTERRUPT;
        return 0;
      }
      return -1;
    }

    *condition = ENET_SOCKET_WAIT_NONE;

    if (pollCount == 0) return 0;

    if (pollSocket.revents&POLLOUT) *condition |= ENET_SOCKET_WAIT_SEND;
    if (pollSocket.revents&POLLIN) *condition |= ENET_SOCKET_WAIT_RECEIVE;

    return 0;
  }
}


// callbacks.c
extern(C) nothrow {
  private __gshared ENetCallbacks callbacks;


  shared static this () @nogc {
    static import core.stdc.stdlib;
    callbacks.malloc = &core.stdc.stdlib.malloc;
    callbacks.free = &core.stdc.stdlib.free;
    callbacks.no_memory = &core.stdc.stdlib.abort; //FIXME
  }


  int enet_initialize_with_callbacks (ENetVersion version_, const ENetCallbacks* inits) nothrow @nogc {
    if (version_ < ENET_VERSION_CREATE(1, 3, 0)) return -1;
    if (inits.malloc !is null || inits.free !is null) {
      if (inits.malloc is null || inits.free is null) return -1;
      callbacks.malloc = inits.malloc;
      callbacks.free = inits.free;
     }
     if (inits.no_memory !is null) callbacks.no_memory = inits.no_memory;
     return enet_initialize();
  }


  ENetVersion enet_linked_version () nothrow @nogc {
    return ENET_VERSION;
  }


  void* enet_malloc (usize size) nothrow {
    void* memory = callbacks.malloc(size);
    if (memory is null) callbacks.no_memory();
    return memory;
  }


  void enet_free (void* memory) nothrow {
    callbacks.free(memory);
  }
}


// list.c
extern(C) @nogc nothrow {
  alias ENetListIterator = ENetListNode*;


  @safe pure {
    ENetListIterator enet_list_begin (ENetList* list) {
      pragma(inline, true);
      return list.sentinel.next;
    }

    ENetListIterator enet_list_end (ENetList* list) {
      pragma(inline, true);
      return &list.sentinel;
    }

    bool enet_list_empty (ENetList* list) {
      pragma(inline, true);
      return enet_list_begin(list) == enet_list_end(list);
    }

    ENetListIterator enet_list_next (ENetListIterator iterator) {
      pragma(inline, true);
      return iterator.next;
    }

    ENetListIterator enet_list_previous (ENetListIterator iterator) {
      pragma(inline, true);
      return iterator.previous;
    }

    void* enet_list_front (ENetList* list) {
      pragma(inline, true);
      return cast(void*)(list.sentinel.next);
    }

    void* enet_list_back (ENetList* list) {
      pragma(inline, true);
      return cast(void*)(list.sentinel.previous);
    }
  }

  /**
      @defgroup list ENet linked list utility functions
      @ingroup private
      @{
  */
  void enet_list_clear (ENetList* list) {
    list.sentinel.next = &list.sentinel;
    list.sentinel.previous = &list.sentinel;
  }

  ENetListIterator enet_list_insert (ENetListIterator position, void* data) {
    ENetListIterator result = cast(ENetListIterator)data;

    result.previous = position.previous;
    result.next = position;

    result.previous.next = result;
    position.previous = result;

    return result;
  }

  void* enet_list_remove (ENetListIterator position) {
    position.previous.next = position.next;
    position.next.previous = position.previous;
    return position;
  }

  ENetListIterator enet_list_move (ENetListIterator position, void * dataFirst, void * dataLast) {
    ENetListIterator first = cast(ENetListIterator)dataFirst;
    ENetListIterator last = cast(ENetListIterator)dataLast;

    first.previous.next = last.next;
    last.next.previous = first.previous;

    first.previous = position.previous;
    last.next = position;

    first.previous.next = first;
    position.previous = last;

    return first;
  }

  usize enet_list_size (ENetList* list) {
    usize size = 0;
    ENetListIterator position;
    for (position = enet_list_begin(list); position != enet_list_end(list); position = enet_list_next(position)) ++size;
    return size;
  }
}


// packet.c
extern(C) nothrow {
  /** Creates a packet that may be sent to a peer.
   *
   * Params:
   *  data = initial contents of the packet's data; the packet's data will remain uninitialized if data is null
   *  dataLength = size of the data allocated for this packet
   *  flags = flags for this packet as described for the ENetPacket structure
   *
   * Returns:
   *   the packet on success, null on failure
   */
  ENetPacket* enet_packet_create (const(void)* data, usize dataLength, enet_uint32 flags) {
    ENetPacket* packet = cast(ENetPacket*)enet_malloc(ENetPacket.sizeof);
    if (packet is null) return null;

    if (flags&ENET_PACKET_FLAG_NO_ALLOCATE) {
      packet.data = cast(enet_uint8*)data;
    } else if (dataLength <= 0) {
      packet.data = null;
    } else {
      packet.data = cast(enet_uint8*)enet_malloc(dataLength);
      if (packet.data is null) {
        enet_free(packet);
        return null;
      }
      if (data !is null) {
        import core.stdc.string : memcpy;
        memcpy(packet.data, data, dataLength);
      }
    }

    //FIXME
    packet.referenceCount = 0;
    packet.flags = flags;
    packet.dataLength = dataLength;
    packet.freeCallback = null;
    packet.userData = null;

    return packet;
  }


  /** Destroys the packet and deallocates its data.
   *
   * Params:
   *  packet = packet to be destroyed
   */
  void enet_packet_destroy (ENetPacket* packet) {
    if (packet is null) return;
    if (packet.freeCallback !is null) (*packet.freeCallback)(packet);
    if (!(packet.flags&ENET_PACKET_FLAG_NO_ALLOCATE) && packet.data !is null) enet_free(packet.data);
    enet_free(packet);
  }


  /** Attempts to resize the data in the packet to length specified in the dataLength parameter.
   *
   * Params:
   *  packet = packet to resize
   *  dataLength = new size for the packet data
   *
   * Returns:
   *  0 on success, < 0 on failure
   */
  int enet_packet_resize (ENetPacket* packet, usize dataLength) {
    import core.stdc.string : memcpy;

    enet_uint8* newData;

    if (dataLength <= packet.dataLength || (packet.flags&ENET_PACKET_FLAG_NO_ALLOCATE)) {
      packet.dataLength = dataLength;
      return 0;
    }

    newData = cast(enet_uint8*) enet_malloc(dataLength);
    if (newData is null) return -1;

    memcpy(newData, packet.data, packet.dataLength);
    enet_free(packet.data);

    packet.data = newData;
    packet.dataLength = dataLength;

    return 0;
  }


  private immutable enet_uint32[256] crcTable = (() {
    enet_uint32 reflect_crc (int val, int bits) {
      int result = 0, bit;
      for (bit = 0; bit < bits; ++bit) {
        if (val&1) result |= 1<<(bits-1-bit);
        val >>= 1;
      }
      return result;
    }

    enet_uint32[256] crcTable;
    for (int bt = 0; bt < 256; ++bt) {
      enet_uint32 crc = reflect_crc(bt, 8)<<24;
      for (int offset = 0; offset < 8; ++offset) {
        if (crc&0x80000000u) crc = (crc<<1)^0x04c11db7u; else crc <<= 1;
      }
      crcTable[bt] = reflect_crc (crc, 32);
    }
    return crcTable;
  }());


  enet_uint32 enet_crc32 (const(ENetBuffer)* buffers, usize bufferCount) pure @nogc {
    enet_uint32 crc = 0xFFFFFFFF;
    while (bufferCount-- > 0) {
      auto data = cast(const(enet_uint8)*)buffers.data;
      auto dataEnd = data+buffers.dataLength;
      while (data < dataEnd) crc = (crc>>8)^crcTable[(crc&0xFF)^*data++];
      ++buffers;
    }
    return ENET_HOST_TO_NET_32(~crc);
  }
}


// peer.c
extern(C) nothrow {
  /** Configures throttle parameter for a peer.
   *
   * Unreliable packets are dropped by ENet in response to the varying conditions
   * of the Internet connection to the peer.  The throttle represents a probability
   * that an unreliable packet should not be dropped and thus sent by ENet to the peer.
   * The lowest mean round trip time from the sending of a reliable packet to the
   * receipt of its acknowledgement is measured over an amount of time specified by
   * the interval parameter in milliseconds.  If a measured round trip time happens to
   * be significantly less than the mean round trip time measured over the interval,
   * then the throttle probability is increased to allow more traffic by an amount
   * specified in the acceleration parameter, which is a ratio to the ENET_PEER_PACKET_THROTTLE_SCALE
   * constant.  If a measured round trip time happens to be significantly greater than
   * the mean round trip time measured over the interval, then the throttle probability
   * is decreased to limit traffic by an amount specified in the deceleration parameter, which
   * is a ratio to the ENET_PEER_PACKET_THROTTLE_SCALE constant.  When the throttle has
   * a value of ENET_PEER_PACKET_THROTTLE_SCALE, no unreliable packets are dropped by
   * ENet, and so 100% of all unreliable packets will be sent.  When the throttle has a
   * value of 0, all unreliable packets are dropped by ENet, and so 0% of all unreliable
   * packets will be sent.  Intermediate values for the throttle represent intermediate
   * probabilities between 0% and 100% of unreliable packets being sent.  The bandwidth
   * limits of the local and foreign hosts are taken into account to determine a
   * sensible limit for the throttle probability above which it should not raise even in
   * the best of conditions.
   *
   * Params:
   *  peer = peer to configure
   *  interval = interval, in milliseconds, over which to measure lowest mean RTT; the default value is ENET_PEER_PACKET_THROTTLE_INTERVAL.
   *  acceleration = rate at which to increase the throttle probability as mean RTT declines
   *  deceleration = rate at which to decrease the throttle probability as mean RTT increases
   */
  void enet_peer_throttle_configure (ENetPeer* peer, enet_uint32 interval, enet_uint32 acceleration, enet_uint32 deceleration) {
    ENetProtocol command;

    peer.packetThrottleInterval = interval;
    peer.packetThrottleAcceleration = acceleration;
    peer.packetThrottleDeceleration = deceleration;

    command.header.command = ENET_PROTOCOL_COMMAND_THROTTLE_CONFIGURE | ENET_PROTOCOL_COMMAND_FLAG_ACKNOWLEDGE;
    command.header.channelID = 0xFF;

    command.throttleConfigure.packetThrottleInterval = ENET_HOST_TO_NET_32 (interval);
    command.throttleConfigure.packetThrottleAcceleration = ENET_HOST_TO_NET_32 (acceleration);
    command.throttleConfigure.packetThrottleDeceleration = ENET_HOST_TO_NET_32 (deceleration);

    enet_peer_queue_outgoing_command(peer, &command, null, 0, 0);
  }


  int enet_peer_throttle (ENetPeer* peer, enet_uint32 rtt) @nogc {
    if (peer.lastRoundTripTime <= peer.lastRoundTripTimeVariance) {
      peer.packetThrottle = peer.packetThrottleLimit;
    } else if (rtt < peer.lastRoundTripTime) {
      peer.packetThrottle += peer.packetThrottleAcceleration;
      if (peer.packetThrottle > peer.packetThrottleLimit) peer.packetThrottle = peer.packetThrottleLimit;
      return 1;
    } else if (rtt > peer.lastRoundTripTime+2*peer.lastRoundTripTimeVariance) {
      if (peer.packetThrottle > peer.packetThrottleDeceleration) {
        peer.packetThrottle -= peer.packetThrottleDeceleration;
      } else {
        peer.packetThrottle = 0;
      }
      return -1;
    }
    return 0;
  }


  /** Queues a packet to be sent.
   *
   * Params:
   *  peer = destination for the packet
   *  channelID = channel on which to send
   *  packet = packet to send
   *
   * Returns:
   *  0 on success, < 0 on failure
   */
  int enet_peer_send (ENetPeer* peer, enet_uint8 channelID, ENetPacket* packet) {
    ENetChannel* channel = &peer.channels[channelID];
    ENetProtocol command;
    usize fragmentLength;

    if (peer.state != ENET_PEER_STATE_CONNECTED || channelID >= peer.channelCount || packet.dataLength > peer.host.maximumPacketSize) return -1;

    fragmentLength = peer.mtu-ENetProtocolHeader.sizeof-ENetProtocolSendFragment.sizeof;
    if (peer.host.checksum !is null) fragmentLength -= enet_uint32.sizeof;

    if (packet.dataLength > fragmentLength) {
      enet_uint32 fragmentCount = cast(uint)((packet.dataLength+fragmentLength-1)/fragmentLength);
      enet_uint32 fragmentNumber, fragmentOffset;
      enet_uint8 commandNumber;
      enet_uint16 startSequenceNumber;
      ENetList fragments;
      ENetOutgoingCommand* fragment;

      if (fragmentCount > ENET_PROTOCOL_MAXIMUM_FRAGMENT_COUNT) return -1;

      if ((packet.flags&(ENET_PACKET_FLAG_RELIABLE|ENET_PACKET_FLAG_UNRELIABLE_FRAGMENT)) == ENET_PACKET_FLAG_UNRELIABLE_FRAGMENT && channel.outgoingUnreliableSequenceNumber < 0xFFFF) {
        commandNumber = ENET_PROTOCOL_COMMAND_SEND_UNRELIABLE_FRAGMENT;
        startSequenceNumber = ENET_HOST_TO_NET_16(cast(ushort)(channel.outgoingUnreliableSequenceNumber+1));
      } else {
        commandNumber = ENET_PROTOCOL_COMMAND_SEND_FRAGMENT|ENET_PROTOCOL_COMMAND_FLAG_ACKNOWLEDGE;
        startSequenceNumber = ENET_HOST_TO_NET_16(cast(ushort)(channel.outgoingReliableSequenceNumber+1));
      }

      enet_list_clear(&fragments);

      for (fragmentNumber = 0, fragmentOffset = 0; fragmentOffset < packet.dataLength; ++fragmentNumber, fragmentOffset += fragmentLength) {
        if (packet.dataLength-fragmentOffset < fragmentLength) fragmentLength = packet.dataLength-fragmentOffset;

        fragment = cast(ENetOutgoingCommand*)enet_malloc(ENetOutgoingCommand.sizeof);
        if (fragment is null) {
          while (!enet_list_empty(&fragments)) {
            fragment = cast(ENetOutgoingCommand*)enet_list_remove(enet_list_begin(&fragments));
            enet_free(fragment);
          }
          return -1;
        }

        fragment.fragmentOffset = fragmentOffset;
        fragment.fragmentLength = cast(ushort)fragmentLength;
        fragment.packet = packet;
        fragment.command.header.command = commandNumber;
        fragment.command.header.channelID = channelID;
        fragment.command.sendFragment.startSequenceNumber = startSequenceNumber;
        fragment.command.sendFragment.dataLength = ENET_HOST_TO_NET_16(cast(ushort)fragmentLength);
        fragment.command.sendFragment.fragmentCount = ENET_HOST_TO_NET_32(fragmentCount);
        fragment.command.sendFragment.fragmentNumber = ENET_HOST_TO_NET_32(fragmentNumber);
        fragment.command.sendFragment.totalLength = ENET_HOST_TO_NET_32(cast(uint)packet.dataLength);
        fragment.command.sendFragment.fragmentOffset = ENET_NET_TO_HOST_32(fragmentOffset);

        enet_list_insert(enet_list_end(&fragments), fragment);
      }

      packet.referenceCount += fragmentNumber;

      while (!enet_list_empty(&fragments)) {
        fragment = cast(ENetOutgoingCommand*)enet_list_remove(enet_list_begin(&fragments));
        enet_peer_setup_outgoing_command(peer, fragment);
      }

      return 0;
    }

    command.header.channelID = channelID;

    if ((packet.flags&(ENET_PACKET_FLAG_RELIABLE|ENET_PACKET_FLAG_UNSEQUENCED)) == ENET_PACKET_FLAG_UNSEQUENCED) {
      command.header.command = ENET_PROTOCOL_COMMAND_SEND_UNSEQUENCED|ENET_PROTOCOL_COMMAND_FLAG_UNSEQUENCED;
      command.sendUnsequenced.dataLength = ENET_HOST_TO_NET_16(cast(ushort)packet.dataLength);
    } else if (packet.flags&ENET_PACKET_FLAG_RELIABLE || channel.outgoingUnreliableSequenceNumber >= 0xFFFF) {
      command.header.command = ENET_PROTOCOL_COMMAND_SEND_RELIABLE|ENET_PROTOCOL_COMMAND_FLAG_ACKNOWLEDGE;
      command.sendReliable.dataLength = ENET_HOST_TO_NET_16(cast(ushort)packet.dataLength);
    } else {
      command.header.command = ENET_PROTOCOL_COMMAND_SEND_UNRELIABLE;
      command.sendUnreliable.dataLength = ENET_HOST_TO_NET_16(cast(ushort)packet.dataLength);
    }

    if (enet_peer_queue_outgoing_command(peer, &command, packet, 0, cast(ushort)packet.dataLength) is null) return -1;

    return 0;
  }


  /** Attempts to dequeue any incoming queued packet.
   *
   * Params:
   *  peer = peer to dequeue packets from
   *  channelID = holds the channel ID of the channel the packet was received on success
   *
   * Returns:
   *   returns a pointer to the packet, or null if there are no available incoming queued packets
   */
  ENetPacket* enet_peer_receive (ENetPeer* peer, enet_uint8* channelID) {
    ENetIncomingCommand* incomingCommand;
    ENetPacket* packet;

    if (enet_list_empty(&peer.dispatchedCommands)) return null;
    incomingCommand = cast(ENetIncomingCommand*)enet_list_remove(enet_list_begin(&peer.dispatchedCommands));
    if (channelID !is null) *channelID = incomingCommand.command.header.channelID;
    packet = incomingCommand.packet;
    --packet.referenceCount;
    if (incomingCommand.fragments !is null) enet_free(incomingCommand.fragments);
    enet_free(incomingCommand);
    peer.totalWaitingData -= packet.dataLength;

    return packet;
  }


  private void enet_peer_reset_outgoing_commands (ENetList* queue) {
    ENetOutgoingCommand* outgoingCommand;
    while (!enet_list_empty(queue)) {
      outgoingCommand = cast(ENetOutgoingCommand*)enet_list_remove(enet_list_begin(queue));
      if (outgoingCommand.packet !is null) {
        --outgoingCommand.packet.referenceCount;
        if (outgoingCommand.packet.referenceCount == 0) enet_packet_destroy(outgoingCommand.packet);
      }
      enet_free(outgoingCommand);
    }
  }


  private void enet_peer_remove_incoming_commands (ENetList* queue, ENetListIterator startCommand, ENetListIterator endCommand) {
    ENetListIterator currentCommand;
    for (currentCommand = startCommand; currentCommand != endCommand; ) {
      ENetIncomingCommand* incomingCommand = cast(ENetIncomingCommand*)currentCommand;
      currentCommand = enet_list_next(currentCommand);
      enet_list_remove(&incomingCommand.incomingCommandList);
      if (incomingCommand.packet !is null) {
        --incomingCommand.packet.referenceCount;
        if (incomingCommand.packet.referenceCount == 0) enet_packet_destroy(incomingCommand.packet);
      }
      if (incomingCommand.fragments !is null) enet_free(incomingCommand.fragments);
      enet_free(incomingCommand);
    }
  }


  private void enet_peer_reset_incoming_commands (ENetList* queue) {
    enet_peer_remove_incoming_commands(queue, enet_list_begin(queue), enet_list_end(queue));
  }


  void enet_peer_reset_queues (ENetPeer* peer) {
    ENetChannel* channel;

    if (peer.needsDispatch) {
      enet_list_remove(&peer.dispatchList);
      peer.needsDispatch = false;
    }

    while (!enet_list_empty(&peer.acknowledgements)) enet_free(enet_list_remove(enet_list_begin(&peer.acknowledgements)));

    enet_peer_reset_outgoing_commands(&peer.sentReliableCommands);
    enet_peer_reset_outgoing_commands(&peer.sentUnreliableCommands);
    enet_peer_reset_outgoing_commands(&peer.outgoingReliableCommands);
    enet_peer_reset_outgoing_commands(&peer.outgoingUnreliableCommands);
    enet_peer_reset_incoming_commands(&peer.dispatchedCommands);

    if (peer.channels !is null && peer.channelCount > 0) {
      for (channel = peer.channels; channel < &peer.channels[peer.channelCount]; ++channel) {
        enet_peer_reset_incoming_commands(&channel.incomingReliableCommands);
        enet_peer_reset_incoming_commands(&channel.incomingUnreliableCommands);
      }
      enet_free(peer.channels);
    }

    peer.channels = null;
    peer.channelCount = 0;
  }


  void enet_peer_on_connect (ENetPeer* peer) @nogc {
    if (peer.state != ENET_PEER_STATE_CONNECTED && peer.state != ENET_PEER_STATE_DISCONNECT_LATER) {
      if (peer.incomingBandwidth != 0) ++peer.host.bandwidthLimitedPeers;
      ++peer.host.connectedPeers;
    }
  }


  void enet_peer_on_disconnect (ENetPeer* peer) @nogc {
    if (peer.state == ENET_PEER_STATE_CONNECTED || peer.state == ENET_PEER_STATE_DISCONNECT_LATER) {
      if (peer.incomingBandwidth != 0) --peer.host.bandwidthLimitedPeers;
      --peer.host.connectedPeers;
    }
  }


  /** Forcefully disconnects a peer.
   *
   * Params:
   *  peer = peer to forcefully disconnect
   *
   * Remarks:
   *  The foreign host represented by the peer is not notified of the disconnection and will timeout
   *  on its connection to the local host.
   */
  void enet_peer_reset (ENetPeer* peer) {
    import core.stdc.string : memset;

    enet_peer_on_disconnect(peer);

    peer.outgoingPeerID = ENET_PROTOCOL_MAXIMUM_PEER_ID;
    peer.connectID = 0;

    peer.state = ENET_PEER_STATE_DISCONNECTED;

    peer.incomingBandwidth = 0;
    peer.outgoingBandwidth = 0;
    peer.incomingBandwidthThrottleEpoch = 0;
    peer.outgoingBandwidthThrottleEpoch = 0;
    peer.incomingDataTotal = 0;
    peer.outgoingDataTotal = 0;
    peer.lastSendTime = 0;
    peer.lastReceiveTime = 0;
    peer.nextTimeout = 0;
    peer.earliestTimeout = 0;
    peer.packetLossEpoch = 0;
    peer.packetsSent = 0;
    peer.packetsLost = 0;
    peer.packetLoss = 0;
    peer.packetLossVariance = 0;
    peer.packetThrottle = ENET_PEER_DEFAULT_PACKET_THROTTLE;
    peer.packetThrottleLimit = ENET_PEER_PACKET_THROTTLE_SCALE;
    peer.packetThrottleCounter = 0;
    peer.packetThrottleEpoch = 0;
    peer.packetThrottleAcceleration = ENET_PEER_PACKET_THROTTLE_ACCELERATION;
    peer.packetThrottleDeceleration = ENET_PEER_PACKET_THROTTLE_DECELERATION;
    peer.packetThrottleInterval = ENET_PEER_PACKET_THROTTLE_INTERVAL;
    peer.pingInterval = ENET_PEER_PING_INTERVAL;
    peer.timeoutLimit = ENET_PEER_TIMEOUT_LIMIT;
    peer.timeoutMinimum = ENET_PEER_TIMEOUT_MINIMUM;
    peer.timeoutMaximum = ENET_PEER_TIMEOUT_MAXIMUM;
    peer.lastRoundTripTime = ENET_PEER_DEFAULT_ROUND_TRIP_TIME;
    peer.lowestRoundTripTime = ENET_PEER_DEFAULT_ROUND_TRIP_TIME;
    peer.lastRoundTripTimeVariance = 0;
    peer.highestRoundTripTimeVariance = 0;
    peer.roundTripTime = ENET_PEER_DEFAULT_ROUND_TRIP_TIME;
    peer.roundTripTimeVariance = 0;
    peer.mtu = peer.host.mtu;
    peer.reliableDataInTransit = 0;
    peer.outgoingReliableSequenceNumber = 0;
    peer.windowSize = ENET_PROTOCOL_MAXIMUM_WINDOW_SIZE;
    peer.incomingUnsequencedGroup = 0;
    peer.outgoingUnsequencedGroup = 0;
    peer.eventData = 0;
    peer.totalWaitingData = 0;

    memset(peer.unsequencedWindow.ptr, 0, peer.unsequencedWindow.sizeof);

    enet_peer_reset_queues(peer);
  }


  /** Sends a ping request to a peer.
   *
   * Params:
   *  peer = destination for the ping request
   *
   * Remarks:
   *  ping requests factor into the mean round trip time as designated by the
   *  roundTripTime field in the ENetPeer structure.  ENet automatically pings all connected
   *  peers at regular intervals, however, this function may be called to ensure more
   *  frequent ping requests.
   */
  void enet_peer_ping (ENetPeer* peer) {
    ENetProtocol command;

    if (peer.state != ENET_PEER_STATE_CONNECTED) return;

    command.header.command = ENET_PROTOCOL_COMMAND_PING|ENET_PROTOCOL_COMMAND_FLAG_ACKNOWLEDGE;
    command.header.channelID = 0xFF;

    enet_peer_queue_outgoing_command(peer, &command, null, 0, 0);
  }


  /** Sets the interval at which pings will be sent to a peer.
   *
   * Pings are used both to monitor the liveness of the connection and also to dynamically
   * adjust the throttle during periods of low traffic so that the throttle has reasonable
   * responsiveness during traffic spikes.
   *
   * Params:
   *  peer = the peer to adjust
   *  pingInterval = the interval at which to send pings; defaults to ENET_PEER_PING_INTERVAL if 0
   */
  void enet_peer_ping_interval (ENetPeer* peer, enet_uint32 pingInterval) @nogc {
    peer.pingInterval = (pingInterval ? pingInterval : ENET_PEER_PING_INTERVAL);
  }


  /** Sets the timeout parameters for a peer.
   *
   * The timeout parameter control how and when a peer will timeout from a failure to acknowledge
   * reliable traffic. Timeout values use an exponential backoff mechanism, where if a reliable
   * packet is not acknowledge within some multiple of the average RTT plus a variance tolerance,
   * the timeout will be doubled until it reaches a set limit. If the timeout is thus at this
   * limit and reliable packets have been sent but not acknowledged within a certain minimum time
   * period, the peer will be disconnected. Alternatively, if reliable packets have been sent
   * but not acknowledged for a certain maximum time period, the peer will be disconnected regardless
   * of the current timeout limit value.
   *
   * Params:
   *  peer = the peer to adjust
   *  timeoutLimit = the timeout limit; defaults to ENET_PEER_TIMEOUT_LIMIT if 0
   *  timeoutMinimum = the timeout minimum; defaults to ENET_PEER_TIMEOUT_MINIMUM if 0
   *  timeoutMaximum = the timeout maximum; defaults to ENET_PEER_TIMEOUT_MAXIMUM if 0
   */
  void enet_peer_timeout (ENetPeer* peer, enet_uint32 timeoutLimit, enet_uint32 timeoutMinimum, enet_uint32 timeoutMaximum) @nogc {
    peer.timeoutLimit = (timeoutLimit ? timeoutLimit : ENET_PEER_TIMEOUT_LIMIT);
    peer.timeoutMinimum = (timeoutMinimum ? timeoutMinimum : ENET_PEER_TIMEOUT_MINIMUM);
    peer.timeoutMaximum = (timeoutMaximum ? timeoutMaximum : ENET_PEER_TIMEOUT_MAXIMUM);
  }


  /** Force an immediate disconnection from a peer.
   *
   * Params:
   *  peer = peer to disconnect
   *  data = data describing the disconnection
   *
   * Remarks:
   *  No ENET_EVENT_DISCONNECT event will be generated. The foreign peer is not
   *  guaranteed to receive the disconnect notification, and is reset immediately upon
   *  return from this function.
   */
  void enet_peer_disconnect_now (ENetPeer* peer, enet_uint32 data) {
    ENetProtocol command;

    if (peer.state == ENET_PEER_STATE_DISCONNECTED) return;

    if (peer.state != ENET_PEER_STATE_ZOMBIE && peer.state != ENET_PEER_STATE_DISCONNECTING) {
      enet_peer_reset_queues(peer);

      command.header.command = ENET_PROTOCOL_COMMAND_DISCONNECT|ENET_PROTOCOL_COMMAND_FLAG_UNSEQUENCED;
      command.header.channelID = 0xFF;
      command.disconnect.data = ENET_HOST_TO_NET_32(data);

      enet_peer_queue_outgoing_command(peer, &command, null, 0, 0);

      enet_host_flush(peer.host);
    }

    enet_peer_reset(peer);
  }


  /** Request a disconnection from a peer.
   *
   * Params:
   *  peer = peer to request a disconnection
   *  data = data describing the disconnection
   *
   * Remarks:
   *  An ENET_EVENT_DISCONNECT event will be generated by enet_host_service()
   *  once the disconnection is complete.
   */
  void enet_peer_disconnect (ENetPeer* peer, enet_uint32 data) {
    ENetProtocol command;

    if (peer.state == ENET_PEER_STATE_DISCONNECTING ||
        peer.state == ENET_PEER_STATE_DISCONNECTED ||
        peer.state == ENET_PEER_STATE_ACKNOWLEDGING_DISCONNECT ||
        peer.state == ENET_PEER_STATE_ZOMBIE)
      return;

    enet_peer_reset_queues(peer);

    command.header.command = ENET_PROTOCOL_COMMAND_DISCONNECT;
    command.header.channelID = 0xFF;
    command.disconnect.data = ENET_HOST_TO_NET_32(data);

    if (peer.state == ENET_PEER_STATE_CONNECTED || peer.state == ENET_PEER_STATE_DISCONNECT_LATER) {
      command.header.command |= ENET_PROTOCOL_COMMAND_FLAG_ACKNOWLEDGE;
    } else {
      command.header.command |= ENET_PROTOCOL_COMMAND_FLAG_UNSEQUENCED;
    }

    enet_peer_queue_outgoing_command(peer, &command, null, 0, 0);

    if (peer.state == ENET_PEER_STATE_CONNECTED || peer.state == ENET_PEER_STATE_DISCONNECT_LATER) {
      enet_peer_on_disconnect(peer);
      peer.state = ENET_PEER_STATE_DISCONNECTING;
    } else {
      enet_host_flush(peer.host);
      enet_peer_reset(peer);
    }
  }


  /** Request a disconnection from a peer, but only after all queued outgoing packets are sent.
   *
   * Params:
   *  peer = peer to request a disconnection
   *  data = data describing the disconnection
   *
   * Remarks:
   *  An ENET_EVENT_DISCONNECT event will be generated by enet_host_service()
   *  once the disconnection is complete.
   */
  void enet_peer_disconnect_later (ENetPeer* peer, enet_uint32 data) {
    if ((peer.state == ENET_PEER_STATE_CONNECTED || peer.state == ENET_PEER_STATE_DISCONNECT_LATER) &&
        !(enet_list_empty (& peer.outgoingReliableCommands) &&
          enet_list_empty (& peer.outgoingUnreliableCommands) &&
          enet_list_empty (& peer.sentReliableCommands)))
    {
      peer.state = ENET_PEER_STATE_DISCONNECT_LATER;
      peer.eventData = data;
    } else {
      enet_peer_disconnect(peer, data);
    }
  }


  ENetAcknowledgement* enet_peer_queue_acknowledgement (ENetPeer* peer, const ENetProtocol* command, enet_uint16 sentTime) {
    ENetAcknowledgement* acknowledgement;

    if (command.header.channelID < peer.channelCount) {
      ENetChannel* channel = &peer.channels[command.header.channelID];
      enet_uint16 reliableWindow = command.header.reliableSequenceNumber/ENET_PEER_RELIABLE_WINDOW_SIZE;
      enet_uint16 currentWindow = channel.incomingReliableSequenceNumber/ENET_PEER_RELIABLE_WINDOW_SIZE;

      if (command.header.reliableSequenceNumber < channel.incomingReliableSequenceNumber) reliableWindow += ENET_PEER_RELIABLE_WINDOWS;
      if (reliableWindow >= currentWindow + ENET_PEER_FREE_RELIABLE_WINDOWS-1 && reliableWindow <= currentWindow+ENET_PEER_FREE_RELIABLE_WINDOWS) return null;
    }

    acknowledgement = cast(ENetAcknowledgement*)enet_malloc(ENetAcknowledgement.sizeof);
    if (acknowledgement is null) return null;

    peer.outgoingDataTotal += ENetProtocolAcknowledge.sizeof;

    acknowledgement.sentTime = sentTime;
    acknowledgement.command = * command;

    enet_list_insert(enet_list_end(&peer.acknowledgements), acknowledgement);

    return acknowledgement;
  }


  void enet_peer_setup_outgoing_command (ENetPeer* peer, ENetOutgoingCommand* outgoingCommand) @nogc {
    ENetChannel* channel = &peer.channels[outgoingCommand.command.header.channelID];

    peer.outgoingDataTotal += enet_protocol_command_size(outgoingCommand.command.header.command)+outgoingCommand.fragmentLength;

    if (outgoingCommand.command.header.channelID == 0xFF) {
      ++peer.outgoingReliableSequenceNumber;
      outgoingCommand.reliableSequenceNumber = peer.outgoingReliableSequenceNumber;
      outgoingCommand.unreliableSequenceNumber = 0;
    } else if (outgoingCommand.command.header.command&ENET_PROTOCOL_COMMAND_FLAG_ACKNOWLEDGE) {
      ++channel.outgoingReliableSequenceNumber;
      channel.outgoingUnreliableSequenceNumber = 0;

      outgoingCommand.reliableSequenceNumber = channel.outgoingReliableSequenceNumber;
      outgoingCommand.unreliableSequenceNumber = 0;
    } else if (outgoingCommand.command.header.command&ENET_PROTOCOL_COMMAND_FLAG_UNSEQUENCED) {
      ++peer.outgoingUnsequencedGroup;
      outgoingCommand.reliableSequenceNumber = 0;
      outgoingCommand.unreliableSequenceNumber = 0;
    } else {
      if (outgoingCommand.fragmentOffset == 0) ++channel.outgoingUnreliableSequenceNumber;
      outgoingCommand.reliableSequenceNumber = channel.outgoingReliableSequenceNumber;
      outgoingCommand.unreliableSequenceNumber = channel.outgoingUnreliableSequenceNumber;
    }

    outgoingCommand.sendAttempts = 0;
    outgoingCommand.sentTime = 0;
    outgoingCommand.roundTripTimeout = 0;
    outgoingCommand.roundTripTimeoutLimit = 0;
    outgoingCommand.command.header.reliableSequenceNumber = ENET_HOST_TO_NET_16(outgoingCommand.reliableSequenceNumber);

    switch (outgoingCommand.command.header.command&ENET_PROTOCOL_COMMAND_MASK) {
      case ENET_PROTOCOL_COMMAND_SEND_UNRELIABLE:
        outgoingCommand.command.sendUnreliable.unreliableSequenceNumber = ENET_HOST_TO_NET_16(outgoingCommand.unreliableSequenceNumber);
        break;
      case ENET_PROTOCOL_COMMAND_SEND_UNSEQUENCED:
        outgoingCommand.command.sendUnsequenced.unsequencedGroup = ENET_HOST_TO_NET_16(peer.outgoingUnsequencedGroup);
        break;
      default:
        break;
    }

    if (outgoingCommand.command.header.command&ENET_PROTOCOL_COMMAND_FLAG_ACKNOWLEDGE) {
      enet_list_insert(enet_list_end(&peer.outgoingReliableCommands), outgoingCommand);
    } else {
      enet_list_insert(enet_list_end(&peer.outgoingUnreliableCommands), outgoingCommand);
    }
  }


  ENetOutgoingCommand* enet_peer_queue_outgoing_command (ENetPeer* peer, const ENetProtocol* command, ENetPacket* packet, enet_uint32 offset, enet_uint16 length) {
    ENetOutgoingCommand* outgoingCommand = cast(ENetOutgoingCommand*)enet_malloc(ENetOutgoingCommand.sizeof);
    if (outgoingCommand is null) return null;

    outgoingCommand.command = * command;
    outgoingCommand.fragmentOffset = offset;
    outgoingCommand.fragmentLength = length;
    outgoingCommand.packet = packet;
    if (packet !is null) ++packet.referenceCount;

    enet_peer_setup_outgoing_command (peer, outgoingCommand);

    return outgoingCommand;
  }


  void enet_peer_dispatch_incoming_unreliable_commands (ENetPeer* peer, ENetChannel* channel) {
    ENetListIterator droppedCommand, startCommand, currentCommand;

    for (droppedCommand = startCommand = currentCommand = enet_list_begin(& channel.incomingUnreliableCommands);
         currentCommand != enet_list_end(& channel.incomingUnreliableCommands);
         currentCommand = enet_list_next(currentCommand))
    {
      ENetIncomingCommand* incomingCommand = cast(ENetIncomingCommand*)currentCommand;
      if ((incomingCommand.command.header.command&ENET_PROTOCOL_COMMAND_MASK) == ENET_PROTOCOL_COMMAND_SEND_UNSEQUENCED) continue;

      if (incomingCommand.reliableSequenceNumber == channel.incomingReliableSequenceNumber) {
        if (incomingCommand.fragmentsRemaining <= 0) {
          channel.incomingUnreliableSequenceNumber = incomingCommand.unreliableSequenceNumber;
          continue;
        }
        if (startCommand != currentCommand) {
          enet_list_move(enet_list_end(&peer.dispatchedCommands), startCommand, enet_list_previous(currentCommand));
          if (!peer.needsDispatch) {
            enet_list_insert(enet_list_end(&peer.host.dispatchQueue), &peer.dispatchList);
            peer.needsDispatch = true;
          }
          droppedCommand = currentCommand;
        } else if (droppedCommand != currentCommand) {
          droppedCommand = enet_list_previous (currentCommand);
        }
      } else {
        enet_uint16 reliableWindow = incomingCommand.reliableSequenceNumber/ENET_PEER_RELIABLE_WINDOW_SIZE;
        enet_uint16 currentWindow = channel.incomingReliableSequenceNumber/ENET_PEER_RELIABLE_WINDOW_SIZE;
        if (incomingCommand.reliableSequenceNumber < channel.incomingReliableSequenceNumber) reliableWindow += ENET_PEER_RELIABLE_WINDOWS;
        if (reliableWindow >= currentWindow && reliableWindow < currentWindow+ENET_PEER_FREE_RELIABLE_WINDOWS-1) break;

        droppedCommand = enet_list_next(currentCommand);

        if (startCommand != currentCommand) {
          enet_list_move(enet_list_end(&peer.dispatchedCommands), startCommand, enet_list_previous(currentCommand));
          if (!peer.needsDispatch) {
            enet_list_insert (enet_list_end(&peer.host.dispatchQueue), &peer.dispatchList);
            peer.needsDispatch = true;
          }
        }
      }

      startCommand = enet_list_next(currentCommand);
    }

    if (startCommand != currentCommand) {
      enet_list_move(enet_list_end(&peer.dispatchedCommands), startCommand, enet_list_previous(currentCommand));
      if (!peer.needsDispatch) {
        enet_list_insert(enet_list_end(&peer.host.dispatchQueue), &peer.dispatchList);
        peer.needsDispatch = true;
      }
      droppedCommand = currentCommand;
    }

    enet_peer_remove_incoming_commands(&channel.incomingUnreliableCommands, enet_list_begin(&channel.incomingUnreliableCommands), droppedCommand);
  }


  void enet_peer_dispatch_incoming_reliable_commands (ENetPeer* peer, ENetChannel* channel) {
    ENetListIterator currentCommand;

    for (currentCommand = enet_list_begin(&channel.incomingReliableCommands);
         currentCommand != enet_list_end(&channel.incomingReliableCommands);
         currentCommand = enet_list_next(currentCommand))
    {
      ENetIncomingCommand* incomingCommand = cast(ENetIncomingCommand*)currentCommand;
      if (incomingCommand.fragmentsRemaining > 0 || incomingCommand.reliableSequenceNumber != cast(enet_uint16)(channel.incomingReliableSequenceNumber+1)) break;
      channel.incomingReliableSequenceNumber = incomingCommand.reliableSequenceNumber;
      if (incomingCommand.fragmentCount > 0) channel.incomingReliableSequenceNumber += incomingCommand.fragmentCount-1;
    }

    if (currentCommand == enet_list_begin(&channel.incomingReliableCommands)) return;

    channel.incomingUnreliableSequenceNumber = 0;

    enet_list_move(enet_list_end(&peer.dispatchedCommands), enet_list_begin(&channel.incomingReliableCommands), enet_list_previous(currentCommand));

    if (!peer.needsDispatch) {
      enet_list_insert(enet_list_end(&peer.host.dispatchQueue), &peer.dispatchList);
      peer.needsDispatch = true;
    }

    if (!enet_list_empty(&channel.incomingUnreliableCommands)) enet_peer_dispatch_incoming_unreliable_commands(peer, channel);
  }


  ENetIncomingCommand* enet_peer_queue_incoming_command (ENetPeer* peer, const ENetProtocol* command, const(void)* data, usize dataLength, enet_uint32 flags, enet_uint32 fragmentCount) {
    static ENetIncomingCommand dummyCommand;

    ENetChannel* channel = &peer.channels[command.header.channelID];
    enet_uint32 unreliableSequenceNumber = 0, reliableSequenceNumber = 0;
    enet_uint16 reliableWindow, currentWindow;
    ENetIncomingCommand* incomingCommand;
    ENetListIterator currentCommand;
    ENetPacket* packet = null;

    if (peer.state == ENET_PEER_STATE_DISCONNECT_LATER) goto discardCommand;

    if ((command.header.command & ENET_PROTOCOL_COMMAND_MASK) != ENET_PROTOCOL_COMMAND_SEND_UNSEQUENCED) {
      reliableSequenceNumber = command.header.reliableSequenceNumber;
      reliableWindow = cast(ushort)(reliableSequenceNumber/ENET_PEER_RELIABLE_WINDOW_SIZE);
      currentWindow = channel.incomingReliableSequenceNumber/ENET_PEER_RELIABLE_WINDOW_SIZE;

      if (reliableSequenceNumber < channel.incomingReliableSequenceNumber) reliableWindow += ENET_PEER_RELIABLE_WINDOWS;

      if (reliableWindow < currentWindow || reliableWindow >= currentWindow+ENET_PEER_FREE_RELIABLE_WINDOWS-1) goto discardCommand;
    }

    switch (command.header.command & ENET_PROTOCOL_COMMAND_MASK) {
      case ENET_PROTOCOL_COMMAND_SEND_FRAGMENT:
      case ENET_PROTOCOL_COMMAND_SEND_RELIABLE:
        if (reliableSequenceNumber == channel.incomingReliableSequenceNumber) goto discardCommand;
        for (currentCommand = enet_list_previous(enet_list_end(&channel.incomingReliableCommands));
             currentCommand != enet_list_end(&channel.incomingReliableCommands);
             currentCommand = enet_list_previous(currentCommand))
        {
          incomingCommand = cast(ENetIncomingCommand*)currentCommand;
          if (reliableSequenceNumber >= channel.incomingReliableSequenceNumber) {
            if (incomingCommand.reliableSequenceNumber < channel.incomingReliableSequenceNumber) continue;
          } else if (incomingCommand.reliableSequenceNumber >= channel.incomingReliableSequenceNumber) break;
          if (incomingCommand.reliableSequenceNumber <= reliableSequenceNumber) {
            if (incomingCommand.reliableSequenceNumber < reliableSequenceNumber) break;
            goto discardCommand;
          }
        }
        break;
      case ENET_PROTOCOL_COMMAND_SEND_UNRELIABLE:
      case ENET_PROTOCOL_COMMAND_SEND_UNRELIABLE_FRAGMENT:
        unreliableSequenceNumber = ENET_NET_TO_HOST_16(command.sendUnreliable.unreliableSequenceNumber);
        if (reliableSequenceNumber == channel.incomingReliableSequenceNumber && unreliableSequenceNumber <= channel.incomingUnreliableSequenceNumber) goto discardCommand;
        for (currentCommand = enet_list_previous (enet_list_end (& channel.incomingUnreliableCommands));
             currentCommand != enet_list_end (& channel.incomingUnreliableCommands);
             currentCommand = enet_list_previous (currentCommand))
        {
          incomingCommand = cast(ENetIncomingCommand*)currentCommand;
          if ((command.header.command&ENET_PROTOCOL_COMMAND_MASK) == ENET_PROTOCOL_COMMAND_SEND_UNSEQUENCED) continue;
          if (reliableSequenceNumber >= channel.incomingReliableSequenceNumber) {
            if (incomingCommand.reliableSequenceNumber < channel.incomingReliableSequenceNumber) continue;
          } else if (incomingCommand.reliableSequenceNumber >= channel.incomingReliableSequenceNumber) break;
          if (incomingCommand.reliableSequenceNumber < reliableSequenceNumber) break;
          if (incomingCommand.reliableSequenceNumber > reliableSequenceNumber) continue;
          if (incomingCommand.unreliableSequenceNumber <= unreliableSequenceNumber) {
            if (incomingCommand.unreliableSequenceNumber < unreliableSequenceNumber) break;
            goto discardCommand;
          }
        }
        break;
      case ENET_PROTOCOL_COMMAND_SEND_UNSEQUENCED:
        currentCommand = enet_list_end(&channel.incomingUnreliableCommands);
        break;
      default:
        goto discardCommand;
    }

    if (peer.totalWaitingData >= peer.host.maximumWaitingData) goto notifyError;

    packet = enet_packet_create(data, dataLength, flags);
    if (packet is null) goto notifyError;

    incomingCommand = cast(ENetIncomingCommand*)enet_malloc(ENetIncomingCommand.sizeof);
    if (incomingCommand is null) goto notifyError;

    incomingCommand.reliableSequenceNumber = command.header.reliableSequenceNumber;
    incomingCommand.unreliableSequenceNumber = unreliableSequenceNumber&0xFFFF;
    incomingCommand.command = *command;
    incomingCommand.fragmentCount = fragmentCount;
    incomingCommand.fragmentsRemaining = fragmentCount;
    incomingCommand.packet = packet;
    incomingCommand.fragments = null;

    if (fragmentCount > 0) {
      if (fragmentCount <= ENET_PROTOCOL_MAXIMUM_FRAGMENT_COUNT) {
        incomingCommand.fragments = cast(enet_uint32*)enet_malloc((fragmentCount+31)/32*enet_uint32.sizeof);
      }
      if (incomingCommand.fragments is null) {
         enet_free(incomingCommand);
         goto notifyError;
      }
      import core.stdc.string : memset;
      memset(incomingCommand.fragments, 0, (fragmentCount+31)/32*enet_uint32.sizeof);
    }

    if (packet !is null) {
      ++packet.referenceCount;
      peer.totalWaitingData += packet.dataLength;
    }

    enet_list_insert(enet_list_next(currentCommand), incomingCommand);

    switch (command.header.command & ENET_PROTOCOL_COMMAND_MASK) {
      case ENET_PROTOCOL_COMMAND_SEND_FRAGMENT:
      case ENET_PROTOCOL_COMMAND_SEND_RELIABLE:
        enet_peer_dispatch_incoming_reliable_commands (peer, channel);
        break;
      default:
        enet_peer_dispatch_incoming_unreliable_commands (peer, channel);
        break;
    }

    return incomingCommand;

  discardCommand:
    if (fragmentCount > 0) goto notifyError;
    if (packet !is null && packet.referenceCount == 0) enet_packet_destroy(packet);
    return &dummyCommand;

  notifyError:
    if (packet !is null && packet.referenceCount == 0) enet_packet_destroy(packet);
    return null;
  }
}


// host.c
extern(C) nothrow {
  /** Creates a host for communicating to peers.
   *
   * Params:
   *  address = the address at which other peers may connect to this host.  If null, then no peers may connect to the host.
   *  peerCount = the maximum number of peers that should be allocated for the host.
   *  channelLimit = the maximum number of channels allowed; if 0, then this is equivalent to ENET_PROTOCOL_MAXIMUM_CHANNEL_COUNT
   *  incomingBandwidth = downstream bandwidth of the host in bytes/second; if 0, ENet will assume unlimited bandwidth.
   *  outgoingBandwidth = upstream bandwidth of the host in bytes/second; if 0, ENet will assume unlimited bandwidth.
   *
   * Returns:
   *  the host on success and null on failure
   *
   * Remarks:
   *  ENet will strategically drop packets on specific sides of a connection between hosts
   *  to ensure the host's bandwidth is not overwhelmed.  The bandwidth parameters also determine
   *  the window size of a connection which limits the amount of reliable packets that may be in transit
   *  at any given time.
   */
  ENetHost* enet_host_create (const ENetAddress* address, usize peerCount, usize channelLimit, enet_uint32 incomingBandwidth=0, enet_uint32 outgoingBandwidth=0) {
    import core.stdc.string : memset;

    ENetHost* host;
    ENetPeer* currentPeer;

    if (peerCount > ENET_PROTOCOL_MAXIMUM_PEER_ID) return null;

    host = cast(ENetHost*)enet_malloc(ENetHost.sizeof);
    if (host is null) return null;
    memset(host, 0, ENetHost.sizeof);

    host.peers = cast(ENetPeer*)enet_malloc(peerCount*ENetPeer.sizeof);
    if (host.peers is null) {
      enet_free(host);
      return null;
    }
    memset(host.peers, 0, peerCount*ENetPeer.sizeof);

    host.socket = enet_socket_create(ENET_SOCKET_TYPE_DATAGRAM);
    if (host.socket == ENET_SOCKET_NULL || (address !is null && enet_socket_bind(host.socket, address) < 0)) {
      if (host.socket != ENET_SOCKET_NULL) enet_socket_destroy(host.socket);
      enet_free(host.peers);
      enet_free(host);
      return null;
    }

    enet_socket_set_option(host.socket, ENET_SOCKOPT_NONBLOCK, 1);
    enet_socket_set_option(host.socket, ENET_SOCKOPT_BROADCAST, 1);
    enet_socket_set_option(host.socket, ENET_SOCKOPT_RCVBUF, ENET_HOST_RECEIVE_BUFFER_SIZE);
    enet_socket_set_option(host.socket, ENET_SOCKOPT_SNDBUF, ENET_HOST_SEND_BUFFER_SIZE);

    if (address !is null && enet_socket_get_address(host.socket, &host.address) < 0) host.address = *address;

    if (!channelLimit || channelLimit > ENET_PROTOCOL_MAXIMUM_CHANNEL_COUNT) channelLimit = ENET_PROTOCOL_MAXIMUM_CHANNEL_COUNT;
    else if (channelLimit < ENET_PROTOCOL_MINIMUM_CHANNEL_COUNT) channelLimit = ENET_PROTOCOL_MINIMUM_CHANNEL_COUNT;

    host.randomSeed = cast(enet_uint32)cast(usize)host;
    host.randomSeed += enet_host_random_seed();
    host.randomSeed = (host.randomSeed<<16)|(host.randomSeed>>16);
    host.channelLimit = channelLimit;
    host.incomingBandwidth = incomingBandwidth;
    host.outgoingBandwidth = outgoingBandwidth;
    host.bandwidthThrottleEpoch = 0;
    host.recalculateBandwidthLimits = 0;
    host.mtu = ENET_HOST_DEFAULT_MTU;
    host.peerCount = peerCount;
    host.commandCount = 0;
    host.bufferCount = 0;
    host.checksum = null;
    host.receivedAddress.host = ENET_HOST_ANY;
    host.receivedAddress.port = 0;
    host.receivedData = null;
    host.receivedDataLength = 0;

    host.totalSentData = 0;
    host.totalSentPackets = 0;
    host.totalReceivedData = 0;
    host.totalReceivedPackets = 0;

    host.connectedPeers = 0;
    host.bandwidthLimitedPeers = 0;
    host.duplicatePeers = ENET_PROTOCOL_MAXIMUM_PEER_ID;
    host.maximumPacketSize = ENET_HOST_DEFAULT_MAXIMUM_PACKET_SIZE;
    host.maximumWaitingData = ENET_HOST_DEFAULT_MAXIMUM_WAITING_DATA;

    host.compressor.context = null;
    host.compressor.compress = null;
    host.compressor.decompress = null;
    host.compressor.destroy = null;

    host.intercept = null;

    enet_list_clear(&host.dispatchQueue);

    for (currentPeer = host.peers; currentPeer < &host.peers [host.peerCount]; ++currentPeer) {
      currentPeer.host = host;
      currentPeer.incomingPeerID = cast(ushort)(currentPeer-host.peers);
      currentPeer.outgoingSessionID = currentPeer.incomingSessionID = 0xFF;
      currentPeer.data = null;

      enet_list_clear(&currentPeer.acknowledgements);
      enet_list_clear(&currentPeer.sentReliableCommands);
      enet_list_clear(&currentPeer.sentUnreliableCommands);
      enet_list_clear(&currentPeer.outgoingReliableCommands);
      enet_list_clear(&currentPeer.outgoingUnreliableCommands);
      enet_list_clear(&currentPeer.dispatchedCommands);

      enet_peer_reset(currentPeer);
    }

    return host;
  }


  /** Destroys the host and all resources associated with it.
   *
   * Params:
   *  host = pointer to the host to destroy
   */
  void enet_host_destroy (ENetHost* host) {
    ENetPeer* currentPeer;

    if (host is null) return;

    enet_socket_destroy(host.socket);

    for (currentPeer = host.peers; currentPeer < &host.peers[host.peerCount]; ++currentPeer) {
      enet_peer_reset(currentPeer);
    }

    if (host.compressor.context !is null && host.compressor.destroy) (*host.compressor.destroy)(host.compressor.context);

    enet_free(host.peers);
    enet_free(host);
  }


  /** Initiates a connection to a foreign host.
   *
   * Params:
   *  host = host seeking the connection
   *  address = destination for the connection
   *  channelCount = number of channels to allocate
   *  data = user data supplied to the receiving host
   *
   * Returns:
   *  a peer representing the foreign host on success, null on failure
   *
   * Remarks:
   *  The peer returned will have not completed the connection until enet_host_service()
   *  notifies of an ENET_EVENT_TYPE_CONNECT event for the peer.
   */
  ENetPeer* enet_host_connect (ENetHost* host, const ENetAddress* address, usize channelCount, enet_uint32 data) {
    ENetPeer* currentPeer;
    ENetChannel* channel;
    ENetProtocol command;

    if (channelCount < ENET_PROTOCOL_MINIMUM_CHANNEL_COUNT) channelCount = ENET_PROTOCOL_MINIMUM_CHANNEL_COUNT;
    else if (channelCount > ENET_PROTOCOL_MAXIMUM_CHANNEL_COUNT) channelCount = ENET_PROTOCOL_MAXIMUM_CHANNEL_COUNT;

    for (currentPeer = host.peers; currentPeer < &host.peers [host.peerCount]; ++currentPeer) {
      if (currentPeer.state == ENET_PEER_STATE_DISCONNECTED) break;
    }

    if (currentPeer >= &host.peers[host.peerCount]) return null;

    currentPeer.channels = cast(ENetChannel*)enet_malloc(channelCount*ENetChannel.sizeof);
    if (currentPeer.channels is null) return null;
    currentPeer.channelCount = channelCount;
    currentPeer.state = ENET_PEER_STATE_CONNECTING;
    currentPeer.address = *address;
    currentPeer.connectID = ++host.randomSeed;

    if (host.outgoingBandwidth == 0) {
      currentPeer.windowSize = ENET_PROTOCOL_MAXIMUM_WINDOW_SIZE;
    } else {
      currentPeer.windowSize = (host.outgoingBandwidth/ENET_PEER_WINDOW_SIZE_SCALE)*ENET_PROTOCOL_MINIMUM_WINDOW_SIZE;
    }

    if (currentPeer.windowSize < ENET_PROTOCOL_MINIMUM_WINDOW_SIZE) currentPeer.windowSize = ENET_PROTOCOL_MINIMUM_WINDOW_SIZE;
    else if (currentPeer.windowSize > ENET_PROTOCOL_MAXIMUM_WINDOW_SIZE) currentPeer.windowSize = ENET_PROTOCOL_MAXIMUM_WINDOW_SIZE;

    for (channel = currentPeer.channels; channel < &currentPeer.channels[channelCount]; ++channel) {
      import core.stdc.string : memset;

      channel.outgoingReliableSequenceNumber = 0;
      channel.outgoingUnreliableSequenceNumber = 0;
      channel.incomingReliableSequenceNumber = 0;
      channel.incomingUnreliableSequenceNumber = 0;

      enet_list_clear(&channel.incomingReliableCommands);
      enet_list_clear(&channel.incomingUnreliableCommands);

      channel.usedReliableWindows = 0;
      memset(channel.reliableWindows.ptr, 0, channel.reliableWindows.sizeof);
    }

    command.header.command = ENET_PROTOCOL_COMMAND_CONNECT|ENET_PROTOCOL_COMMAND_FLAG_ACKNOWLEDGE;
    command.header.channelID = 0xFF;
    command.connect.outgoingPeerID = ENET_HOST_TO_NET_16(currentPeer.incomingPeerID);
    command.connect.incomingSessionID = currentPeer.incomingSessionID;
    command.connect.outgoingSessionID = currentPeer.outgoingSessionID;
    command.connect.mtu = ENET_HOST_TO_NET_32(currentPeer.mtu);
    command.connect.windowSize = ENET_HOST_TO_NET_32(currentPeer.windowSize);
    command.connect.channelCount = ENET_HOST_TO_NET_32(cast(uint)channelCount);
    command.connect.incomingBandwidth = ENET_HOST_TO_NET_32(host.incomingBandwidth);
    command.connect.outgoingBandwidth = ENET_HOST_TO_NET_32(host.outgoingBandwidth);
    command.connect.packetThrottleInterval = ENET_HOST_TO_NET_32(currentPeer.packetThrottleInterval);
    command.connect.packetThrottleAcceleration = ENET_HOST_TO_NET_32(currentPeer.packetThrottleAcceleration);
    command.connect.packetThrottleDeceleration = ENET_HOST_TO_NET_32(currentPeer.packetThrottleDeceleration);
    command.connect.connectID = currentPeer.connectID;
    command.connect.data = ENET_HOST_TO_NET_32(data);

    enet_peer_queue_outgoing_command(currentPeer, &command, null, 0, 0);

    return currentPeer;
  }


  /** Queues a packet to be sent to all peers associated with the host.
   *
   * Params:
   *  host = host on which to broadcast the packet
   *  channelID = channel on which to broadcast
   *  packet = packet to broadcast
   */
  void enet_host_broadcast (ENetHost* host, enet_uint8 channelID, ENetPacket* packet) {
    ENetPeer* currentPeer;

    for (currentPeer = host.peers; currentPeer < &host.peers[host.peerCount]; ++currentPeer) {
      if (currentPeer.state != ENET_PEER_STATE_CONNECTED) continue;
      enet_peer_send(currentPeer, channelID, packet);
    }

    if (packet.referenceCount == 0) enet_packet_destroy(packet);
  }


  /** Sets the packet compressor the host should use to compress and decompress packets.
   *
   * Params:
   *  host = host to enable or disable compression for
   *  compressor = callbacks for for the packet compressor; if null, then compression is disabled
   */
  void enet_host_compress (ENetHost* host, /*const*/ ENetCompressor* compressor) {
    if (host.compressor.context !is null && host.compressor.destroy) (*host.compressor.destroy)(host.compressor.context);
    if (compressor) host.compressor = *compressor; else host.compressor.context = null;
  }


  /** Limits the maximum allowed channels of future incoming connections.
   *
   * Params:
   *  host = host to limit
   *  channelLimit = the maximum number of channels allowed; if 0, then this is equivalent to ENET_PROTOCOL_MAXIMUM_CHANNEL_COUNT
   */
  void enet_host_channel_limit (ENetHost* host, usize channelLimit) @nogc {
    if (!channelLimit || channelLimit > ENET_PROTOCOL_MAXIMUM_CHANNEL_COUNT) channelLimit = ENET_PROTOCOL_MAXIMUM_CHANNEL_COUNT;
    else if (channelLimit < ENET_PROTOCOL_MINIMUM_CHANNEL_COUNT) channelLimit = ENET_PROTOCOL_MINIMUM_CHANNEL_COUNT;
    host.channelLimit = channelLimit;
  }


  /** Adjusts the bandwidth limits of a host.
   *
   * Params:
   *  host = host to adjust
   *  incomingBandwidth = new incoming bandwidth
   *  outgoingBandwidth = new outgoing bandwidth
   *
   * Remarks:
   *  the incoming and outgoing bandwidth parameters are identical in function to those
   *  specified in enet_host_create().
   */
  void enet_host_bandwidth_limit (ENetHost* host, enet_uint32 incomingBandwidth, enet_uint32 outgoingBandwidth) @nogc {
    host.incomingBandwidth = incomingBandwidth;
    host.outgoingBandwidth = outgoingBandwidth;
    host.recalculateBandwidthLimits = 1;
  }


  void enet_host_bandwidth_throttle (ENetHost* host) {
    enet_uint32 timeCurrent = enet_time_get();
    enet_uint32 elapsedTime = timeCurrent-host.bandwidthThrottleEpoch;
    enet_uint32 peersRemaining = cast(enet_uint32)host.connectedPeers;
    enet_uint32 dataTotal = ~0;
    enet_uint32 bandwidth = ~0;
    enet_uint32 throttle = 0;
    enet_uint32 bandwidthLimit = 0;
    int needsAdjustment = (host.bandwidthLimitedPeers > 0 ? 1 : 0);
    ENetPeer* peer;
    ENetProtocol command;

    if (elapsedTime < ENET_HOST_BANDWIDTH_THROTTLE_INTERVAL) return;

    host.bandwidthThrottleEpoch = timeCurrent;

    if (peersRemaining == 0) return;

    if (host.outgoingBandwidth != 0) {
      dataTotal = 0;
      bandwidth = (host.outgoingBandwidth*elapsedTime)/1000;

      for (peer = host.peers; peer < &host.peers[host.peerCount]; ++peer) {
        if (peer.state != ENET_PEER_STATE_CONNECTED && peer.state != ENET_PEER_STATE_DISCONNECT_LATER) continue;
        dataTotal += peer.outgoingDataTotal;
      }
    }

    while (peersRemaining > 0 && needsAdjustment != 0) {
      needsAdjustment = 0;

      throttle = (dataTotal <= bandwidth ? ENET_PEER_PACKET_THROTTLE_SCALE : (bandwidth*ENET_PEER_PACKET_THROTTLE_SCALE)/dataTotal);

      for (peer = host.peers; peer < &host.peers[host.peerCount]; ++peer) {
        enet_uint32 peerBandwidth;

        if ((peer.state != ENET_PEER_STATE_CONNECTED && peer.state != ENET_PEER_STATE_DISCONNECT_LATER) ||
            peer.incomingBandwidth == 0 ||
            peer.outgoingBandwidthThrottleEpoch == timeCurrent)
          continue;

        peerBandwidth = (peer.incomingBandwidth*elapsedTime)/1000;
        if ((throttle*peer.outgoingDataTotal)/ENET_PEER_PACKET_THROTTLE_SCALE <= peerBandwidth) continue;

        peer.packetThrottleLimit = (peerBandwidth*ENET_PEER_PACKET_THROTTLE_SCALE)/peer.outgoingDataTotal;

        if (peer.packetThrottleLimit == 0) peer.packetThrottleLimit = 1;

        if (peer.packetThrottle > peer.packetThrottleLimit) peer.packetThrottle = peer.packetThrottleLimit;

        peer.outgoingBandwidthThrottleEpoch = timeCurrent;

        peer.incomingDataTotal = 0;
        peer.outgoingDataTotal = 0;

        needsAdjustment = 1;
        --peersRemaining;
        bandwidth -= peerBandwidth;
        dataTotal -= peerBandwidth;
      }
    }

    if (peersRemaining > 0) {
      throttle = (dataTotal <= bandwidth ? ENET_PEER_PACKET_THROTTLE_SCALE : (bandwidth*ENET_PEER_PACKET_THROTTLE_SCALE)/dataTotal);

      for (peer = host.peers; peer < &host.peers[host.peerCount]; ++peer) {
        if ((peer.state != ENET_PEER_STATE_CONNECTED && peer.state != ENET_PEER_STATE_DISCONNECT_LATER) ||
            peer.outgoingBandwidthThrottleEpoch == timeCurrent)
          continue;

        peer.packetThrottleLimit = throttle;

        if (peer.packetThrottle > peer.packetThrottleLimit) peer.packetThrottle = peer.packetThrottleLimit;

        peer.incomingDataTotal = 0;
        peer.outgoingDataTotal = 0;
      }
    }

    if (host.recalculateBandwidthLimits) {
      host.recalculateBandwidthLimits = 0;

      peersRemaining = cast(enet_uint32)host.connectedPeers;
      bandwidth = host.incomingBandwidth;
      needsAdjustment = 1;

      if (bandwidth == 0) {
        bandwidthLimit = 0;
      } else {
        while (peersRemaining > 0 && needsAdjustment != 0) {
          needsAdjustment = 0;
          bandwidthLimit = bandwidth/peersRemaining;

          for (peer = host.peers; peer < &host.peers[host.peerCount]; ++peer) {
            if ((peer.state != ENET_PEER_STATE_CONNECTED && peer.state != ENET_PEER_STATE_DISCONNECT_LATER) ||
                peer.incomingBandwidthThrottleEpoch == timeCurrent)
              continue;

            if (peer.outgoingBandwidth > 0 && peer.outgoingBandwidth >= bandwidthLimit) continue;

            peer.incomingBandwidthThrottleEpoch = timeCurrent;

            needsAdjustment = 1;
            --peersRemaining;
            bandwidth -= peer.outgoingBandwidth;
          }
        }
      }

      for (peer = host.peers; peer < &host.peers[host.peerCount]; ++peer) {
        if (peer.state != ENET_PEER_STATE_CONNECTED && peer.state != ENET_PEER_STATE_DISCONNECT_LATER)
          continue;

        command.header.command = ENET_PROTOCOL_COMMAND_BANDWIDTH_LIMIT | ENET_PROTOCOL_COMMAND_FLAG_ACKNOWLEDGE;
        command.header.channelID = 0xFF;
        command.bandwidthLimit.outgoingBandwidth = ENET_HOST_TO_NET_32 (host.outgoingBandwidth);

        if (peer.incomingBandwidthThrottleEpoch == timeCurrent) {
          command.bandwidthLimit.incomingBandwidth = ENET_HOST_TO_NET_32(peer.outgoingBandwidth);
        } else {
          command.bandwidthLimit.incomingBandwidth = ENET_HOST_TO_NET_32(bandwidthLimit);
        }

        enet_peer_queue_outgoing_command(peer, &command, null, 0, 0);
      }
    }
  }
}


// protocol.c
extern(C) nothrow {
  // `auto` to trigger attribute inference
  private auto ENET_MIN(T) (T a, T b) { pragma(inline, true); return (a < b ? a : b); }
  private auto ENET_MAX(T) (T a, T b) { pragma(inline, true); return (a > b ? a : b); }


  enum ENET_TIME_OVERFLOW = 86400000;

  // `auto` to trigger attribute inference
  auto ENET_TIME_LESS(T) (T a, T b) { pragma(inline, true); return (a-b >= ENET_TIME_OVERFLOW); }
  auto ENET_TIME_GREATER(T) (T a, T b) { pragma(inline, true); return (b-a >= ENET_TIME_OVERFLOW); }
  auto ENET_TIME_LESS_EQUAL(T) (T a, T b) { pragma(inline, true); return !ENET_TIME_GREATER(a, b); }
  auto ENET_TIME_GREATER_EQUAL(T) (T a, T b) { pragma(inline, true); return !ENET_TIME_LESS(a, b); }

  auto ENET_TIME_DIFFERENCE(T) (T a, T b) { pragma(inline, true); return (a-b >= ENET_TIME_OVERFLOW ? b-a : a-b); }


  private immutable usize[ENET_PROTOCOL_COMMAND_COUNT] commandSizes = [
    0,
    ENetProtocolAcknowledge.sizeof,
    ENetProtocolConnect.sizeof,
    ENetProtocolVerifyConnect.sizeof,
    ENetProtocolDisconnect.sizeof,
    ENetProtocolPing.sizeof,
    ENetProtocolSendReliable.sizeof,
    ENetProtocolSendUnreliable.sizeof,
    ENetProtocolSendFragment.sizeof,
    ENetProtocolSendUnsequenced.sizeof,
    ENetProtocolBandwidthLimit.sizeof,
    ENetProtocolThrottleConfigure.sizeof,
    ENetProtocolSendFragment.sizeof,
  ];


  usize enet_protocol_command_size (enet_uint8 commandNumber) @nogc {
    return commandSizes[commandNumber&ENET_PROTOCOL_COMMAND_MASK];
  }


  private void enet_protocol_change_state (ENetHost* host, ENetPeer* peer, ENetPeerState state) {
    if (state == ENET_PEER_STATE_CONNECTED || state == ENET_PEER_STATE_DISCONNECT_LATER) {
      enet_peer_on_connect(peer);
    } else {
      enet_peer_on_disconnect(peer);
    }
    peer.state = state;
  }


  private void enet_protocol_dispatch_state (ENetHost* host, ENetPeer* peer, ENetPeerState state) {
    enet_protocol_change_state(host, peer, state);
    if (!peer.needsDispatch) {
      enet_list_insert(enet_list_end(&host.dispatchQueue), &peer.dispatchList);
      peer.needsDispatch = true;
    }
  }


  private int enet_protocol_dispatch_incoming_commands (ENetHost* host, ENetEvent* event) {
    while (!enet_list_empty(&host.dispatchQueue)) {
      ENetPeer* peer = cast(ENetPeer*)enet_list_remove(enet_list_begin(&host.dispatchQueue));
      peer.needsDispatch = false;
      switch (peer.state) {
        case ENET_PEER_STATE_CONNECTION_PENDING:
        case ENET_PEER_STATE_CONNECTION_SUCCEEDED:
          enet_protocol_change_state(host, peer, ENET_PEER_STATE_CONNECTED);
          event.type = ENET_EVENT_TYPE_CONNECT;
          event.peer = peer;
          event.data = peer.eventData;
          return 1;
        case ENET_PEER_STATE_ZOMBIE:
          host.recalculateBandwidthLimits = 1;
          event.type = ENET_EVENT_TYPE_DISCONNECT;
          event.peer = peer;
          event.data = peer.eventData;
          enet_peer_reset(peer);
          return 1;
        case ENET_PEER_STATE_CONNECTED:
          if (enet_list_empty(&peer.dispatchedCommands)) continue;
          event.packet = enet_peer_receive(peer, &event.channelID);
          if (event.packet is null) continue;
          event.type = ENET_EVENT_TYPE_RECEIVE;
          event.peer = peer;
          if (!enet_list_empty(&peer.dispatchedCommands)) {
            peer.needsDispatch = true;
            enet_list_insert(enet_list_end(&host.dispatchQueue), &peer.dispatchList);
          }
          return 1;
        default:
          break;
      }
    }
    return 0;
  }


  private void enet_protocol_notify_connect (ENetHost* host, ENetPeer* peer, ENetEvent* event) {
    host.recalculateBandwidthLimits = 1;
    if (event !is null) {
      enet_protocol_change_state(host, peer, ENET_PEER_STATE_CONNECTED);
      event.type = ENET_EVENT_TYPE_CONNECT;
      event.peer = peer;
      event.data = peer.eventData;
    } else {
      enet_protocol_dispatch_state(host, peer, (peer.state == ENET_PEER_STATE_CONNECTING ? ENET_PEER_STATE_CONNECTION_SUCCEEDED : ENET_PEER_STATE_CONNECTION_PENDING));
    }
  }


  private void enet_protocol_notify_disconnect (ENetHost* host, ENetPeer* peer, ENetEvent* event) {
    if (peer.state >= ENET_PEER_STATE_CONNECTION_PENDING) host.recalculateBandwidthLimits = 1;
    if (peer.state != ENET_PEER_STATE_CONNECTING && peer.state < ENET_PEER_STATE_CONNECTION_SUCCEEDED) {
      enet_peer_reset(peer);
    } else if (event !is null) {
      event.type = ENET_EVENT_TYPE_DISCONNECT;
      event.peer = peer;
      event.data = 0;
      enet_peer_reset(peer);
    } else {
      peer.eventData = 0;
      enet_protocol_dispatch_state(host, peer, ENET_PEER_STATE_ZOMBIE);
    }
  }


  private void enet_protocol_remove_sent_unreliable_commands (ENetPeer* peer) {
    ENetOutgoingCommand * outgoingCommand;
    while (!enet_list_empty(&peer.sentUnreliableCommands)) {
      outgoingCommand = cast(ENetOutgoingCommand*)enet_list_front(&peer.sentUnreliableCommands);
      enet_list_remove(&outgoingCommand.outgoingCommandList);
      if (outgoingCommand.packet !is null) {
        --outgoingCommand.packet.referenceCount;
        if (outgoingCommand.packet.referenceCount == 0) {
          outgoingCommand.packet.flags |= ENET_PACKET_FLAG_SENT;
          enet_packet_destroy (outgoingCommand.packet);
        }
      }
      enet_free(outgoingCommand);
    }
  }


  private ENetProtocolCommand enet_protocol_remove_sent_reliable_command (ENetPeer* peer, enet_uint16 reliableSequenceNumber, enet_uint8 channelID) {
    ENetOutgoingCommand* outgoingCommand = null;
    ENetListIterator currentCommand;
    ENetProtocolCommand commandNumber;
    int wasSent = 1;

    for (currentCommand = enet_list_begin(&peer.sentReliableCommands);
         currentCommand != enet_list_end(&peer.sentReliableCommands);
         currentCommand = enet_list_next(currentCommand))
    {
      outgoingCommand = cast(ENetOutgoingCommand*)currentCommand;
      if (outgoingCommand.reliableSequenceNumber == reliableSequenceNumber && outgoingCommand.command.header.channelID == channelID) break;
    }

    if (currentCommand == enet_list_end(&peer.sentReliableCommands)) {
      for (currentCommand = enet_list_begin(&peer.outgoingReliableCommands);
           currentCommand != enet_list_end(&peer.outgoingReliableCommands);
           currentCommand = enet_list_next(currentCommand))
      {
        outgoingCommand = cast(ENetOutgoingCommand*)currentCommand;
        if (outgoingCommand.sendAttempts < 1) return ENET_PROTOCOL_COMMAND_NONE;
        if (outgoingCommand.reliableSequenceNumber == reliableSequenceNumber && outgoingCommand.command.header.channelID == channelID) break;
      }
      if (currentCommand == enet_list_end(&peer.outgoingReliableCommands)) return ENET_PROTOCOL_COMMAND_NONE;
      wasSent = 0;
    }

    if (outgoingCommand is null) return ENET_PROTOCOL_COMMAND_NONE;

    if (channelID < peer.channelCount) {
      ENetChannel* channel = &peer.channels[channelID];
      enet_uint16 reliableWindow = reliableSequenceNumber/ENET_PEER_RELIABLE_WINDOW_SIZE;
      if (channel.reliableWindows[reliableWindow] > 0) {
        --channel.reliableWindows[reliableWindow];
        if (!channel.reliableWindows[reliableWindow]) channel.usedReliableWindows &= ~(1<<reliableWindow);
      }
    }

    commandNumber = cast(ENetProtocolCommand)(outgoingCommand.command.header.command&ENET_PROTOCOL_COMMAND_MASK);

    enet_list_remove(&outgoingCommand.outgoingCommandList);

    if (outgoingCommand.packet !is null) {
      if (wasSent) peer.reliableDataInTransit -= outgoingCommand.fragmentLength;
      --outgoingCommand.packet.referenceCount;
      if (outgoingCommand.packet.referenceCount == 0) {
        outgoingCommand.packet.flags |= ENET_PACKET_FLAG_SENT;
        enet_packet_destroy (outgoingCommand.packet);
      }
    }

    enet_free(outgoingCommand);

    if (enet_list_empty(&peer.sentReliableCommands)) return commandNumber;

    outgoingCommand = cast(ENetOutgoingCommand*)enet_list_front(&peer.sentReliableCommands);

    peer.nextTimeout = outgoingCommand.sentTime+outgoingCommand.roundTripTimeout;

    return commandNumber;
  }


  private ENetPeer* enet_protocol_handle_connect (ENetHost* host, ENetProtocolHeader* header, ENetProtocol* command) {
    enet_uint8 incomingSessionID, outgoingSessionID;
    enet_uint32 mtu, windowSize;
    ENetChannel* channel;
    usize channelCount, duplicatePeers = 0;
    ENetPeer* currentPeer, peer = null;
    ENetProtocol verifyCommand;

    channelCount = ENET_NET_TO_HOST_32(command.connect.channelCount);

    if (channelCount < ENET_PROTOCOL_MINIMUM_CHANNEL_COUNT || channelCount > ENET_PROTOCOL_MAXIMUM_CHANNEL_COUNT) return null;

    for (currentPeer = host.peers; currentPeer < &host.peers[host.peerCount]; ++currentPeer) {
      if (currentPeer.state == ENET_PEER_STATE_DISCONNECTED) {
        if (peer is null) peer = currentPeer;
      } else if (currentPeer.state != ENET_PEER_STATE_CONNECTING && currentPeer.address.host == host.receivedAddress.host) {
        if (currentPeer.address.port == host.receivedAddress.port && currentPeer.connectID == command.connect.connectID) return null;
        ++duplicatePeers;
      }
    }

    if (peer is null || duplicatePeers >= host.duplicatePeers) return null;

    if (channelCount > host.channelLimit) channelCount = host.channelLimit;
    peer.channels = cast(ENetChannel*)enet_malloc(channelCount*ENetChannel.sizeof);
    if (peer.channels is null) return null;

    peer.channelCount = channelCount;
    peer.state = ENET_PEER_STATE_ACKNOWLEDGING_CONNECT;
    peer.connectID = command.connect.connectID;
    peer.address = host.receivedAddress;
    peer.outgoingPeerID = ENET_NET_TO_HOST_16(command.connect.outgoingPeerID);
    peer.incomingBandwidth = ENET_NET_TO_HOST_32(command.connect.incomingBandwidth);
    peer.outgoingBandwidth = ENET_NET_TO_HOST_32(command.connect.outgoingBandwidth);
    peer.packetThrottleInterval = ENET_NET_TO_HOST_32(command.connect.packetThrottleInterval);
    peer.packetThrottleAcceleration = ENET_NET_TO_HOST_32(command.connect.packetThrottleAcceleration);
    peer.packetThrottleDeceleration = ENET_NET_TO_HOST_32(command.connect.packetThrottleDeceleration);
    peer.eventData = ENET_NET_TO_HOST_32(command.connect.data);

    incomingSessionID = (command.connect.incomingSessionID == 0xFF ? peer.outgoingSessionID : command.connect.incomingSessionID);
    incomingSessionID = (incomingSessionID+1)&(ENET_PROTOCOL_HEADER_SESSION_MASK>>ENET_PROTOCOL_HEADER_SESSION_SHIFT);
    if (incomingSessionID == peer.outgoingSessionID) incomingSessionID = (incomingSessionID+1)&(ENET_PROTOCOL_HEADER_SESSION_MASK>>ENET_PROTOCOL_HEADER_SESSION_SHIFT);
    peer.outgoingSessionID = incomingSessionID;

    outgoingSessionID = (command.connect.outgoingSessionID == 0xFF ? peer.incomingSessionID : command.connect.outgoingSessionID);
    outgoingSessionID = (outgoingSessionID+1)&(ENET_PROTOCOL_HEADER_SESSION_MASK>>ENET_PROTOCOL_HEADER_SESSION_SHIFT);
    if (outgoingSessionID == peer.incomingSessionID) outgoingSessionID = (outgoingSessionID+1)&(ENET_PROTOCOL_HEADER_SESSION_MASK>>ENET_PROTOCOL_HEADER_SESSION_SHIFT);
    peer.incomingSessionID = outgoingSessionID;

    for (channel = peer.channels; channel < &peer.channels[channelCount]; ++channel) {
      channel.outgoingReliableSequenceNumber = 0;
      channel.outgoingUnreliableSequenceNumber = 0;
      channel.incomingReliableSequenceNumber = 0;
      channel.incomingUnreliableSequenceNumber = 0;

      enet_list_clear(&channel.incomingReliableCommands);
      enet_list_clear(&channel.incomingUnreliableCommands);

      channel.usedReliableWindows = 0;

      import core.stdc.string : memset;
      memset(channel.reliableWindows.ptr, 0, channel.reliableWindows.sizeof);
    }

    mtu = ENET_NET_TO_HOST_32(command.connect.mtu);

    if (mtu < ENET_PROTOCOL_MINIMUM_MTU) mtu = ENET_PROTOCOL_MINIMUM_MTU;
    else if (mtu > ENET_PROTOCOL_MAXIMUM_MTU) mtu = ENET_PROTOCOL_MAXIMUM_MTU;

    peer.mtu = mtu;

    if (host.outgoingBandwidth == 0 && peer.incomingBandwidth == 0) {
      peer.windowSize = ENET_PROTOCOL_MAXIMUM_WINDOW_SIZE;
    } else if (host.outgoingBandwidth == 0 || peer.incomingBandwidth == 0) {
      peer.windowSize = (ENET_MAX(host.outgoingBandwidth, peer.incomingBandwidth)/ENET_PEER_WINDOW_SIZE_SCALE)*ENET_PROTOCOL_MINIMUM_WINDOW_SIZE;
    } else {
      peer.windowSize = (ENET_MIN(host.outgoingBandwidth, peer.incomingBandwidth)/ENET_PEER_WINDOW_SIZE_SCALE)*ENET_PROTOCOL_MINIMUM_WINDOW_SIZE;
    }
    if (peer.windowSize < ENET_PROTOCOL_MINIMUM_WINDOW_SIZE) peer.windowSize = ENET_PROTOCOL_MINIMUM_WINDOW_SIZE;
    else if (peer.windowSize > ENET_PROTOCOL_MAXIMUM_WINDOW_SIZE) peer.windowSize = ENET_PROTOCOL_MAXIMUM_WINDOW_SIZE;

    if (host.incomingBandwidth == 0) windowSize = ENET_PROTOCOL_MAXIMUM_WINDOW_SIZE;
    else windowSize = (host.incomingBandwidth/ENET_PEER_WINDOW_SIZE_SCALE)*ENET_PROTOCOL_MINIMUM_WINDOW_SIZE;

    if (windowSize > ENET_NET_TO_HOST_32(command.connect.windowSize)) windowSize = ENET_NET_TO_HOST_32(command.connect.windowSize);

    if (windowSize < ENET_PROTOCOL_MINIMUM_WINDOW_SIZE) windowSize = ENET_PROTOCOL_MINIMUM_WINDOW_SIZE;
    else if (windowSize > ENET_PROTOCOL_MAXIMUM_WINDOW_SIZE) windowSize = ENET_PROTOCOL_MAXIMUM_WINDOW_SIZE;

    verifyCommand.header.command = ENET_PROTOCOL_COMMAND_VERIFY_CONNECT|ENET_PROTOCOL_COMMAND_FLAG_ACKNOWLEDGE;
    verifyCommand.header.channelID = 0xFF;
    verifyCommand.verifyConnect.outgoingPeerID = ENET_HOST_TO_NET_16 (peer.incomingPeerID);
    verifyCommand.verifyConnect.incomingSessionID = incomingSessionID;
    verifyCommand.verifyConnect.outgoingSessionID = outgoingSessionID;
    verifyCommand.verifyConnect.mtu = ENET_HOST_TO_NET_32(peer.mtu);
    verifyCommand.verifyConnect.windowSize = ENET_HOST_TO_NET_32(windowSize);
    verifyCommand.verifyConnect.channelCount = ENET_HOST_TO_NET_32(cast(uint)channelCount);
    verifyCommand.verifyConnect.incomingBandwidth = ENET_HOST_TO_NET_32(host.incomingBandwidth);
    verifyCommand.verifyConnect.outgoingBandwidth = ENET_HOST_TO_NET_32(host.outgoingBandwidth);
    verifyCommand.verifyConnect.packetThrottleInterval = ENET_HOST_TO_NET_32(peer.packetThrottleInterval);
    verifyCommand.verifyConnect.packetThrottleAcceleration = ENET_HOST_TO_NET_32(peer.packetThrottleAcceleration);
    verifyCommand.verifyConnect.packetThrottleDeceleration = ENET_HOST_TO_NET_32(peer.packetThrottleDeceleration);
    verifyCommand.verifyConnect.connectID = peer.connectID;

    enet_peer_queue_outgoing_command(peer, &verifyCommand, null, 0, 0);

    return peer;
  }


  private int enet_protocol_handle_send_reliable (ENetHost* host, ENetPeer* peer, const ENetProtocol* command, enet_uint8** currentData) {
    usize dataLength;
    if (command.header.channelID >= peer.channelCount || (peer.state != ENET_PEER_STATE_CONNECTED && peer.state != ENET_PEER_STATE_DISCONNECT_LATER)) return -1;
    dataLength = ENET_NET_TO_HOST_16(command.sendReliable.dataLength);
    *currentData += dataLength;
    if (dataLength > host.maximumPacketSize || *currentData < host.receivedData || *currentData > &host.receivedData[host.receivedDataLength]) return -1;
    if (enet_peer_queue_incoming_command(peer, command, cast(const(enet_uint8)*)command+ENetProtocolSendReliable.sizeof, dataLength, ENET_PACKET_FLAG_RELIABLE, 0) is null) return -1;
    return 0;
  }


  private int enet_protocol_handle_send_unsequenced (ENetHost* host, ENetPeer* peer, const ENetProtocol* command, enet_uint8** currentData) {
    enet_uint32 unsequencedGroup, index;
    usize dataLength;

    if (command.header.channelID >= peer.channelCount || (peer.state != ENET_PEER_STATE_CONNECTED && peer.state != ENET_PEER_STATE_DISCONNECT_LATER)) return -1;

    dataLength = ENET_NET_TO_HOST_16(command.sendUnsequenced.dataLength);
    *currentData += dataLength;
    if (dataLength > host.maximumPacketSize || *currentData < host.receivedData || *currentData > &host.receivedData[host.receivedDataLength]) return -1;

    unsequencedGroup = ENET_NET_TO_HOST_16 (command.sendUnsequenced.unsequencedGroup);
    index = unsequencedGroup%ENET_PEER_UNSEQUENCED_WINDOW_SIZE;

    if (unsequencedGroup < peer.incomingUnsequencedGroup) unsequencedGroup += 0x10000;

    if (unsequencedGroup >= cast(enet_uint32)peer.incomingUnsequencedGroup+ENET_PEER_FREE_UNSEQUENCED_WINDOWS*ENET_PEER_UNSEQUENCED_WINDOW_SIZE) return 0;

    unsequencedGroup &= 0xFFFF;

    if (unsequencedGroup-index != peer.incomingUnsequencedGroup) {
      import core.stdc.string : memset;
      peer.incomingUnsequencedGroup = cast(ushort)(unsequencedGroup-index);
      memset(peer.unsequencedWindow.ptr, 0, peer.unsequencedWindow.sizeof);
    } else if (peer.unsequencedWindow.ptr[index/32]&(1<<(index%32))) {
      return 0;
    }

    if (enet_peer_queue_incoming_command(peer, command, cast(const(enet_uint8)*)command+ENetProtocolSendUnsequenced.sizeof, dataLength, ENET_PACKET_FLAG_UNSEQUENCED, 0) is null) return -1;

    peer.unsequencedWindow.ptr[index/32] |= 1<<(index%32);

    return 0;
  }


  private int enet_protocol_handle_send_unreliable (ENetHost* host, ENetPeer* peer, const ENetProtocol* command, enet_uint8** currentData) {
    usize dataLength;

    if (command.header.channelID >= peer.channelCount || (peer.state != ENET_PEER_STATE_CONNECTED && peer.state != ENET_PEER_STATE_DISCONNECT_LATER)) return -1;

    dataLength = ENET_NET_TO_HOST_16(command.sendUnreliable.dataLength);
    *currentData += dataLength;
    if (dataLength > host.maximumPacketSize || *currentData < host.receivedData || *currentData > &host.receivedData[host.receivedDataLength]) return -1;

    if (enet_peer_queue_incoming_command(peer, command, cast(const(enet_uint8)*)command+ENetProtocolSendUnreliable.sizeof, dataLength, 0, 0) is null) return -1;

    return 0;
  }


  private int enet_protocol_handle_send_fragment (ENetHost* host, ENetPeer* peer, const ENetProtocol* command, enet_uint8** currentData) {
    enet_uint32 fragmentNumber, fragmentCount, fragmentOffset, fragmentLength, startSequenceNumber, totalLength;
    ENetChannel* channel;
    enet_uint16 startWindow, currentWindow;
    ENetListIterator currentCommand;
    ENetIncomingCommand* startCommand = null;

    if (command.header.channelID >= peer.channelCount || (peer.state != ENET_PEER_STATE_CONNECTED && peer.state != ENET_PEER_STATE_DISCONNECT_LATER)) return -1;

    fragmentLength = ENET_NET_TO_HOST_16 (command.sendFragment.dataLength);
    *currentData += fragmentLength;
    if (fragmentLength > host.maximumPacketSize || *currentData < host.receivedData || *currentData > &host.receivedData[host.receivedDataLength]) return -1;

    channel = &peer.channels[command.header.channelID];
    startSequenceNumber = ENET_NET_TO_HOST_16(command.sendFragment.startSequenceNumber);
    startWindow = cast(ushort)(startSequenceNumber/ENET_PEER_RELIABLE_WINDOW_SIZE);
    currentWindow = channel.incomingReliableSequenceNumber/ENET_PEER_RELIABLE_WINDOW_SIZE;

    if (startSequenceNumber < channel.incomingReliableSequenceNumber) startWindow += ENET_PEER_RELIABLE_WINDOWS;

    if (startWindow < currentWindow || startWindow >= currentWindow+ENET_PEER_FREE_RELIABLE_WINDOWS-1) return 0;

    fragmentNumber = ENET_NET_TO_HOST_32(command.sendFragment.fragmentNumber);
    fragmentCount = ENET_NET_TO_HOST_32(command.sendFragment.fragmentCount);
    fragmentOffset = ENET_NET_TO_HOST_32(command.sendFragment.fragmentOffset);
    totalLength = ENET_NET_TO_HOST_32(command.sendFragment.totalLength);

    if (fragmentCount > ENET_PROTOCOL_MAXIMUM_FRAGMENT_COUNT ||
        fragmentNumber >= fragmentCount ||
        totalLength > host.maximumPacketSize ||
        fragmentOffset >= totalLength ||
        fragmentLength > totalLength-fragmentOffset)
      return -1;

    for (currentCommand = enet_list_previous(enet_list_end(&channel.incomingReliableCommands));
         currentCommand != enet_list_end(&channel.incomingReliableCommands);
         currentCommand = enet_list_previous(currentCommand))
    {
      ENetIncomingCommand* incomingCommand = cast(ENetIncomingCommand*)currentCommand;
      if (startSequenceNumber >= channel.incomingReliableSequenceNumber) {
        if (incomingCommand.reliableSequenceNumber < channel.incomingReliableSequenceNumber) continue;
      } else if (incomingCommand.reliableSequenceNumber >= channel.incomingReliableSequenceNumber) break;
      if (incomingCommand.reliableSequenceNumber <= startSequenceNumber) {
        if (incomingCommand.reliableSequenceNumber < startSequenceNumber) break;
        if ((incomingCommand.command.header.command&ENET_PROTOCOL_COMMAND_MASK) != ENET_PROTOCOL_COMMAND_SEND_FRAGMENT ||
            totalLength != incomingCommand.packet.dataLength ||
            fragmentCount != incomingCommand.fragmentCount)
          return -1;
        startCommand = incomingCommand;
        break;
      }
    }

    if (startCommand is null) {
      ENetProtocol hostCommand = *command;
      hostCommand.header.reliableSequenceNumber = cast(ushort)startSequenceNumber;
      startCommand = enet_peer_queue_incoming_command(peer, &hostCommand, null, totalLength, ENET_PACKET_FLAG_RELIABLE, fragmentCount);
      if (startCommand is null) return -1;
    }

    if ((startCommand.fragments[fragmentNumber/32]&(1<<(fragmentNumber%32))) == 0) {
      import core.stdc.string : memcpy;
      --startCommand.fragmentsRemaining;
      startCommand.fragments[fragmentNumber/32] |= (1<<(fragmentNumber%32));
      if (fragmentOffset+fragmentLength > startCommand.packet.dataLength) fragmentLength = cast(uint)(startCommand.packet.dataLength-fragmentOffset);
      memcpy(startCommand.packet.data+fragmentOffset, cast(enet_uint8*)command+ENetProtocolSendFragment.sizeof, fragmentLength);
      if (startCommand.fragmentsRemaining <= 0) enet_peer_dispatch_incoming_reliable_commands(peer, channel);
    }

    return 0;
  }


  private int enet_protocol_handle_send_unreliable_fragment (ENetHost* host, ENetPeer* peer, const ENetProtocol* command, enet_uint8** currentData) {
    enet_uint32 fragmentNumber, fragmentCount, fragmentOffset, fragmentLength, reliableSequenceNumber, startSequenceNumber, totalLength;
    enet_uint16 reliableWindow, currentWindow;
    ENetChannel* channel;
    ENetListIterator currentCommand;
    ENetIncomingCommand* startCommand = null;

    if (command.header.channelID >= peer.channelCount || (peer.state != ENET_PEER_STATE_CONNECTED && peer.state != ENET_PEER_STATE_DISCONNECT_LATER)) return -1;

    fragmentLength = ENET_NET_TO_HOST_16(command.sendFragment.dataLength);
    *currentData += fragmentLength;
    if (fragmentLength > host.maximumPacketSize || *currentData < host.receivedData || *currentData > &host.receivedData[host.receivedDataLength]) return -1;

    channel = &peer.channels[command.header.channelID];
    reliableSequenceNumber = command.header.reliableSequenceNumber;
    startSequenceNumber = ENET_NET_TO_HOST_16(command.sendFragment.startSequenceNumber);

    reliableWindow = cast(ushort)(reliableSequenceNumber/ENET_PEER_RELIABLE_WINDOW_SIZE);
    currentWindow = channel.incomingReliableSequenceNumber/ENET_PEER_RELIABLE_WINDOW_SIZE;

    if (reliableSequenceNumber < channel.incomingReliableSequenceNumber) reliableWindow += ENET_PEER_RELIABLE_WINDOWS;

    if (reliableWindow < currentWindow || reliableWindow >= currentWindow+ENET_PEER_FREE_RELIABLE_WINDOWS-1) return 0;

    if (reliableSequenceNumber == channel.incomingReliableSequenceNumber && startSequenceNumber <= channel.incomingUnreliableSequenceNumber) return 0;

    fragmentNumber = ENET_NET_TO_HOST_32(command.sendFragment.fragmentNumber);
    fragmentCount = ENET_NET_TO_HOST_32(command.sendFragment.fragmentCount);
    fragmentOffset = ENET_NET_TO_HOST_32(command.sendFragment.fragmentOffset);
    totalLength = ENET_NET_TO_HOST_32(command.sendFragment.totalLength);

    if (fragmentCount > ENET_PROTOCOL_MAXIMUM_FRAGMENT_COUNT ||
        fragmentNumber >= fragmentCount ||
        totalLength > host.maximumPacketSize ||
        fragmentOffset >= totalLength ||
        fragmentLength > totalLength - fragmentOffset)
      return -1;

    for (currentCommand = enet_list_previous(enet_list_end (&channel.incomingUnreliableCommands));
         currentCommand != enet_list_end(&channel.incomingUnreliableCommands);
         currentCommand = enet_list_previous(currentCommand))
    {
      ENetIncomingCommand* incomingCommand = cast(ENetIncomingCommand*)currentCommand;
      if (reliableSequenceNumber >= channel.incomingReliableSequenceNumber) {
        if (incomingCommand.reliableSequenceNumber < channel.incomingReliableSequenceNumber) continue;
      } else if (incomingCommand.reliableSequenceNumber >= channel.incomingReliableSequenceNumber) break;
      if (incomingCommand.reliableSequenceNumber < reliableSequenceNumber) break;
      if (incomingCommand.reliableSequenceNumber > reliableSequenceNumber) continue;
      if (incomingCommand.unreliableSequenceNumber <= startSequenceNumber) {
        if (incomingCommand.unreliableSequenceNumber < startSequenceNumber) break;
        if ((incomingCommand.command.header.command&ENET_PROTOCOL_COMMAND_MASK) != ENET_PROTOCOL_COMMAND_SEND_UNRELIABLE_FRAGMENT ||
            totalLength != incomingCommand.packet.dataLength ||
            fragmentCount != incomingCommand.fragmentCount)
          return -1;
        startCommand = incomingCommand;
        break;
      }
    }

    if (startCommand is null) {
      startCommand = enet_peer_queue_incoming_command(peer, command, null, totalLength, ENET_PACKET_FLAG_UNRELIABLE_FRAGMENT, fragmentCount);
      if (startCommand is null) return -1;
    }

    if ((startCommand.fragments[fragmentNumber/32]&(1<<(fragmentNumber%32))) == 0) {
      import core.stdc.string : memcpy;
      --startCommand.fragmentsRemaining;
      startCommand.fragments[fragmentNumber/32] |= (1<<(fragmentNumber%32));
      if (fragmentOffset+fragmentLength > startCommand.packet.dataLength) fragmentLength = cast(uint)(startCommand.packet.dataLength-fragmentOffset);
      memcpy(startCommand.packet.data+fragmentOffset, cast(enet_uint8*)command+ENetProtocolSendFragment.sizeof, fragmentLength);
      if (startCommand.fragmentsRemaining <= 0) enet_peer_dispatch_incoming_unreliable_commands(peer, channel);
    }

    return 0;
  }


  private int enet_protocol_handle_ping (ENetHost* host, ENetPeer* peer, const ENetProtocol* command) @nogc {
    if (peer.state != ENET_PEER_STATE_CONNECTED && peer.state != ENET_PEER_STATE_DISCONNECT_LATER) return -1;
    return 0;
  }


  private int enet_protocol_handle_bandwidth_limit (ENetHost* host, ENetPeer* peer, const ENetProtocol* command) @nogc {
    if (peer.state != ENET_PEER_STATE_CONNECTED && peer.state != ENET_PEER_STATE_DISCONNECT_LATER) return -1;

    if (peer.incomingBandwidth != 0) --host.bandwidthLimitedPeers;

    peer.incomingBandwidth = ENET_NET_TO_HOST_32(command.bandwidthLimit.incomingBandwidth);
    peer.outgoingBandwidth = ENET_NET_TO_HOST_32(command.bandwidthLimit.outgoingBandwidth);

    if (peer.incomingBandwidth != 0) ++host.bandwidthLimitedPeers;

    if (peer.incomingBandwidth == 0 && host.outgoingBandwidth == 0) {
      peer.windowSize = ENET_PROTOCOL_MAXIMUM_WINDOW_SIZE;
    } else if (peer.incomingBandwidth == 0 || host.outgoingBandwidth == 0) {
      peer.windowSize = (ENET_MAX(peer.incomingBandwidth, host.outgoingBandwidth)/ ENET_PEER_WINDOW_SIZE_SCALE)*ENET_PROTOCOL_MINIMUM_WINDOW_SIZE;
    } else {
      peer.windowSize = (ENET_MIN(peer.incomingBandwidth, host.outgoingBandwidth)/ENET_PEER_WINDOW_SIZE_SCALE)*ENET_PROTOCOL_MINIMUM_WINDOW_SIZE;
    }

    if (peer.windowSize < ENET_PROTOCOL_MINIMUM_WINDOW_SIZE) peer.windowSize = ENET_PROTOCOL_MINIMUM_WINDOW_SIZE;
    else if (peer.windowSize > ENET_PROTOCOL_MAXIMUM_WINDOW_SIZE) peer.windowSize = ENET_PROTOCOL_MAXIMUM_WINDOW_SIZE;

    return 0;
  }


  private int enet_protocol_handle_throttle_configure (ENetHost* host, ENetPeer* peer, const ENetProtocol* command) @nogc {
    if (peer.state != ENET_PEER_STATE_CONNECTED && peer.state != ENET_PEER_STATE_DISCONNECT_LATER) return -1;

    peer.packetThrottleInterval = ENET_NET_TO_HOST_32(command.throttleConfigure.packetThrottleInterval);
    peer.packetThrottleAcceleration = ENET_NET_TO_HOST_32(command.throttleConfigure.packetThrottleAcceleration);
    peer.packetThrottleDeceleration = ENET_NET_TO_HOST_32(command.throttleConfigure.packetThrottleDeceleration);

    return 0;
  }


  private int enet_protocol_handle_disconnect (ENetHost* host, ENetPeer* peer, const ENetProtocol* command) {
    if (peer.state == ENET_PEER_STATE_DISCONNECTED || peer.state == ENET_PEER_STATE_ZOMBIE || peer.state == ENET_PEER_STATE_ACKNOWLEDGING_DISCONNECT) return 0;

    enet_peer_reset_queues(peer);

    if (peer.state == ENET_PEER_STATE_CONNECTION_SUCCEEDED || peer.state == ENET_PEER_STATE_DISCONNECTING || peer.state == ENET_PEER_STATE_CONNECTING) {
      enet_protocol_dispatch_state(host, peer, ENET_PEER_STATE_ZOMBIE);
    } else if (peer.state != ENET_PEER_STATE_CONNECTED && peer.state != ENET_PEER_STATE_DISCONNECT_LATER) {
      if (peer.state == ENET_PEER_STATE_CONNECTION_PENDING) host.recalculateBandwidthLimits = 1;
      enet_peer_reset(peer);
    } else if (command.header.command&ENET_PROTOCOL_COMMAND_FLAG_ACKNOWLEDGE) {
      enet_protocol_change_state(host, peer, ENET_PEER_STATE_ACKNOWLEDGING_DISCONNECT);
    } else {
      enet_protocol_dispatch_state(host, peer, ENET_PEER_STATE_ZOMBIE);
    }

    if (peer.state != ENET_PEER_STATE_DISCONNECTED) peer.eventData = ENET_NET_TO_HOST_32(command.disconnect.data);

    return 0;
  }


  private int enet_protocol_handle_acknowledge (ENetHost* host, ENetEvent* event, ENetPeer* peer, const ENetProtocol* command) {
    enet_uint32 roundTripTime, receivedSentTime, receivedReliableSequenceNumber;
    ENetProtocolCommand commandNumber;

    if (peer.state == ENET_PEER_STATE_DISCONNECTED || peer.state == ENET_PEER_STATE_ZOMBIE) return 0;

    receivedSentTime = ENET_NET_TO_HOST_16(command.acknowledge.receivedSentTime);
    receivedSentTime |= host.serviceTime&0xFFFF0000;
    if ((receivedSentTime&0x8000) > (host.serviceTime&0x8000)) receivedSentTime -= 0x10000;

    if (ENET_TIME_LESS(host.serviceTime, receivedSentTime)) return 0;

    peer.lastReceiveTime = host.serviceTime;
    peer.earliestTimeout = 0;

    roundTripTime = ENET_TIME_DIFFERENCE(host.serviceTime, receivedSentTime);

    enet_peer_throttle(peer, roundTripTime);

    peer.roundTripTimeVariance -= peer.roundTripTimeVariance/4;

    if (roundTripTime >= peer.roundTripTime) {
       peer.roundTripTime += (roundTripTime-peer.roundTripTime)/8;
       peer.roundTripTimeVariance += (roundTripTime-peer.roundTripTime)/4;
    } else {
       peer.roundTripTime -= (peer.roundTripTime-roundTripTime)/8;
       peer.roundTripTimeVariance += (peer.roundTripTime-roundTripTime)/4;
    }

    if (peer.roundTripTime < peer.lowestRoundTripTime) peer.lowestRoundTripTime = peer.roundTripTime;

    if (peer.roundTripTimeVariance > peer.highestRoundTripTimeVariance) peer.highestRoundTripTimeVariance = peer.roundTripTimeVariance;

    if (peer.packetThrottleEpoch == 0 || ENET_TIME_DIFFERENCE(host.serviceTime, peer.packetThrottleEpoch) >= peer.packetThrottleInterval) {
      peer.lastRoundTripTime = peer.lowestRoundTripTime;
      peer.lastRoundTripTimeVariance = peer.highestRoundTripTimeVariance;
      peer.lowestRoundTripTime = peer.roundTripTime;
      peer.highestRoundTripTimeVariance = peer.roundTripTimeVariance;
      peer.packetThrottleEpoch = host.serviceTime;
    }

    receivedReliableSequenceNumber = ENET_NET_TO_HOST_16(command.acknowledge.receivedReliableSequenceNumber);

    commandNumber = enet_protocol_remove_sent_reliable_command(peer, cast(ushort)receivedReliableSequenceNumber, command.header.channelID);

    switch (peer.state) {
      case ENET_PEER_STATE_ACKNOWLEDGING_CONNECT:
        if (commandNumber != ENET_PROTOCOL_COMMAND_VERIFY_CONNECT) return -1;
        enet_protocol_notify_connect (host, peer, event);
        break;
      case ENET_PEER_STATE_DISCONNECTING:
        if (commandNumber != ENET_PROTOCOL_COMMAND_DISCONNECT) return -1;
        enet_protocol_notify_disconnect (host, peer, event);
        break;
      case ENET_PEER_STATE_DISCONNECT_LATER:
        if (enet_list_empty (&peer.outgoingReliableCommands) && enet_list_empty(&peer.outgoingUnreliableCommands) && enet_list_empty(&peer.sentReliableCommands)) {
          enet_peer_disconnect(peer, peer.eventData);
        }
        break;
      default:
        break;
    }

    return 0;
  }


  private int enet_protocol_handle_verify_connect (ENetHost* host, ENetEvent* event, ENetPeer* peer, const ENetProtocol* command) {
    enet_uint32 mtu, windowSize;
    usize channelCount;

    if (peer.state != ENET_PEER_STATE_CONNECTING) return 0;

    channelCount = ENET_NET_TO_HOST_32(command.verifyConnect.channelCount);

    if (channelCount < ENET_PROTOCOL_MINIMUM_CHANNEL_COUNT || channelCount > ENET_PROTOCOL_MAXIMUM_CHANNEL_COUNT ||
        ENET_NET_TO_HOST_32 (command.verifyConnect.packetThrottleInterval) != peer.packetThrottleInterval ||
        ENET_NET_TO_HOST_32 (command.verifyConnect.packetThrottleAcceleration) != peer.packetThrottleAcceleration ||
        ENET_NET_TO_HOST_32 (command.verifyConnect.packetThrottleDeceleration) != peer.packetThrottleDeceleration ||
        command.verifyConnect.connectID != peer.connectID)
    {
      peer.eventData = 0;
      enet_protocol_dispatch_state(host, peer, ENET_PEER_STATE_ZOMBIE);
      return -1;
    }

    enet_protocol_remove_sent_reliable_command(peer, 1, 0xFF);

    if (channelCount < peer.channelCount) peer.channelCount = channelCount;

    peer.outgoingPeerID = ENET_NET_TO_HOST_16(command.verifyConnect.outgoingPeerID);
    peer.incomingSessionID = command.verifyConnect.incomingSessionID;
    peer.outgoingSessionID = command.verifyConnect.outgoingSessionID;

    mtu = ENET_NET_TO_HOST_32(command.verifyConnect.mtu);

    if (mtu < ENET_PROTOCOL_MINIMUM_MTU) mtu = ENET_PROTOCOL_MINIMUM_MTU;
    else if (mtu > ENET_PROTOCOL_MAXIMUM_MTU) mtu = ENET_PROTOCOL_MAXIMUM_MTU;

    if (mtu < peer.mtu) peer.mtu = mtu;

    windowSize = ENET_NET_TO_HOST_32(command.verifyConnect.windowSize);

    if (windowSize < ENET_PROTOCOL_MINIMUM_WINDOW_SIZE) windowSize = ENET_PROTOCOL_MINIMUM_WINDOW_SIZE;
    if (windowSize > ENET_PROTOCOL_MAXIMUM_WINDOW_SIZE) windowSize = ENET_PROTOCOL_MAXIMUM_WINDOW_SIZE;
    if (windowSize < peer.windowSize) peer.windowSize = windowSize;

    peer.incomingBandwidth = ENET_NET_TO_HOST_32(command.verifyConnect.incomingBandwidth);
    peer.outgoingBandwidth = ENET_NET_TO_HOST_32(command.verifyConnect.outgoingBandwidth);

    enet_protocol_notify_connect(host, peer, event);

    return 0;
  }


  private int enet_protocol_handle_incoming_commands (ENetHost* host, ENetEvent* event) {
    ENetProtocolHeader* header;
    ENetProtocol* command;
    ENetPeer* peer;
    enet_uint8* currentData;
    usize headerSize;
    enet_uint16 peerID, flags;
    enet_uint8 sessionID;

    if (host.receivedDataLength < cast(usize)&(cast(ENetProtocolHeader*)0).sentTime) return 0; //k8:???

    header = cast(ENetProtocolHeader*)host.receivedData;

    peerID = ENET_NET_TO_HOST_16(header.peerID);
    sessionID = (peerID&ENET_PROTOCOL_HEADER_SESSION_MASK)>>ENET_PROTOCOL_HEADER_SESSION_SHIFT;
    flags = peerID&ENET_PROTOCOL_HEADER_FLAG_MASK;
    peerID &= ~(ENET_PROTOCOL_HEADER_FLAG_MASK|ENET_PROTOCOL_HEADER_SESSION_MASK);

    headerSize = (flags&ENET_PROTOCOL_HEADER_FLAG_SENT_TIME ? ENetProtocolHeader.sizeof : cast(usize)&(cast(ENetProtocolHeader*)0).sentTime);
    if (host.checksum !is null) headerSize += enet_uint32.sizeof;

    if (peerID == ENET_PROTOCOL_MAXIMUM_PEER_ID) {
      peer = null;
    } else if (peerID >= host.peerCount) {
      return 0;
    } else {
      peer = &host.peers[peerID];
      if (peer.state == ENET_PEER_STATE_DISCONNECTED ||
          peer.state == ENET_PEER_STATE_ZOMBIE ||
          ((host.receivedAddress.host != peer.address.host ||
            host.receivedAddress.port != peer.address.port) && peer.address.host != ENET_HOST_BROADCAST) ||
           (peer.outgoingPeerID < ENET_PROTOCOL_MAXIMUM_PEER_ID && sessionID != peer.incomingSessionID))
        return 0;
    }

    if (flags&ENET_PROTOCOL_HEADER_FLAG_COMPRESSED) {
      usize originalSize;
      if (host.compressor.context is null || host.compressor.decompress is null) return 0;

      originalSize = host.compressor.decompress(host.compressor.context,
                                    host.receivedData+headerSize,
                                    host.receivedDataLength-headerSize,
                                    host.packetData.ptr[1].ptr+headerSize,
                                    host.packetData.ptr[1].sizeof-headerSize);
      if (originalSize <= 0 || originalSize > host.packetData.ptr[1].sizeof-headerSize) return 0;

      import core.stdc.string : memcpy;
      memcpy(host.packetData.ptr[1].ptr, header, headerSize);
      host.receivedData = host.packetData.ptr[1].ptr;
      host.receivedDataLength = headerSize+originalSize;
    }

    if (host.checksum !is null) {
      enet_uint32* checksum = cast(enet_uint32*)&host.receivedData[headerSize-enet_uint32.sizeof];
      enet_uint32 desiredChecksum = *checksum;
      ENetBuffer buffer;

      *checksum = (peer !is null ? peer.connectID : 0);

      buffer.data = host.receivedData;
      buffer.dataLength = host.receivedDataLength;

      if (host.checksum(&buffer, 1) != desiredChecksum) return 0;
    }

    if (peer !is null) {
      peer.address.host = host.receivedAddress.host;
      peer.address.port = host.receivedAddress.port;
      peer.incomingDataTotal += host.receivedDataLength;
    }

    currentData = host.receivedData+headerSize;

    while (currentData < &host.receivedData[host.receivedDataLength]) {
      enet_uint8 commandNumber;
      usize commandSize;

      command = cast(ENetProtocol*)currentData;

      if (currentData+ENetProtocolCommandHeader.sizeof > &host.receivedData[host.receivedDataLength]) break;

      commandNumber = command.header.command&ENET_PROTOCOL_COMMAND_MASK;
      if (commandNumber >= ENET_PROTOCOL_COMMAND_COUNT) break;

      commandSize = commandSizes[commandNumber];
      if (commandSize == 0 || currentData+commandSize > &host.receivedData[host.receivedDataLength]) break;

      currentData += commandSize;

      if (peer is null && commandNumber != ENET_PROTOCOL_COMMAND_CONNECT) break;

      command.header.reliableSequenceNumber = ENET_NET_TO_HOST_16(command.header.reliableSequenceNumber);

      switch (commandNumber) {
        case ENET_PROTOCOL_COMMAND_ACKNOWLEDGE:
          if (enet_protocol_handle_acknowledge(host, event, peer, command)) goto commandError;
          break;
        case ENET_PROTOCOL_COMMAND_CONNECT:
          if (peer !is null) goto commandError;
          peer = enet_protocol_handle_connect(host, header, command);
          if (peer is null) goto commandError;
          break;
        case ENET_PROTOCOL_COMMAND_VERIFY_CONNECT:
          if (enet_protocol_handle_verify_connect(host, event, peer, command)) goto commandError;
          break;
        case ENET_PROTOCOL_COMMAND_DISCONNECT:
          if (enet_protocol_handle_disconnect(host, peer, command)) goto commandError;
          break;
        case ENET_PROTOCOL_COMMAND_PING:
          if (enet_protocol_handle_ping(host, peer, command)) goto commandError;
          break;
        case ENET_PROTOCOL_COMMAND_SEND_RELIABLE:
          if (enet_protocol_handle_send_reliable(host, peer, command, &currentData)) goto commandError;
          break;
        case ENET_PROTOCOL_COMMAND_SEND_UNRELIABLE:
          if (enet_protocol_handle_send_unreliable(host, peer, command, &currentData)) goto commandError;
          break;
        case ENET_PROTOCOL_COMMAND_SEND_UNSEQUENCED:
          if (enet_protocol_handle_send_unsequenced(host, peer, command, &currentData)) goto commandError;
          break;
        case ENET_PROTOCOL_COMMAND_SEND_FRAGMENT:
          if (enet_protocol_handle_send_fragment(host, peer, command, &currentData)) goto commandError;
          break;
        case ENET_PROTOCOL_COMMAND_BANDWIDTH_LIMIT:
          if (enet_protocol_handle_bandwidth_limit(host, peer, command)) goto commandError;
          break;
        case ENET_PROTOCOL_COMMAND_THROTTLE_CONFIGURE:
          if (enet_protocol_handle_throttle_configure(host, peer, command)) goto commandError;
          break;
        case ENET_PROTOCOL_COMMAND_SEND_UNRELIABLE_FRAGMENT:
          if (enet_protocol_handle_send_unreliable_fragment(host, peer, command, &currentData)) goto commandError;
          break;
        default:
          goto commandError;
      }

      if (peer !is null && (command.header.command&ENET_PROTOCOL_COMMAND_FLAG_ACKNOWLEDGE) != 0) {
        enet_uint16 sentTime;

        if (!(flags&ENET_PROTOCOL_HEADER_FLAG_SENT_TIME)) break;
        sentTime = ENET_NET_TO_HOST_16 (header.sentTime);
        switch (peer.state) {
          case ENET_PEER_STATE_DISCONNECTING:
          case ENET_PEER_STATE_ACKNOWLEDGING_CONNECT:
          case ENET_PEER_STATE_DISCONNECTED:
          case ENET_PEER_STATE_ZOMBIE:
            break;
          case ENET_PEER_STATE_ACKNOWLEDGING_DISCONNECT:
            if ((command.header.command&ENET_PROTOCOL_COMMAND_MASK) == ENET_PROTOCOL_COMMAND_DISCONNECT) {
              enet_peer_queue_acknowledgement(peer, command, sentTime);
            }
            break;
          default:
            enet_peer_queue_acknowledgement(peer, command, sentTime);
            break;
        }
      }
    }

  commandError:
    if (event !is null && event.type != ENET_EVENT_TYPE_NONE) return 1;
    return 0;
  }


  private int enet_protocol_receive_incoming_commands (ENetHost* host, ENetEvent* event) {
    for (int packets = 0; packets < 256; ++packets) {
      int receivedLength;
      ENetBuffer buffer;
      buffer.data = host.packetData.ptr[0].ptr;
      buffer.dataLength = host.packetData.ptr[0].sizeof;
      receivedLength = enet_socket_receive(host.socket, &host.receivedAddress, &buffer, 1);
      if (receivedLength < 0) return -1;
      if (receivedLength == 0) return 0;
      host.receivedData = host.packetData.ptr[0].ptr;
      host.receivedDataLength = receivedLength;
      host.totalReceivedData += receivedLength;
      ++host.totalReceivedPackets;
      if (host.intercept !is null) {
        switch (host.intercept(host, event)) {
          case 1:
            if (event !is null && event.type != ENET_EVENT_TYPE_NONE) return 1;
            continue;
          case -1:
            return -1;
          default:
            break;
         }
      }
      switch (enet_protocol_handle_incoming_commands(host, event)) {
        case 1: return 1;
        case -1: return -1;
        default: break;
      }
    }
    return -1;
  }


  private void enet_protocol_send_acknowledgements (ENetHost* host, ENetPeer* peer) {
    ENetProtocol* command = &host.commands.ptr[host.commandCount];
    ENetBuffer* buffer = &host.buffers.ptr[host.bufferCount];
    ENetAcknowledgement* acknowledgement;
    ENetListIterator currentAcknowledgement;
    enet_uint16 reliableSequenceNumber;

    currentAcknowledgement = enet_list_begin(&peer.acknowledgements);

    while (currentAcknowledgement != enet_list_end(&peer.acknowledgements)) {
      if (command >= &host.commands.ptr[host.commands.sizeof/ENetProtocol.sizeof] ||
          buffer >= &host.buffers.ptr[host.buffers.sizeof/ENetBuffer.sizeof] ||
          peer.mtu-host.packetSize < ENetProtocolAcknowledge.sizeof)
      {
        host.continueSending = 1;
        break;
      }

      acknowledgement = cast(ENetAcknowledgement*)currentAcknowledgement;

      currentAcknowledgement = enet_list_next(currentAcknowledgement);

      buffer.data = command;
      buffer.dataLength = ENetProtocolAcknowledge.sizeof;

      host.packetSize += buffer.dataLength;

      reliableSequenceNumber = ENET_HOST_TO_NET_16(acknowledgement.command.header.reliableSequenceNumber);

      command.header.command = ENET_PROTOCOL_COMMAND_ACKNOWLEDGE;
      command.header.channelID = acknowledgement.command.header.channelID;
      command.header.reliableSequenceNumber = reliableSequenceNumber;
      command.acknowledge.receivedReliableSequenceNumber = reliableSequenceNumber;
      command.acknowledge.receivedSentTime = ENET_HOST_TO_NET_16(cast(ushort)acknowledgement.sentTime);

      if ((acknowledgement.command.header.command&ENET_PROTOCOL_COMMAND_MASK) == ENET_PROTOCOL_COMMAND_DISCONNECT) {
        enet_protocol_dispatch_state(host, peer, ENET_PEER_STATE_ZOMBIE);
      }

      enet_list_remove(&acknowledgement.acknowledgementList);
      enet_free(acknowledgement);

      ++command;
      ++buffer;
    }

    host.commandCount = command-host.commands.ptr;
    host.bufferCount = buffer-host.buffers.ptr;
  }


  private void enet_protocol_send_unreliable_outgoing_commands (ENetHost* host, ENetPeer* peer) {
    ENetProtocol* command = &host.commands.ptr[host.commandCount];
    ENetBuffer* buffer = &host.buffers.ptr[host.bufferCount];
    ENetOutgoingCommand * outgoingCommand;
    ENetListIterator currentCommand;

    currentCommand = enet_list_begin(&peer.outgoingUnreliableCommands);

    while (currentCommand != enet_list_end(&peer.outgoingUnreliableCommands)) {
      usize commandSize;

      outgoingCommand = cast(ENetOutgoingCommand*)currentCommand;
      commandSize = commandSizes[outgoingCommand.command.header.command&ENET_PROTOCOL_COMMAND_MASK];

      if (command >= &host.commands.ptr[host.commands.sizeof/ENetProtocol.sizeof] ||
          buffer+1 >= &host.buffers.ptr[host.buffers.sizeof/ENetBuffer.sizeof] ||
          peer.mtu-host.packetSize < commandSize ||
          (outgoingCommand.packet !is null && peer.mtu-host.packetSize < commandSize+outgoingCommand.fragmentLength))
      {
        host.continueSending = 1;
        break;
      }

      currentCommand = enet_list_next(currentCommand);

      if (outgoingCommand.packet !is null && outgoingCommand.fragmentOffset == 0) {
        peer.packetThrottleCounter += ENET_PEER_PACKET_THROTTLE_COUNTER;
        peer.packetThrottleCounter %= ENET_PEER_PACKET_THROTTLE_SCALE;
        if (peer.packetThrottleCounter > peer.packetThrottle) {
          enet_uint16 reliableSequenceNumber = outgoingCommand.reliableSequenceNumber;
          enet_uint16 unreliableSequenceNumber = outgoingCommand.unreliableSequenceNumber;
          for (;;) {
            --outgoingCommand.packet.referenceCount;

            if (outgoingCommand.packet.referenceCount == 0) enet_packet_destroy(outgoingCommand.packet);

            enet_list_remove(&outgoingCommand.outgoingCommandList);
            enet_free(outgoingCommand);

            if (currentCommand == enet_list_end(&peer.outgoingUnreliableCommands)) break;

            outgoingCommand = cast(ENetOutgoingCommand*)currentCommand;
            if (outgoingCommand.reliableSequenceNumber != reliableSequenceNumber ||
                outgoingCommand.unreliableSequenceNumber != unreliableSequenceNumber)
              break;

            currentCommand = enet_list_next(currentCommand);
          }
          continue;
        }
      }

      buffer.data = command;
      buffer.dataLength = commandSize;

      host.packetSize += buffer.dataLength;

      *command = outgoingCommand.command;

      enet_list_remove(&outgoingCommand.outgoingCommandList);

      if (outgoingCommand.packet !is null) {
        ++buffer;

        buffer.data = outgoingCommand.packet.data+outgoingCommand.fragmentOffset;
        buffer.dataLength = outgoingCommand.fragmentLength;

        host.packetSize += buffer.dataLength;

        enet_list_insert(enet_list_end(&peer.sentUnreliableCommands), outgoingCommand);
      } else {
        enet_free(outgoingCommand);
      }

      ++command;
      ++buffer;
    }

    host.commandCount = command-host.commands.ptr;
    host.bufferCount = buffer-host.buffers.ptr;

    if (peer.state == ENET_PEER_STATE_DISCONNECT_LATER && enet_list_empty(&peer.outgoingReliableCommands) &&
        enet_list_empty(&peer.outgoingUnreliableCommands) && enet_list_empty(&peer.sentReliableCommands))
    {
      enet_peer_disconnect(peer, peer.eventData);
    }
  }


  private int enet_protocol_check_timeouts (ENetHost* host, ENetPeer* peer, ENetEvent* event) {
    ENetOutgoingCommand* outgoingCommand;
    ENetListIterator currentCommand, insertPosition;

    currentCommand = enet_list_begin(&peer.sentReliableCommands);
    insertPosition = enet_list_begin(&peer.outgoingReliableCommands);

    while (currentCommand != enet_list_end(&peer.sentReliableCommands)) {
      outgoingCommand = cast(ENetOutgoingCommand*)currentCommand;

      currentCommand = enet_list_next(currentCommand);

      if (ENET_TIME_DIFFERENCE(host.serviceTime, outgoingCommand.sentTime) < outgoingCommand.roundTripTimeout) continue;

      if (peer.earliestTimeout == 0 || ENET_TIME_LESS(outgoingCommand.sentTime, peer.earliestTimeout)) {
        peer.earliestTimeout = outgoingCommand.sentTime;
      }

      if (peer.earliestTimeout != 0 && (ENET_TIME_DIFFERENCE(host.serviceTime, peer.earliestTimeout) >= peer.timeoutMaximum ||
          (outgoingCommand.roundTripTimeout >= outgoingCommand.roundTripTimeoutLimit && ENET_TIME_DIFFERENCE(host.serviceTime, peer.earliestTimeout) >= peer.timeoutMinimum)))
      {
        enet_protocol_notify_disconnect(host, peer, event);
        return 1;
      }

      if (outgoingCommand.packet !is null) peer.reliableDataInTransit -= outgoingCommand.fragmentLength;

      ++peer.packetsLost;

      outgoingCommand.roundTripTimeout *= 2;

      enet_list_insert(insertPosition, enet_list_remove(&outgoingCommand.outgoingCommandList));

      if (currentCommand == enet_list_begin(&peer.sentReliableCommands) && !enet_list_empty(&peer.sentReliableCommands)) {
        outgoingCommand = cast(ENetOutgoingCommand*)currentCommand;
        peer.nextTimeout = outgoingCommand.sentTime+outgoingCommand.roundTripTimeout;
      }
    }

    return 0;
  }


  private int enet_protocol_send_reliable_outgoing_commands (ENetHost* host, ENetPeer* peer) @nogc {
    ENetProtocol* command = &host.commands.ptr[host.commandCount];
    ENetBuffer* buffer = &host.buffers.ptr[host.bufferCount];
    ENetOutgoingCommand* outgoingCommand;
    ENetListIterator currentCommand;
    ENetChannel* channel;
    enet_uint16 reliableWindow;
    usize commandSize;
    int windowExceeded = 0, windowWrap = 0, canPing = 1;

    currentCommand = enet_list_begin(&peer.outgoingReliableCommands);
    while (currentCommand != enet_list_end(&peer.outgoingReliableCommands)) {
      outgoingCommand = cast(ENetOutgoingCommand*)currentCommand;
      channel = (outgoingCommand.command.header.channelID < peer.channelCount ? &peer.channels[outgoingCommand.command.header.channelID] : null);
      reliableWindow = outgoingCommand.reliableSequenceNumber/ENET_PEER_RELIABLE_WINDOW_SIZE;

      if (channel !is null) {
        if (!windowWrap && outgoingCommand.sendAttempts < 1 && !(outgoingCommand.reliableSequenceNumber%ENET_PEER_RELIABLE_WINDOW_SIZE) &&
            (channel.reliableWindows[(reliableWindow+ENET_PEER_RELIABLE_WINDOWS-1)%ENET_PEER_RELIABLE_WINDOWS] >= ENET_PEER_RELIABLE_WINDOW_SIZE ||
             channel.usedReliableWindows&(
               (((1<<ENET_PEER_FREE_RELIABLE_WINDOWS)-1)<<reliableWindow)|
               (((1<<ENET_PEER_FREE_RELIABLE_WINDOWS)-1)>>(ENET_PEER_RELIABLE_WINDOWS-reliableWindow)))))
        {
          windowWrap = 1;
        }
        if (windowWrap) {
          currentCommand = enet_list_next(currentCommand);
          continue;
        }
      }

      if (outgoingCommand.packet !is null) {
        if (!windowExceeded) {
          enet_uint32 windowSize = (peer.packetThrottle*peer.windowSize)/ENET_PEER_PACKET_THROTTLE_SCALE;
          if (peer.reliableDataInTransit+outgoingCommand.fragmentLength > ENET_MAX(windowSize, peer.mtu)) windowExceeded = 1;
         }
         if (windowExceeded) {
           currentCommand = enet_list_next(currentCommand);
           continue;
         }
      }

      canPing = 0;

      commandSize = commandSizes[outgoingCommand.command.header.command&ENET_PROTOCOL_COMMAND_MASK];

      if (command >= &host.commands.ptr[host.commands.sizeof/ENetProtocol.sizeof] ||
          buffer+1 >= &host.buffers.ptr[host.buffers.sizeof/ENetBuffer.sizeof] ||
          peer.mtu-host.packetSize < commandSize ||
          (outgoingCommand.packet !is null && cast(enet_uint16)(peer.mtu-host.packetSize) < cast(enet_uint16)(commandSize+outgoingCommand.fragmentLength)))
      {
        host.continueSending = 1;
        break;
      }

      currentCommand = enet_list_next(currentCommand);

      if (channel !is null && outgoingCommand.sendAttempts < 1) {
        channel.usedReliableWindows |= 1<<reliableWindow;
        ++channel.reliableWindows[reliableWindow];
      }

      ++outgoingCommand.sendAttempts;

      if (outgoingCommand.roundTripTimeout == 0) {
        outgoingCommand.roundTripTimeout = peer.roundTripTime+4*peer.roundTripTimeVariance;
        outgoingCommand.roundTripTimeoutLimit = peer.timeoutLimit*outgoingCommand.roundTripTimeout;
      }

      if (enet_list_empty(&peer.sentReliableCommands)) peer.nextTimeout = host.serviceTime+outgoingCommand.roundTripTimeout;

      enet_list_insert(enet_list_end(&peer.sentReliableCommands), enet_list_remove(&outgoingCommand.outgoingCommandList));

      outgoingCommand.sentTime = host.serviceTime;

      buffer.data = command;
      buffer.dataLength = commandSize;

      host.packetSize += buffer.dataLength;
      host.headerFlags |= ENET_PROTOCOL_HEADER_FLAG_SENT_TIME;

      *command = outgoingCommand.command;

      if (outgoingCommand.packet !is null) {
        ++buffer;

        buffer.data = outgoingCommand.packet.data+outgoingCommand.fragmentOffset;
        buffer.dataLength = outgoingCommand.fragmentLength;

        host.packetSize += outgoingCommand.fragmentLength;

        peer.reliableDataInTransit += outgoingCommand.fragmentLength;
      }

      ++peer.packetsSent;

      ++command;
      ++buffer;
    }

    host.commandCount = command-host.commands.ptr;
    host.bufferCount = buffer-host.buffers.ptr;

    return canPing;
  }


  private int enet_protocol_send_outgoing_commands (ENetHost* host, ENetEvent* event, int checkForTimeouts) {
    enet_uint8[ENetProtocolHeader.sizeof+enet_uint32.sizeof] headerData;
    ENetProtocolHeader* header = cast(ENetProtocolHeader*)headerData;
    ENetPeer* currentPeer;
    int sentLength;
    usize shouldCompress = 0;

    host.continueSending = 1;

    while (host.continueSending) {
      for (host.continueSending = 0, currentPeer = host.peers; currentPeer < &host.peers[host.peerCount]; ++currentPeer) {
        if (currentPeer.state == ENET_PEER_STATE_DISCONNECTED || currentPeer.state == ENET_PEER_STATE_ZOMBIE) continue;

        host.headerFlags = 0;
        host.commandCount = 0;
        host.bufferCount = 1;
        host.packetSize = ENetProtocolHeader.sizeof;

        if (!enet_list_empty(&currentPeer.acknowledgements)) enet_protocol_send_acknowledgements(host, currentPeer);

        if (checkForTimeouts != 0 && !enet_list_empty(&currentPeer.sentReliableCommands) && ENET_TIME_GREATER_EQUAL(host.serviceTime, currentPeer.nextTimeout) &&
            enet_protocol_check_timeouts(host, currentPeer, event) == 1)
        {
          if (event !is null && event.type != ENET_EVENT_TYPE_NONE) return 1;
          continue;
        }

        if ((enet_list_empty(&currentPeer.outgoingReliableCommands) || enet_protocol_send_reliable_outgoing_commands(host, currentPeer)) &&
            enet_list_empty(&currentPeer.sentReliableCommands) && ENET_TIME_DIFFERENCE(host.serviceTime, currentPeer.lastReceiveTime) >= currentPeer.pingInterval &&
            currentPeer.mtu-host.packetSize >= ENetProtocolPing.sizeof)
        {
          enet_peer_ping(currentPeer);
          enet_protocol_send_reliable_outgoing_commands(host, currentPeer);
        }

        if (!enet_list_empty(&currentPeer.outgoingUnreliableCommands)) enet_protocol_send_unreliable_outgoing_commands (host, currentPeer);

        if (host.commandCount == 0) continue;

        if (currentPeer.packetLossEpoch == 0) {
          currentPeer.packetLossEpoch = host.serviceTime;
        } else if (ENET_TIME_DIFFERENCE(host.serviceTime, currentPeer.packetLossEpoch) >= ENET_PEER_PACKET_LOSS_INTERVAL && currentPeer.packetsSent > 0) {
          enet_uint32 packetLoss = currentPeer.packetsLost * ENET_PEER_PACKET_LOSS_SCALE / currentPeer.packetsSent;

          version(enet_debug) {
            import core.stdc.stdio : printf;
            printf("peer %u: %f%%+-%f%% packet loss, %u+-%u ms round trip time, %f%% throttle, %u/%u outgoing, %u/%u incoming\n",
              currentPeer.incomingPeerID, currentPeer.packetLoss/cast(float)ENET_PEER_PACKET_LOSS_SCALE, currentPeer.packetLossVariance/cast(float)ENET_PEER_PACKET_LOSS_SCALE,
              currentPeer.roundTripTime, currentPeer.roundTripTimeVariance, currentPeer.packetThrottle/cast(float)ENET_PEER_PACKET_THROTTLE_SCALE,
              enet_list_size(&currentPeer.outgoingReliableCommands), enet_list_size(&currentPeer.outgoingUnreliableCommands),
              (currentPeer.channels !is null ? enet_list_size(&currentPeer.channels.incomingReliableCommands) : 0),
              (currentPeer.channels !is null ? enet_list_size(&currentPeer.channels.incomingUnreliableCommands) : 0));
          }

          currentPeer.packetLossVariance -= currentPeer.packetLossVariance/4;

          if (packetLoss >= currentPeer.packetLoss) {
            currentPeer.packetLoss += (packetLoss - currentPeer.packetLoss)/8;
            currentPeer.packetLossVariance += (packetLoss-currentPeer.packetLoss)/4;
          } else {
            currentPeer.packetLoss -= (currentPeer.packetLoss-packetLoss)/8;
            currentPeer.packetLossVariance += (currentPeer.packetLoss-packetLoss)/4;
          }

          currentPeer.packetLossEpoch = host.serviceTime;
          currentPeer.packetsSent = 0;
          currentPeer.packetsLost = 0;
        }

        host.buffers.ptr[0].data = headerData.ptr;
        if (host.headerFlags&ENET_PROTOCOL_HEADER_FLAG_SENT_TIME) {
          header.sentTime = ENET_HOST_TO_NET_16(host.serviceTime&0xFFFF);
          host.buffers.ptr[0].dataLength = ENetProtocolHeader.sizeof;
        } else {
          host.buffers.ptr[0].dataLength = cast(usize)&(cast(ENetProtocolHeader*)0).sentTime;
        }

        shouldCompress = 0;
        if (host.compressor.context !is null && host.compressor.compress !is null) {
          usize originalSize = host.packetSize-ENetProtocolHeader.sizeof;
          usize compressedSize = host.compressor.compress(host.compressor.context, &host.buffers.ptr[1], host.bufferCount-1, originalSize, host.packetData.ptr[1].ptr, originalSize);
          if (compressedSize > 0 && compressedSize < originalSize) {
            host.headerFlags |= ENET_PROTOCOL_HEADER_FLAG_COMPRESSED;
            shouldCompress = compressedSize;
            version(enet_debug_compress) {
              import core.stdc.stdio : printf;
              printf("peer %u: compressed %u.%u (%u%%)\n", currentPeer.incomingPeerID, originalSize, compressedSize, (compressedSize*100)/originalSize);
            }
          }
        }

        if (currentPeer.outgoingPeerID < ENET_PROTOCOL_MAXIMUM_PEER_ID) host.headerFlags |= currentPeer.outgoingSessionID<<ENET_PROTOCOL_HEADER_SESSION_SHIFT;
        header.peerID = ENET_HOST_TO_NET_16(currentPeer.outgoingPeerID|host.headerFlags);
        if (host.checksum !is null) {
          enet_uint32* checksum = cast(enet_uint32*)&headerData[host.buffers.ptr[0].dataLength];
          *checksum = (currentPeer.outgoingPeerID < ENET_PROTOCOL_MAXIMUM_PEER_ID ? currentPeer.connectID : 0);
          host.buffers.ptr[0].dataLength += enet_uint32.sizeof;
          *checksum = host.checksum(host.buffers.ptr, host.bufferCount);
        }

        if (shouldCompress > 0) {
          host.buffers.ptr[1].data = host.packetData.ptr[1].ptr;
          host.buffers.ptr[1].dataLength = shouldCompress;
          host.bufferCount = 2;
        }

        currentPeer.lastSendTime = host.serviceTime;

        sentLength = enet_socket_send(host.socket, &currentPeer.address, host.buffers.ptr, host.bufferCount);

        enet_protocol_remove_sent_unreliable_commands(currentPeer);

        if (sentLength < 0) return -1;

        host.totalSentData += sentLength;
        ++host.totalSentPackets;
      }
    }

    return 0;
  }


  /** Sends any queued packets on the host specified to its designated peers.
   *
   * Params:
   *  host = host to flush
   *
   * Remarks:
   *  this function need only be used in circumstances where one wishes to send queued packets earlier than in a call to enet_host_service().
   */
  void enet_host_flush (ENetHost* host) {
    host.serviceTime = enet_time_get();
    enet_protocol_send_outgoing_commands(host, null, 0);
  }


  /** Checks for any queued events on the host and dispatches one if available.
   *
   * Params:
   *  host = host to check for events
   *  event = an event structure where event details will be placed if available
   *
   * Returns:
   *  > 0 if an event was dispatched, 0 if no events are available, < 0 on failure
   */
  int enet_host_check_events (ENetHost* host, ENetEvent* event) {
    if (event is null) return -1;
    event.type = ENET_EVENT_TYPE_NONE;
    event.peer = null;
    event.packet = null;
    return enet_protocol_dispatch_incoming_commands(host, event);
  }


  /** Waits for events on the host specified and shuttles packets between
   * the host and its peers.
   *
   * Params:
   *  host = host to service
   *  event = an event structure where event details will be placed if one occurs
   *          if event is null then no events will be delivered
   *  timeout = number of milliseconds that ENet should wait for events
   *
   * Returns:
   * > 0 if an event occurred within the specified time limit, 0 if no event occurred, < 0 on failure
   *
   * Remarks:
   *  enet_host_service should be called fairly regularly for adequate performance
   */
  int enet_host_service (ENetHost* host, ENetEvent* event, enet_uint32 timeout) {
    enet_uint32 waitCondition;

    if (event !is null) {
      event.type = ENET_EVENT_TYPE_NONE;
      event.peer = null;
      event.packet = null;
      switch (enet_protocol_dispatch_incoming_commands(host, event)) {
        case 1: return 1;
        case -1: version(enet_debug) { import core.stdc.stdio : perror; perror("Error dispatching incoming packets"); } return -1;
        default: break;
      }
    }

    host.serviceTime = enet_time_get();
    timeout += host.serviceTime;
    do {
      if (ENET_TIME_DIFFERENCE(host.serviceTime, host.bandwidthThrottleEpoch) >= ENET_HOST_BANDWIDTH_THROTTLE_INTERVAL) enet_host_bandwidth_throttle(host);
      switch (enet_protocol_send_outgoing_commands(host, event, 1)) {
        case 1: return 1;
        case -1:version(enet_debug) { import core.stdc.stdio : perror; perror("Error sending outgoing packets"); } return -1;
        default: break;
      }

      switch (enet_protocol_receive_incoming_commands(host, event)) {
        case 1: return 1;
        case -1: version(enet_debug) { import core.stdc.stdio : perror; perror("Error receiving incoming packets"); } return -1;
        default: break;
      }

      switch (enet_protocol_send_outgoing_commands(host, event, 1)) {
        case 1: return 1;
        case -1: version(enet_debug) { import core.stdc.stdio : perror; perror("Error sending outgoing packets"); } return -1;
        default: break;
      }

      if (event !is null) {
        switch (enet_protocol_dispatch_incoming_commands (host, event)) {
          case 1: return 1;
          case -1: version(enet_debug) { import core.stdc.stdio : perror; perror("Error dispatching incoming packets"); } return -1;
          default: break;
        }
      }

      if (ENET_TIME_GREATER_EQUAL(host.serviceTime, timeout)) return 0;

      do {
        host.serviceTime = enet_time_get();
        if (ENET_TIME_GREATER_EQUAL(host.serviceTime, timeout)) return 0;
        waitCondition = ENET_SOCKET_WAIT_RECEIVE|ENET_SOCKET_WAIT_INTERRUPT;
        if (enet_socket_wait(host.socket, &waitCondition, ENET_TIME_DIFFERENCE (timeout, host.serviceTime)) != 0) return -1;
      } while (waitCondition&ENET_SOCKET_WAIT_INTERRUPT);

      host.serviceTime = enet_time_get ();
    } while (waitCondition&ENET_SOCKET_WAIT_RECEIVE);

    return 0;
  }
}


// compress.c
/*
 * An adaptive order-2 PPM range coder
 */
private:
// cool helper to translate C defines
template cmacroFixVars(T...) {
  string cmacroFixVars (string s, string[] names...) {
    assert(T.length == names.length, "cmacroFixVars: names and arguments count mismatch");
    string res;
    uint pos = 0;
    // skip empty lines (for pretty printing)
    // trim trailing spaces
    while (s.length > 0 && s[$-1] <= ' ') s = s[0..$-1];
    uint linestpos = 0; // start of the current line
    while (pos < s.length) {
      if (s[pos] > ' ') break;
      if (s[pos] == '\n') linestpos = pos+1;
      ++pos;
    }
    pos = linestpos;
    while (pos+2 < s.length) {
      int epos = pos;
      while (epos+2 < s.length && (s[epos] != '$' || s[epos+1] != '{')) ++epos;
      if (epos > pos) {
        if (s.length-epos < 3) break;
        res ~= s[pos..epos];
        pos = epos;
      }
      assert(s[pos] == '$' && s[pos+1] == '{');
      bool ascode = (pos > 0 && s[pos-1] == '$');
      pos += 2;
      bool found = false;
      if (ascode) res = res[0..$-1]; // remove dollar
      foreach (immutable nidx, string oname; T) {
        static assert(oname.length > 0);
        if (s.length-pos >= oname.length+1 && s[pos+oname.length] == '}' && s[pos..pos+oname.length] == oname) {
          found = true;
          pos += oname.length+1;
          if (ascode) {
            bool hasbang = false;
            foreach (immutable char ch; names[nidx]) {
              if (ch == '{') break;
              if (ch == '!') { hasbang = true; break; }
            }
            if (hasbang) res ~= "mixin("~names[nidx]~")"; else res ~= names[nidx];
            if (names[nidx][$-1] != '}') res ~= ";";
          } else {
            res ~= names[nidx];
          }
          break;
        }
      }
      assert(found, "unknown variable in macro");
    }
    if (pos < s.length) res ~= s[pos..$];
    return res;
  }
}


struct ENetSymbol {
  /* binary indexed tree of symbols */
  enet_uint8 value;
  enet_uint8 count;
  enet_uint16 under;
  enet_uint16 left, right;

  /* context defined by this symbol */
  enet_uint16 symbols;
  enet_uint16 escapes;
  enet_uint16 total;
  enet_uint16 parent;
}

/* adaptation constants tuned aggressively for small packet sizes rather than large file compression */
enum {
  ENET_RANGE_CODER_TOP    = 1<<24,
  ENET_RANGE_CODER_BOTTOM = 1<<16,

  ENET_CONTEXT_SYMBOL_DELTA = 3,
  ENET_CONTEXT_SYMBOL_MINIMUM = 1,
  ENET_CONTEXT_ESCAPE_MINIMUM = 1,

  ENET_SUBCONTEXT_ORDER = 2,
  ENET_SUBCONTEXT_SYMBOL_DELTA = 2,
  ENET_SUBCONTEXT_ESCAPE_DELTA = 5
}

/* context exclusion roughly halves compression speed, so disable for now (k8: and i removed it's code) */

struct ENetRangeCoder {
  /* only allocate enough symbols for reasonable MTUs, would need to be larger for large file compression */
  ENetSymbol[4096] symbols;
}


public extern(C) void *enet_range_coder_create () nothrow @trusted {
  return enet_malloc(ENetRangeCoder.sizeof);
}


public extern(C) void enet_range_coder_destroy (void* context) nothrow @trusted {
  if (context !is null) enet_free(context);
}

enum ENET_SYMBOL_CREATE(string symbol, string value_, string count_) = q{{
  ${symbol} = &rangeCoder.symbols.ptr[nextSymbol++];
  ${symbol}.value = ${value_};
  ${symbol}.count = ${count_};
  ${symbol}.under = ${count_};
  ${symbol}.left = 0;
  ${symbol}.right = 0;
  ${symbol}.symbols = 0;
  ${symbol}.escapes = 0;
  ${symbol}.total = 0;
  ${symbol}.parent = 0;
}}.cmacroFixVars!("symbol", "value_", "count_")(symbol, value_, count_);

enum ENET_CONTEXT_CREATE(string context, string escapes_, string minimum) = q{{
  mixin(ENET_SYMBOL_CREATE!("${context}", "0", "0"));
  (${context}).escapes = ${escapes_};
  (${context}).total = ${escapes_}+256*${minimum};
  (${context}).symbols = 0;
}}.cmacroFixVars!("context", "escapes_", "minimum")(context, escapes_, minimum);


enet_uint16 enet_symbol_rescale (ENetSymbol* symbol) nothrow @trusted @nogc {
  enet_uint16 total = 0;
  for (;;) {
    symbol.count -= symbol.count>>1;
    symbol.under = symbol.count;
    if (symbol.left) symbol.under += enet_symbol_rescale(symbol+symbol.left);
    total += symbol.under;
    if (!symbol.right) break;
    symbol += symbol.right;
  }
  return total;
}

enum ENET_CONTEXT_RESCALE(string context, string minimum) = q{{
  (${context}).total = (${context}).symbols ? enet_symbol_rescale((${context})+(${context}).symbols) : 0;
  (${context}).escapes -= (${context}).escapes>>1;
  (${context}).total += (${context}).escapes+256*${minimum};
}}.cmacroFixVars!("context", "minimum")(context, minimum);

enum ENET_RANGE_CODER_OUTPUT(string value) = q{{
  if (outData >= outEnd) return 0;
  *outData++ = ${value};
}}.cmacroFixVars!("value")(value);

enum ENET_RANGE_CODER_ENCODE(string under, string count, string total) = q{{
  encodeRange /= (${total});
  encodeLow += (${under})*encodeRange;
  encodeRange *= (${count});
  for (;;) {
    if ((encodeLow^(encodeLow+encodeRange)) >= ENET_RANGE_CODER_TOP) {
      if (encodeRange >= ENET_RANGE_CODER_BOTTOM) break;
      encodeRange = -encodeLow&(ENET_RANGE_CODER_BOTTOM-1);
    }
    mixin(ENET_RANGE_CODER_OUTPUT!"encodeLow>>24");
    encodeRange <<= 8;
    encodeLow <<= 8;
  }
}}.cmacroFixVars!("under", "count", "total")(under, count, total);

enum ENET_RANGE_CODER_FLUSH = q{{
  while (encodeLow) {
    mixin(ENET_RANGE_CODER_OUTPUT!"encodeLow>>24");
    encodeLow <<= 8;
  }
}};

enum ENET_RANGE_CODER_FREE_SYMBOLS = q{{
  if (nextSymbol >= rangeCoder.symbols.sizeof/ENetSymbol.sizeof-ENET_SUBCONTEXT_ORDER) {
    nextSymbol = 0;
    mixin(ENET_CONTEXT_CREATE!("root", "ENET_CONTEXT_ESCAPE_MINIMUM", "ENET_CONTEXT_SYMBOL_MINIMUM"));
    predicted = 0;
    order = 0;
  }
}};

enum ENET_CONTEXT_ENCODE(string context, string symbol_, string value_, string under_, string count_, string update, string minimum) = q{{
  ${under_} = value*${minimum};
  ${count_} = ${minimum};
  if (!(${context}).symbols) {
    mixin(ENET_SYMBOL_CREATE!("${symbol_}", "${value_}", "${update}"));
    (${context}).symbols = cast(typeof((${context}).symbols))(${symbol_}-(${context}));
  } else {
    ENetSymbol* node = (${context})+(${context}).symbols;
    for (;;) {
      if (${value_} < node.value) {
        node.under += ${update};
        if (node.left) { node += node.left; continue; }
        mixin(ENET_SYMBOL_CREATE!("${symbol_}", "${value_}", "${update}"));
        node.left = cast(typeof(node.left))(${symbol_}-node);
      } else if (${value_} > node.value) {
        ${under_} += node.under;
        if (node.right) { node += node.right; continue; }
        mixin(ENET_SYMBOL_CREATE!("${symbol_}", "${value_}", "${update}"));
        node.right = cast(typeof(node.right))(${symbol_}-node);
      } else {
        ${count_} += node.count;
        ${under_} += node.under-node.count;
        node.under += ${update};
        node.count += ${update};
        ${symbol_} = node;
      }
      break;
    }
  }
}}.cmacroFixVars!("context","symbol_","value_","under_","count_","update","minimum")(context,symbol_,value_,under_,count_,update,minimum);


public extern(C) usize enet_range_coder_compress (void* context, const(ENetBuffer)* inBuffers, usize inBufferCount, usize inLimit, ubyte* outData, usize outLimit) nothrow @trusted @nogc {
  ENetRangeCoder* rangeCoder = cast(ENetRangeCoder*)context;
  ubyte* outStart = outData, outEnd = &outData[outLimit];
  const(ubyte)* inData, inEnd;
  enet_uint32 encodeLow = 0, encodeRange = ~0;
  ENetSymbol* root;
  ushort predicted = 0;
  usize order = 0, nextSymbol = 0;

  if (rangeCoder is null || inBufferCount <= 0 || inLimit <= 0) return 0;

  inData = cast(const(ubyte)*)inBuffers.data;
  inEnd = &inData[inBuffers.dataLength];
  ++inBuffers;
  --inBufferCount;

  mixin(ENET_CONTEXT_CREATE!("root", "ENET_CONTEXT_ESCAPE_MINIMUM", "ENET_CONTEXT_SYMBOL_MINIMUM"));

  for (;;) {
    ENetSymbol* subcontext, symbol;
    ubyte value;
    ushort count, under, total;
    ushort *parent = &predicted;
    if (inData >= inEnd) {
      if (inBufferCount <= 0) break;
      inData = cast(const(ubyte)*)inBuffers.data;
      inEnd = &inData[inBuffers.dataLength];
      ++inBuffers;
      --inBufferCount;
    }
    value = *inData++;

    for (subcontext = &rangeCoder.symbols.ptr[predicted]; subcontext != root; subcontext = &rangeCoder.symbols.ptr[subcontext.parent]) {
      mixin(ENET_CONTEXT_ENCODE!("subcontext", "symbol", "value", "under", "count", "ENET_SUBCONTEXT_SYMBOL_DELTA", "0"));
      *parent = cast(ushort)(symbol-rangeCoder.symbols.ptr);
      parent = &symbol.parent;
      total = subcontext.total;
      if (count > 0) {
        mixin(ENET_RANGE_CODER_ENCODE!("subcontext.escapes+under", "count", "total"));
      } else {
        if (subcontext.escapes > 0 && subcontext.escapes < total) { mixin(ENET_RANGE_CODER_ENCODE!("0", "subcontext.escapes", "total")); }
        subcontext.escapes += ENET_SUBCONTEXT_ESCAPE_DELTA;
        subcontext.total += ENET_SUBCONTEXT_ESCAPE_DELTA;
      }
      subcontext.total += ENET_SUBCONTEXT_SYMBOL_DELTA;
      if (count > 0xFF-2*ENET_SUBCONTEXT_SYMBOL_DELTA || subcontext.total > ENET_RANGE_CODER_BOTTOM-0x100) { mixin(ENET_CONTEXT_RESCALE!("subcontext", "0")); }
      if (count > 0) goto nextInput;
    }

    mixin(ENET_CONTEXT_ENCODE!("root", "symbol", "value", "under", "count", "ENET_CONTEXT_SYMBOL_DELTA", "ENET_CONTEXT_SYMBOL_MINIMUM"));
    *parent = cast(ushort)(symbol-rangeCoder.symbols.ptr);
    parent = &symbol.parent;
    total = root.total;
    mixin(ENET_RANGE_CODER_ENCODE!("root.escapes+under", "count", "total"));
    root.total += ENET_CONTEXT_SYMBOL_DELTA;
    if (count > 0xFF-2*ENET_CONTEXT_SYMBOL_DELTA+ENET_CONTEXT_SYMBOL_MINIMUM || root.total > ENET_RANGE_CODER_BOTTOM-0x100) { mixin(ENET_CONTEXT_RESCALE!("root", "ENET_CONTEXT_SYMBOL_MINIMUM")); }

  nextInput:
    if (order >= ENET_SUBCONTEXT_ORDER) {
      predicted = rangeCoder.symbols.ptr[predicted].parent;
    } else {
      ++order;
    }
    mixin(ENET_RANGE_CODER_FREE_SYMBOLS);
  }

  mixin(ENET_RANGE_CODER_FLUSH);

  return cast(usize)(outData-outStart);
}

enum ENET_RANGE_CODER_SEED = q{{
  if (inData < inEnd) decodeCode |= *inData++<<24;
  if (inData < inEnd) decodeCode |= *inData++<<16;
  if (inData < inEnd) decodeCode |= *inData++<<8;
  if (inData < inEnd) decodeCode |= *inData++;
}};

enum ENET_RANGE_CODER_READ(string total) = q{((decodeCode-decodeLow)/(decodeRange /= (${total})))}.cmacroFixVars!"total"(total);

enum ENET_RANGE_CODER_DECODE(string under, string count, string total) = q{{
  decodeLow += (${under})*decodeRange;
  decodeRange *= (${count});
  for (;;) {
    if ((decodeLow^(decodeLow+decodeRange)) >= ENET_RANGE_CODER_TOP) {
      if (decodeRange >= ENET_RANGE_CODER_BOTTOM) break;
      decodeRange = -decodeLow&(ENET_RANGE_CODER_BOTTOM-1);
    }
    decodeCode <<= 8;
    if (inData < inEnd) decodeCode |= *inData++;
    decodeRange <<= 8;
    decodeLow <<= 8;
  }
}}.cmacroFixVars!("under", "count", "total")(under, count, total);

enum ENET_CONTEXT_DECODE(string context, string symbol_, string code, string value_, string under_, string count_, string update, string minimum, string createRoot,
                         string visitNode, string createRight, string createLeft) =
q{{
  ${under_} = 0;
  ${count_} = ${minimum};
  if (!(${context}).symbols) {
    $${createRoot}
  } else {
    ENetSymbol* node = (${context})+(${context}).symbols;
    for (;;) {
      ushort after = cast(ushort)(${under_}+node.under+(node.value+1)*${minimum}), before = cast(ushort)(node.count+${minimum});
      $${visitNode}
      if (${code} >= after) {
        ${under_} += node.under;
        if (node.right) { node += node.right; continue; }
        $${createRight}
      } else if (${code} < after-before) {
        node.under += ${update};
        if (node.left) { node += node.left; continue; }
        $${createLeft}
      } else {
        ${value_} = node.value;
        ${count_} += node.count;
        ${under_} = cast(typeof(${under_}))(after-before);
        node.under += ${update};
        node.count += ${update};
        ${symbol_} = node;
      }
      break;
    }
  }
}}.cmacroFixVars!("context","symbol_","code","value_","under_","count_","update","minimum","createRoot","visitNode","createRight","createLeft")
     (context, symbol_, code, value_, under_, count_, update, minimum, createRoot, visitNode, createRight, createLeft);

enum ENET_CONTEXT_TRY_DECODE(string context, string symbol_, string code, string value_, string under_, string count_, string update, string minimum, string exclude) =
  ENET_CONTEXT_DECODE!(context, symbol_, code, value_, under_, count_, update, minimum, "return 0", exclude~"(`node.value`, `after`, `before`)", "return 0", "return 0");

enum ENET_CONTEXT_ROOT_DECODE(string context, string symbol_, string code, string value_, string under_, string count_, string update, string minimum, string exclude) =
  ENET_CONTEXT_DECODE!(context, symbol_, code, value_, under_, count_, update, minimum,
    q{{
      ${value_} = cast(typeof(${value_}))(${code}/${minimum});
      ${under_} = cast(typeof(${under_}))(${code}-${code}%${minimum});
      mixin(ENET_SYMBOL_CREATE!("${symbol_}", "${value_}", "${update}"));
      (${context}).symbols = cast(typeof((${context}).symbols))(${symbol_}-(${context}));
    }}.cmacroFixVars!("context","symbol_","code","value_","under_","count_","update","minimum","exclude")(context, symbol_, code, value_, under_, count_, update, minimum, exclude),
    exclude~"(`node.value`, `after`, `before`)",
    q{{
      ${value_} = cast(typeof(${value_}))(node.value+1+(${code}-after)/${minimum});
      ${under_} = cast(typeof(${under_}))(${code}-(${code}-after)%${minimum});
      mixin(ENET_SYMBOL_CREATE!("${symbol_}", "${value_}", "${update}"));
      node.right = cast(typeof(node.right))(${symbol_}-node);
    }}.cmacroFixVars!("context","symbol_","code","value_","under_","count_","update","minimum","exclude")(context, symbol_, code, value_, under_, count_, update, minimum, exclude),
    q{{
      ${value_} = cast(typeof(${value_}))(node.value-1-(after-before-${code}-1)/${minimum});
      ${under_} = cast(typeof(${under_}))(${code}-(after-before-${code}-1)%${minimum});
      mixin(ENET_SYMBOL_CREATE!("${symbol_}", "${value_}", "${update}"));
      node.left = cast(typeof(node.left))(${symbol_}-node);
    }}.cmacroFixVars!("context","symbol_","code","value_","under_","count_","update","minimum","exclude")(context, symbol_, code, value_, under_, count_, update, minimum, exclude));


enum ENET_CONTEXT_NOT_EXCLUDED(string value_, string after, string before) = "{}";


public extern(C) usize enet_range_coder_decompress (void* context, const(ubyte)* inData, usize inLimit, ubyte* outData, usize outLimit) nothrow @trusted @nogc {
  ENetRangeCoder* rangeCoder = cast(ENetRangeCoder*)context;
  ubyte* outStart = outData, outEnd = &outData[outLimit];
  const(ubyte)* inEnd = &inData[inLimit];
  enet_uint32 decodeLow = 0, decodeCode = 0, decodeRange = ~0;
  ENetSymbol* root;
  ushort predicted = 0;
  usize order = 0, nextSymbol = 0;

  if (rangeCoder is null || inLimit <= 0) return 0;

  mixin(ENET_CONTEXT_CREATE!("root", "ENET_CONTEXT_ESCAPE_MINIMUM", "ENET_CONTEXT_SYMBOL_MINIMUM"));

  mixin(ENET_RANGE_CODER_SEED);

  for (;;) {
    ENetSymbol* subcontext, symbol, patch;
    ubyte value = 0;
    ushort code, under, count, bottom, total;
    ushort* parent = &predicted;

    for (subcontext = &rangeCoder.symbols.ptr[predicted]; subcontext != root; subcontext = &rangeCoder.symbols.ptr[subcontext.parent]) {
      if (subcontext.escapes <= 0) continue;
      total = subcontext.total;
      if (subcontext.escapes >= total) continue;
      code = cast(ushort)(mixin(ENET_RANGE_CODER_READ!"total"));
      if (code < subcontext.escapes) {
        mixin(ENET_RANGE_CODER_DECODE!("0", "subcontext.escapes", "total"));
        continue;
      }
      code -= subcontext.escapes;
      {
        mixin(ENET_CONTEXT_TRY_DECODE!("subcontext", "symbol", "code", "value", "under", "count", "ENET_SUBCONTEXT_SYMBOL_DELTA", "0", "ENET_CONTEXT_NOT_EXCLUDED!"));
      }
      bottom = cast(ushort)(symbol-rangeCoder.symbols.ptr);
      mixin(ENET_RANGE_CODER_DECODE!("subcontext.escapes+under", "count", "total"));
      subcontext.total += ENET_SUBCONTEXT_SYMBOL_DELTA;
      if (count > 0xFF-2*ENET_SUBCONTEXT_SYMBOL_DELTA || subcontext.total > ENET_RANGE_CODER_BOTTOM-0x100) { mixin(ENET_CONTEXT_RESCALE!("subcontext", "0")); }
      goto patchContexts;
    }

    total = root.total;
    code = cast(ushort)(mixin(ENET_RANGE_CODER_READ!"total"));
    if (code < root.escapes) {
      mixin(ENET_RANGE_CODER_DECODE!("0", "root.escapes", "total"));
      break;
    }
    code -= root.escapes;
    {
      mixin(ENET_CONTEXT_ROOT_DECODE!("root", "symbol", "code", "value", "under", "count", "ENET_CONTEXT_SYMBOL_DELTA", "ENET_CONTEXT_SYMBOL_MINIMUM", "ENET_CONTEXT_NOT_EXCLUDED!"));
    }
    bottom = cast(ushort)(symbol-rangeCoder.symbols.ptr);
    mixin(ENET_RANGE_CODER_DECODE!("root.escapes+under", "count", "total"));
    root.total += ENET_CONTEXT_SYMBOL_DELTA;
    if (count > 0xFF-2*ENET_CONTEXT_SYMBOL_DELTA+ENET_CONTEXT_SYMBOL_MINIMUM || root.total > ENET_RANGE_CODER_BOTTOM-0x100) { mixin(ENET_CONTEXT_RESCALE!("root", "ENET_CONTEXT_SYMBOL_MINIMUM")); }

  patchContexts:
    for (patch = &rangeCoder.symbols.ptr[predicted]; patch != subcontext; patch = &rangeCoder.symbols.ptr[patch.parent]) {
      mixin(ENET_CONTEXT_ENCODE!("patch", "symbol", "value", "under", "count", "ENET_SUBCONTEXT_SYMBOL_DELTA", "0"));
      *parent = cast(ushort)(symbol-rangeCoder.symbols.ptr);
      parent = &symbol.parent;
      if (count <= 0) {
        patch.escapes += ENET_SUBCONTEXT_ESCAPE_DELTA;
        patch.total += ENET_SUBCONTEXT_ESCAPE_DELTA;
      }
      patch.total += ENET_SUBCONTEXT_SYMBOL_DELTA;
      if (count > 0xFF-2*ENET_SUBCONTEXT_SYMBOL_DELTA || patch.total > ENET_RANGE_CODER_BOTTOM-0x100) { mixin(ENET_CONTEXT_RESCALE!("patch", "0")); }
    }
    *parent = bottom;

    mixin(ENET_RANGE_CODER_OUTPUT!"value");

    if (order >= ENET_SUBCONTEXT_ORDER) {
      predicted = rangeCoder.symbols.ptr[predicted].parent;
    } else {
      ++order;
    }
    mixin(ENET_RANGE_CODER_FREE_SYMBOLS);
  }

  return cast(usize)(outData-outStart);
}

/** @defgroup host ENet host functions
    @{
*/

/** Sets the packet compressor the host should use to the default range coder.
    @param host host to enable the range coder for
    @returns 0 on success, < 0 on failure
*/
public int enet_host_compress_with_range_coder (ENetHost* host) nothrow {
  import core.stdc.string : memset;

  ENetCompressor compressor = void;
  memset(&compressor, 0, compressor.sizeof);
  compressor.context = enet_range_coder_create();
  if (compressor.context is null) return -1;
  compressor.compress = &enet_range_coder_compress;
  compressor.decompress = &enet_range_coder_decompress;
  compressor.destroy = &enet_range_coder_destroy;
  enet_host_compress(host, &compressor);
  return 0;
}
