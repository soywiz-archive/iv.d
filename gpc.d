/**
Generic Polygon Clipper

A new algorithm for calculating the difference, intersection,
exclusive-or or union of arbitrary polygon sets.

Written by Alan Murta (email: gpc@cs.man.ac.uk)

[http://www.cs.man.ac.uk/~toby/alan/software/|Original GPC site].

Current version is 2.33 (21st May 2014).

Ported to D by Ketmar // Invisible Vector.

GPC is using standard libc `malloc()`, `realloc()` and `free()` functions
to manage memory.

Copyright (C) Advanced Interfaces Group, University of Manchester.

This software is free for non-commercial use. It may be copied,
modified, and redistributed provided that this copyright notice
is preserved on all copies. The intellectual property rights of
the algorithms used reside with the University of Manchester
Advanced Interfaces Group.

You may not use this software, in whole or in part, in support
of any commercial product without the express consent of the
author.

There is no warranty or other guarantee of fitness of this
software for any purpose. It is provided solely "as is".
*/
module iv.gpc;
private nothrow @trusted @nogc:

/*
===========================================================================
                               Constants
===========================================================================
*/

private enum DBL_EPSILON = double.epsilon; //cast(double)2.2204460492503131e-16;

version(gpc_use_custom_epsilon) {
  public double GPC_EPSILON = DBL_EPSILON; /// Increase GPC_EPSILON to encourage merging of near coincident edges
} else {
  public enum GPC_EPSILON = DBL_EPSILON; /// Increase GPC_EPSILON to encourage merging of near coincident edges
}

public bool GPC_INVERT_TRISTRIPS = false;

version(gpc_use_custom_epsilon) {
  /// Compares two floating point numbers using [GPC_EPSILON] as epsilon value.
  public bool gpc_eq (in double a, in double b) nothrow @safe @nogc { pragma(inline, true); import std.math; return (abs(a-b) <= GPC_EPSILON); }
} else {
  /// Compares two floating point numbers using [GPC_EPSILON] as epsilon value.
  public bool gpc_eq (in double a, in double b) pure nothrow @safe @nogc { pragma(inline, true); import std.math; return (abs(a-b) <= GPC_EPSILON); }
}


/*
===========================================================================
                           Public Data Types
===========================================================================
*/

/// Set operation type
public enum GPC {
  Diff, /// Difference
  Int, /// Intersection
  Xor, /// Exclusive or
  Union, /// Union
}

/// Polygon vertex structure
public struct gpc_vertex {
  double x; /// vertex x component
  double y; /// vertex y component
}

/// Vertex list structure
public struct gpc_vertex_list {
  int num_vertices; /// Number of vertices in list
  gpc_vertex* vertex; /// Vertex array pointer
}

/// Polygon set structure
public struct gpc_polygon {
  int num_contours; /// Number of contours in polygon
  int* hole; /// Hole / external contour flags
  gpc_vertex_list* contour; /// Contour array pointer
}

/// Tristrip set structure
public struct gpc_tristrip {
  int num_strips; /// Number of tristrips
  gpc_vertex_list* strip; /// Tristrip array pointer
}


private:
/*
===========================================================================
                                Constants
===========================================================================
*/

enum LEFT = 0;
enum RIGHT = 1;

enum ABOVE = 0;
enum BELOW = 1;

enum CLIP = 0;
enum SUBJ = 1;


/*
===========================================================================
                                 Macros
===========================================================================
*/

version(gpc_use_custom_epsilon) {
  bool EQ(T) (in T a, in T b) nothrow @safe @nogc { pragma(inline, true); import std.math; return (abs(a-b) <= GPC_EPSILON); }
} else {
  bool EQ(T) (in T a, in T b) pure nothrow @safe @nogc { pragma(inline, true); import std.math; return (abs(a-b) <= GPC_EPSILON); }
}

T PREV_INDEX(T) (in T i, in T n) pure nothrow @safe @nogc { pragma(inline, true); return (i-1+n)%n; }
T NEXT_INDEX(T) (in T i, in T n) pure nothrow @safe @nogc { pragma(inline, true); return (i+1)%n; }

bool OPTIMAL(TV, T) (const(TV)* v, in T i, in T n) pure nothrow @trusted @nogc { pragma(inline, true); return ((v[PREV_INDEX(i, n)].y != v[i].y) || (v[NEXT_INDEX(i, n)].y != v[i].y)); }

bool FWD_MIN(TV, T) (const(TV)* v, in T i, in T n) pure nothrow @trusted @nogc { pragma(inline, true); return ((v[PREV_INDEX(i, n)].vertex.y >= v[i].vertex.y) && (v[NEXT_INDEX(i, n)].vertex.y > v[i].vertex.y)); }

bool NOT_FMAX(TV, T) (const(TV)* v, in T i, in T n) pure nothrow @trusted @nogc { pragma(inline, true); return (v[NEXT_INDEX(i, n)].vertex.y > v[i].vertex.y); }

bool REV_MIN(TV, T) (const(TV)* v, in T i, in T n) pure nothrow @trusted @nogc { pragma(inline, true); return ((v[PREV_INDEX(i, n)].vertex.y > v[i].vertex.y) && (v[NEXT_INDEX(i, n)].vertex.y >= v[i].vertex.y)); }

bool NOT_RMAX(TV, T) (const(TV)* v, in T i, in T n) pure nothrow @trusted @nogc { pragma(inline, true); return (v[PREV_INDEX(i, n)].vertex.y > v[i].vertex.y); }

void VERTEX(T) (ref edge_node* e, in int p, in int s, in T x, in T y) nothrow @trusted @nogc { pragma(inline, true); add_vertex(&((e).outp[(p)].v[(s)]), x, y); (e).outp[(p)].active++; }

void P_EDGE(T) (ref edge_node* d, ref edge_node* e, in int p, ref T i, in T j) nothrow @trusted @nogc {
  (d)= (e);
  do { (d)= (d).prev; } while (!(d).outp[(p)]);
  (i)= (d).bot.x + (d).dx * ((j)-(d).bot.y);
}

void N_EDGE(T) (ref edge_node* d, ref edge_node* e, in int p, ref T i, in T j) nothrow @trusted @nogc {
  (d) = (e);
  do { (d)= (d).next; } while (!(d).outp[(p)]);
  (i) = (d).bot.x + (d).dx * ((j)-(d).bot.y);
}


T* MALLOC(T) (uint count=1) nothrow @trusted @nogc {
  import core.stdc.stdlib : malloc;
  static assert(T.sizeof > 0);
  if (count == 0) return null;
  if (count >= int.max/4/T.sizeof) assert(0, "gpc malloc failure");
  T* p = cast(T*)malloc(T.sizeof*count);
  if (p is null) assert(0, "gpc malloc failure");
  return p;
}

void REALLOC(T) (ref T* p, uint count) nothrow @trusted @nogc {
  import core.stdc.stdlib : free, realloc;
  if (p is null) {
    if (count != 0) p = MALLOC!T(count);
  } else if (count == 0) {
    if (p !is null) {
      free(p);
      p = null;
    }
  } else {
    static assert(T.sizeof > 0);
    assert(count > 0);
    if (count >= int.max/4/T.sizeof) assert(0, "gpc malloc failure");
    T* np = cast(T*)realloc(p, T.sizeof*count);
    if (np is null) assert(0, "gpc malloc failure");
    p = np;
  }
}

void FREE(T) (ref T* ptr) nothrow @trusted @nogc {
  import core.stdc.stdlib : free;
  if (ptr !is null) { free(ptr); ptr = null; }
}


/*
===========================================================================
                            Private Data Types
===========================================================================
*/

// Edge intersection classes
alias vertex_type = int;
enum : uint {
  NUL, // Empty non-intersection
  EMX, // External maximum
  ELI, // External left intermediate
  TED, // Top edge
  ERI, // External right intermediate
  RED, // Right edge
  IMM, // Internal maximum and minimum
  IMN, // Internal minimum
  EMN, // External minimum
  EMM, // External maximum and minimum
  LED, // Left edge
  ILI, // Internal left intermediate
  BED, // Bottom edge
  IRI, // Internal right intermediate
  IMX, // Internal maximum
  FUL, // Full non-intersection
}

// Horizontal edge states
alias h_state = int;
enum : int {
  NH, // No horizontal edge
  BH, // Bottom horizontal edge
  TH, // Top horizontal edge
}

// Edge bundle state
alias bundle_state = int;
enum : int {
  UNBUNDLED, // Isolated edge not within a bundle
  BUNDLE_HEAD, // Bundle head node
  BUNDLE_TAIL, // Passive bundle tail node
}

// Internal vertex list datatype
//alias v_shape = vertex_node;
struct vertex_node {
  double x; // X coordinate component
  double y; // Y coordinate component
  vertex_node* next; // Pointer to next vertex in list
}

//p_shape
// Internal contour / tristrip type
struct polygon_node {
  int active; // Active flag / vertex count
  int hole; // Hole / external contour flag
  vertex_node*[2] v; // Left and right vertex list ptrs
  polygon_node* next; // Pointer to next polygon contour
  polygon_node* proxy; // Pointer to actual structure used
}

// edge_shape
struct edge_node {
  gpc_vertex vertex; // Piggy-backed contour vertex data
  gpc_vertex bot; // Edge lower (x, y) coordinate
  gpc_vertex top; // Edge upper (x, y) coordinate
  double xb; // Scanbeam bottom x coordinate
  double xt; // Scanbeam top x coordinate
  double dx; // Change in x for a unit y increase
  int type; // Clip / subject edge flag
  int[2][2] bundle; // Bundle edge flags
  int[2] bside; // Bundle left / right indicators
  bundle_state[2] bstate; // Edge bundle state
  polygon_node*[2] outp; // Output polygon / tristrip pointer
  edge_node* prev; // Previous edge in the AET
  edge_node* next; // Next edge in the AET
  edge_node* pred; // Edge connected at the lower end
  edge_node* succ; // Edge connected at the upper end
  edge_node* next_bound; // Pointer to next bound in LMT
}

// lmt_shape
// Local minima table
struct lmt_node {
  double y; // Y coordinate at local minimum
  edge_node* first_bound; // Pointer to bound list
  lmt_node* next; // Pointer to next local minimum
}

// sbt_t_shape
// Scanbeam tree
struct sb_tree {
  double y; // Scanbeam node y value
  sb_tree* less; // Pointer to nodes with lower y
  sb_tree* more; // Pointer to nodes with higher y
}

// it_shape
// Intersection table
struct it_node {
  edge_node*[2] ie; // Intersecting edge (bundle) pair
  gpc_vertex point; // Point of intersection
  it_node* next; // The next intersection table node
}

// st_shape
// Sorted edge table
struct st_node {
  edge_node* edge; // Pointer to AET edge
  double xb; // Scanbeam bottom x coordinate
  double xt; // Scanbeam top x coordinate
  double dx; // Change in x for a unit y increase
  st_node* prev; // Previous edge in sorted list
}

// bbox_shape
// Contour axis-aligned bounding box
struct bbox {
  double xmin; // Minimum x coordinate
  double ymin; // Minimum y coordinate
  double xmax; // Maximum x coordinate
  double ymax; // Maximum y coordinate
}


/*
===========================================================================
                               Global Data
===========================================================================
*/

// Horizontal edge state transitions within scanbeam boundary
static immutable h_state[6][3] next_h_state= [
  /*        ABOVE     BELOW     CROSS */
  /*        L   R     L   R     L   R */
  /* NH */ [BH, TH,   TH, BH,   NH, NH],
  /* BH */ [NH, NH,   NH, NH,   TH, TH],
  /* TH */ [NH, NH,   NH, NH,   BH, BH],
];


/*
===========================================================================
                             Private Functions
===========================================================================
*/

private void reset_it (it_node** it) {
  while (*it) {
    it_node* itn = (*it).next;
    FREE(*it);
    *it = itn;
  }
}


private void reset_lmt (lmt_node** lmt) {
  while (*lmt) {
    lmt_node* lmtn = (*lmt).next;
    FREE(*lmt);
    *lmt= lmtn;
  }
}


private void insert_bound (edge_node** b, edge_node* e) {
  edge_node* existing_bound;

  if (!*b) {
    // Link node e to the tail of the list
    *b = e;
  } else {
    // Do primary sort on the x field
    if (e[0].bot.x < (*b)[0].bot.x) {
      // Insert a new node mid-list
      existing_bound = *b;
      *b = e;
      (*b).next_bound = existing_bound;
    } else {
      if (e[0].bot.x == (*b)[0].bot.x) {
        // Do secondary sort on the dx field
        if (e[0].dx < (*b)[0].dx) {
          // Insert a new node mid-list
          existing_bound = *b;
          *b = e;
          (*b).next_bound = existing_bound;
        } else {
          // Head further down the list
          insert_bound(&((*b).next_bound), e);
        }
      } else {
        // Head further down the list
        insert_bound(&((*b).next_bound), e);
      }
    }
  }
}


private edge_node** bound_list (lmt_node** lmt, double y) {
  lmt_node* existing_node;

  if (!*lmt) {
    // Add node onto the tail end of the LMT
    *lmt = MALLOC!lmt_node();
    (*lmt).y = y;
    (*lmt).first_bound = null;
    (*lmt).next = null;
    return &((*lmt).first_bound);
  } else if (y < (*lmt).y) {
    // Insert a new LMT node before the current node
    existing_node = *lmt;
    *lmt = MALLOC!lmt_node();
    (*lmt).y = y;
    (*lmt).first_bound = null;
    (*lmt).next = existing_node;
    return &((*lmt).first_bound);
  } else if (y > (*lmt).y) {
    // Head further up the LMT
    return bound_list(&((*lmt).next), y);
  } else {
    // Use this existing LMT node
    return &((*lmt).first_bound);
  }
}


private void add_to_sbtree (int* entries, sb_tree** sbtree, double y) {
  if (!*sbtree) {
    // Add a new tree node here
    *sbtree = MALLOC!sb_tree();
    (*sbtree).y = y;
    (*sbtree).less = null;
    (*sbtree).more = null;
    ++(*entries);
  } else {
    if ((*sbtree).y > y) {
      // Head into the 'less' sub-tree
      add_to_sbtree(entries, &((*sbtree).less), y);
    } else {
      if ((*sbtree).y < y) {
        // Head into the 'more' sub-tree
        add_to_sbtree(entries, &((*sbtree).more), y);
      }
    }
  }
}


private void build_sbt (int* entries, double* sbt, sb_tree* sbtree) {
  if (sbtree.less) build_sbt(entries, sbt, sbtree.less);
  sbt[*entries]= sbtree.y;
  ++(*entries);
  if (sbtree.more) build_sbt(entries, sbt, sbtree.more);
}


private void free_sbtree (sb_tree** sbtree) {
  if (*sbtree) {
    free_sbtree(&((*sbtree).less));
    free_sbtree(&((*sbtree).more));
    FREE(*sbtree);
  }
}


private int count_optimal_vertices (gpc_vertex_list c) {
  int result = 0;
  // Ignore non-contributing contours
  if (c.num_vertices > 0) {
    foreach (immutable int i; 0..c.num_vertices) {
      // Ignore superfluous vertices embedded in horizontal edges
      if (OPTIMAL(c.vertex, i, c.num_vertices)) ++result;
    }
  }
  return result;
}


private edge_node* build_lmt (lmt_node** lmt, sb_tree** sbtree, int* sbt_entries, gpc_polygon* p, int type, GPC op) {
  int min, max, num_edges, v, num_vertices;
  int total_vertices = 0, e_index = 0;
  edge_node* e, edge_table;

  foreach (immutable int c; 0..p.num_contours) total_vertices += count_optimal_vertices(p.contour[c]);

  // Create the entire input polygon edge table in one go
  edge_table = MALLOC!edge_node(total_vertices);

  foreach (immutable int c; 0..p.num_contours) {
    if (p.contour[c].num_vertices < 0) {
      // Ignore the non-contributing contour and repair the vertex count
      p.contour[c].num_vertices = -p.contour[c].num_vertices;
    } else {
      // Perform contour optimisation
      num_vertices = 0;
      foreach (immutable int i; 0..p.contour[c].num_vertices) {
        if (OPTIMAL(p.contour[c].vertex, i, p.contour[c].num_vertices)) {
          edge_table[num_vertices].vertex.x = p.contour[c].vertex[i].x;
          edge_table[num_vertices].vertex.y = p.contour[c].vertex[i].y;
          // Record vertex in the scanbeam table
          add_to_sbtree(sbt_entries, sbtree, edge_table[num_vertices].vertex.y);
          ++num_vertices;
        }
      }

      // Do the contour forward pass
      for (min = 0; min < num_vertices; ++min) {
        // If a forward local minimum...
        if (FWD_MIN(edge_table, min, num_vertices)) {
          // Search for the next local maximum...
          num_edges = 1;
          max = NEXT_INDEX(min, num_vertices);
          while (NOT_FMAX(edge_table, max, num_vertices)) {
            ++num_edges;
            max = NEXT_INDEX(max, num_vertices);
          }

          // Build the next edge list
          e = &edge_table[e_index];
          e_index += num_edges;
          v = min;
          e[0].bstate[BELOW] = UNBUNDLED;
          e[0].bundle[BELOW][CLIP] = false;
          e[0].bundle[BELOW][SUBJ] = false;
          foreach (immutable int i; 0..num_edges) {
            e[i].xb = edge_table[v].vertex.x;
            e[i].bot.x = edge_table[v].vertex.x;
            e[i].bot.y = edge_table[v].vertex.y;

            v = NEXT_INDEX(v, num_vertices);

            e[i].top.x = edge_table[v].vertex.x;
            e[i].top.y = edge_table[v].vertex.y;
            e[i].dx = (edge_table[v].vertex.x - e[i].bot.x) / (e[i].top.y - e[i].bot.y);
            e[i].type = type;
            e[i].outp[ABOVE] = null;
            e[i].outp[BELOW] = null;
            e[i].next = null;
            e[i].prev = null;
            e[i].succ = ((num_edges > 1) && (i < (num_edges - 1))) ? &(e[i + 1]) : null;
            e[i].pred = ((num_edges > 1) && (i > 0)) ? &(e[i - 1]) : null;
            e[i].next_bound = null;
            e[i].bside[CLIP] = (op == GPC.Diff ? RIGHT : LEFT);
            e[i].bside[SUBJ] = LEFT;
          }
          insert_bound(bound_list(lmt, edge_table[min].vertex.y), e);
        }
      }

      // Do the contour reverse pass
      for (min = 0; min < num_vertices; ++min) {
        // If a reverse local minimum...
        if (REV_MIN(edge_table, min, num_vertices)) {
          // Search for the previous local maximum...
          num_edges = 1;
          max = PREV_INDEX(min, num_vertices);
          while (NOT_RMAX(edge_table, max, num_vertices)) {
            ++num_edges;
            max = PREV_INDEX(max, num_vertices);
          }

          // Build the previous edge list
          e = &edge_table[e_index];
          e_index += num_edges;
          v = min;
          e[0].bstate[BELOW] = UNBUNDLED;
          e[0].bundle[BELOW][CLIP] = false;
          e[0].bundle[BELOW][SUBJ] = false;
          foreach (immutable i; 0..num_edges) {
            e[i].xb = edge_table[v].vertex.x;
            e[i].bot.x = edge_table[v].vertex.x;
            e[i].bot.y = edge_table[v].vertex.y;

            v = PREV_INDEX(v, num_vertices);

            e[i].top.x = edge_table[v].vertex.x;
            e[i].top.y = edge_table[v].vertex.y;
            e[i].dx = (edge_table[v].vertex.x - e[i].bot.x) / (e[i].top.y - e[i].bot.y);
            e[i].type = type;
            e[i].outp[ABOVE] = null;
            e[i].outp[BELOW] = null;
            e[i].next = null;
            e[i].prev = null;
            e[i].succ = ((num_edges > 1) && (i < (num_edges - 1))) ? &(e[i + 1]) : null;
            e[i].pred = ((num_edges > 1) && (i > 0)) ? &(e[i - 1]) : null;
            e[i].next_bound = null;
            e[i].bside[CLIP] = (op == GPC.Diff ? RIGHT : LEFT);
            e[i].bside[SUBJ] = LEFT;
          }
          insert_bound(bound_list(lmt, edge_table[min].vertex.y), e);
        }
      }
    }
  }
  return edge_table;
}


private void add_edge_to_aet (edge_node** aet, edge_node* edge, edge_node* prev) {
  if (!*aet) {
    // Append edge onto the tail end of the AET
    *aet = edge;
    edge.prev = prev;
    edge.next = null;
  } else {
    // Do primary sort on the xb field
    if (edge.xb < (*aet).xb) {
      // Insert edge here (before the AET edge)
      edge.prev = prev;
      edge.next = *aet;
      (*aet).prev = edge;
      *aet = edge;
    } else {
      if (edge.xb == (*aet).xb) {
        // Do secondary sort on the dx field
        if (edge.dx < (*aet).dx) {
          // Insert edge here (before the AET edge)
          edge.prev = prev;
          edge.next = *aet;
          (*aet).prev = edge;
          *aet = edge;
        } else {
          // Head further into the AET
          add_edge_to_aet(&((*aet).next), edge, *aet);
        }
      } else {
        // Head further into the AET
        add_edge_to_aet(&((*aet).next), edge, *aet);
      }
    }
  }
}


private void add_intersection (it_node** it, edge_node* edge0, edge_node* edge1, double x, double y) {
  it_node* existing_node;

  if (!*it) {
    // Append a new node to the tail of the list
    *it = MALLOC!it_node();
    (*it).ie[0] = edge0;
    (*it).ie[1] = edge1;
    (*it).point.x = x;
    (*it).point.y = y;
    (*it).next = null;
  } else {
    if ((*it).point.y > y) {
      // Insert a new node mid-list
      existing_node = *it;
      *it = MALLOC!it_node();
      (*it).ie[0] = edge0;
      (*it).ie[1] = edge1;
      (*it).point.x = x;
      (*it).point.y = y;
      (*it).next = existing_node;
    } else {
      // Head further down the list
      add_intersection(&((*it).next), edge0, edge1, x, y);
    }
  }
}


private void add_st_edge (st_node** st, it_node** it, edge_node* edge, double dy) {
  import std.math : abs;

  st_node* existing_node;
  double den, r, x, y;

  if (!*st) {
    // Append edge onto the tail end of the ST
    *st = MALLOC!st_node();
    (*st).edge = edge;
    (*st).xb = edge.xb;
    (*st).xt = edge.xt;
    (*st).dx = edge.dx;
    (*st).prev = null;
  } else {
    den = ((*st).xt - (*st).xb) - (edge.xt - edge.xb);

    // If new edge and ST edge don't cross
    if (edge.xt >= (*st).xt || edge.dx == (*st).dx || abs(den) <= DBL_EPSILON) {
      // No intersection - insert edge here (before the ST edge)
      existing_node = *st;
      *st = MALLOC!st_node();
      (*st).edge = edge;
      (*st).xb = edge.xb;
      (*st).xt = edge.xt;
      (*st).dx = edge.dx;
      (*st).prev = existing_node;
    } else {
      // Compute intersection between new edge and ST edge
      r = (edge.xb - (*st).xb) / den;
      x = (*st).xb + r * ((*st).xt - (*st).xb);
      y = r * dy;

      // Insert the edge pointers and the intersection point in the IT
      add_intersection(it, (*st).edge, edge, x, y);

      // Head further into the ST
      add_st_edge(&((*st).prev), it, edge, dy);
    }
  }
}


private void build_intersection_table (it_node** it, edge_node* aet, double dy) {
  st_node* st, stp;
  edge_node* edge;

  // Build intersection table for the current scanbeam
  reset_it(it);
  st = null;

  // Process each AET edge
  for (edge = aet; edge !is null; edge = edge.next) {
    if (edge.bstate[ABOVE] == BUNDLE_HEAD || edge.bundle[ABOVE][CLIP] || edge.bundle[ABOVE][SUBJ]) {
      add_st_edge(&st, it, edge, dy);
    }
  }

  // Free the sorted edge table
  while (st !is null) {
    stp = st.prev;
    FREE(st);
    st = stp;
  }
}


private void swap_intersecting_edge_bundles (edge_node** aet, it_node* intersect) {
  edge_node* e0 = intersect.ie[0];
  edge_node* e1 = intersect.ie[1];
  edge_node* e0t = e0;
  edge_node* e1t = e1;
  edge_node* e0n = e0.next;
  edge_node* e1n = e1.next;

  // Find the node before the e0 bundle
  edge_node* e0p = e0.prev;
  if (e0.bstate[ABOVE] == BUNDLE_HEAD) {
    do {
      e0t = e0p;
      e0p = e0p.prev;
    } while (e0p && (e0p.bstate[ABOVE] == BUNDLE_TAIL));
  }

  // Find the node before the e1 bundle
  edge_node* e1p = e1.prev;
  if (e1.bstate[ABOVE] == BUNDLE_HEAD) {
    do {
      e1t = e1p;
      e1p = e1p.prev;
    } while (e1p && (e1p.bstate[ABOVE] == BUNDLE_TAIL));
  }

  // Swap the e0p and e1p links
  if (e0p) {
    if (e1p) {
      if (e0p !is e1) {
        e0p.next = e1t;
        e1t.prev = e0p;
      }
      if (e1p !is e0) {
        e1p.next = e0t;
        e0t.prev = e1p;
      }
    } else {
      if (e0p !is e1) {
        e0p.next = e1t;
        e1t.prev = e0p;
      }
      *aet = e0t;
      e0t.prev = null;
    }
  } else {
    if (e1p !is e0) {
      e1p.next = e0t;
      e0t.prev = e1p;
    }
    *aet = e1t;
    e1t.prev = null;
  }

  // Re-link after e0
  if (e0p !is e1) {
    e0.next = e1n;
    if (e1n) e1n.prev = e0;
  } else {
    e0.next = e1t;
    e1t.prev = e0;
  }

  // Re-link after e1
  if (e1p !is e0) {
    e1.next = e0n;
    if (e0n) e0n.prev = e1;
  } else {
    e1.next = e0t;
    e0t.prev = e1;
  }
}


private int count_contours (polygon_node* polygon) {
  int nc, nv;
  vertex_node* v, nextv;

  for (nc = 0; polygon !is null; polygon = polygon.next) {
    if (polygon.active) {
      // Count the vertices in the current contour
      nv = 0;
      for (v= polygon.proxy.v[LEFT]; v; v= v.next) ++nv;

      // Record valid vertex counts in the active field
      if (nv > 2) {
        polygon.active= nv;
        ++nc;
      } else {
        // Invalid contour: just free the heap
        for (v = polygon.proxy.v[LEFT]; v !is null; v = nextv) {
          nextv = v.next;
          FREE(v);
        }
        polygon.active = 0;
      }
    }
  }

  return nc;
}


private void add_left (polygon_node* p, double x, double y) {
  vertex_node* nv;

  // Create a new vertex node and set its fields
  nv = MALLOC!vertex_node();
  nv.x = x;
  nv.y = y;

  // Add vertex nv to the left end of the polygon's vertex list
  nv.next = p.proxy.v[LEFT];

  // Update proxy.[LEFT] to point to nv
  p.proxy.v[LEFT] = nv;
}


private void merge_left (polygon_node* p, polygon_node* q, polygon_node* list) {
  polygon_node* target;

  // Label contour as a hole
  q.proxy.hole = true;

  if (p.proxy !is q.proxy) {
    // Assign p's vertex list to the left end of q's list
    p.proxy.v[RIGHT].next = q.proxy.v[LEFT];
    q.proxy.v[LEFT] = p.proxy.v[LEFT];

    // Redirect any p.proxy references to q.proxy
    for (target = p.proxy; list !is null; list = list.next) {
      if (list.proxy is target) {
        list.active = false;
        list.proxy = q.proxy;
      }
    }
  }
}


private void add_right (polygon_node* p, double x, double y) {
  vertex_node* nv;

  // Create a new vertex node and set its fields
  nv = MALLOC!vertex_node();
  nv.x = x;
  nv.y = y;
  nv.next = null;

  // Add vertex nv to the right end of the polygon's vertex list
  p.proxy.v[RIGHT].next = nv;

  // Update proxy.v[RIGHT] to point to nv
  p.proxy.v[RIGHT] = nv;
}


private void merge_right (polygon_node* p, polygon_node* q, polygon_node* list) {
  polygon_node* target;

  // Label contour as external
  q.proxy.hole = false;

  if (p.proxy !is q.proxy) {
    // Assign p's vertex list to the right end of q's list
    q.proxy.v[RIGHT].next = p.proxy.v[LEFT];
    q.proxy.v[RIGHT] = p.proxy.v[RIGHT];

    // Redirect any p.proxy references to q.proxy
    for (target = p.proxy; list !is null; list = list.next) {
      if (list.proxy is target) {
        list.active = false;
        list.proxy = q.proxy;
      }
    }
  }
}


private void add_local_min (polygon_node** p, edge_node* edge, double x, double y) {
  polygon_node* existing_min;
  vertex_node* nv;

  existing_min = *p;

  *p = MALLOC!polygon_node();

  // Create a new vertex node and set its fields
  nv = MALLOC!vertex_node();
  nv.x = x;
  nv.y = y;
  nv.next = null;

  // Initialise proxy to point to p itself
  (*p).proxy = (*p);
  (*p).active = true;
  (*p).next = existing_min;

  // Make v[LEFT] and v[RIGHT] point to new vertex nv
  (*p).v[LEFT] = nv;
  (*p).v[RIGHT] = nv;

  // Assign polygon p to the edge
  edge.outp[ABOVE] = *p;
}


private int count_tristrips (polygon_node* tn) {
  int total;
  for (total = 0; tn !is null; tn = tn.next) if (tn.active > 2) ++total;
  return total;
}


private void add_vertex (vertex_node** t, double x, double y) {
  if (!(*t)) {
    *t = MALLOC!vertex_node();
    (*t).x = x;
    (*t).y = y;
    (*t).next = null;
  } else {
    // Head further down the list
    add_vertex(&((*t).next), x, y);
  }
}


private void new_tristrip (polygon_node** tn, edge_node* edge, double x, double y) {
  if (!(*tn)) {
    *tn = MALLOC!polygon_node();
    (*tn).next = null;
    (*tn).v[LEFT] = null;
    (*tn).v[RIGHT] = null;
    (*tn).active = 1;
    add_vertex(&((*tn).v[LEFT]), x, y);
    edge.outp[ABOVE] = *tn;
  } else {
    // Head further down the list
    new_tristrip(&((*tn).next), edge, x, y);
  }
}


private bbox* create_contour_bboxes (gpc_polygon* p) {
  bbox* box = MALLOC!bbox(p.num_contours);

  // Construct contour bounding boxes
  foreach (immutable int c; 0..p.num_contours) {
    // Initialise bounding box extent
    box[c].xmin = double.max;
    box[c].ymin = double.max;
    box[c].xmax = -double.max;
    box[c].ymax = -double.max;

    foreach (immutable int v; 0..p.contour[c].num_vertices) {
      // Adjust bounding box
      if (p.contour[c].vertex[v].x < box[c].xmin) box[c].xmin = p.contour[c].vertex[v].x;
      if (p.contour[c].vertex[v].y < box[c].ymin) box[c].ymin = p.contour[c].vertex[v].y;
      if (p.contour[c].vertex[v].x > box[c].xmax) box[c].xmax = p.contour[c].vertex[v].x;
      if (p.contour[c].vertex[v].y > box[c].ymax) box[c].ymax = p.contour[c].vertex[v].y;
    }
  }

  return box;
}


private void minimax_test (gpc_polygon* subj, gpc_polygon* clip, GPC op) {
  bbox* s_bbox, c_bbox;
  int overlap;
  int* o_table;

  s_bbox = create_contour_bboxes(subj);
  c_bbox = create_contour_bboxes(clip);

  o_table = MALLOC!int(subj.num_contours*clip.num_contours);

  // Check all subject contour bounding boxes against clip boxes
  foreach (immutable int s; 0..subj.num_contours) {
    foreach (immutable int c; 0..clip.num_contours) {
      o_table[c*subj.num_contours + s] =
             (!((s_bbox[s].xmax < c_bbox[c].xmin) ||
                (s_bbox[s].xmin > c_bbox[c].xmax))) &&
             (!((s_bbox[s].ymax < c_bbox[c].ymin) ||
                (s_bbox[s].ymin > c_bbox[c].ymax)));
    }
  }

  // For each clip contour, search for any subject contour overlaps
  foreach (immutable int c; 0..clip.num_contours) {
    overlap = 0;
    for (int s = 0; !overlap && s < subj.num_contours; ++s) overlap = o_table[c * subj.num_contours + s];
    // Flag non contributing status by negating vertex count
    if (!overlap) clip.contour[c].num_vertices = -clip.contour[c].num_vertices;
  }

  if (op == GPC.Int) {
    // For each subject contour, search for any clip contour overlaps
    foreach (immutable int s; 0..subj.num_contours) {
      overlap = 0;
      for (int c = 0; !overlap && c < clip.num_contours; ++c) overlap = o_table[c * subj.num_contours + s];
      // Flag non contributing status by negating vertex count
      if (!overlap) subj.contour[s].num_vertices = -subj.contour[s].num_vertices;
    }
  }

  FREE(s_bbox);
  FREE(c_bbox);
  FREE(o_table);
}


/*
===========================================================================
                             Public Functions
===========================================================================
*/

import core.stdc.stdio : FILE;

public void gpc_read_polygon() (FILE* fp, bool read_hole_flags, ref gpc_polygon p) {
  import core.stdc.stdio : fscanf;
  fscanf(fp, "%d", &(p.num_contours));
  p.hole = MALLOC!int(p.num_contours);
  p.contour = MALLOC!gpc_vertex_list(p.num_contours);
  foreach (immutable int c; 0..p.num_contours) {
    fscanf(fp, "%d", &(p.contour[c].num_vertices));
    if (read_hole_flags) {
      fscanf(fp, "%d", &(p.hole[c]));
    } else {
      p.hole[c] = false; // Assume all contours to be external
    }
    p.contour[c].vertex = MALLOC!gpc_vertex(p.contour[c].num_vertices);
    foreach (immutable int v; 0..p.contour[c].num_vertices) {
      fscanf(fp, "%lf %lf", &(p.contour[c].vertex[v].x), &(p.contour[c].vertex[v].y));
    }
  }
}

public void gpc_write_polygon() (FILE* fp, bool write_hole_flags, in ref gpc_polygon p) {
  import core.stdc.stdio : fprintf;
  fprintf(fp, "%d\n", p.num_contours);
  foreach (immutable int c; 0..p.num_contours) {
    fprintf(fp, "%d\n", p.contour[c].num_vertices);
    if (write_hole_flags) fprintf(fp, "%d\n", p.hole[c]);
    foreach (immutable int v; 0..p.contour[c].num_vertices) {
      fprintf(fp, "% .*lf % .*lf\n", double.dig, p.contour[c].vertex[v].x, double.dig, p.contour[c].vertex[v].y);
    }
  }
}


/// Frees allocated polygon memory. It is safe to call it on empty (but initialized) polygon.
public void gpc_free_polygon (ref gpc_polygon p) {
  foreach (immutable int c; 0..p.num_contours) FREE(p.contour[c].vertex);
  FREE(p.hole);
  FREE(p.contour);
  p.num_contours = 0;
}

/** Add new contour to the existing polygon.
 *
 * This function copies `new_contour` contents. But it reallocates quite inefficiently,
 * so you'd better build polys yourself.
 *
 * Contours with less than three points will not be added.
 *
 * Returns `true` if contour contains three or more points (i.e. it was added).
 */
public bool gpc_add_contour (ref gpc_polygon p, const(gpc_vertex)[] new_contour, bool hole=false) {
  import core.stdc.string : memcpy;

  if (new_contour.length < 3) return false;
  if (new_contour.length > int.max/8) assert(0, "out of memory");

  int c = p.num_contours;

  // allocate hole array with one more item
  REALLOC(p.hole, c+1);

  // allocate contour array with one more item
  REALLOC(p.contour, c+1);

  // copy the new contour and hole onto the end of the extended arrays
  p.hole[c] = hole;
  p.contour[c].num_vertices = cast(int)new_contour.length;
  p.contour[c].vertex = MALLOC!gpc_vertex(cast(uint)new_contour.length);
  memcpy(p.contour[c].vertex, new_contour.ptr, cast(uint)new_contour.length*gpc_vertex.sizeof);

  // Update the polygon information
  ++p.num_contours;

  return true;
}


/** Calculates clipping.
 *
 * [result] will be overwritten (so old contents won't be freed, and it may be uninitialized at all).
 */
public void gpc_polygon_clip (GPC op, ref gpc_polygon subj, ref gpc_polygon clip, ref gpc_polygon result) {
  sb_tree* sbtree = null;
  it_node* it = null, intersect;
  edge_node* edge, prev_edge, next_edge, succ_edge, e0, e1;
  edge_node* aet = null, c_heap = null, s_heap = null;
  lmt_node* lmt = null, local_min;
  polygon_node* out_poly = null, p, q, poly, npoly, cf = null;
  vertex_node* vtx, nv;
  h_state[2] horiz;
  int[2] inn, exists;
  int[2] parity = [LEFT, LEFT];
  int c, v, contributing, scanbeam = 0, sbt_entries = 0;
  int vclass, bl, br, tl, tr;
  double* sbt = null;
  double xb, px, yb, yt, dy, ix, iy;

  // Test for trivial NULL result cases
  if ((subj.num_contours == 0 && clip.num_contours == 0) ||
      (subj.num_contours == 0 && (op == GPC.Int || op == GPC.Diff)) ||
      (clip.num_contours == 0 && op == GPC.Int))
  {
    result.num_contours = 0;
    result.hole = null;
    result.contour = null;
    return;
  }

  // Identify potentialy contributing contours
  if ((op == GPC.Int || op == GPC.Diff) && subj.num_contours > 0 && clip.num_contours > 0) minimax_test(&subj, &clip, op);

  // Build LMT
  if (subj.num_contours > 0) s_heap = build_lmt(&lmt, &sbtree, &sbt_entries, &subj, SUBJ, op);
  if (clip.num_contours > 0) c_heap = build_lmt(&lmt, &sbtree, &sbt_entries, &clip, CLIP, op);

  // Return a NULL result if no contours contribute
  if (lmt is null) {
    result.num_contours = 0;
    result.hole = null;
    result.contour = null;
    reset_lmt(&lmt);
    FREE(s_heap);
    FREE(c_heap);
    return;
  }

  // Build scanbeam table from scanbeam tree
  sbt = MALLOC!double(sbt_entries);
  build_sbt(&scanbeam, sbt, sbtree);
  scanbeam = 0;
  free_sbtree(&sbtree);

  // Allow pointer re-use without causing memory leak
  if (&subj is &result) gpc_free_polygon(subj);
  if (&clip is &result) gpc_free_polygon(clip);

  // Invert clip polygon for difference operation
  if (op == GPC.Diff) parity[CLIP] = RIGHT;

  local_min = lmt;

  // Process each scanbeam
  while (scanbeam < sbt_entries) {
    // Set yb and yt to the bottom and top of the scanbeam
    yb = sbt[scanbeam++];
    if (scanbeam < sbt_entries) {
      yt = sbt[scanbeam];
      dy = yt - yb;
    }

    // === SCANBEAM BOUNDARY PROCESSING ================================

    // If LMT node corresponding to yb exists
    if (local_min) {
      if (local_min.y == yb) {
        // Add edges starting at this local minimum to the AET
        for (edge = local_min.first_bound; edge !is null; edge = edge.next_bound) add_edge_to_aet(&aet, edge, null);
        local_min = local_min.next;
      }
    }

    // Set dummy previous x value
    px = -double.max;

    // Create bundles within AET
    e0 = aet;
    e1 = aet;

    // Set up bundle fields of first edge
    aet.bundle[ABOVE][ aet.type] = (aet.top.y != yb);
    aet.bundle[ABOVE][!aet.type] = false;
    aet.bstate[ABOVE] = UNBUNDLED;

    for (next_edge = aet.next; next_edge !is null; next_edge = next_edge.next) {
      // Set up bundle fields of next edge
      next_edge.bundle[ABOVE][ next_edge.type] = (next_edge.top.y != yb);
      next_edge.bundle[ABOVE][!next_edge.type] = false;
      next_edge.bstate[ABOVE] = UNBUNDLED;

      // Bundle edges above the scanbeam boundary if they coincide
      if (next_edge.bundle[ABOVE][next_edge.type]) {
        if (EQ(e0.xb, next_edge.xb) && EQ(e0.dx, next_edge.dx) && e0.top.y != yb) {
          next_edge.bundle[ABOVE][ next_edge.type] ^= e0.bundle[ABOVE][ next_edge.type];
          next_edge.bundle[ABOVE][!next_edge.type] = e0.bundle[ABOVE][!next_edge.type];
          next_edge.bstate[ABOVE] = BUNDLE_HEAD;
          e0.bundle[ABOVE][CLIP] = false;
          e0.bundle[ABOVE][SUBJ] = false;
          e0.bstate[ABOVE] = BUNDLE_TAIL;
        }
        e0 = next_edge;
      }
    }

    horiz[CLIP] = NH;
    horiz[SUBJ] = NH;

    // Process each edge at this scanbeam boundary
    for (edge = aet; edge !is null; edge = edge.next) {
      exists[CLIP] = edge.bundle[ABOVE][CLIP] + (edge.bundle[BELOW][CLIP] << 1);
      exists[SUBJ] = edge.bundle[ABOVE][SUBJ] + (edge.bundle[BELOW][SUBJ] << 1);

      if (exists[CLIP] || exists[SUBJ]) {
        // Set bundle side
        edge.bside[CLIP] = parity[CLIP];
        edge.bside[SUBJ] = parity[SUBJ];

        // Determine contributing status and quadrant occupancies
        switch (op) {
          case GPC.Diff:
          case GPC.Int:
            contributing = (exists[CLIP] && (parity[SUBJ] || horiz[SUBJ])) || (exists[SUBJ] && (parity[CLIP] || horiz[CLIP])) || (exists[CLIP] && exists[SUBJ] && (parity[CLIP] == parity[SUBJ]));
            br = (parity[CLIP]) && (parity[SUBJ]);
            bl = (parity[CLIP] ^ edge.bundle[ABOVE][CLIP]) && (parity[SUBJ] ^ edge.bundle[ABOVE][SUBJ]);
            tr = (parity[CLIP] ^ (horiz[CLIP] != NH)) && (parity[SUBJ] ^ (horiz[SUBJ] != NH));
            tl = (parity[CLIP] ^ (horiz[CLIP] != NH) ^ edge.bundle[BELOW][CLIP]) && (parity[SUBJ] ^ (horiz[SUBJ] != NH) ^ edge.bundle[BELOW][SUBJ]);
            break;
          case GPC.Xor:
            contributing = exists[CLIP] || exists[SUBJ];
            br = (parity[CLIP]) ^ (parity[SUBJ]);
            bl = (parity[CLIP] ^ edge.bundle[ABOVE][CLIP]) ^ (parity[SUBJ] ^ edge.bundle[ABOVE][SUBJ]);
            tr = (parity[CLIP] ^ (horiz[CLIP] != NH)) ^ (parity[SUBJ] ^ (horiz[SUBJ] != NH));
            tl = (parity[CLIP] ^ (horiz[CLIP] != NH) ^ edge.bundle[BELOW][CLIP]) ^ (parity[SUBJ] ^ (horiz[SUBJ] != NH) ^ edge.bundle[BELOW][SUBJ]);
            break;
          case GPC.Union:
            contributing = (exists[CLIP] && (!parity[SUBJ] || horiz[SUBJ])) || (exists[SUBJ] && (!parity[CLIP] || horiz[CLIP])) || (exists[CLIP] && exists[SUBJ] && (parity[CLIP] == parity[SUBJ]));
            br = (parity[CLIP]) || (parity[SUBJ]);
            bl = (parity[CLIP] ^ edge.bundle[ABOVE][CLIP]) || (parity[SUBJ] ^ edge.bundle[ABOVE][SUBJ]);
            tr = (parity[CLIP] ^ (horiz[CLIP] != NH)) || (parity[SUBJ] ^ (horiz[SUBJ] != NH));
            tl = (parity[CLIP] ^ (horiz[CLIP] != NH) ^ edge.bundle[BELOW][CLIP]) || (parity[SUBJ] ^ (horiz[SUBJ] != NH) ^ edge.bundle[BELOW][SUBJ]);
            break;
          default: assert(0);
        }

        // Update parity
        parity[CLIP] ^= edge.bundle[ABOVE][CLIP];
        parity[SUBJ] ^= edge.bundle[ABOVE][SUBJ];

        // Update horizontal state
        if (exists[CLIP]) horiz[CLIP] = next_h_state[horiz[CLIP]][((exists[CLIP] - 1) << 1) + parity[CLIP]];
        if (exists[SUBJ]) horiz[SUBJ] = next_h_state[horiz[SUBJ]][((exists[SUBJ] - 1) << 1) + parity[SUBJ]];

        vclass = tr + (tl << 1) + (br << 2) + (bl << 3);

        if (contributing) {
          xb = edge.xb;

          switch (vclass) {
            case EMN:
            case IMN:
              add_local_min(&out_poly, edge, xb, yb);
              px = xb;
              cf = edge.outp[ABOVE];
              break;
            case ERI:
              if (xb != px) {
                add_right(cf, xb, yb);
                px = xb;
              }
              edge.outp[ABOVE]= cf;
              cf = null;
              break;
            case ELI:
              add_left(edge.outp[BELOW], xb, yb);
              px = xb;
              cf = edge.outp[BELOW];
              break;
            case EMX:
              if (xb != px) {
                add_left(cf, xb, yb);
                px = xb;
              }
              merge_right(cf, edge.outp[BELOW], out_poly);
              cf = null;
              break;
            case ILI:
              if (xb != px) {
                add_left(cf, xb, yb);
                px = xb;
              }
              edge.outp[ABOVE] = cf;
              cf = null;
              break;
            case IRI:
              add_right(edge.outp[BELOW], xb, yb);
              px = xb;
              cf = edge.outp[BELOW];
              edge.outp[BELOW] = null;
              break;
            case IMX:
              if (xb != px) {
                add_right(cf, xb, yb);
                px = xb;
              }
              merge_left(cf, edge.outp[BELOW], out_poly);
              cf = null;
              edge.outp[BELOW] = null;
              break;
            case IMM:
              if (xb != px) {
                add_right(cf, xb, yb);
                px = xb;
              }
              merge_left(cf, edge.outp[BELOW], out_poly);
              edge.outp[BELOW] = null;
              add_local_min(&out_poly, edge, xb, yb);
              cf = edge.outp[ABOVE];
              break;
            case EMM:
              if (xb != px) {
                add_left(cf, xb, yb);
                px = xb;
              }
              merge_right(cf, edge.outp[BELOW], out_poly);
              edge.outp[BELOW] = null;
              add_local_min(&out_poly, edge, xb, yb);
              cf = edge.outp[ABOVE];
              break;
            case LED:
              if (edge.bot.y == yb) add_left(edge.outp[BELOW], xb, yb);
              edge.outp[ABOVE] = edge.outp[BELOW];
              px = xb;
              break;
            case RED:
              if (edge.bot.y == yb) add_right(edge.outp[BELOW], xb, yb);
              edge.outp[ABOVE] = edge.outp[BELOW];
              px = xb;
              break;
            default:
              break;
          } // End of switch
        } // End of contributing conditional
      } // End of edge exists conditional
    } // End of AET loop

    // Delete terminating edges from the AET, otherwise compute xt
    for (edge = aet; edge !is null; edge = edge.next) {
      if (edge.top.y == yb) {
        prev_edge = edge.prev;
        next_edge = edge.next;
        if (prev_edge) prev_edge.next = next_edge; else aet = next_edge;
        if (next_edge) next_edge.prev = prev_edge;

        // Copy bundle head state to the adjacent tail edge if required
        if ((edge.bstate[BELOW] == BUNDLE_HEAD) && prev_edge) {
          if (prev_edge.bstate[BELOW] == BUNDLE_TAIL) {
            prev_edge.outp[BELOW] = edge.outp[BELOW];
            prev_edge.bstate[BELOW] = UNBUNDLED;
            if (prev_edge.prev) {
              if (prev_edge.prev.bstate[BELOW] == BUNDLE_TAIL) prev_edge.bstate[BELOW] = BUNDLE_HEAD;
            }
          }
        }
      } else {
        if (edge.top.y == yt) {
          edge.xt = edge.top.x;
        } else {
          edge.xt = edge.bot.x + edge.dx * (yt - edge.bot.y);
        }
      }
    }

    if (scanbeam < sbt_entries) {
      // === SCANBEAM INTERIOR PROCESSING ==============================

      build_intersection_table(&it, aet, dy);

      // Process each node in the intersection table
      for (intersect = it; intersect; intersect = intersect.next) {
        e0 = intersect.ie[0];
        e1 = intersect.ie[1];

        // Only generate output for contributing intersections
        if ((e0.bundle[ABOVE][CLIP] || e0.bundle[ABOVE][SUBJ]) && (e1.bundle[ABOVE][CLIP] || e1.bundle[ABOVE][SUBJ])) {
          p = e0.outp[ABOVE];
          q = e1.outp[ABOVE];
          ix = intersect.point.x;
          iy = intersect.point.y + yb;

          inn[CLIP] = (e0.bundle[ABOVE][CLIP] && !e0.bside[CLIP]) || (e1.bundle[ABOVE][CLIP] && e1.bside[CLIP]) || (!e0.bundle[ABOVE][CLIP] && !e1.bundle[ABOVE][CLIP] && e0.bside[CLIP] && e1.bside[CLIP]);
          inn[SUBJ] = (e0.bundle[ABOVE][SUBJ] && !e0.bside[SUBJ]) || (e1.bundle[ABOVE][SUBJ] && e1.bside[SUBJ]) || (!e0.bundle[ABOVE][SUBJ] && !e1.bundle[ABOVE][SUBJ] && e0.bside[SUBJ] && e1.bside[SUBJ]);

          // Determine quadrant occupancies
          switch (op) {
            case GPC.Diff:
            case GPC.Int:
              tr = (inn[CLIP]) && (inn[SUBJ]);
              tl = (inn[CLIP] ^ e1.bundle[ABOVE][CLIP]) && (inn[SUBJ] ^ e1.bundle[ABOVE][SUBJ]);
              br = (inn[CLIP] ^ e0.bundle[ABOVE][CLIP]) && (inn[SUBJ] ^ e0.bundle[ABOVE][SUBJ]);
              bl = (inn[CLIP] ^ e1.bundle[ABOVE][CLIP] ^ e0.bundle[ABOVE][CLIP]) && (inn[SUBJ] ^ e1.bundle[ABOVE][SUBJ] ^ e0.bundle[ABOVE][SUBJ]);
              break;
            case GPC.Xor:
              tr = (inn[CLIP]) ^ (inn[SUBJ]);
              tl = (inn[CLIP] ^ e1.bundle[ABOVE][CLIP]) ^ (inn[SUBJ] ^ e1.bundle[ABOVE][SUBJ]);
              br = (inn[CLIP] ^ e0.bundle[ABOVE][CLIP]) ^ (inn[SUBJ] ^ e0.bundle[ABOVE][SUBJ]);
              bl = (inn[CLIP] ^ e1.bundle[ABOVE][CLIP] ^ e0.bundle[ABOVE][CLIP]) ^ (inn[SUBJ] ^ e1.bundle[ABOVE][SUBJ] ^ e0.bundle[ABOVE][SUBJ]);
              break;
            case GPC.Union:
              tr = (inn[CLIP]) || (inn[SUBJ]);
              tl = (inn[CLIP] ^ e1.bundle[ABOVE][CLIP]) || (inn[SUBJ] ^ e1.bundle[ABOVE][SUBJ]);
              br = (inn[CLIP] ^ e0.bundle[ABOVE][CLIP]) || (inn[SUBJ] ^ e0.bundle[ABOVE][SUBJ]);
              bl = (inn[CLIP] ^ e1.bundle[ABOVE][CLIP] ^ e0.bundle[ABOVE][CLIP]) || (inn[SUBJ] ^ e1.bundle[ABOVE][SUBJ] ^ e0.bundle[ABOVE][SUBJ]);
              break;
            default: assert(0);
          }

          vclass = tr + (tl << 1) + (br << 2) + (bl << 3);

          switch (vclass) {
            case EMN:
              add_local_min(&out_poly, e0, ix, iy);
              e1.outp[ABOVE] = e0.outp[ABOVE];
              break;
            case ERI:
              if (p) {
                add_right(p, ix, iy);
                e1.outp[ABOVE] = p;
                e0.outp[ABOVE] = null;
              }
              break;
            case ELI:
              if (q) {
                add_left(q, ix, iy);
                e0.outp[ABOVE] = q;
                e1.outp[ABOVE] = null;
              }
              break;
            case EMX:
              if (p && q) {
                add_left(p, ix, iy);
                merge_right(p, q, out_poly);
                e0.outp[ABOVE] = null;
                e1.outp[ABOVE] = null;
              }
              break;
            case IMN:
              add_local_min(&out_poly, e0, ix, iy);
              e1.outp[ABOVE] = e0.outp[ABOVE];
              break;
            case ILI:
              if (p) {
                add_left(p, ix, iy);
                e1.outp[ABOVE] = p;
                e0.outp[ABOVE] = null;
              }
              break;
            case IRI:
              if (q) {
                add_right(q, ix, iy);
                e0.outp[ABOVE] = q;
                e1.outp[ABOVE] = null;
              }
              break;
            case IMX:
              if (p && q) {
                add_right(p, ix, iy);
                merge_left(p, q, out_poly);
                e0.outp[ABOVE] = null;
                e1.outp[ABOVE] = null;
              }
              break;
            case IMM:
              if (p && q) {
                add_right(p, ix, iy);
                merge_left(p, q, out_poly);
                add_local_min(&out_poly, e0, ix, iy);
                e1.outp[ABOVE] = e0.outp[ABOVE];
              }
              break;
            case EMM:
              if (p && q) {
                add_left(p, ix, iy);
                merge_right(p, q, out_poly);
                add_local_min(&out_poly, e0, ix, iy);
                e1.outp[ABOVE] = e0.outp[ABOVE];
              }
              break;
            default:
              break;
          } // End of switch
        } // End of contributing intersection conditional

        // Swap bundle sides in response to edge crossing
        if (e0.bundle[ABOVE][CLIP]) e1.bside[CLIP] = !e1.bside[CLIP];
        if (e1.bundle[ABOVE][CLIP]) e0.bside[CLIP] = !e0.bside[CLIP];
        if (e0.bundle[ABOVE][SUBJ]) e1.bside[SUBJ] = !e1.bside[SUBJ];
        if (e1.bundle[ABOVE][SUBJ]) e0.bside[SUBJ] = !e0.bside[SUBJ];

        // Swap the edge bundles in the aet
        swap_intersecting_edge_bundles(&aet, intersect);
      } // End of IT loop

      // Prepare for next scanbeam
      for (edge = aet; edge !is null; edge = next_edge) {
        next_edge = edge.next;
        succ_edge = edge.succ;

        if (edge.top.y == yt && succ_edge) {
          // Replace AET edge by its successor
          succ_edge.outp[BELOW] = edge.outp[ABOVE];
          succ_edge.bstate[BELOW] = edge.bstate[ABOVE];
          succ_edge.bundle[BELOW][CLIP] = edge.bundle[ABOVE][CLIP];
          succ_edge.bundle[BELOW][SUBJ] = edge.bundle[ABOVE][SUBJ];
          prev_edge = edge.prev;
          if (prev_edge) prev_edge.next = succ_edge; else aet = succ_edge;
          if (next_edge) next_edge.prev= succ_edge;
          succ_edge.prev = prev_edge;
          succ_edge.next = next_edge;
        } else {
          // Update this edge
          edge.outp[BELOW] = edge.outp[ABOVE];
          edge.bstate[BELOW] = edge.bstate[ABOVE];
          edge.bundle[BELOW][CLIP] = edge.bundle[ABOVE][CLIP];
          edge.bundle[BELOW][SUBJ] = edge.bundle[ABOVE][SUBJ];
          edge.xb = edge.xt;
        }
        edge.outp[ABOVE] = null;
      }
    }
  } // === END OF SCANBEAM PROCESSING ==================================

  // Generate result polygon from out_poly
  result.contour = null;
  result.hole = null;
  result.num_contours = count_contours(out_poly);
  if (result.num_contours > 0) {
    result.hole = MALLOC!int(result.num_contours);
    result.contour = MALLOC!gpc_vertex_list(result.num_contours);
    c = 0;
    for (poly = out_poly; poly !is null; poly = npoly) {
      npoly = poly.next;
      if (poly.active) {
        result.hole[c] = poly.proxy.hole;
        result.contour[c].num_vertices = poly.active;
        result.contour[c].vertex = MALLOC!gpc_vertex(result.contour[c].num_vertices);
        v = result.contour[c].num_vertices-1;
        for (vtx = poly.proxy.v[LEFT]; vtx !is null; vtx = nv) {
          nv = vtx.next;
          result.contour[c].vertex[v].x = vtx.x;
          result.contour[c].vertex[v].y = vtx.y;
          FREE(vtx);
          --v;
        }
        ++c;
      }
      FREE(poly);
    }
  } else {
    for (poly = out_poly; poly !is null; poly = npoly) {
      npoly = poly.next;
      FREE(poly);
    }
  }

  // Tidy up
  reset_it(&it);
  reset_lmt(&lmt);
  FREE(c_heap);
  FREE(s_heap);
  FREE(sbt);
}


/// Frees allocated tristrip memory. It is safe to call it on empty (but initialized) tristrip.
public void gpc_free_tristrip (ref gpc_tristrip t) {
  foreach (immutable int s; 0..t.num_strips) FREE(t.strip[s].vertex);
  FREE(t.strip);
  t.num_strips = 0;
}


/** Converts polygon to triangle strip (tristrip).
 *
 * [result] will be overwritten (so old contents won't be freed, and it may be uninitialized at all).
 */
public void gpc_polygon_to_tristrip (ref gpc_polygon s, ref gpc_tristrip result) {
  gpc_polygon c;
  c.num_contours = 0;
  c.hole = null;
  c.contour = null;
  gpc_tristrip_clip(GPC.Diff, s, c, result);
}


/** Calculates clipping, returns result as triangle strip (tristrip).
 *
 * [result] will be overwritten (so old contents won't be freed, and it may be uninitialized at all).
 */
public void gpc_tristrip_clip (GPC op, ref gpc_polygon subj, ref gpc_polygon clip, ref gpc_tristrip result) {
  sb_tree* sbtree = null;
  it_node* it = null, intersect;
  edge_node* edge, prev_edge, next_edge, succ_edge, e0, e1;
  edge_node* aet = null, c_heap = null, s_heap = null, cf;
  lmt_node* lmt = null, local_min;
  polygon_node* tlist = null, tn, tnn, p, q;
  vertex_node* lt, ltn, rt, rtn;
  h_state[2] horiz;
  vertex_type cft;
  int[2] inn, exists;
  int[2] parity = [LEFT, LEFT];
  int s, v, contributing, scanbeam = 0, sbt_entries = 0;
  int vclass, bl, br, tl, tr;
  double* sbt = null;
  double xb, px, nx, yb, yt, dy, ix, iy;

  // Test for trivial NULL result cases
  if ((subj.num_contours == 0 && clip.num_contours == 0) ||
      (subj.num_contours == 0 && (op == GPC.Int || op == GPC.Diff)) ||
      (clip.num_contours == 0 && op == GPC.Int))
  {
    result.num_strips = 0;
    result.strip = null;
    return;
  }

  // Identify potentialy contributing contours
  if ((op == GPC.Int || op == GPC.Diff) && subj.num_contours > 0 && clip.num_contours > 0) minimax_test(&subj, &clip, op);

  // Build LMT
  if (subj.num_contours > 0) s_heap = build_lmt(&lmt, &sbtree, &sbt_entries, &subj, SUBJ, op);
  if (clip.num_contours > 0) c_heap = build_lmt(&lmt, &sbtree, &sbt_entries, &clip, CLIP, op);

  // Return a NULL result if no contours contribute
  if (lmt is null) {
    result.num_strips = 0;
    result.strip = null;
    reset_lmt(&lmt);
    FREE(s_heap);
    FREE(c_heap);
    return;
  }

  // Build scanbeam table from scanbeam tree
  sbt = MALLOC!double(sbt_entries);
  build_sbt(&scanbeam, sbt, sbtree);
  scanbeam = 0;
  free_sbtree(&sbtree);

  // Invert clip polygon for difference operation
  if (op == GPC.Diff) parity[CLIP] = RIGHT;

  local_min = lmt;

  // Process each scanbeam
  while (scanbeam < sbt_entries) {
    // Set yb and yt to the bottom and top of the scanbeam
    yb = sbt[scanbeam++];
    if (scanbeam < sbt_entries) {
      yt = sbt[scanbeam];
      dy = yt - yb;
    }

    // === SCANBEAM BOUNDARY PROCESSING ================================

    // If LMT node corresponding to yb exists
    if (local_min) {
      if (local_min.y == yb) {
        // Add edges starting at this local minimum to the AET
        for (edge = local_min.first_bound; edge !is null; edge = edge.next_bound) add_edge_to_aet(&aet, edge, null);
        local_min = local_min.next;
      }
    }

    // Set dummy previous x value
    px = -double.max;

    // Create bundles within AET
    e0 = aet;
    e1 = aet;

    // Set up bundle fields of first edge
    aet.bundle[ABOVE][ aet.type] = (aet.top.y != yb);
    aet.bundle[ABOVE][!aet.type] = false;
    aet.bstate[ABOVE] = UNBUNDLED;

    for (next_edge = aet.next; next_edge !is null; next_edge = next_edge.next) {
      // Set up bundle fields of next edge
      next_edge.bundle[ABOVE][next_edge.type] = (next_edge.top.y != yb);
      next_edge.bundle[ABOVE][!next_edge.type] = false;
      next_edge.bstate[ABOVE] = UNBUNDLED;

      // Bundle edges above the scanbeam boundary if they coincide
      if (next_edge.bundle[ABOVE][next_edge.type]) {
        if (EQ(e0.xb, next_edge.xb) && EQ(e0.dx, next_edge.dx) && e0.top.y != yb) {
          next_edge.bundle[ABOVE][ next_edge.type] ^= e0.bundle[ABOVE][ next_edge.type];
          next_edge.bundle[ABOVE][!next_edge.type] = e0.bundle[ABOVE][!next_edge.type];
          next_edge.bstate[ABOVE] = BUNDLE_HEAD;
          e0.bundle[ABOVE][CLIP] = false;
          e0.bundle[ABOVE][SUBJ] = false;
          e0.bstate[ABOVE] = BUNDLE_TAIL;
        }
        e0 = next_edge;
      }
    }

    horiz[CLIP] = NH;
    horiz[SUBJ] = NH;

    // Process each edge at this scanbeam boundary
    for (edge = aet; edge !is null; edge = edge.next) {
      exists[CLIP] = edge.bundle[ABOVE][CLIP] + (edge.bundle[BELOW][CLIP] << 1);
      exists[SUBJ] = edge.bundle[ABOVE][SUBJ] + (edge.bundle[BELOW][SUBJ] << 1);

      if (exists[CLIP] || exists[SUBJ]) {
        // Set bundle side
        edge.bside[CLIP] = parity[CLIP];
        edge.bside[SUBJ] = parity[SUBJ];

        // Determine contributing status and quadrant occupancies
        switch (op) {
          case GPC.Diff:
          case GPC.Int:
            contributing= (exists[CLIP] && (parity[SUBJ] || horiz[SUBJ])) || (exists[SUBJ] && (parity[CLIP] || horiz[CLIP])) || (exists[CLIP] && exists[SUBJ] && (parity[CLIP] == parity[SUBJ]));
            br = (parity[CLIP]) && (parity[SUBJ]);
            bl = (parity[CLIP] ^ edge.bundle[ABOVE][CLIP]) && (parity[SUBJ] ^ edge.bundle[ABOVE][SUBJ]);
            tr = (parity[CLIP] ^ (horiz[CLIP] != NH)) && (parity[SUBJ] ^ (horiz[SUBJ] != NH));
            tl = (parity[CLIP] ^ (horiz[CLIP] != NH) ^ edge.bundle[BELOW][CLIP]) && (parity[SUBJ] ^ (horiz[SUBJ] != NH) ^ edge.bundle[BELOW][SUBJ]);
            break;
          case GPC.Xor:
            contributing = exists[CLIP] || exists[SUBJ];
            br = (parity[CLIP]) ^ (parity[SUBJ]);
            bl = (parity[CLIP] ^ edge.bundle[ABOVE][CLIP]) ^ (parity[SUBJ] ^ edge.bundle[ABOVE][SUBJ]);
            tr = (parity[CLIP] ^ (horiz[CLIP] != NH)) ^ (parity[SUBJ] ^ (horiz[SUBJ] != NH));
            tl = (parity[CLIP] ^ (horiz[CLIP] != NH) ^ edge.bundle[BELOW][CLIP]) ^ (parity[SUBJ] ^ (horiz[SUBJ] != NH) ^ edge.bundle[BELOW][SUBJ]);
            break;
          case GPC.Union:
            contributing = (exists[CLIP] && (!parity[SUBJ] || horiz[SUBJ])) || (exists[SUBJ] && (!parity[CLIP] || horiz[CLIP])) || (exists[CLIP] && exists[SUBJ] && (parity[CLIP] == parity[SUBJ]));
            br = (parity[CLIP]) || (parity[SUBJ]);
            bl = (parity[CLIP] ^ edge.bundle[ABOVE][CLIP]) || (parity[SUBJ] ^ edge.bundle[ABOVE][SUBJ]);
            tr = (parity[CLIP] ^ (horiz[CLIP] != NH)) || (parity[SUBJ] ^ (horiz[SUBJ] != NH));
            tl = (parity[CLIP] ^ (horiz[CLIP] != NH) ^ edge.bundle[BELOW][CLIP]) || (parity[SUBJ] ^ (horiz[SUBJ] != NH) ^ edge.bundle[BELOW][SUBJ]);
            break;
          default: assert(0);
        }

        // Update parity
        parity[CLIP] ^= edge.bundle[ABOVE][CLIP];
        parity[SUBJ] ^= edge.bundle[ABOVE][SUBJ];

        // Update horizontal state
        if (exists[CLIP]) horiz[CLIP] = next_h_state[horiz[CLIP]][((exists[CLIP] - 1) << 1) + parity[CLIP]];
        if (exists[SUBJ]) horiz[SUBJ] = next_h_state[horiz[SUBJ]][((exists[SUBJ] - 1) << 1) + parity[SUBJ]];

        vclass = tr + (tl << 1) + (br << 2) + (bl << 3);

        if (contributing) {
          xb = edge.xb;

          switch (vclass) {
            case EMN:
              new_tristrip(&tlist, edge, xb, yb);
              cf = edge;
              break;
            case ERI:
              edge.outp[ABOVE] = cf.outp[ABOVE];
              if (xb != cf.xb) VERTEX(edge, ABOVE, RIGHT, xb, yb);
              cf = null;
              break;
            case ELI:
              VERTEX(edge, BELOW, LEFT, xb, yb);
              edge.outp[ABOVE] = null;
              cf = edge;
              break;
            case EMX:
              if (xb != cf.xb) VERTEX(edge, BELOW, RIGHT, xb, yb);
              edge.outp[ABOVE] = null;
              cf = null;
              break;
            case IMN:
              if (cft == LED) {
                if (cf.bot.y != yb) VERTEX(cf, BELOW, LEFT, cf.xb, yb);
                new_tristrip(&tlist, cf, cf.xb, yb);
              }
              edge.outp[ABOVE] = cf.outp[ABOVE];
              VERTEX(edge, ABOVE, RIGHT, xb, yb);
              break;
            case ILI:
              new_tristrip(&tlist, edge, xb, yb);
              cf = edge;
              cft = ILI;
              break;
            case IRI:
              if (cft == LED) {
                if (cf.bot.y != yb) VERTEX(cf, BELOW, LEFT, cf.xb, yb);
                new_tristrip(&tlist, cf, cf.xb, yb);
              }
              VERTEX(edge, BELOW, RIGHT, xb, yb);
              edge.outp[ABOVE] = null;
              break;
            case IMX:
              VERTEX(edge, BELOW, LEFT, xb, yb);
              edge.outp[ABOVE] = null;
              cft = IMX;
              break;
            case IMM:
              VERTEX(edge, BELOW, LEFT, xb, yb);
              edge.outp[ABOVE] = cf.outp[ABOVE];
              if (xb != cf.xb) VERTEX(cf, ABOVE, RIGHT, xb, yb);
              cf = edge;
              break;
            case EMM:
              VERTEX(edge, BELOW, RIGHT, xb, yb);
              edge.outp[ABOVE] = null;
              new_tristrip(&tlist, edge, xb, yb);
              cf = edge;
              break;
            case LED:
              if (edge.bot.y == yb) VERTEX(edge, BELOW, LEFT, xb, yb);
              edge.outp[ABOVE] = edge.outp[BELOW];
              cf = edge;
              cft = LED;
              break;
            case RED:
              edge.outp[ABOVE]= cf.outp[ABOVE];
              if (cft == LED) {
                if (cf.bot.y == yb) {
                  VERTEX(edge, BELOW, RIGHT, xb, yb);
                } else {
                  if (edge.bot.y == yb) {
                    VERTEX(cf, BELOW, LEFT, cf.xb, yb);
                    VERTEX(edge, BELOW, RIGHT, xb, yb);
                  }
                }
              } else {
                VERTEX(edge, BELOW, RIGHT, xb, yb);
                VERTEX(edge, ABOVE, RIGHT, xb, yb);
              }
              cf = null;
              break;
            default:
              break;
          } // End of switch
        } // End of contributing conditional
      } // End of edge exists conditional
    } // End of AET loop

    // Delete terminating edges from the AET, otherwise compute xt
    for (edge = aet; edge !is null; edge = edge.next) {
      if (edge.top.y == yb) {
        prev_edge = edge.prev;
        next_edge = edge.next;
        if (prev_edge) prev_edge.next = next_edge; else aet = next_edge;
        if (next_edge) next_edge.prev = prev_edge;

        // Copy bundle head state to the adjacent tail edge if required
        if ((edge.bstate[BELOW] == BUNDLE_HEAD) && prev_edge) {
          if (prev_edge.bstate[BELOW] == BUNDLE_TAIL) {
            prev_edge.outp[BELOW] = edge.outp[BELOW];
            prev_edge.bstate[BELOW] = UNBUNDLED;
            if (prev_edge.prev) {
              if (prev_edge.prev.bstate[BELOW] == BUNDLE_TAIL) prev_edge.bstate[BELOW] = BUNDLE_HEAD;
            }
          }
        }
      } else {
        if (edge.top.y == yt) edge.xt = edge.top.x; else edge.xt = edge.bot.x + edge.dx * (yt - edge.bot.y);
      }
    }

    if (scanbeam < sbt_entries) {
      // === SCANBEAM INTERIOR PROCESSING ==============================

      build_intersection_table(&it, aet, dy);

      // Process each node in the intersection table
      for (intersect = it; intersect !is null; intersect = intersect.next) {
        e0 = intersect.ie[0];
        e1 = intersect.ie[1];

        // Only generate output for contributing intersections
        if ((e0.bundle[ABOVE][CLIP] || e0.bundle[ABOVE][SUBJ]) && (e1.bundle[ABOVE][CLIP] || e1.bundle[ABOVE][SUBJ])) {
          p = e0.outp[ABOVE];
          q = e1.outp[ABOVE];
          ix = intersect.point.x;
          iy = intersect.point.y + yb;

          inn[CLIP] = (e0.bundle[ABOVE][CLIP] && !e0.bside[CLIP]) || (e1.bundle[ABOVE][CLIP] && e1.bside[CLIP]) || (!e0.bundle[ABOVE][CLIP] && !e1.bundle[ABOVE][CLIP] && e0.bside[CLIP] && e1.bside[CLIP]);
          inn[SUBJ] = (e0.bundle[ABOVE][SUBJ] && !e0.bside[SUBJ]) || (e1.bundle[ABOVE][SUBJ] && e1.bside[SUBJ]) || (!e0.bundle[ABOVE][SUBJ] && !e1.bundle[ABOVE][SUBJ] && e0.bside[SUBJ] && e1.bside[SUBJ]);

          // Determine quadrant occupancies
          switch (op) {
            case GPC.Diff:
            case GPC.Int:
              tr = (inn[CLIP]) && (inn[SUBJ]);
              tl = (inn[CLIP] ^ e1.bundle[ABOVE][CLIP]) && (inn[SUBJ] ^ e1.bundle[ABOVE][SUBJ]);
              br = (inn[CLIP] ^ e0.bundle[ABOVE][CLIP]) && (inn[SUBJ] ^ e0.bundle[ABOVE][SUBJ]);
              bl = (inn[CLIP] ^ e1.bundle[ABOVE][CLIP] ^ e0.bundle[ABOVE][CLIP]) && (inn[SUBJ] ^ e1.bundle[ABOVE][SUBJ] ^ e0.bundle[ABOVE][SUBJ]);
              break;
            case GPC.Xor:
              tr = (inn[CLIP]) ^ (inn[SUBJ]);
              tl = (inn[CLIP] ^ e1.bundle[ABOVE][CLIP]) ^ (inn[SUBJ] ^ e1.bundle[ABOVE][SUBJ]);
              br = (inn[CLIP] ^ e0.bundle[ABOVE][CLIP]) ^ (inn[SUBJ] ^ e0.bundle[ABOVE][SUBJ]);
              bl = (inn[CLIP] ^ e1.bundle[ABOVE][CLIP] ^ e0.bundle[ABOVE][CLIP]) ^ (inn[SUBJ] ^ e1.bundle[ABOVE][SUBJ] ^ e0.bundle[ABOVE][SUBJ]);
              break;
            case GPC.Union:
              tr = (inn[CLIP]) || (inn[SUBJ]);
              tl = (inn[CLIP] ^ e1.bundle[ABOVE][CLIP]) || (inn[SUBJ] ^ e1.bundle[ABOVE][SUBJ]);
              br = (inn[CLIP] ^ e0.bundle[ABOVE][CLIP]) || (inn[SUBJ] ^ e0.bundle[ABOVE][SUBJ]);
              bl = (inn[CLIP] ^ e1.bundle[ABOVE][CLIP] ^ e0.bundle[ABOVE][CLIP]) || (inn[SUBJ] ^ e1.bundle[ABOVE][SUBJ] ^ e0.bundle[ABOVE][SUBJ]);
              break;
            default: assert(0);
          }

          vclass = tr + (tl << 1) + (br << 2) + (bl << 3);

          switch (vclass) {
            case EMN:
              new_tristrip(&tlist, e1, ix, iy);
              e0.outp[ABOVE] = e1.outp[ABOVE];
              break;
            case ERI:
              if (p) {
                P_EDGE(prev_edge, e0, ABOVE, px, iy);
                VERTEX(prev_edge, ABOVE, LEFT, px, iy);
                VERTEX(e0, ABOVE, RIGHT, ix, iy);
                e1.outp[ABOVE] = e0.outp[ABOVE];
                e0.outp[ABOVE] = null;
              }
              break;
            case ELI:
              if (q) {
                N_EDGE(next_edge, e1, ABOVE, nx, iy);
                VERTEX(e1, ABOVE, LEFT, ix, iy);
                VERTEX(next_edge, ABOVE, RIGHT, nx, iy);
                e0.outp[ABOVE] = e1.outp[ABOVE];
                e1.outp[ABOVE] = null;
              }
              break;
            case EMX:
              if (p && q) {
                VERTEX(e0, ABOVE, LEFT, ix, iy);
                e0.outp[ABOVE] = null;
                e1.outp[ABOVE] = null;
              }
              break;
            case IMN:
              P_EDGE(prev_edge, e0, ABOVE, px, iy);
              VERTEX(prev_edge, ABOVE, LEFT, px, iy);
              N_EDGE(next_edge, e1, ABOVE, nx, iy);
              VERTEX(next_edge, ABOVE, RIGHT, nx, iy);
              new_tristrip(&tlist, prev_edge, px, iy);
              e1.outp[ABOVE] = prev_edge.outp[ABOVE];
              VERTEX(e1, ABOVE, RIGHT, ix, iy);
              new_tristrip(&tlist, e0, ix, iy);
              next_edge.outp[ABOVE] = e0.outp[ABOVE];
              VERTEX(next_edge, ABOVE, RIGHT, nx, iy);
              break;
            case ILI:
              if (p) {
                VERTEX(e0, ABOVE, LEFT, ix, iy);
                N_EDGE(next_edge, e1, ABOVE, nx, iy);
                VERTEX(next_edge, ABOVE, RIGHT, nx, iy);
                e1.outp[ABOVE] = e0.outp[ABOVE];
                e0.outp[ABOVE] = null;
              }
              break;
            case IRI:
              if (q) {
                VERTEX(e1, ABOVE, RIGHT, ix, iy);
                P_EDGE(prev_edge, e0, ABOVE, px, iy);
                VERTEX(prev_edge, ABOVE, LEFT, px, iy);
                e0.outp[ABOVE] = e1.outp[ABOVE];
                e1.outp[ABOVE] = null;
              }
              break;
            case IMX:
              if (p && q) {
                VERTEX(e0, ABOVE, RIGHT, ix, iy);
                VERTEX(e1, ABOVE, LEFT, ix, iy);
                e0.outp[ABOVE] = null;
                e1.outp[ABOVE] = null;
                P_EDGE(prev_edge, e0, ABOVE, px, iy);
                VERTEX(prev_edge, ABOVE, LEFT, px, iy);
                new_tristrip(&tlist, prev_edge, px, iy);
                N_EDGE(next_edge, e1, ABOVE, nx, iy);
                VERTEX(next_edge, ABOVE, RIGHT, nx, iy);
                next_edge.outp[ABOVE] = prev_edge.outp[ABOVE];
                VERTEX(next_edge, ABOVE, RIGHT, nx, iy);
              }
              break;
            case IMM:
              if (p && q) {
                VERTEX(e0, ABOVE, RIGHT, ix, iy);
                VERTEX(e1, ABOVE, LEFT, ix, iy);
                P_EDGE(prev_edge, e0, ABOVE, px, iy);
                VERTEX(prev_edge, ABOVE, LEFT, px, iy);
                new_tristrip(&tlist, prev_edge, px, iy);
                N_EDGE(next_edge, e1, ABOVE, nx, iy);
                VERTEX(next_edge, ABOVE, RIGHT, nx, iy);
                e1.outp[ABOVE] = prev_edge.outp[ABOVE];
                VERTEX(e1, ABOVE, RIGHT, ix, iy);
                new_tristrip(&tlist, e0, ix, iy);
                next_edge.outp[ABOVE] = e0.outp[ABOVE];
                VERTEX(next_edge, ABOVE, RIGHT, nx, iy);
              }
              break;
            case EMM:
              if (p && q) {
                VERTEX(e0, ABOVE, LEFT, ix, iy);
                new_tristrip(&tlist, e1, ix, iy);
                e0.outp[ABOVE]= e1.outp[ABOVE];
              }
              break;
            default:
              break;
          } // End of switch
        } // End of contributing intersection conditional

        // Swap bundle sides in response to edge crossing
        if (e0.bundle[ABOVE][CLIP]) e1.bside[CLIP] = !e1.bside[CLIP];
        if (e1.bundle[ABOVE][CLIP]) e0.bside[CLIP] = !e0.bside[CLIP];
        if (e0.bundle[ABOVE][SUBJ]) e1.bside[SUBJ] = !e1.bside[SUBJ];
        if (e1.bundle[ABOVE][SUBJ]) e0.bside[SUBJ] = !e0.bside[SUBJ];

        // Swap the edge bundles in the aet
        swap_intersecting_edge_bundles(&aet, intersect);
      } // End of IT loop

      // Prepare for next scanbeam
      for (edge = aet; edge !is null; edge = next_edge) {
        next_edge = edge.next;
        succ_edge = edge.succ;

        if (edge.top.y == yt && succ_edge) {
          // Replace AET edge by its successor
          succ_edge.outp[BELOW] = edge.outp[ABOVE];
          succ_edge.bstate[BELOW] = edge.bstate[ABOVE];
          succ_edge.bundle[BELOW][CLIP] = edge.bundle[ABOVE][CLIP];
          succ_edge.bundle[BELOW][SUBJ] = edge.bundle[ABOVE][SUBJ];
          prev_edge = edge.prev;
          if (prev_edge) prev_edge.next = succ_edge; else aet = succ_edge;
          if (next_edge) next_edge.prev = succ_edge;
          succ_edge.prev = prev_edge;
          succ_edge.next = next_edge;
        } else {
          // Update this edge
          edge.outp[BELOW] = edge.outp[ABOVE];
          edge.bstate[BELOW] = edge.bstate[ABOVE];
          edge.bundle[BELOW][CLIP] = edge.bundle[ABOVE][CLIP];
          edge.bundle[BELOW][SUBJ] = edge.bundle[ABOVE][SUBJ];
          edge.xb = edge.xt;
        }
        edge.outp[ABOVE] = null;
      }
    }
  } // === END OF SCANBEAM PROCESSING ==================================

  // Generate result tristrip from tlist
  result.strip = null;
  result.num_strips = count_tristrips(tlist);
  if (result.num_strips > 0) {
    result.strip = MALLOC!gpc_vertex_list(result.num_strips);
    s = 0;
    for (tn = tlist; tn !is null; tn = tnn) {
      tnn = tn.next;
      if (tn.active > 2) {
        // Valid tristrip: copy the vertices and free the heap
        result.strip[s].num_vertices= tn.active;
        result.strip[s].vertex = MALLOC!gpc_vertex(tn.active);
        v = 0;
        if (GPC_INVERT_TRISTRIPS) {
          lt = tn.v[RIGHT];
          rt = tn.v[LEFT];
        } else {
          lt = tn.v[LEFT];
          rt = tn.v[RIGHT];
        }
        while (lt || rt) {
          if (lt) {
            ltn = lt.next;
            result.strip[s].vertex[v].x = lt.x;
            result.strip[s].vertex[v].y = lt.y;
            ++v;
            FREE(lt);
            lt = ltn;
          }
          if (rt) {
            rtn = rt.next;
            result.strip[s].vertex[v].x = rt.x;
            result.strip[s].vertex[v].y = rt.y;
            ++v;
            FREE(rt);
            rt = rtn;
          }
        }
        ++s;
      } else {
        // Invalid tristrip: just free the heap
        for (lt = tn.v[LEFT]; lt !is null; lt = ltn) {
          ltn = lt.next;
          FREE(lt);
        }
        for (rt = tn.v[RIGHT]; rt !is null; rt = rtn) {
          rtn = rt.next;
          FREE(rt);
        }
      }
      FREE(tn);
    }
  }

  // Tidy up
  reset_it(&it);
  reset_lmt(&lmt);
  FREE(c_heap);
  FREE(s_heap);
  FREE(sbt);
}
