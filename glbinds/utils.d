// WTFPL or Public Domain, on your choice
module iv.glbinds.utils /*is aliced*/;

import iv.alice;
import iv.glbinds;

// replacement for `gluPerspective()`
// sets the frustum to perspective mode.
// fovY   - Field of vision in degrees in the y direction
// aspect - Aspect ratio of the viewport
// zNear  - The near clipping distance
// zFar   - The far clipping distance
void oglPerspective (double fovY, double aspect, double zNear, double zFar) nothrow @trusted @nogc {
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
) nothrow @trusted @nogc {
  import core.stdc.math : sqrtf;

  GLfloat[16] m = void;
  GLfloat[3] x = void, y = void, z = void;
  GLfloat mag;
  // make rotation matrix
  // Z vector
  z.ptr[0] = eyex-centerx;
  z.ptr[1] = eyey-centery;
  z.ptr[2] = eyez-centerz;
  mag = sqrtf(z.ptr[0]*z.ptr[0]+z.ptr[1]*z.ptr[1]+z.ptr[2]*z.ptr[2]);
  if (mag != 0.0f) {
    z.ptr[0] /= mag;
    z.ptr[1] /= mag;
    z.ptr[2] /= mag;
  }
  // Y vector
  y.ptr[0] = upx;
  y.ptr[1] = upy;
  y.ptr[2] = upz;
  // X vector = Y cross Z
  x.ptr[0] =  y.ptr[1]*z.ptr[2]-y.ptr[2]*z.ptr[1];
  x.ptr[1] = -y.ptr[0]*z.ptr[2]+y.ptr[2]*z.ptr[0];
  x.ptr[2] =  y.ptr[0]*z.ptr[1]-y.ptr[1]*z.ptr[0];
  // Recompute Y = Z cross X
  y.ptr[0] =  z.ptr[1]*x.ptr[2]-z.ptr[2]*x.ptr[1];
  y.ptr[1] = -z.ptr[0]*x.ptr[2]+z.ptr[2]*x.ptr[0];
  y.ptr[2] =  z.ptr[0]*x.ptr[1]-z.ptr[1]*x.ptr[0];

  /* cross product gives area of parallelogram, which is < 1.0 for
   * non-perpendicular unit-length vectors; so normalize x, y here
   */
  mag = sqrtf(x.ptr[0]*x.ptr[0]+x.ptr[1]*x.ptr[1]+x.ptr[2]*x.ptr[2]);
  if (mag != 0.0f) {
    x.ptr[0] /= mag;
    x.ptr[1] /= mag;
    x.ptr[2] /= mag;
  }

  mag = sqrtf(y.ptr[0]*y.ptr[0]+y.ptr[1]*y.ptr[1]+y.ptr[2]*y.ptr[2]);
  if (mag != 0.0f) {
    y.ptr[0] /= mag;
    y.ptr[1] /= mag;
    y.ptr[2] /= mag;
  }

  m.ptr[0*4+0] = x.ptr[0];
  m.ptr[1*4+0] = x.ptr[1];
  m.ptr[2*4+0] = x.ptr[2];
  m.ptr[3*4+0] = 0.0f;
  m.ptr[0*4+1] = y.ptr[0];
  m.ptr[1*4+1] = y.ptr[1];
  m.ptr[2*4+1] = y.ptr[2];
  m.ptr[3*4+1] = 0.0f;
  m.ptr[0*4+2] = z.ptr[0];
  m.ptr[1*4+2] = z.ptr[1];
  m.ptr[2*4+2] = z.ptr[2];
  m.ptr[3*4+2] = 0.0f;
  m.ptr[0*4+3] = 0.0f;
  m.ptr[1*4+3] = 0.0f;
  m.ptr[2*4+3] = 0.0f;
  m.ptr[3*4+3] = 1.0f;

  glMultMatrixf(m.ptr);

  // translate Eye to Origin
  glTranslatef(-eyex, -eyey, -eyez);
}
