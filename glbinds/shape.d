// GPLv3
// shamelessly ripped from FreeGLUT (except cube)
module iv.glbinds.shape /*is aliced*/;
nothrow @trusted @nogc:

import iv.glbinds;


/*
 * Compute lookup table of cos and sin values forming a circle
 * (or half circle if halfCircle==TRUE)
 *
 * Notes:
 *    It is the responsibility of the caller to free these tables
 *    The size of the table is (n+1) to form a connected loop
 *    The last entry is exactly the same as the first
 *    The sign of n can be flipped to get the reverse loop
 */
private void fghCircleTable() (GLfloat** sint, GLfloat** cost, in int n, in bool halfCircle) {
  import core.stdc.stdlib : malloc, free;
  import std.math;

  // table size, the sign of n flips the circle direction
  immutable int size = abs(n);

  // determine the angle between samples
  immutable GLfloat angle = (halfCircle ? 1 : 2)*cast(GLfloat)PI/cast(GLfloat)(n == 0 ? 1 : n);

  // allocate memory for n samples, plus duplicate of first entry at the end
  *sint = cast(GLfloat*)malloc(GLfloat.sizeof*(size+1));
  *cost = cast(GLfloat*)malloc(GLfloat.sizeof*(size+1));

  // bail out if memory allocation fails, fgError never returns
  if (*sint is null || *cost is null) {
    free(*sint);
    free(*cost);
    assert(0, "out of memory");
  }

  // compute cos and sin around the circle
  (*sint)[0] = 0.0f;
  (*cost)[0] = 1.0f;

  foreach (immutable int i; 1..size) {
    (*sint)[i] = cast(GLfloat)sin(angle*i);
    (*cost)[i] = cast(GLfloat)cos(angle*i);
  }

  if (halfCircle) {
    (*sint)[size] =  0.0f;  // sin PI
    (*cost)[size] = -1.0f;  // cos PI
  } else {
    // last sample is duplicate of the first (sin or cos of 2 PI)
    (*sint)[size] = (*sint)[0];
    (*cost)[size] = (*cost)[0];
  }
}


private void fghGenerateSphere() (GLfloat radius, GLint slices, GLint stacks, GLfloat** vertices, GLfloat** normals, int* nVert) {
  import core.stdc.stdlib : malloc, free;

  int idx = 0; // idx into vertex/normal buffer
  GLfloat x, y, z;

  // pre-computed circle
  GLfloat* sint1, cost1;
  GLfloat* sint2, cost2;

  // number of unique vertices
  if (slices == 0 || stacks < 2) {
    // nothing to generate
    *nVert = 0;
    return;
  }

  *nVert = slices*(stacks-1)+2;

  if (*nVert > 65535) {
    // limit of glushort, thats 256*256 subdivisions, should be enough in practice. See note above
    assert(0, "too many slices or stacks requested, indices will wrap");
  }

  // precompute values on unit circle
  fghCircleTable(&sint1, &cost1, -slices, false);
  fghCircleTable(&sint2, &cost2, stacks, true);

  // allocate vertex and normal buffers, bail out if memory allocation fails
  *vertices = cast(GLfloat*)malloc((*nVert)*3*GLfloat.sizeof);
  *normals = cast(GLfloat*)malloc((*nVert)*3*GLfloat.sizeof);
  if (*vertices is null || *normals is null) {
    free(*vertices);
    free(*normals);
    assert(0, "out of memory");
  }

  // top
  (*vertices)[0] = 0.0f;
  (*vertices)[1] = 0.0f;
  (*vertices)[2] = radius;
  (*normals)[0] = 0.0f;
  (*normals)[1] = 0.0f;
  (*normals)[2] = 1.0f;
  idx = 3;

  // each stack
  foreach (immutable int i; 1..stacks) {
    foreach (immutable int j; 0..slices) {
      x = cost1[j]*sint2[i];
      y = sint1[j]*sint2[i];
      z = cost2[i];

      (*vertices)[idx+0] = x*radius;
      (*vertices)[idx+1] = y*radius;
      (*vertices)[idx+2] = z*radius;
      (*normals)[idx+0] = x;
      (*normals)[idx+1] = y;
      (*normals)[idx+2] = z;

      idx += 3;
    }
  }

  // bottom
  (*vertices)[idx+0] = 0.0f;
  (*vertices)[idx+1] = 0.0f;
  (*vertices)[idx+2] = -radius;
  (*normals)[idx+0] = 0.0f;
  (*normals)[idx+1] = 0.0f;
  (*normals)[idx+2] = -1.0f;

  // done creating vertices, release sin and cos tables
  free(sint1);
  free(cost1);
  free(sint2);
  free(cost2);
}


private void fghGenerateCone() (
  GLfloat base, GLfloat height, GLint slices, GLint stacks,   // input
  GLfloat** vertices, GLfloat** normals, int* nVert           // output
) {
  import core.stdc.stdlib : malloc, free;
  import std.math;

  int idx = 0; // idx into vertex/normal buffer

  // pre-computed circle
  GLfloat* sint, cost;

  // step in z and radius as stacks are drawn.
  GLfloat z = 0;
  GLfloat r = cast(GLfloat)base;

  immutable GLfloat zStep = cast(GLfloat)height/(stacks > 0 ? stacks : 1);
  immutable GLfloat rStep = cast(GLfloat)base/(stacks > 0 ? stacks : 1);

  // scaling factors for vertex normals
  immutable GLfloat cosn = cast(GLfloat)(height/sqrt(height*height+base*base));
  immutable GLfloat sinn = cast(GLfloat)(base/sqrt(height*height+base*base));

  // number of unique vertices
  if (slices == 0 || stacks < 1) {
    // nothing to generate
    *nVert = 0;
    return;
  }
  *nVert = slices*(stacks+2)+1; // need an extra stack for closing off bottom with correct normals

  if (*nVert > 65535) {
    // limit of glushort, thats 256*256 subdivisions, should be enough in practice. See note above
    assert(0, "too many slices or stacks requested, indices will wrap");
  }

  // pre-computed circle
  fghCircleTable(&sint, &cost, -slices, false);

  // allocate vertex and normal buffers, bail out if memory allocation fails
  *vertices = cast(GLfloat*)malloc((*nVert)*3*GLfloat.sizeof);
  *normals = cast(GLfloat*)malloc((*nVert)*3*GLfloat.sizeof);
  if (*vertices is null || *normals is null) {
    free(*vertices);
    free(*normals);
    assert(0, "out of memory");
  }

  // bottom
  (*vertices)[0] = 0.0f;
  (*vertices)[1] = 0.0f;
  (*vertices)[2] = z;
  (*normals)[0] = 0.0f;
  (*normals)[1] = 0.0f;
  (*normals)[2] = -1.0f;

  idx = 3;
  // other on bottom (get normals right)
  foreach (immutable int j; 0..slices) {
    (*vertices)[idx+0] = cost[j]*r;
    (*vertices)[idx+1] = sint[j]*r;
    (*vertices)[idx+2] = z;
    (*normals)[idx+0] = 0.0f;
    (*normals)[idx+1] = 0.0f;
    (*normals)[idx+2] = -1.0f;
    idx += 3;
  }

  // each stack
  foreach (immutable int i; 0..stacks+1) {
    foreach (immutable int j; 0..slices) {
      (*vertices)[idx+0] = cost[j]*r;
      (*vertices)[idx+1] = sint[j]*r;
      (*vertices)[idx+2] = z;
      (*normals)[idx+0] = cost[j]*cosn;
      (*normals)[idx+1] = sint[j]*cosn;
      (*normals)[idx+2] = sinn;
      idx += 3;
    }
    z += zStep;
    r -= rStep;
  }

  // release sin and cos tables
  free(sint);
  free(cost);
}


private void fghGenerateCylinder() (
  GLfloat radius, GLfloat height, GLint slices, GLint stacks, // input
  GLfloat** vertices, GLfloat** normals, int* nVert           // output
) {
  import core.stdc.stdlib : malloc, free;
  import std.math;

  int idx = 0; // idx into vertex/normal buffer

  // step in z as stacks are drawn
  GLfloat radf = cast(GLfloat)radius;
  immutable GLfloat zStep = cast(GLfloat)height/(stacks > 0 ? stacks : 1);

  // pre-computed circle
  GLfloat* sint, cost;

  // number of unique vertices
  if (slices == 0 || stacks < 1) {
    // nothing to generate
    *nVert = 0;
    return;
  }
  *nVert = slices*(stacks+3)+2; // need two extra stacks for closing off top and bottom with correct normals

  if (*nVert > 65535) {
    // limit of glushort, thats 256*256 subdivisions, should be enough in practice. See note above
    assert(0, "too many slices or stacks requested, indices will wrap");
  }

  // pre-computed circle
  fghCircleTable(&sint, &cost, -slices, false);

  // Allocate vertex and normal buffers, bail out if memory allocation fails
  *vertices = cast(GLfloat*)malloc((*nVert)*3*GLfloat.sizeof);
  *normals = cast(GLfloat*)malloc((*nVert)*3*GLfloat.sizeof);
  if (*vertices is null || *normals is null) {
    free(*vertices);
    free(*normals);
    assert(0, "out of memory");
  }

  GLfloat z = 0;
  // top on Z-axis
  (*vertices)[0] = 0.0f;
  (*vertices)[1] = 0.0f;
  (*vertices)[2] = 0.0f;
  (*normals)[0] = 0.0f;
  (*normals)[1] = 0.0f;
  (*normals)[2] = -1.0f;
  idx = 3;
  // other on top (get normals right)
  foreach (immutable int j; 0..slices) {
    (*vertices)[idx+0] = cost[j]*radf;
    (*vertices)[idx+1] = sint[j]*radf;
    (*vertices)[idx+2] = z;
    (*normals)[idx+0] = 0.0f;
    (*normals)[idx+1] = 0.0f;
    (*normals)[idx+2] = -1.0f;
    idx += 3;
  }

  // each stack
  foreach (immutable int i; 0..stacks+1) {
    foreach (immutable int j; 0..slices) {
      (*vertices)[idx+0] = cost[j]*radf;
      (*vertices)[idx+1] = sint[j]*radf;
      (*vertices)[idx+2] = z;
      (*normals)[idx+0] = cost[j];
      (*normals)[idx+1] = sint[j];
      (*normals)[idx+2] = 0.0f;
      idx += 3;
    }
    z += zStep;
  }

  // other on bottom (get normals right)
  z -= zStep;
  foreach (immutable int j; 0..slices) {
    (*vertices)[idx+0] = cost[j]*radf;
    (*vertices)[idx+1] = sint[j]*radf;
    (*vertices)[idx+2] = z;
    (*normals)[idx+0] = 0.0f;
    (*normals)[idx+1] = 0.0f;
    (*normals)[idx+2] = 1.0f;
    idx += 3;
  }

  // bottom
  (*vertices)[idx+0] = 0.0f;
  (*vertices)[idx+1] = 0.0f;
  (*vertices)[idx+2] = height;
  (*normals)[idx+0] = 0.0f;
  (*normals)[idx+1] = 0.0f;
  (*normals)[idx+2] = 1.0f;

  // Release sin and cos tables
  free(sint);
  free(cost);
}


private void fghGenerateTorus() (
  double dInnerRadius, double dOuterRadius, GLint nSides, GLint nRings, // input
  GLfloat** vertices, GLfloat** normals, int* nVert                     // output
  )
{
  import core.stdc.stdlib : malloc, free;
  import std.math;

  GLfloat iradius = cast(GLfloat)dInnerRadius;
  GLfloat oradius = cast(GLfloat)dOuterRadius;

  // pre-computed circle
  GLfloat* spsi, cpsi;
  GLfloat* sphi, cphi;

  // number of unique vertices
  if (nSides < 2 || nRings < 2) {
    // nothing to generate
    *nVert = 0;
    return;
  }
  *nVert = nSides*nRings;

  if (*nVert > 65535) {
    // limit of glushort, thats 256*256 subdivisions, should be enough in practice. See note above
    assert(0, "too many slices or stacks requested, indices will wrap");
  }

  // precompute values on unit circle
  fghCircleTable(&spsi, &cpsi, nRings, false);
  fghCircleTable(&sphi, &cphi, -nSides, false);

  // Allocate vertex and normal buffers, bail out if memory allocation fails
  *vertices = cast(GLfloat*)malloc((*nVert)*3*GLfloat.sizeof);
  *normals = cast(GLfloat*)malloc((*nVert)*3*GLfloat.sizeof);
  if (*vertices is null || *normals is null) {
    free(*vertices);
    free(*normals);
    assert(0, "out of memory");
  }

  foreach (immutable int j; 0..nRings) {
    foreach (immutable int i; 0..nSides) {
      int offset = 3*(j*nSides+i);

      (*vertices)[offset+0] = cpsi[j]*(oradius+cphi[i]*iradius);
      (*vertices)[offset+1] = spsi[j]*(oradius+cphi[i]*iradius);
      (*vertices)[offset+2] = sphi[i]*iradius;
      (*normals)[offset+0] = cpsi[j]*cphi[i];
      (*normals)[offset+1] = spsi[j]*cphi[i];
      (*normals)[offset+2] = sphi[i];
    }
  }

  // release sin and cos tables
  free(spsi);
  free(cpsi);
  free(sphi);
  free(cphi);
}


private void fghDrawGeometrySolid (
  GLfloat* vertices, GLfloat* normals, GLfloat* textcs, GLsizei numVertices,
  GLushort* vertIdxs, GLsizei numParts, GLsizei numVertIdxsPerPart,
) {
  glEnableClientState(GL_VERTEX_ARRAY);
  glEnableClientState(GL_NORMAL_ARRAY);

  glVertexPointer(3, GL_FLOAT, 0, vertices);
  glNormalPointer(GL_FLOAT, 0, normals);

  if (textcs !is null) {
    glEnableClientState(GL_TEXTURE_COORD_ARRAY);
    glTexCoordPointer(2, GL_FLOAT, 0, textcs);
  }

  if (vertIdxs is null) {
    glDrawArrays(GL_TRIANGLES, 0, numVertices);
  } else {
    if (numParts > 1) {
      foreach (immutable i; 0..numParts) glDrawElements(GL_TRIANGLE_STRIP, numVertIdxsPerPart, GL_UNSIGNED_SHORT, vertIdxs+i*numVertIdxsPerPart);
    } else {
      glDrawElements(GL_TRIANGLES, numVertIdxsPerPart, GL_UNSIGNED_SHORT, vertIdxs);
    }
  }

  glDisableClientState(GL_VERTEX_ARRAY);
  glDisableClientState(GL_NORMAL_ARRAY);
  if (textcs !is null) glDisableClientState(GL_TEXTURE_COORD_ARRAY);
}


public void oglShapeSolidCube (GLdouble dSize) {
  // vertex coordinates
  static immutable GLfloat[24] cube_verts = [
     0.5f, 0.5f, 0.5f,
    -0.5f, 0.5f, 0.5f,
    -0.5f,-0.5f, 0.5f,
     0.5f,-0.5f, 0.5f,
     0.5f,-0.5f,-0.5f,
     0.5f, 0.5f,-0.5f,
    -0.5f, 0.5f,-0.5f,
    -0.5f,-0.5f,-0.5f,
  ];

  // normal vectors
  static immutable GLfloat[18] cube_norms = [
     0.0f, 0.0f, 1.0f,
     1.0f, 0.0f, 0.0f,
     0.0f, 1.0f, 0.0f,
    -1.0f, 0.0f, 0.0f,
     0.0f,-1.0f, 0.0f,
     0.0f, 0.0f,-1.0f,
  ];

  // vertex indices, as quads, before triangulation
  static immutable GLushort[24] cube_vertIdxs = [
    0,1,2,3,
    0,3,4,5,
    0,5,6,1,
    1,6,7,2,
    7,4,3,2,
    4,7,6,5,
  ];

  glBegin(GL_QUADS);
  foreach (immutable fidx; 0..6) {
    glNormal3fv(&cube_norms[fidx*3]);
    foreach (immutable vidx; fidx*4..fidx*4+4) {
      int vpi = cube_vertIdxs[vidx]*3;
      GLfloat[3] v = cube_verts[vpi..vpi+3];
      foreach (ref vv; v[]) vv *= dSize;
      glVertex3fv(v.ptr);
    }
  }
  glEnd();
}


public void oglShapeSolidSphere() (GLfloat radius, GLint slices, GLint stacks) {
  import core.stdc.stdlib : malloc, free;
  import std.math;

  int i, j, idx, nVert;
  GLfloat* vertices, normals;

  // generate vertices and normals
  fghGenerateSphere(radius, slices, stacks, &vertices, &normals, &nVert);

  if (nVert == 0) return;

  /* First, generate vertex index arrays for drawing with glDrawElements
   * All stacks, including top and bottom are covered with a triangle strip.
   */
  GLushort* stripIdx;
  // create index vector
  int offset;

  // allocate buffers for indices, bail out if memory allocation fails
  stripIdx = cast(GLushort*)malloc((slices+1)*2*(stacks)*GLushort.sizeof);
  if (stripIdx is null) assert(0, "out of memory");

  // top stack
  for (j = 0, idx = 0; j < slices; ++j, idx += 2) {
    stripIdx[idx+0] = cast(GLushort)(j+1); // 0 is top vertex, 1 is first for first stack
    stripIdx[idx+1] = 0;
  }
  stripIdx[idx+0] = 1; // repeat first slice's idx for closing off shape
  stripIdx[idx+1] = 0;
  idx += 2;

  // middle stacks
  // strip indices are relative to first index belonging to strip, NOT relative to first vertex/normal pair in array
  for (i = 0; i < stacks-2; ++i, idx += 2) {
    offset = 1+i*slices; // triangle_strip indices start at 1 (0 is top vertex), and we advance one stack down as we go along
    for (j = 0; j < slices; ++j, idx += 2) {
      stripIdx[idx+0] = cast(GLushort)(offset+j+slices);
      stripIdx[idx+1] = cast(GLushort)(offset+j);
    }
    stripIdx[idx+0] = cast(GLushort)(offset+slices); // repeat first slice's idx for closing off shape
    stripIdx[idx+1] = cast(GLushort)(offset);
  }

  // bottom stack
  offset = 1+(stacks-2)*slices; // triangle_strip indices start at 1 (0 is top vertex), and we advance one stack down as we go along
  for (j = 0; j < slices; ++j, idx += 2) {
    stripIdx[idx+0] = cast(GLushort)(nVert-1); // zero based index, last element in array (bottom vertex)...
    stripIdx[idx+1] = cast(GLushort)(offset+j);
  }
  stripIdx[idx+0] = cast(GLushort)(nVert-1); // repeat first slice's idx for closing off shape
  stripIdx[idx+1] = cast(GLushort)(offset);

  // draw */
  fghDrawGeometrySolid(vertices, normals, null, nVert, stripIdx, stacks, (slices+1)*2);

  // cleanup allocated memory
  free(stripIdx);

  // cleanup allocated memory
  free(vertices);
  free(normals);
}


public void oglShapeSolidCone() (GLfloat base, GLfloat height, GLint slices, GLint stacks) {
  import core.stdc.stdlib : malloc, free;
  import std.math;

  int i, j, idx, nVert;
  GLfloat* vertices, normals;

  // generate vertices and normals
  // note, (stacks+1)*slices vertices for side of object, slices+1 for top and bottom closures
  fghGenerateCone(base, height, slices, stacks, &vertices, &normals, &nVert);

  if (nVert == 0) return;

  /* First, generate vertex index arrays for drawing with glDrawElements
   * All stacks, including top and bottom are covered with a triangle
   * strip.
   */
  GLushort* stripIdx;
  // create index vector
  int offset;

  /* Allocate buffers for indices, bail out if memory allocation fails */
  stripIdx = cast(GLushort*)malloc((slices+1)*2*(stacks+1)*GLushort.sizeof); // stacks+1 because of closing off bottom
  if (stripIdx is null) assert(0, "out of memory");

  // top stack
  for (j = 0, idx = 0;  j < slices; ++j, idx += 2) {
    stripIdx[idx+0] = 0;
    stripIdx[idx+1] = cast(GLushort)(j+1); // 0 is top vertex, 1 is first for first stack
  }
  stripIdx[idx+0] = 0; // repeat first slice's idx for closing off shape
  stripIdx[idx+1] = 1;
  idx += 2;

  // middle stacks
  // strip indices are relative to first index belonging to strip, NOT relative to first vertex/normal pair in array
  for (i = 0; i < stacks; ++i, idx += 2) {
    offset = 1+(i+1)*slices; // triangle_strip indices start at 1 (0 is top vertex), and we advance one stack down as we go along
    for (j = 0; j < slices; ++j, idx += 2) {
      stripIdx[idx+0] = cast(GLushort)(offset+j);
      stripIdx[idx+1] = cast(GLushort)(offset+j+slices);
    }
    stripIdx[idx+0] = cast(GLushort)(offset); // repeat first slice's idx for closing off shape
    stripIdx[idx+1] = cast(GLushort)(offset+slices);
  }

  // draw
  fghDrawGeometrySolid(vertices, normals, null, nVert, stripIdx, stacks+1, (slices+1)*2);

  // cleanup allocated memory
  free(stripIdx);

  // cleanup allocated memory
  free(vertices);
  free(normals);
}


public void oglShapeSolidCylinder() (GLfloat radius, GLfloat height, GLint slices, GLint stacks) {
  import core.stdc.stdlib : malloc, free;
  import std.math;

  int i, j, idx, nVert;
  GLfloat* vertices, normals;

  // generate vertices and normals
  // note, (stacks+1)*slices vertices for side of object, 2*slices+2 for top and bottom closures
  fghGenerateCylinder(radius, height, slices, stacks, &vertices, &normals, &nVert);

  if (nVert == 0) return;

  /* First, generate vertex index arrays for drawing with glDrawElements
   * All stacks, including top and bottom are covered with a triangle
   * strip.
   */
  GLushort* stripIdx;
  // create index vector
  int offset;

  // allocate buffers for indices, bail out if memory allocation fails
  stripIdx = cast(GLushort*)malloc((slices+1)*2*(stacks+2)*GLushort.sizeof); // stacks+2 because of closing off bottom and top
  if (stripIdx is null) assert(0, "out of memory");

  // top stack
  for (j = 0, idx = 0; j < slices; ++j, idx += 2) {
    stripIdx[idx+0] = 0;
    stripIdx[idx+1] = cast(GLushort)(j+1); // 0 is top vertex, 1 is first for first stack
  }
  stripIdx[idx+0] = 0; // repeat first slice's idx for closing off shape
  stripIdx[idx+1] = 1;
  idx += 2;

  // middle stacks
  // strip indices are relative to first index belonging to strip, NOT relative to first vertex/normal pair in array
  for (i = 0; i < stacks; ++i, idx += 2) {
    offset = 1+(i+1)*slices; // triangle_strip indices start at 1 (0 is top vertex), and we advance one stack down as we go along
    for (j = 0; j < slices; ++j, idx += 2) {
      stripIdx[idx+0] = cast(GLushort)(offset+j);
      stripIdx[idx+1] = cast(GLushort)(offset+j+slices);
    }
    stripIdx[idx+0] = cast(GLushort)(offset); // repeat first slice's idx for closing off shape
    stripIdx[idx+1] = cast(GLushort)(offset+slices);
  }

  // top stack
  offset = 1+(stacks+2)*slices;
  for (j = 0; j < slices; ++j, idx += 2) {
    stripIdx[idx+0] = cast(GLushort)(offset+j);
    stripIdx[idx+1] = cast(GLushort)(nVert-1); // zero based index, last element in array (bottom vertex)...
  }
  stripIdx[idx+0] = cast(GLushort)(offset);
  stripIdx[idx+1] = cast(GLushort)(nVert-1); // repeat first slice's idx for closing off shape

  // draw
  fghDrawGeometrySolid(vertices, normals, null, nVert, stripIdx, stacks+2, (slices+1)*2);

  // cleanup allocated memory
  free(stripIdx);

  // cleanup allocated memory
  free(vertices);
  free(normals);
}


public void oglShapeSolidTorus() (GLfloat dInnerRadius, GLfloat dOuterRadius, GLint nSides, GLint nRings) {
  import core.stdc.stdlib : malloc, free;
  import std.math;

  int i, j, idx, nVert;
  GLfloat* vertices, normals;

  // generate vertices and normals
  fghGenerateTorus(dInnerRadius, dOuterRadius, nSides, nRings, &vertices, &normals, &nVert);

  if (nVert == 0) return;

  /* First, generate vertex index arrays for drawing with glDrawElements
   * All stacks, including top and bottom are covered with a triangle
   * strip.
   */
  GLushort* stripIdx;

  /* Allocate buffers for indices, bail out if memory allocation fails */
  stripIdx = cast(GLushort*)malloc((nRings+1)*2*nSides*GLushort.sizeof);
  if (stripIdx is null) assert(0, "out of memory");

  for (i = 0, idx = 0; i < nSides; ++i) {
    int ioff = 1;
    if (i == nSides-1) ioff = -i;
    for (j = 0; j < nRings; ++j, idx += 2) {
      int offset = j*nSides+i;
      stripIdx[idx+0] = cast(GLushort)(offset);
      stripIdx[idx+1] = cast(GLushort)(offset+ioff);
    }
    // repeat first to close off shape
    stripIdx[idx+0] = cast(GLushort)(i);
    stripIdx[idx+1] = cast(GLushort)(i+ioff);
    idx += 2;
  }

  // draw
  fghDrawGeometrySolid(vertices, normals, null, nVert, stripIdx, nSides, (nRings+1)*2);

  // cleanup allocated memory
  free(stripIdx);

  // cleanup allocated memory
  free(vertices);
  free(normals);
}
