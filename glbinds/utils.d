// WTFPL or Public Domain, on your choice
module iv.glbinds.utils;

import iv.glbinds;

// replacement for `gluPerspective()`
// sets the frustum to perspective mode.
// fovY   - Field of vision in degrees in the y direction
// aspect - Aspect ratio of the viewport
// zNear  - The near clipping distance
// zFar   - The far clipping distance
void oglPerspective (double fovY, double aspect, double zNear, double zFar) {
  import std.math;

  //const GLdouble pi = 3.1415926535897932384626433832795;
  double fW, fH; // half of the size of the x and y clipping planes.
  // calculate the distance from 0 of the y clipping plane.
  // basically trig to calculate position of clipper at zNear.
  // Note: tan(double) uses radians but OpenGL works in degrees so we convert
  //       degrees to radians by dividing by 360 then multiplying by PI
  //fH = tan((fovY/2)/180*PI)*zNear;
  fH = tan(fovY/360*PI)*zNear;
  // calculate the distance from 0 of the x clipping plane based on the aspect ratio
  fW = fH*aspect;
  // finally call glFrustum, this is all gluPerspective does anyway!
  // this is why we calculate half the distance between the clipping planes,
  // glFrustum takes an offset from zero for each clipping planes distance (saves 2 divides)
  glFrustum(-fW, fW, -fH, fH, zNear, zFar);
}


// replacement for `gluLookAt()`
void oglLookAt (
  GLfloat eyex, GLfloat eyey, GLfloat eyez,
  GLfloat centerx, GLfloat centery, GLfloat centerz,
  GLfloat upx, GLfloat upy, GLfloat upz
) {
  import std.math;

  GLfloat[16] m;
  GLfloat[3] x, y, z;
  GLfloat mag;
  // make rotation matrix
  // Z vector
  z[0] = eyex-centerx;
  z[1] = eyey-centery;
  z[2] = eyez-centerz;
  mag = sqrt(z[0]*z[0]+z[1]*z[1]+z[2]*z[2]);
  if (mag != 0.0f) {
    z[0] /= mag;
    z[1] /= mag;
    z[2] /= mag;
  }
  // Y vector
  y[0] = upx;
  y[1] = upy;
  y[2] = upz;
  // X vector = Y cross Z
  x[0] =  y[1]*z[2]-y[2]*z[1];
  x[1] = -y[0]*z[2]+y[2]*z[0];
  x[2] =  y[0]*z[1]-y[1]*z[0];
  // Recompute Y = Z cross X
  y[0] =  z[1]*x[2]-z[2]*x[1];
  y[1] = -z[0]*x[2]+z[2]*x[0];
  y[2] =  z[0]*x[1]-z[1]*x[0];

  /* cross product gives area of parallelogram, which is < 1.0 for
   * non-perpendicular unit-length vectors; so normalize x, y here
   */
  mag = sqrt(x[0]*x[0]+x[1]*x[1]+x[2]*x[2]);
  if (mag != 0.0f) {
    x[0] /= mag;
    x[1] /= mag;
    x[2] /= mag;
  }

  mag = sqrt(y[0]*y[0]+y[1]*y[1]+y[2]*y[2]);
  if (mag != 0.0f) {
    y[0] /= mag;
    y[1] /= mag;
    y[2] /= mag;
  }

  void setM (ubyte row, ubyte col, GLfloat v) @safe nothrow @nogc { m[col*4+row] = v; }
  setM(0, 0, x[0]);
  setM(0, 1, x[1]);
  setM(0, 2, x[2]);
  setM(0, 3, 0.0f);
  setM(1, 0, y[0]);
  setM(1, 1, y[1]);
  setM(1, 2, y[2]);
  setM(1, 3, 0.0f);
  setM(2, 0, z[0]);
  setM(2, 1, z[1]);
  setM(2, 2, z[2]);
  setM(2, 3, 0.0f);
  setM(3, 0, 0.0f);
  setM(3, 1, 0.0f);
  setM(3, 2, 0.0f);
  setM(3, 3, 1.0f);

  glMultMatrixf(m.ptr);

  // translate Eye to Origin
  glTranslatef(-eyex, -eyey, -eyez);
}
