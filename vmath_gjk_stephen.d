/* the Oxford version of Gilbert, Johnson and Keerthi's minimum distance routine.
 * Version 2.4, July 1998, (c) Stephen Cameron 1996, 1997, 1998
 * origin site: http://www.cs.ox.ac.uk/people/stephen.cameron/distances/
 *
 * copyright (c) Stephen Cameron 1996, 1997, 1998, but may be freely
 * copied and used for non-profit making applications and for evaluation.
 * The code is also available for commercial use; please contact the
 * author for details. In no way will either Stephen Cameron or the
 * University of Oxford be responsible for loss or damages resulting from
 * the use of this code.
 *
 * D translation by Ketmar // Invisible Vector
 */
module iv.vmath_gjk;

import iv.vmath;

/* defining GJK_TEST_BACKUP_PROCEDURE disables the default simplex
 * distance routine, in order to test the (otherwise extremely
 * rarely used) backup procedure
 */
//version = GJK_TEST_BACKUP_PROCEDURE;

/*
 * If there is no topological information given for the hull
 * then an exhaustive search of the vertices is used. Otherwise,
 * hill-climbing is performed. If GJK_EAGER_HILL_CLIMBING is defined
 * then the hill-climbing moves to a new vertex as soon as a better
 * vertex is found, and if it is not defined then every vertex leading
 * from the current vertex is explored before moving to the best one.
 * Initial conclusions are that fewer vertices are explored with
 * GJK_EAGER_HILL_CLIMBING defined, but that the code runs slighty slower!
 * This is presumably due to pipeline bubbles and/or cache misses.
 */
//version = GJK_EAGER_HILL_CLIMBING;


// ////////////////////////////////////////////////////////////////////////// //
// GJK object should support:
//   int vertCount const nothrow @nogc
//   VecN vert (int idx) const nothrow @nogc
//  optional:
//   int ringCount const nothrow @nogc
//   int ring (int idx) const nothrow @nogc
public template IsGoodGJKObject(T, VT) if ((is(T == struct) || is(T == class)) && IsVector!VT) {
  enum IsGoodGJKObject = is(typeof((inout int=0) nothrow @nogc {
    const o = T.init;
    int vc = o.vertCount; // number of vertices
    auto vx = o.vert(vc); // get nth vertex
    static assert(is(typeof(vx) == VT));
    static if (is(typeof(o.ringCount))) {
      // has rings
      int rc = o.ringCount; // number of rings
      int r = o.ring(rc); // get nth ring
    }
  }));
}


// ////////////////////////////////////////////////////////////////////////// //
public struct GJKImpl(VT) if (IsVector!VT) {
public:
  enum Dims = VT.Dims; /* dimension of space (i.e., x/y/z = 3) */
  alias Float = VT.Float;
  alias Vec = VT;

  /* Even this algorithm has an epsilon (fudge) factor. It basically indicates
     how far apart two points have to be to declared different, expressed
     loosely as a proportion of the `average distance' between the point sets.
   */
  //enum EPS = cast(Float)1.0e-8;
  enum EPS = EPSILON!Float;

public:
  // VObject structure: holds basic information about each object
  /*
  static struct VObject {
    const(Vec)[] vertices;
    int[] rings;
  }
  */

  /* The SimplexPoint structure is really designed to be private to the
     main GJK routines. However the calling routine may wish to allocate
     some to be used to cache information for the distance routines.
     */
  static struct SimplexPoint {
  private:
    int npts; /* number of points in this simplex */

    /* simplex1 and simplex2 are two arrays of indices into the point arrays, given by the user. */
    VertexID[Dims+1] simplex1;
    VertexID[Dims+1] simplex2;

    /* and lambdas gives the values of lambda associated with those points. */
    Float[Dims+1] lambdas;

    /* calculated coordinates from the last iteration */
    Float[Dims][Dims+1] coords1;
    Float[Dims][Dims+1] coords2;

    /* last maximal vertices, used for hill-climbing */
    VertexID last_best1, last_best2;

    /* indication of maximum error in the return value */
    double error;
    /* This value is that returned by the `G-test', and indicates the
       difference between the reported shortest distance vector and the
       vector constructed from supporting hyperplanes in the direction
       of the reported shortest distance vector. That is, if the reported
       shortest distance vector is x, and the hyperplanes are distance D
       apart, this value is G = x.x - D|x|, and should be exactly zero
       for the true shortest distance vector (as |x| should then equal
       D).

       Alternatively, G/(x.x) is a relative error bound on the result.
    */
    bool calculated; // can this struct be used as a seed?

    Float[Dims] displacementv;

  public nothrow @safe @nogc:
    Float[Dims] disp () const { return displacementv; }
  }

  @property ref const(SimplexPoint) simplex () const nothrow @safe @nogc { pragma(inline, true); return local_simplex; }

  /* The main GJK distance routine. This routine implements the routine
   * of Gilbert, Johnson and Keerthi, as described in the paper (GJK88)
   * listed below. It also optionally runs my speed-up extension to this
   * algorithm, as described in (Cam97).
   *
   * The first two parameters are two hulls. These data-structures are
   * designed to be opaque to this code; the data is accessed through
   * selectors, iterators and prediciates, which are discussed below.
   *
   * The 3th and 4th parameters are point arrays, that are set to the
   * coordinates of two witness points (one within each convex hull)
   * that realise the minimum distance between them.
   *
   * The actual return value for the function is the square of the
   * minimum distance between the hulls, which is equal to the (square
   * of the) distance between the witness points.
   *
   * The 5th parameter is a flag, which when set tells the routine to
   * use the previously calculated SimplexPoint structure instance as
   * seed, otherwise it just uses any seed. A special form of the
   * witness points is stored in the structure by the routine, suitable
   * for using as seed points for any further calls involving these
   * two objects.
   *
   * Note that with this version one field of the SimplexPoint structure
   * can be used to pass back the confidence region for the routine: when
   * the routine returns with distance squared equal to D*d, it means that
   * the true distance is known to lie between D-(E/D) and D, where E is
   * the positive value returned in the `error' field of the SimplexPoint.
   * Equivalently; the true value of the distance squared is less than or equal
   * to the value returned DSQ, with an error bound width of 2E - E*E/DSQ.
   * (In `normal' cases E is very small, and so the error bound width 2E can
   * be sensibly used.)
   *
   * The code will attempt to return with E<=EPS, which the user
   * can set, but will in any event return with some value of E. In particular,
   * the code should return even with EPS set to zero.
   *
   * Alternatively, either or both of the pointer values for the witness
   * points can be zero, in which case those witness points are not
   * returned. The caller can later extract the coordinates of the
   * witness points from the SimplexPoint structure by using the
   * function gjk_extract_point.
   *
   * Returning to the opaque data-structures used to describe the objects
   * and their transformations. For an object then the minimum information
   * required is a list of vertices. The vertices themselves are another
   * opaque type, accessed through the type VertexID. The following macros
   * are defined for the vertices:
   *
   *  InvalidVertexID      a VertexID which cannot point to a valid vertex
   *  FirstVertex( obj)    an arbitrary first vertex for the object
   *  NumVertices( obj)    the number of vertices in the object
   *  IncrementVertex(o,v) set vertex to the next vertex
   *  ValidVertex( obj, v) says whether the VertexID is valid for obj
   *  LastVertex( obj, v)  is this the last vertex?
   *  SupportValue(o,v,d)  returns support value for v in direction d
   *
   * Optionally, the object data-structures encode the wireframe of the objects;
   * this is used in my extended GJK algorithm to greatly speed up the routine
   * in many cases. For an object the predicate ValidRing(obj) says whether
   * this information is provided, in which case the edges that surround any
   * can be accessed and traversed with the following:
   *
   *  FirstEdge( obj, vertex)     Returns the first edge (type EdgeID)
   *  IncrementEdge( obj, edge)   Sets edge to the next edge
   *  ValidEdge( obj, edge)       Indicates whether edge is a real edge
   *  VertexOfEdge( obj, edge)    Returns the (other) vertex of an edge
   *
   * With this information this routine runs in expected constant time
   * for tracking operations and small relative motions. If the
   * information is not supplied the the routine reverts to using the
   * original GJK technique, which takes time roughly linear in the number
   * of vertices. (As a rough rule of thumb, this difference becomes
   * measurable at around 10 vertices per hull, and important at about
   * 20 vertices per hull.)
   *
   * References:
   * (GJK88) "A Fast Procedure for Computing the Distance between Complex
   * Objects in Three-Dimensional Space" by EG Gilbert, DW Johnson and SS
   * Keerthi, IEEE Trans Robotics and Automation 4(2):193--203, April 1988.
   *
   * (Cam97) "A Comparison of Two Fast Algorithms for Computing the Distance
   * between Convex Polyhedra" by Stephen Cameron, IEEE Trans Robotics and
   * Automation 13(6):915-920, December 1997.
   *
   */
  public Float distance(VO1, VO2) (in auto ref VO1 obj1, VO2 obj2, bool use_seed=false)
  if (IsGoodGJKObject!(VO1, VT) && IsGoodGJKObject!(VO2, VT))
  {
    return distance(obj1, obj2, null, null, use_seed);
  }

  public Float distance(VO1, VO2) (in auto ref VO1 obj1, VO2 obj2, Vec* wpt1, Vec* wpt2, bool use_seed=false)
  if (IsGoodGJKObject!(VO1, VT) && IsGoodGJKObject!(VO2, VT))
  {
    VertexID v, maxp, minp;
    Float minus_minv, maxv, sqrd, g_val;
    Float[Dims] displacementv, reverse_displacementv;
    Float[Dims] local_witness1, local_witness2;
    int max_iterations;
    bool compute_both_witnesses, use_default, first_iteration;
    double oldsqrd;
    SimplexPoint* simplex = &local_simplex;

    assert(NumVertices(obj1) > 0 && NumVertices(obj2) > 0);

    use_default = first_iteration = true;

    compute_both_witnesses = (wpt1 !is null || wpt2 !is null);

    /*if (wpt1 is null)*/ xwpt1 = local_witness1[];
    /*if (wpt2 is null)*/ xwpt2 = local_witness2[];

    /*
    if (simplex is null) {
      use_seed = false;
      simplex = &local_simplex;
    }
    */
    if (use_seed && !simplex.calculated) use_seed = false;
    scope(exit) simplex.calculated = true;

    if (!use_seed) {
      simplex.simplex1.ptr[0] = 0;
      simplex.simplex2.ptr[0] = 0;
      simplex.npts = 1;
      simplex.lambdas.ptr[0] = cast(Float)1;
      simplex.last_best1 = 0;
      simplex.last_best2 = 0;
      add_simplex_vertex(simplex, 0, obj1, FirstVertex(obj1), obj2, FirstVertex(obj2));
    } else {
      /* If we are being told to use this seed point, there
         is a good chance that the near point will be on
         the current simplex. Besides, if we don't confirm
         that the seed point given satisfies the invariant
         (that the witness points given are the closest points
         on the current simplex) things can and will fall down.
       */
      for (v = 0; v < simplex.npts; ++v) add_simplex_vertex(simplex, v, obj1, simplex.simplex1.ptr[v], obj2, simplex.simplex2.ptr[v]);
    }

    /* Now the main loop. We first compute the distance between the
       current simplicies, the check whether this gives the globally
       correct answer, and if not construct new simplices and try again.
     */
    max_iterations = NumVertices(obj1)*NumVertices(obj2);
    /* in practice we never see more than about 6 iterations. */

    /* Counting the iterations in this way should not be necessary; a while( 1) should do just as well. */
    while (max_iterations-- > 0) {
      if (simplex.npts == 1) {
        /* simple case */
        simplex.lambdas.ptr[0] = cast(Float)1;
      } else {
        /* normal case */
        compute_subterms(simplex);
        if (use_default) use_default = default_distance(simplex);
        if (!use_default) backup_distance(simplex);
      }

      /* compute at least the displacement vectors given by the
         SimplexPoint structure. If we are to provide both witness
         points, it's slightly faster to compute those first.
       */
      if (compute_both_witnesses) {
        compute_point(xwpt1, simplex.npts, simplex.coords1, simplex.lambdas);
        compute_point(xwpt2, simplex.npts, simplex.coords2, simplex.lambdas);
        foreach (immutable d; 0..Dims) {
          displacementv.ptr[d] = xwpt2.ptr[d]-xwpt1.ptr[d];
          reverse_displacementv.ptr[d] = -displacementv.ptr[d];
        }
        if (wpt1 !is null) foreach (immutable vi; 0..Dims) (*wpt1)[vi] = xwpt1.ptr[vi];
        if (wpt2 !is null) foreach (immutable vi; 0..Dims) (*wpt2)[vi] = xwpt2.ptr[vi];
      } else {
        foreach (immutable d; 0..Dims) {
          displacementv.ptr[d] = 0;
          foreach (immutable p; 0..simplex.npts) displacementv.ptr[d] += simplex.lambdas.ptr[p]*(simplex.coords2.ptr[p].ptr[d]-simplex.coords1.ptr[p].ptr[d]);
          reverse_displacementv.ptr[d] = -displacementv.ptr[d];
        }
      }
      simplex.displacementv[] = displacementv[];

      sqrd = DOT_PRODUCT(displacementv, displacementv);

      /* if we are using a c-space simplex with DIM_PLUS_ONE
         points, this is interior to the simplex, and indicates
         that the original hulls overlap, as does the distance
         between them being too small. */
      if (sqrd < EPS) {
        simplex.error = EPS;
        return sqrd;
      }

      /* find the point in obj1 that is maximal in the
         direction displacement, and the point in obj2 that
         is minimal in direction displacement;
      */
      maxp = support_function(obj1, (use_seed ? simplex.last_best1 : InvalidVertexID), &maxv, displacementv.ptr[0..Dims]);
      minp = support_function(obj2, (use_seed ? simplex.last_best2 : InvalidVertexID), &minus_minv, reverse_displacementv.ptr[0..Dims]);

      /* Now apply the G-test on this pair of points */
      g_val = sqrd + maxv + minus_minv;

      if (g_val < 0.0) g_val = 0; /* not sure how, but it happens! */

      if (g_val < EPS) {
        /* then no better points - finish */
        simplex.error = g_val;
        return sqrd;
      }

      /* check for good calculation above */
      if ((first_iteration || sqrd < oldsqrd) && simplex.npts <= Dims) {
        /* Normal case: add the new c-space points to the current
           simplex, and call simplex_distance() */
        simplex.simplex1.ptr[ simplex.npts] = simplex.last_best1 = maxp;
        simplex.simplex2.ptr[ simplex.npts] = simplex.last_best2 = minp;
        simplex.lambdas.ptr[ simplex.npts] = 0;
        add_simplex_vertex(simplex, simplex.npts, obj1, maxp, obj2, minp);
        ++simplex.npts;
        oldsqrd = sqrd;
        first_iteration = 0;
        use_default = 1;
        continue;
      }

      /* Abnormal cases! */
      if (use_default) {
        use_default = false;
      } else {
        /* give up trying! */
        simplex.error = g_val;
        return sqrd;
      }
    } /* end of `while ( 1 )' */

    assert(0, "the thing that should not be"); /* we never actually get here, but it keeps some fussy compilers happy */
  }

  /*
   * A subsidary routine, that given a simplex record, the point arrays to
   * which it refers, an integer 0 or 1, and a pointer to a vector, sets
   * the coordinates of that vector to the coordinates of either the first
   * or second witness point given by the simplex record.
   */
  public Vec extractPoint (usize whichpoint) {
    if (whichpoint > 1 || !local_simplex.calculated) return Vec(Float.nan, Float.nan);
    Float[Dims] vector = void;
    compute_point(vector, local_simplex.npts, (whichpoint == 0 ? local_simplex.coords1 : local_simplex.coords2), local_simplex.lambdas[]);
    static if (Dims == 3) {
      return Vec(vector.ptr[0], vector.ptr[1], vector.ptr[2]);
    } else {
      return Vec(vector.ptr[0], vector.ptr[1]);
    }
  }

private nothrow @nogc:
  // working arrays
  Float[DIM_PLUS_ONE][TWICE_TWO_TO_DIM] delta_values;
  Float[DIM_PLUS_ONE][DIM_PLUS_ONE] dot_products;
  Float[TWICE_TWO_TO_DIM] delta_sum;
  Float[] xwpt1, xwpt2;
  SimplexPoint local_simplex;

  alias delta = delta_values;
  alias prod = dot_products;


  static Float DOT_PRODUCT (const(Float)[] a, const(Float)[] b) {
    pragma(inline, true);
    static if (Dims == 2) {
      return (a.ptr[0]*b.ptr[0])+(a.ptr[1]*b.ptr[1]);
    } else static if (Dims == 3) {
      return (a.ptr[0]*b.ptr[0])+(a.ptr[1]*b.ptr[1])+(a.ptr[2]*b.ptr[2]);
    } else {
      static assert(0, "invalid Dims");
    }
  }

  /* Basic selectors, predicates and iterators for the VObject structure;
     the idea is that you should be able to supply your own object structure,
     as long as you can fill in equivalent macros for your structure.
     */
  enum InvalidVertexID = -1;

  static int FirstVertex(VO) (in ref VO obj) { pragma(inline, true); return 0; }
  static int NumVertices(VO) (in ref VO obj) { pragma(inline, true); return obj.vertCount; }
  static void IncrementVertex(VO) (in ref VO obj, ref int vertex) { pragma(inline, true); ++vertex; }
  static bool ValidVertex(VO) (in ref VO obj, int vertex) { pragma(inline, true); return (vertex >= 0); }
  static bool LastVertex(VO) (in ref VO obj, int vertex) { pragma(inline, true); return (vertex >= obj.vertCount); }
  static Float SupportValue(VO) (in ref VO obj, int v, const(Float)[] d) {
    Float[Dims] vx = void;
    immutable vv = obj.vert(v);
    vx.ptr[0] = vv.x;
    vx.ptr[1] = vv.y;
    static if (Dims == 3) vx.ptr[2] = vv.z;
    return DOT_PRODUCT(vx[], d);
  }

  static int VertexOfEdge(VO) (in ref VO obj, int edge) { pragma(inline, true); return obj.ring(edge); }
  static int FirstEdge(VO) (in ref VO obj, int vertex) { pragma(inline, true); return obj.ring(vertex); }
  static bool ValidEdge(VO) (in ref VO obj, int edge) { pragma(inline, true); return (obj.ring(edge) >= 0); }
  static void IncrementEdge(VO) (in ref VO obj, ref int edge) { pragma(inline, true); ++edge; }

  static bool ValidRings(VO) (in ref VO obj) {
    pragma(inline, true);
    static if (is(typeof(obj.ringCount))) {
      return (obj.ringCount > 0);
    } else {
      return false;
    }
  }

  /* The above set up for vertices to be stored in an array, and for
   * edges to be encoded within a single array of integers as follows.
   * Consider a hull whose vertices are stored in array
   * Pts, and edge topology in integer array Ring. Then the indices of
   * the neighbouring vertices to the vertex with index i are Ring[j],
   * Ring[j+1], Ring[j+2], etc, where j = Ring[i] and the list of
   * indices are terminated with a negative number. Thus the contents
   * of Ring for a tetrahedron could be
   *
   *  [ 4, 8, 12, 16,  1, 2, 3, -1,  0, 2, 3, -1,  0, 1, 3, -1,  0, 1, 2, -1 ]
   *
   */

  /* typedefs for `opaque' pointers to a vertex and to an edge */
  alias VertexID = int;
  alias EdgeID = int;

  /* TINY is used in one place, to indicate when a positive number is getting
     so small that we loose confidence in being able to divide a positive
     number smaller than it into it, and still believing the result.
     */
  static if (is(Float == float)) {
    enum TINY = cast(Float)1.0e-10; /* probably pessimistic! */
  } else {
    enum TINY = cast(Float)1.0e-20; /* probably pessimistic! */
  }


  /* MAX_RING_SIZE gives an upper bound on the size of the array of rings
   * of edges in terms of the number of vertices. From the formula
   *   v - e + f = 2
   * and the relationships that there are two half-edges for each edge,
   * and at least 3 half-edges per face, we obtain
   *   h <= 6v - 12
   * Add to this another v entries for the initial pointers to each ring,
   * another v entries to indicate the end of each ring list, and round it
   * up.
   */
  enum MAX_RING_SIZE_MULTIPLIER = 8;


  /* standard definitions, derived from those in gjk.h */
  enum TWO_TO_DIM = 1<<Dims; /* must have TWO_TO_DIM = 2^Dims */
  enum DIM_PLUS_ONE = Dims+1;
  enum TWICE_TWO_TO_DIM = TWO_TO_DIM+TWO_TO_DIM;

  /* The following #defines are defined to make the code easier to
     read: they are simply standard accesses of the following
     arrays.
   */
  alias card = cardinality;
  alias max_elt = max_element;
  alias elts = elements;
  alias non_elts = non_elements;
  alias pred = predecessor;
  alias succ = successor;
  /* The following arrays store the constant subset structure -- see the
     comments in ctor for the data-invariants.
     Note that the entries could easily be packed, as say for any subset
     with index s we have only DIM_PLUS_ONE active entries in total for
     both elts( s,) and non_elts( s,), and ditto for prec( s,) and succ( s,).
     We have not bothered here as the tables are small.
     */
  __gshared immutable int[TWICE_TWO_TO_DIM] cardinality;
  __gshared immutable int[TWICE_TWO_TO_DIM] max_element;
  __gshared immutable int[DIM_PLUS_ONE][TWICE_TWO_TO_DIM] elements;
  __gshared immutable int[DIM_PLUS_ONE][TWICE_TWO_TO_DIM] non_elements;
  __gshared immutable int[DIM_PLUS_ONE][TWICE_TWO_TO_DIM] predecessor;
  __gshared immutable int[DIM_PLUS_ONE][TWICE_TWO_TO_DIM] successor;

  /* initialise_simplex_distance is called just once per activation of this
     code, to set up some internal tables. It takes around 5000 integer
     instructions for Dims==3.
     */
  shared static this () {
    int power, d, s, e, two_to_e, next_elt, next_non_elt, pr;
    int[TWICE_TWO_TO_DIM] num_succ;

    // check that TWO_TO_DIM is two to the power of Dims
    power = 1;
    for (d = 0; d < Dims; ++d) power *= 2;
    assert(power == TWO_TO_DIM);

    // initialise the number of successors array
    for (s = 0; s < TWICE_TWO_TO_DIM; ++s) num_succ[s] = 0;
    /* Now the main bit of work. Simply stated, we wish to encode
      within the matrices listed below information about each possible
      subset of DIM_PLUS_ONE integers e in the range
      0 <= e < DIM_PLUS_ONE. There are TWICE_TWO_TO_DIM such subsets,
      including the trivial empty subset. We wish to ensure that the
      subsets are ordered such that all the proper subsets of subset
      indexed s themselves have indexes less than s. The easiest way
      to do this is to take the natural mapping from integers to
      subsets, namely integer s corresponds to the subset that contains
      element e if and only if there is a one in the e'th position in
      the binary expansion of s.

      The arrays set are as follows:
      *  card( s) tells how many elements are in the subset s.
      *  max_elt( s) gives the maximum index of all the elements in
         subset s.
      *  elts( s, i) for 0 <= i < card( s) lists the indices of the
         elements in subset s.
      *  non_elts( s, i) for 0 <= i < DIM_PLUS_ONE-card( s) lists the
         indices of the elements that are not in subset s.
      *  pred( s, i) for 0 <= i < card( s) lists the indices of the
         subsets that are subsets of subset s, but with one fewer
         element, namely the element with index elts( s, i).
      *  succ( s, i) for 0 <= i < DIM_PLUS_ONE-card( s) lists the
         indices of the supersets of subset s that have one extra
         element, namely the element with index non_elts( s, i).

      The elements indexed in each elts( s,) and non_elts( s,) are
      listed in order of increasing index.
     */

    /* now for every non-empty subset s (indexed for
      0 < s < TWICE_TWO_TO_DIM ) set the elements of card( s),
      max_elt( s), elts( s,), pred( s,), and succ( s,).
      */

    for (s = 1; s < TWICE_TWO_TO_DIM; ++s) {
      /* Now consider every possible element. Element e is in subset s if and only if s DIV 2^e is odd. */
      two_to_e = 1;
      next_elt = next_non_elt = 0;

      for (e = 0; e < DIM_PLUS_ONE; ++e) {
        if ((s/two_to_e)%2 == 1) {
          /* so e belongs to subset s */
          elts[s][next_elt] = e;
          pr = s - two_to_e;
          pred[s][next_elt] = pr;
          succ[pr][num_succ[pr]] = s;
          num_succ[ pr]++;
          next_elt++;
        } else {
          non_elts[s][next_non_elt++] = e;
        }
        two_to_e *= 2;
      }
      card[s] = next_elt;
      max_elt[s] = elts[s][next_elt-1];
    }

    /* for completeness, add the entries for s=0 as well */
    card[0] = 0;
    max_elt[0] = -1;
    for ( e=0 ; e<DIM_PLUS_ONE ; e++ ) non_elts[0][e] = e;
  }


  /* Computes the coordinates of a simplex point.
     Takes an array into which the stuff the result, the number of vertices
     that make up a simplex point, one of the point arrays, the indices of
     which of the points are used in the for the simplex points, and an
     array of the lambda values.
     */
  static void compute_point (Float[] pt, int len, const(Float)[Dims][] vertices, Float[] lambdas) {
    foreach (immutable d; 0..Dims) {
      pt[d] = 0;
      foreach (immutable i; 0..len ) pt[d] += vertices.ptr[i].ptr[d]*lambdas.ptr[i];
    }
  }

  void reset_simplex (int subset, SimplexPoint* simplex) {
    /* compute the lambda values that indicate exactly where the
      witness points lie. We also fold back the values stored for the
      indices into the original point arrays, and the transformed
      coordinates, so that these are ready for subsequent calls.
     */
    foreach (immutable j; 0..card.ptr[subset]) {
     /* rely on elts( subset, j)>=j, which is true as they are stored in ascending order. */
      auto oldpos = elts.ptr[subset].ptr[j];
      if (oldpos != j) {
        simplex.simplex1.ptr[j] = simplex.simplex1.ptr[oldpos];
        simplex.simplex2.ptr[j] = simplex.simplex2.ptr[oldpos];
        foreach (immutable i; 0..Dims) {
          simplex.coords1.ptr[j].ptr[i] = simplex.coords1.ptr[oldpos].ptr[i];
          simplex.coords2.ptr[j].ptr[i] = simplex.coords2.ptr[oldpos].ptr[i];
        }
      }
      simplex.lambdas.ptr[j] = delta.ptr[subset].ptr[elts.ptr[subset].ptr[j]]/delta_sum.ptr[subset];
    }
    simplex.npts = card.ptr[subset];
  }

  /* The simplex_distance routine requires the computation of a number of delta terms. These are computed here. */
  void compute_subterms (SimplexPoint* simp) {
    int i, j, ielt, jelt, s, jsubset, size = simp.npts;
    Float[Dims][DIM_PLUS_ONE] c_space_points;
    Float sum;

    /* compute the coordinates of the simplex as C-space obstacle points */
    for (i = 0; i < size; i++ )
      for ( j=0 ; j<Dims ; j++ )
         c_space_points.ptr[i].ptr[j] = simp.coords1.ptr[i].ptr[j] - simp.coords2.ptr[i].ptr[j];

    /* compute the dot product terms */
    for ( i=0 ; i<size ; i++ )
      for ( j=i ; j<size ; j++ )
         prod.ptr[i].ptr[j] = prod.ptr[j].ptr[i] = DOT_PRODUCT(c_space_points.ptr[i], c_space_points.ptr[j]);

    /* now compute all the delta terms */
    for ( s=1 ; s<TWICE_TWO_TO_DIM && max_elt.ptr[s] < size ; s++ ) {
      if ( card.ptr[s]<=1 ) {  /* just record delta(s, elts(s, 0)) */
         delta.ptr[s].ptr[elts.ptr[s].ptr[0]] = cast(Float)1;
         continue;
      }

      if ( card.ptr[s]==2 ) {  /* the base case for the recursion */
         delta.ptr[s].ptr[elts.ptr[s].ptr[0]] =
            prod.ptr[elts.ptr[s].ptr[1]].ptr[elts.ptr[s].ptr[1]] -
            prod.ptr[elts.ptr[s].ptr[1]].ptr[elts.ptr[s].ptr[0]];
         delta.ptr[s].ptr[elts.ptr[s].ptr[1]] =
            prod.ptr[elts.ptr[s].ptr[0]].ptr[elts.ptr[s].ptr[0]] -
            prod.ptr[elts.ptr[s].ptr[0]].ptr[elts.ptr[s].ptr[1]];
         continue;
      }

      /* otherwise, card( s)>2, so use the general case */

      /* for each element of this subset s, namely elts( s, j) */
      for ( j=0 ; j<card.ptr[s] ; j++ ) {
         jelt = elts.ptr[s].ptr[j];
         jsubset = pred.ptr[s].ptr[j];
         sum = 0;
         /* for each element of subset jsubset */
         for ( i=0 ; i < card.ptr[jsubset] ; i++ ) {
            ielt = elts.ptr[jsubset].ptr[i];
            sum += delta.ptr[jsubset].ptr[ielt]*(prod.ptr[ielt].ptr[elts.ptr[jsubset].ptr[0]]-prod.ptr[ielt].ptr[jelt]);
         }

         delta.ptr[s].ptr[jelt] = sum;
      }
    }
  }

  /*
   * default_distance is our equivalent of GJK's distance subalgorithm.
   * It is given a c-space simplex as indices of size (up to DIM_PLUS_ONE) points
   * in the master point list, and computes a pair of witness points for the
   * minimum distance vector between the simplices. This vector is indicated
   * by setting the values lambdas[] in the given array, and returning the
   * number of non-zero values of lambda.
   */
  bool default_distance (SimplexPoint* simplex) {
    int s, j, k, ok, size;

    size = simplex.npts;

    assert( size>0 && size<=DIM_PLUS_ONE );


    /* for every subset s of the given set of points ...
      */
    for ( s=1 ; s < TWICE_TWO_TO_DIM && max_elt.ptr[s] < size ; s++ ) {
      /* delta_sum[s] will accumulate the sum of the delta expressions for
         this subset, and ok will remain TRUE whilst this subset can
         still be thought to be a candidate simplex for the shortest
         distance.
         */
      delta_sum.ptr[s] = 0;
      ok=1;

      /* Now the first check is whether the simplex formed by this
         subset holds the foot of the perpendicular from the origin
         to the point/line/plane passing through the simplex. This will
         be the case if all the delta terms for each predecessor subset
         are (strictly) positive.
         */
      for ( j=0 ; ok && j<card.ptr[s] ; j++ ) {
         if ( delta.ptr[s].ptr[elts.ptr[s].ptr[j]]>0 )
            delta_sum.ptr[s] += delta.ptr[s].ptr[elts.ptr[s].ptr[j]];
         else
            ok = 0;
      }

      /* If the subset survives the previous test, we still need to check
         whether the true minimum distance is to a larger piece of geometry,
         or indeed to another piece of geometry of the same dimensionality.
         A necessary and sufficient condition for it to fail at this stage
         is if the delta term for any successor subset is positive, as this
         indicates a direction on the appropriate higher dimensional simplex
         in which the distance gets shorter.
         */

      for ( k=0 ; ok && k < size - card.ptr[s] ; k++ ) {
         if ( delta.ptr[succ.ptr[s].ptr[k]].ptr[non_elts.ptr[s].ptr[k]]>0 )
            ok = 0;
      }

      version(GJK_TEST_BACKUP_PROCEDURE) {
        /* define GJK_TEST_BACKUP_PROCEDURE to test accuracy of the the backup procedure */
        ok = 0;
      }

      if ( ok && delta_sum.ptr[s]>=TINY )   /* then we've found a viable subset */
         break;
    }

    if ( ok ) {
     reset_simplex( s, simplex);
     return true;
    }

    return false;
  }

  /* A version of GJK's `Backup Procedure'.
     Note that it requires that the delta_sum[s] entries have been
     computed for all viable s within simplex_distance.
     */
  void backup_distance (SimplexPoint* simplex) {
    int s, i, j, k, bests;
    int size = simplex.npts;
    Float[TWICE_TWO_TO_DIM] distsq_num, distsq_den;

    /* for every subset s of the given set of points ...
      */
    bests = 0;
    for ( s=1 ; s < TWICE_TWO_TO_DIM && max_elt.ptr[s] < size ; s++ ) {
      if ( delta_sum.ptr[s] <= 0 )
         continue;

      for ( i=0 ; i<card.ptr[s] ; i++ )
         if ( delta.ptr[s].ptr[elts.ptr[s].ptr[i]]<=0 )
            break;

      if (  i < card.ptr[s] )
         continue;

      /* otherwise we've found a viable subset */
      distsq_num.ptr[s] = 0;
      for ( j=0 ; j<card.ptr[s] ; j++ )
         for ( k=0 ; k<card.ptr[s] ; k++ )
            distsq_num.ptr[s] += (delta.ptr[s].ptr[elts.ptr[s].ptr[j]]*delta.ptr[s].ptr[elts.ptr[s].ptr[k]])*prod.ptr[elts.ptr[s].ptr[j]].ptr[elts.ptr[s].ptr[k]];

      distsq_den.ptr[s] = delta_sum.ptr[s]*delta_sum.ptr[s];

      if (bests < 1 || distsq_num.ptr[s]*distsq_den.ptr[bests] < distsq_num.ptr[bests]*distsq_den.ptr[s]) bests = s;
    }

    reset_simplex( bests, simplex);
  }

  static VertexID support_simple(VO) (in ref VO obj, VertexID start, Float* supportval, Float[] direction) {
    VertexID p, maxp;
    Float maxv, thisv;

    /* then no information for hill-climbing. Use brute-force instead. */
    p = maxp = FirstVertex(obj);
    maxv = SupportValue(obj, maxp, direction);
    for (IncrementVertex(obj, p); !LastVertex(obj, p); IncrementVertex(obj, p)) {
      thisv = SupportValue(obj, p, direction);
      if (thisv > maxv) {
        maxv = thisv;
        maxp = p;
      }
    }
    *supportval = maxv;
    return maxp;
  }

  static VertexID support_hill_climbing(VO) (in ref VO obj, VertexID start, Float* supportval, Float[] direction) {
    VertexID p, maxp, lastvisited, neighbour;
    EdgeID index;
    Float maxv, thisv;

    /* Use hill-climbing */
    p = lastvisited = InvalidVertexID;
    maxp = (!ValidVertex(obj, start) ? FirstVertex(obj) : start);
    maxv = SupportValue(obj, maxp, direction);

    while (p != maxp) {
      p = maxp;
      /* Check each neighbour of the current point. */
      for (index = FirstEdge(obj, p); ValidEdge(obj, index); IncrementEdge(obj, index)) {
        neighbour = VertexOfEdge(obj, index);
        /* Check that we haven't already visited this one in the
         * last outer iteration. This is to avoid us calculating
         * the dot-product with vertices we've already looked at.
         */
        if (neighbour == lastvisited) continue;
        thisv = SupportValue(obj, neighbour, direction);
        if (thisv > maxv) {
          maxv = thisv;
          maxp = neighbour;
          version(GJK_EAGER_HILL_CLIMBING) break; // Gilbert & Ong's eager behaviour
        }
      }
      lastvisited = p;
    }
    *supportval = maxv;
    return p;
  }

  /*
   * The implementation of the support function. Given a direction and
   * a hull, this function returns a vertex of the hull that is maximal
   * in that direction, and the value (i.e., dot-product of the maximal
   * vertex and the direction) associated.
   *
   * If there is no topological information given for the hull
   * then an exhaustive search of the vertices is used. Otherwise,
   * hill-climbing is performed. If GJK_EAGER_HILL_CLIMBING is defined
   * then the hill-climbing moves to a new vertex as soon as a better
   * vertex is found, and if it is not defined then every vertex leading
   * from the current vertex is explored before moving to the best one.
   * Initial conclusions are that fewer vertices are explored with
   * GJK_EAGER_HILL_CLIMBING defined, but that the code runs slighty slower!
   * This is presumably due to pipeline bubbles and/or cache misses.
   *
   */
  static VertexID support_function(VO) (in ref VO obj, VertexID start, Float* supportval, Float[] direction) {
    if (!ValidRings(obj)) {
      /* then no information for hill-climbing. Use brute-force instead. */
      return support_simple(obj, start, supportval, direction);
    } else {
      return support_hill_climbing(obj, start, supportval, direction);
    }
  }

  static void add_simplex_vertex(VO1, VO2) (SimplexPoint* s, int pos, in ref VO1 obj1, VertexID v1, in ref VO2 obj2, VertexID v2) {
    immutable vc0 = obj1.vert(v1);
    s.coords1.ptr[pos].ptr[0] = vc0.x;
    s.coords1.ptr[pos].ptr[1] = vc0.y;
    static if (Dims == 3) s.coords1.ptr[pos].ptr[2] = vc0.z;
    immutable vc1 = obj2.vert(v2);
    s.coords2.ptr[pos].ptr[0] = vc1.x;
    s.coords2.ptr[pos].ptr[1] = vc1.y;
    static if (Dims == 3) s.coords2.ptr[pos].ptr[2] = vc1.z;
  }
}
