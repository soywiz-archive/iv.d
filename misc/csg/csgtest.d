module main /*is aliced*/;

import arsd.color;
import arsd.image;
import arsd.simpledisplay;

import iv.alice;
import iv.cmdcon;
import iv.cmdcongl;
//import iv.glbinds;
import iv.vmath;

import csg;
import namedargs;
import gourd;


// ////////////////////////////////////////////////////////////////////////// //
enum GWidth = 800;
enum GHeight = 600;


// ////////////////////////////////////////////////////////////////////////// //
enum VertexShader = q{
  varying Vec3 color;
  varying Vec3 normal;
  varying Vec3 light;
  void main () {
    const Vec3 lightDir = Vec3(1.0, 2.0, 3.0)/3.741657386773941;
    light = (gl_ModelViewMatrix*vec4(lightDir, 0.0)).xyz;
    color = gl_Color.rgb;
    normal = gl_NormalMatrix*gl_Normal;
    gl_Position = gl_ModelViewProjectionMatrix*gl_Vertex;
  }
};

enum FragmentShader = q{
  varying Vec3 color;
  varying Vec3 normal;
  varying Vec3 light;
  void main () {
    Vec3 n = normalize(normal);
    float diffuse = max(0.0, dot(light, n));
    float specular = pow(max(0.0, -reflect(light, n).z), 32.0)*sqrt(diffuse);
    gl_FragColor = vec4(mix(color*(0.3+0.7*diffuse), Vec3(1.0), specular), 1.0);
  }
};


// ////////////////////////////////////////////////////////////////////////// //
__gshared CSG mesh;


// ////////////////////////////////////////////////////////////////////////// //
void initMesh (int sample) {
  if (sample >= 0 && sample <= 2) {
    auto a = CSG.cube();
    auto b = args!(CSG.sphere, radius=>1.3)();
    if (sample == 0) mesh = a.opunion(b);
    if (sample == 1) mesh = a.opsubtract(b);
    if (sample == 2) mesh = a.opintersect(b);
    return;
  }

  if (sample >= 3 && sample <= 5) {
    auto a = CSG.cube();
    auto b = args!(CSG.sphere, center=>Vec3(-0.5, 0, 0.5), radius=>1.3)();
    if (sample == 3) mesh = a.opunion(b);
    if (sample == 4) mesh = a.opsubtract(b);
    if (sample == 5) mesh = a.opintersect(b);
    return;
  }

  if (sample == 6) {
    auto a = CSG.cube();
    auto b = CSG.sphere(radius:1.35, stacks:12);
    auto c = CSG.cylinder(radius:0.7, start:Vec3(-1, 0, 0), end:Vec3(1, 0, 0));
    auto d = CSG.cylinder(radius:0.7, start:Vec3(0, -1, 0), end:Vec3(0, 1, 0));
    auto e = CSG.cylinder(radius:0.7, start:Vec3(0, 0, -1), end:Vec3(0, 0, 1));
    mesh = a.opintersect(b).opsubtract(c.opunion(d).opunion(e));
    return;
  }

  if (sample == 7) {
    auto gourd = buildGourd();
    assert(gourd !is null);
    auto cyl = args!(CSG.cylinder, radius=>0.4, start=>Vec3(0.6, 0.8, -0.6), end=>Vec3(-0.6, -0.8, 0.6))();
    //gourd.setColor(0.5, 1, 0);
    //cyl.setColor(0, 0.5, 1);
    //auto n = new Node(gourd.polygons);
    //auto n = new Node(cyl.polygons);
    //assert(0);
    mesh = gourd.opsubtract(cyl);
    //mesh = gourd;
    return;
  }

  initMesh(0);
}


// ////////////////////////////////////////////////////////////////////////// //
__gshared float zNear = 0.001f;
__gshared float viewAngleVertical = 90.0f;


void oglSetupReversedZ () {
  import std.math : tan;
  import iv.glbinds;
  float f = 1.0f / tan(viewAngleVertical / 2.0f); // 1.0 / tan(X) == cotangent(X)
  float aspect = cast(float)GWidth/cast(float)GHeight;
/+
  glDepthFunc(GL_GREATER); //default would be GL_LESS
  clearDepth(0.0f); //default would be 1.0f

  glClipControl(GL_LOWER_LEFT, GL_ZERO_TO_ONE);


  //infinite Perspective matrix reversed
  glm::mat4 projectionMatrix = {
    f/aspect, 0.0f,  0.0f,  0.0f,
      0.0f,    f,  0.0f,  0.0f,
      0.0f, 0.0f,  0.0f, -1.0f,
      0.0f, 0.0f, zNear,  0.0f
  };
+/
}


// ////////////////////////////////////////////////////////////////////////// //
__gshared int angleX = 20;
__gshared int angleY = 20;
__gshared float depth = -4.5;
__gshared bool drawLines = false;
__gshared bool drawPolys = true;
__gshared int sample = 0;


void oglDrawScene () {
  glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
  if (mesh is null) return;

  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity();
  glTranslatef(0, 0, depth);
  glRotatef(angleX, 1, 0, 0);
  glRotatef(angleY, 0, 1, 0);

  foreach (immutable pidx, Polygon p; mesh.polygons) {
    glColor3f(1.0f, 0.5f, 0.0f);
    if (drawLines) {
      glColor3f(0.0f, 0.0f, 0.0f);
      glBegin(GL_LINES);
      foreach (immutable idx; 2..p.vertices.length) {
        glVertex3f(p.vertices[0].pos.x, p.vertices[0].pos.y, p.vertices[0].pos.z);
        glVertex3f(p.vertices[idx-1].pos.x, p.vertices[idx-1].pos.y, p.vertices[idx-1].pos.z);
        glVertex3f(p.vertices[0].pos.x, p.vertices[0].pos.y, p.vertices[0].pos.z);
        glVertex3f(p.vertices[idx].pos.x, p.vertices[idx].pos.y, p.vertices[idx].pos.z);
        glVertex3f(p.vertices[idx-1].pos.x, p.vertices[idx-1].pos.y, p.vertices[idx-1].pos.z);
        glVertex3f(p.vertices[idx].pos.x, p.vertices[idx].pos.y, p.vertices[idx].pos.z);
      }
      glEnd();
    }
    if (drawPolys) {
      glColor3f(1.0f, cast(float)pidx/cast(float)mesh.polygons.length, 0.0f);
      //glColor3f(1.0f-cast(float)pidx/cast(float)mesh.polygons.length, cast(float)pidx/cast(float)mesh.polygons.length, 0.0f);
      glBegin(GL_TRIANGLE_FAN);
        foreach (const ref v; p.vertices) glVertex3f(v.pos.x, v.pos.y, v.pos.z);
      glEnd();
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
void main (string[] args) {
  //glconShowKey = "M-Grave";
  conProcessQueue(); // load config
  conProcessArgs!true(args);

  initMesh(sample);

  setOpenGLContextVersion(3, 2);
  //openGLContextCompatible = false;

  auto sdwin = new SimpleWindow(GWidth, GHeight, "CSG demo", OpenGlOptions.yes, Resizability.fixedSize);
  //sdwindow.hideCursor();

  oglSetupDG = delegate () {
    import iv.glbinds;

    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    oglPerspective(45, cast(float)GWidth/cast(float)GHeight, 0.1, 100);
    glMatrixMode(GL_MODELVIEW);

    //glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glClearColor(0.93, 0.93, 0.93, 1);
    glEnable(GL_DEPTH_TEST);
    glEnable(GL_CULL_FACE);
    glDisable(GL_BLEND);
    glPolygonOffset(1, 1);
  };

  redrawFrameDG = delegate () { oglDrawScene(); };
  nextFrameDG = delegate () {};

  keyEventDG = delegate (KeyEvent event) {
    if (!event.pressed) return;
    switch (event.key) {
      case Key.Escape: concmd("quit"); break;
      default:
    }
  };

  mouseEventDG = delegate (MouseEvent event) {
    import std.algorithm : max, min;
    if (event.type == MouseEventType.motion) {
      if (event.modifierState&ModifierState.leftButtonDown) {
        angleY += event.dx;
        angleX += event.dy;
        angleX = max(-90, min(90, angleX));
      }
    }
    if (event.type == MouseEventType.buttonPressed && event.button == MouseButton.wheelUp) depth += 0.5;
    if (event.type == MouseEventType.buttonPressed && event.button == MouseButton.wheelDown) depth -= 0.5;
  };

  charEventDG = delegate (dchar ch) {
    if (ch == 'q') { concmd("quit"); return; }
    if (ch == 'l') { drawLines = !drawLines; return; }
    if (ch == 'p') { drawPolys = !drawPolys; return; }
    if (ch == '+') { initMesh(++sample); return; }
    if (ch == '-') { initMesh(--sample); return; }
  };

  glconSetupForGLWindow(sdwin);
  sdwin.eventLoop(0);
}
