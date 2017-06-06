// WTFPL or Public Domain, on your choice
module iv.glbinds.utils /*is aliced*/;
nothrow @trusted @nogc:

import iv.alice;
import iv.glbinds;


//enum GL_PI = 3.14159265358979323846;
enum GL_PI = 3.1415926535897932384626433832795;


// ////////////////////////////////////////////////////////////////////////// //
// replacement for `gluPerspective()`
// sets the frustum to perspective mode.
// fovY   - Field of vision in degrees in the y direction
// aspect - Aspect ratio of the viewport
// zNear  - The near clipping distance
// zFar   - The far clipping distance
/+
void oglPerspective (GLdouble fovY, GLdouble aspect, GLdouble zNear, GLdouble zFar) nothrow @trusted @nogc {
  import core.stdc.math : tan;

  //const GLdouble pi = 3.1415926535897932384626433832795;
  //double fW, fH; // half of the size of the x and y clipping planes.
  // calculate the distance from 0 of the y clipping plane.
  // basically trig to calculate position of clipper at zNear.
  // Note: tan(double) uses radians but OpenGL works in degrees so we convert
  //       degrees to radians by dividing by 360 then multiplying by PI
  //fH = tan((fovY/2)/180*PI)*zNear;
  immutable GLdouble fH = tan(fovY/360.0*GL_PI)*zNear;
  // calculate the distance from 0 of the x clipping plane based on the aspect ratio
  immutable GLdouble fW = fH*aspect;
  // finally call glFrustum, this is all gluPerspective does anyway!
  // this is why we calculate half the distance between the clipping planes,
  // glFrustum takes an offset from zero for each clipping planes distance (saves 2 divides)
  glFrustum(-fW, fW, -fH, fH, zNear, zFar);
}
+/


// ////////////////////////////////////////////////////////////////////////// //
// replacement for `gluLookAt()`
/+
void oglLookAt (
  GLfloat eyex, GLfloat eyey, GLfloat eyez,
  GLfloat centerx, GLfloat centery, GLfloat centerz,
  GLfloat upx, GLfloat upy, GLfloat upz
) {
  import core.math : sqrt;

  GLfloat[16] m = void;
  GLfloat[3] x = void, y = void, z = void;
  GLfloat mag;
  // make rotation matrix
  // Z vector
  z.ptr[0] = eyex-centerx;
  z.ptr[1] = eyey-centery;
  z.ptr[2] = eyez-centerz;
  mag = sqrt(z.ptr[0]*z.ptr[0]+z.ptr[1]*z.ptr[1]+z.ptr[2]*z.ptr[2]);
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
  mag = sqrt(x.ptr[0]*x.ptr[0]+x.ptr[1]*x.ptr[1]+x.ptr[2]*x.ptr[2]);
  if (mag != 0.0f) {
    x.ptr[0] /= mag;
    x.ptr[1] /= mag;
    x.ptr[2] /= mag;
  }

  mag = sqrt(y.ptr[0]*y.ptr[0]+y.ptr[1]*y.ptr[1]+y.ptr[2]*y.ptr[2]);
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
+/


// ////////////////////////////////////////////////////////////////////////// //
private void normalize(GLfloat* v) {
  import core.math : sqrt;
  GLfloat r = sqrt(v[0]*v[0]+v[1]*v[1]+v[2]*v[2]);
  if (r == 0) return;
  r = 1.0f/r;
  v[0] *= r;
  v[1] *= r;
  v[2] *= r;
}


private void cross(GLfloat* v1, GLfloat* v2, GLfloat* result) {
  result[0] = v1[1]*v2[2]-v1[2]*v2[1];
  result[1] = v1[2]*v2[0]-v1[0]*v2[2];
  result[2] = v1[0]*v2[1]-v1[1]*v2[0];
}


// ////////////////////////////////////////////////////////////////////////// //
// make m an identity matrix
void oglMakeIdentity (GLdouble* m) {
  pragma(inline, true);
  m[0+4*0] = 1; m[0+4*1] = 0; m[0+4*2] = 0; m[0+4*3] = 0;
  m[1+4*0] = 0; m[1+4*1] = 1; m[1+4*2] = 0; m[1+4*3] = 0;
  m[2+4*0] = 0; m[2+4*1] = 0; m[2+4*2] = 1; m[2+4*3] = 0;
  m[3+4*0] = 0; m[3+4*1] = 0; m[3+4*2] = 0; m[3+4*3] = 1;
}


void oglMakeIdentity (GLfloat* m) {
  pragma(inline, true);
  m[0+4*0] = 1; m[0+4*1] = 0; m[0+4*2] = 0; m[0+4*3] = 0;
  m[1+4*0] = 0; m[1+4*1] = 1; m[1+4*2] = 0; m[1+4*3] = 0;
  m[2+4*0] = 0; m[2+4*1] = 0; m[2+4*2] = 1; m[2+4*3] = 0;
  m[3+4*0] = 0; m[3+4*1] = 0; m[3+4*2] = 0; m[3+4*3] = 1;
}


void oglMulMatVec (const(GLdouble)* matrix, const(GLdouble)* vin, GLdouble* vout) {
  foreach (immutable i; 0..4) {
    vout[i] =
        vin[0]*matrix[0*4+i]+
        vin[1]*matrix[1*4+i]+
        vin[2]*matrix[2*4+i]+
        vin[3]*matrix[3*4+i];
  }
}


// inverse = invert(src)
bool oglMatInvert (const(GLdouble)* src, GLdouble* inverse) {
  import core.math : fabs;

  GLdouble[4][4] temp = void;

  foreach (immutable i; 0..4) {
    foreach (immutable j; 0..4) {
      temp.ptr[i].ptr[j] = src[i*4+j];
    }
  }

  oglMakeIdentity(inverse);

  foreach (immutable i; 0..4) {
    // look for largest element in column
    int swap = i;
    foreach (immutable j; i+1..4) {
      if (fabs(temp.ptr[j].ptr[i]) > fabs(temp.ptr[i].ptr[i])) swap = j;
    }

    if (swap != i) {
      // swap rows
      foreach (immutable k; 0..4) {
        GLdouble tmp = temp.ptr[i].ptr[k];
        temp.ptr[i].ptr[k] = temp.ptr[swap].ptr[k];
        temp.ptr[swap].ptr[k] = tmp;

        tmp = inverse[i*4+k];
        inverse[i*4+k] = inverse[swap*4+k];
        inverse[swap*4+k] = tmp;
      }
    }

    if (temp.ptr[i].ptr[i] == 0) return false; // no non-zero pivot: the matrix is singular, which shouldn't happen -- this means the user gave us a bad matrix

    {
      GLdouble t = 1.0/temp.ptr[i].ptr[i];
      foreach (immutable k; 0..4) {
        temp.ptr[i].ptr[k] *= t;
        inverse[i*4+k] *= t;
      }
    }

    foreach (immutable j; 0..4) {
      if (j != i) {
        immutable GLdouble t = temp.ptr[j].ptr[i];
        foreach (immutable k; 0..4) {
          temp.ptr[j].ptr[k] -= temp.ptr[i].ptr[k]*t;
          inverse[j*4+k] -= inverse[i*4+k]*t;
        }
      }
    }
  }

  return true;
}


void oglMulMatMat (const(GLdouble)* a, const(GLdouble)* b, GLdouble* res) {
  foreach (immutable i; 0..4) {
    foreach (immutable j; 0..4) {
      res[i*4+j] =
          a[i*4+0]*b[0*4+j]+
          a[i*4+1]*b[1*4+j]+
          a[i*4+2]*b[2*4+j]+
          a[i*4+3]*b[3*4+j];
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
void oglOrtho2D (GLdouble left, GLdouble right, GLdouble bottom, GLdouble top) {
  pragma(inline, true);
  glOrtho(left, right, bottom, top, -1, 1);
}


void oglPerspective (GLdouble fovy, GLdouble aspect, GLdouble zNear, GLdouble zFar) {
  import core.math : cos, sin;

  GLdouble radians = fovy/2.0*GL_PI/180.0;

  GLdouble deltaZ = zFar-zNear;
  GLdouble sine = sin(radians);
  if (deltaZ == 0 || sine == 0 || aspect == 0) return;
  GLdouble cotangent = cos(radians)/sine;

  GLdouble[4][4] m = void;
  oglMakeIdentity(&m[0][0]);
  m.ptr[0].ptr[0] = cotangent/aspect;
  m.ptr[1].ptr[1] = cotangent;
  m.ptr[2].ptr[2] = -(zFar+zNear)/deltaZ;
  m.ptr[2].ptr[3] = -1;
  m.ptr[3].ptr[2] = -2*zNear*zFar/deltaZ;
  m.ptr[3].ptr[3] = 0;
  glMultMatrixd(&m[0][0]);
}


void oglLookAt (
  GLdouble eyex, GLdouble eyey, GLdouble eyez, GLdouble centerx,
  GLdouble centery, GLdouble centerz, GLdouble upx, GLdouble upy,
  GLdouble upz)
{
  int i;
  GLfloat[3] forward = void, side = void, up = void;

  forward.ptr[0] = centerx-eyex;
  forward.ptr[1] = centery-eyey;
  forward.ptr[2] = centerz-eyez;

  up.ptr[0] = upx;
  up.ptr[1] = upy;
  up.ptr[2] = upz;

  normalize(forward.ptr);

  // side = forward x up
  cross(forward.ptr, up.ptr, side.ptr);
  normalize(side.ptr);

  // recompute up as: up = side x forward
  cross(side.ptr, forward.ptr, up.ptr);

  GLfloat[4][4] m = void;
  oglMakeIdentity(&m[0][0]);

  m.ptr[0].ptr[0] = side.ptr[0];
  m.ptr[1].ptr[0] = side.ptr[1];
  m.ptr[2].ptr[0] = side.ptr[2];

  m.ptr[0].ptr[1] = up.ptr[0];
  m.ptr[1].ptr[1] = up.ptr[1];
  m.ptr[2].ptr[1] = up.ptr[2];

  m.ptr[0].ptr[2] = -forward.ptr[0];
  m.ptr[1].ptr[2] = -forward.ptr[1];
  m.ptr[2].ptr[2] = -forward.ptr[2];

  glMultMatrixf(&m[0][0]);
  glTranslated(-eyex, -eyey, -eyez);
}


bool oglProject (
  GLdouble objx, GLdouble objy, GLdouble objz,
  const(GLdouble)* modelMatrix,
  const(GLdouble)* projMatrix,
  const(GLint)[] viewport,
  GLdouble* winx, GLdouble* winy, GLdouble* winz)
{
  if (viewport.length < 4 || modelMatrix is null || projMatrix is null) return false;

  GLdouble[4] vin = void, vout = void;

  vin.ptr[0] = objx;
  vin.ptr[1] = objy;
  vin.ptr[2] = objz;
  vin.ptr[3] = 1.0;

  oglMulMatVec(modelMatrix, vin.ptr, vout.ptr);
  oglMulMatVec(projMatrix, vout.ptr, vin.ptr);
  if (vin.ptr[3] == 0.0) return false;

  if (winx !is null || winy !is null || winz !is null) {
    vin.ptr[0] /= vin.ptr[3];
    vin.ptr[1] /= vin.ptr[3];
    vin.ptr[2] /= vin.ptr[3];

    // map x, y and z to range 0-1
    vin.ptr[0] = vin.ptr[0]*0.5+0.5;
    vin.ptr[1] = vin.ptr[1]*0.5+0.5;
    vin.ptr[2] = vin.ptr[2]*0.5+0.5;

    // map x,y to viewport
    vin.ptr[0] = vin.ptr[0]*viewport.ptr[2]+viewport.ptr[0];
    vin.ptr[1] = vin.ptr[1]*viewport.ptr[3]+viewport.ptr[1];

    if (winx !is null) *winx = vin.ptr[0];
    if (winy !is null) *winy = vin.ptr[1];
    if (winz !is null) *winz = vin.ptr[2];
  }

  return true;
}


bool oglUnProject (
  GLdouble winx, GLdouble winy, GLdouble winz,
  const(GLdouble)* modelMatrix,
  const(GLdouble)* projMatrix,
  const(GLint)[] viewport,
  GLdouble* objx, GLdouble* objy, GLdouble* objz)
{
  if (viewport.length < 4 || modelMatrix is null || projMatrix is null) return false;

  GLdouble[16] finalMatrix = void;
  GLdouble[4] vin = void, vout = void;

  oglMulMatMat(modelMatrix, projMatrix, finalMatrix.ptr);
  if (!oglMatInvert(finalMatrix.ptr, finalMatrix.ptr)) return false;

  vin.ptr[0] = winx;
  vin.ptr[1] = winy;
  vin.ptr[2] = winz;
  vin.ptr[3] = 1.0;

  // map x and y from window coordinates
  vin.ptr[0] = (vin.ptr[0]-viewport.ptr[0])/viewport.ptr[2];
  vin.ptr[1] = (vin.ptr[1]-viewport.ptr[1])/viewport.ptr[3];

  // map to range -1 to 1
  vin.ptr[0] = vin.ptr[0]*2.0-1.0;
  vin.ptr[1] = vin.ptr[1]*2.0-1.0;
  vin.ptr[2] = vin.ptr[2]*2.0-1.0;

  oglMulMatVec(finalMatrix.ptr, vin.ptr, vout.ptr);
  if (vout.ptr[3] == 0.0) return false;

  if (objx !is null || objy !is null || objz !is null) {
    vout.ptr[0] /= vout.ptr[3];
    vout.ptr[1] /= vout.ptr[3];
    vout.ptr[2] /= vout.ptr[3];
    if (objx !is null) *objx = vout.ptr[0];
    if (objy !is null) *objy = vout.ptr[1];
    if (objz !is null) *objz = vout.ptr[2];
  }

  return true;
}


bool oglUnProject4 (
  GLdouble winx, GLdouble winy, GLdouble winz, GLdouble clipw,
  const(GLdouble)* modelMatrix,
  const(GLdouble)* projMatrix,
  const(GLint)[] viewport,
  GLclampd near, GLclampd far,
  GLdouble* objx, GLdouble* objy, GLdouble* objz, GLdouble* objw)
{
  if (viewport.length < 4 || modelMatrix is null || projMatrix is null) return false;

  GLdouble[16] finalMatrix = void;
  GLdouble[4] vin = void, vout = void;

  oglMulMatMat(modelMatrix, projMatrix, finalMatrix.ptr);
  if (!oglMatInvert(finalMatrix.ptr, finalMatrix.ptr)) return false;

  vin.ptr[0] = winx;
  vin.ptr[1] = winy;
  vin.ptr[2] = winz;
  vin.ptr[3] = clipw;

  // map x and y from window coordinates
  vin.ptr[0] = (vin.ptr[0]-viewport.ptr[0])/viewport.ptr[2];
  vin.ptr[1] = (vin.ptr[1]-viewport.ptr[1])/viewport.ptr[3];
  vin.ptr[2] = (vin.ptr[2]-near)/(far-near);

  // map to range -1 to 1
  vin.ptr[0] = vin.ptr[0]*2.0-1.0;
  vin.ptr[1] = vin.ptr[1]*2.0-1.0;
  vin.ptr[2] = vin.ptr[2]*2.0-1.0;

  oglMulMatVec(finalMatrix.ptr, vin.ptr, vout.ptr);
  if (vout.ptr[3] == 0.0) return false;

  if (objx !is null || objy !is null || objz !is null && objw !is null) {
    if (objx !is null) *objx = vout.ptr[0];
    if (objy !is null) *objy = vout.ptr[1];
    if (objz !is null) *objz = vout.ptr[2];
    if (objw !is null) *objw = vout.ptr[3];
  }

  return true;
}


bool oglPickMatrix (GLdouble x, GLdouble y, GLdouble deltax, GLdouble deltay, const(GLint)[] viewport) {
  if (deltax <= 0 || deltay <= 0 || viewport.length < 4) return false;

  // translate and scale the picked region to the entire window
  glTranslatef((viewport.ptr[2]-2*(x-viewport.ptr[0]))/deltax, (viewport.ptr[3]-2*(y-viewport.ptr[1]))/deltay, 0);
  glScalef(viewport.ptr[2]/deltax, viewport.ptr[3]/deltay, 1.0);

  return true;
}
