/* Invisible Vector Library
 * coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * Understanding is not required. Only obedience.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3 of the License ONLY.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */
module iv.crt.evloop /*is aliced*/;
private:

public import iv.evloop : TimerType, addTimer, removeTimer, isGlobalQuit, sendQuitSignal;
import iv.evloop;

import iv.alice;
import iv.rawtty;


public __gshared void delegate (string key) onKeyPressed;


public void ttyEventLoop () {
  import core.sys.posix.unistd : STDIN_FILENO;

  auto oldMode = ttySetRaw();
  if (oldMode == TTYMode.BAD) throw new Exception("not a tty");
  scope(exit) ttySetMode(oldMode);

  removeFD(STDIN_FILENO);
  addFD(STDIN_FILENO, FDFlags.CanRead, (int fd, FDFlags flags) {
    // keyboard
    auto s = ttyReadKey();
    if (s !is null && onKeyPressed !is null) onKeyPressed(s);
  });
  eventLoop();
}
