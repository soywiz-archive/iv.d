/* coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * Understanding is not required. Only obedience.
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
module iv.cmdcon.keybinds /*is aliced*/;
private:

import arsd.simpledisplay : KeyEvent, Key;

import iv.cmdcon;
import iv.strex;


// ////////////////////////////////////////////////////////////////////////// //
/*
  enum Key {
    Forward,
    Backward,
    TurnLeft,
    TurnRight,
    StrafeLeft,
    StrafeRight,
    Attack,
    Jump,
    Run,
    ExtraRun,
    NoClip,
    LookUp,
    LookDown,
    LookCenter,
    //LookXLeft,
    //LookXRight,
  }

  void registerBindCommands!Key;

  // then in KeyEvent handler:
  if (PlayerBinds.processKeyEvent(event)) return;

  // and in frame handler:
  if (PlayerBinds[Key.Forward]) doAction();
  ...
  PlayerBinds.frameComplete();
*/


// ////////////////////////////////////////////////////////////////////////// //
public struct PlayerBinds {
private:
  __gshared ubyte[256] keys; // max 256 actions

static public @trusted:
  /// this will put command in console command queue and return `true`, or do nothing and return `false`
  bool processKeyEvent() (in auto ref KeyEvent event) {
    if (auto pkp = event.key in (event.pressed ? boundkeysDown : boundkeysUp)) {
      auto cmd = *pkp;
      if (cmd.length) concmd(cmd);
      return true;
    }
    return false;
  }

nothrow @nogc:
  /// call this in frame handler
  void frameComplete () {
    foreach (ref k; keys[]) k &= ((k>>1)&0x01)^1;
  }

  bool opIndex (int idx) {
    pragma(inline, true);
    return (idx >= 0 && idx < keys.length ? ((keys.ptr[idx]&0x01) != 0) : false);
  }

  /// don't use this
  void opIndexAssign (bool down, int idx) {
    pragma(inline, true);
    if (idx >= 0 && idx < keys.length) keys.ptr[idx] |= (down ? 1 : 2);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
__gshared string[Key] boundkeysDown;
__gshared string[Key] boundkeysUp;


// ////////////////////////////////////////////////////////////////////////// //
public void clearBindings () {
  boundkeysDown.clear();
  boundkeysUp.clear();
}


public void saveBindings (scope void delegate (scope ConString s) wdg) {
  if (wdg is null) return;
  wdg("bind_clear_all\n");
  foreach (ref kv; boundkeysDown.byKeyValue) {
    wdg("bind ");
    string ksname;
    foreach (string nm; __traits(allMembers, Key)) {
      if (__traits(getMember, Key, nm) == kv.key) { ksname = nm; break; }
    }
    if (ksname.length == 0) continue;
    if (kv.value.length == 0) continue;
    if (kv.value[0] == '+') {
      if (auto kup = kv.key in boundkeysUp) {
        string uv = *kup;
        if (uv.length == kv.value.length && uv[0] == '-' && kv.value[1..$] == uv[1..$]) {
          // "all"
          ConCommand.quoteStringDG(ksname, wdg);
          wdg(" ");
          ConCommand.quoteStringDG(kv.value, wdg);
          wdg("\n");
          continue;
        }
      }
    }
    // down
    bool putPfx = true;
    ConCommand.quoteStringDG!true(ksname, delegate (scope ConString s) {
      if (s.length == 0) return; // just in case
      if (putPfx) {
        assert(s[0] == '"');
        wdg(`"+`);
        if (s.length > 1) wdg(s[1..$]);
        putPfx = false;
      } else {
        wdg(s);
      }
    });
    wdg(` `);
    ConCommand.quoteStringDG(kv.value, wdg);
    wdg("\n");
    // up
    if (auto kup = kv.key in boundkeysUp) {
      string uv = *kup;
      if (uv.length == 0) continue; // just in case
      wdg(`bind `);
      putPfx = true;
      ConCommand.quoteStringDG!true(ksname, delegate (scope ConString s) {
        if (s.length == 0) return; // just in case
        if (putPfx) {
          assert(s[0] == '"');
          wdg(`"-`);
          if (s.length > 1) wdg(s[1..$]);
          putPfx = false;
        } else {
          wdg(s);
        }
      });
      wdg(` `);
      ConCommand.quoteStringDG(uv, wdg);
      wdg("\n");
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
enum KeyState { All, Down, Up }

// 0: invalid
Key findKeyByName (ConString name, KeyState* ks=null) {
  if (ks !is null) *ks = KeyState.All;
  if (name.length && name[0] == '+') {
    if (ks !is null) *ks = KeyState.Down;
    name = name[1..$];
  } else if (name.length && name[0] == '-') {
    if (ks !is null) *ks = KeyState.Up;
    name = name[1..$];
  }
  if (name.length) {
    foreach (string kn; __traits(allMembers, Key)) {
      if (strEquCI(name, kn)) return __traits(getMember, Key, kn);
    }
    if (name.length == 1 && name[0] >= '1' && name[0] <= '9') return cast(Key)(Key.N1+name[0]-'0');
    if (name.length == 1 && name[0] == '0') return Key.N0;
  }
  return cast(Key)0; // HACK!
}


// ////////////////////////////////////////////////////////////////////////// //
public void registerBindCommands(ET) () if (is(ET == enum)) {
  foreach (string nm; __traits(allMembers, ET)) {
    enum v = __traits(getMember, ET, nm);
    string ls;
    foreach (char ch; nm) ls ~= ch.tolower;
    conRegFunc!(() { PlayerBinds[v] = true; })("+"~ls, "start '"~ls~"' action");
    conRegFunc!(() { PlayerBinds[v] = false; })("-"~ls, "stop '"~ls~"' action");
  }

  conRegFunc!clearBindings("bind_clear_all", "remove all command bindings");

  conRegFunc!((ConFuncVA va) {
    auto key = ConCommand.getWord(va.cmdline);
    if (key.length == 0) { conwriteln("bind: empty key!"); return; }
    // strip spaces from cmdline
    va.cmdline = va.cmdline.xstrip;
    if (va.cmdline.length >= 2 && va.cmdline[0] == '"' && va.cmdline[$-1] == '"') {
      va.cmdline = va.cmdline[1..$-1];
      va.cmdline = va.cmdline.xstrip;
    }
    if (va.cmdline.length == 0) { conwriteln("bind: empty command!"); return; }
    KeyState ks;
    auto kk = findKeyByName(key, &ks);
    if (kk == 0) { conwriteln("bind: unknown key '", key, "'"); return; }
    final switch (ks) {
      case KeyState.All:
        if (va.cmdline[0] == '+') {
          // "+command": automatically add "-command" for releasing
          if (va.cmdline.length == 1) { conwriteln("bind: empty command!"); return; }
          char[] c0 = va.cmdline.dup;
          char[] c1 = va.cmdline.dup;
          c1[0] = '-'; // hack
          boundkeysDown[kk] = cast(string)c0; // it is safe to cast here
          boundkeysUp[kk] = cast(string)c1; // it is safe to cast here
        } else {
          // "command": remove releasing action
          boundkeysDown[kk] = va.cmdline.idup;
          boundkeysUp.remove(kk);
        }
        break;
      case KeyState.Down:
        boundkeysDown[kk] = va.cmdline.idup;
        break;
      case KeyState.Up:
        boundkeysUp[kk] = va.cmdline.idup;
        break;
    }
  })("bind", "bind key to action(s)");

  conRegFunc!((ConString key) {
    if (key.length == 0) { conwriteln("unbind: empty key!"); return; }
    KeyState ks;
    auto kk = findKeyByName(key, &ks);
    if (kk == 0) { conwriteln("unbind: unknown key '", key, "'"); return; }
    final switch (ks) {
      case KeyState.All:
        boundkeysDown.remove(kk);
        boundkeysUp.remove(kk);
        break;
      case KeyState.Down:
        boundkeysDown.remove(kk);
        break;
      case KeyState.Up:
        boundkeysUp.remove(kk);
        break;
    }
  })("unbind", "unbind key");
}
