/* Invisible Vector Library
 * ported by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
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
module iv.nanovega.util;
private:

public import arsd.simpledisplay;
public import iv.nanovega.nanovega;


// ////////////////////////////////////////////////////////////////////////// //
public class NVGWindow : SimpleWindow {
public:
  NVGContext nvg; // our NanoVega context
  NVGContextFlag nvgInitFlags = NVGContextFlag.Default; // bitwise or

  void delegate (NVGWindow self, NVGContext nvg) onInitOpenGL; // will be called after creating nvg
  void delegate (NVGWindow self, NVGContext nvg) onDeinitOpenGL; // will be called before destroying nvg
  void delegate (NVGWindow self, NVGContext nvg) onRedraw; // will be called in [redrawOpenGlScene]

protected:
  void setupCallbacks () {
    visibleForTheFirstTime = delegate () {
      onBeforeInitNVG();
      nvg = nvgCreateContext(cast(NVGContextFlag)nvgInitFlags);
      if (nvg is null) assert(0, "cannot initialize NanoVega");
      if (onInitOpenGL !is null) onInitOpenGL(this, nvg);
    };
    redrawOpenGlScene = delegate () {
      if (width < 1 || height < 1 || closed) return;
      if (onRedraw !is null && nvg !is null) {
        glViewport(0, 0, width, height);
        onRedraw(this, nvg);
      }
    };
  }

  void onBeforeInitNVG () {} // you can set [nvgInitFlags] here

public:
  this (int width=800, int height=800, string title=null, Resizability resizable=Resizability.allowResizing, WindowTypes windowType=WindowTypes.normal, int customizationFlags=WindowFlags.normal, SimpleWindow parent=null) {
    setupCallbacks();
    super(width, height, title, OpenGlOptions.yes, resizable, windowType, customizationFlags, parent);
  }

  this (Size size, string title=null, Resizability resizable=Resizability.allowResizing) {
    setupCallbacks();
    super(size, title, OpenGlOptions.yes, resizable);
  }

  override void close () {
    if (!closed && onDeinitOpenGL !is null && nvg !is null) onDeinitOpenGL(this, nvg);
    nvg.kill();
    super.close();
  }

  final void forceRedraw () {
    if (!closed && visible) redrawOpenGlSceneNow();
  }
}
