/*
 * Cassowary.D: an incremental constraint solver for D
 *
 * Copyright (C) 2005-2006 Jo Vermeulen (jo.vermeulen@uhasselt.be)
 * Converted to D by Ketmar // Invisible Vector (ketmar@ketmar.no-ip.org)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public License
 * as published by the Free Software Foundation; either version 2.1
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */
module iv.cassowary is aliced;


// ////////////////////////////////////////////////////////////////////////// //
alias CswNumber = double;
alias CswStrength = CswNumber;


// ////////////////////////////////////////////////////////////////////////// //
private mixin template CswErrorErrorBody() {
  @safe pure nothrow this (string msg, string file=__FILE__, usize line=__LINE__, Throwable next=null) {
    super(msg, file, line, next);
  }
}


class CswError : Exception { mixin CswErrorErrorBody; }


private enum error(string name) = `class CswError`~name~` : CswError { mixin CswErrorErrorBody; }`;

mixin(error!("ConstraintNotFound"));
mixin(error!("InternalError"));
mixin(error!("NonlinearExpression"));
mixin(error!("NotEnoughStays"));
mixin(error!("RequiredFailure"));
mixin(error!("TooDifficult"));
mixin(error!("Parser"));
mixin(error!("NoVariable"));
mixin(error!("InvalidMathOp"));


// ////////////////////////////////////////////////////////////////////////// //
/// The enumerations from CswLinearInequality,
/// and `global' functions that we want easy to access
abstract class Csw {
  private import std.traits : isSomeString;

final:
static:
  enum CompOp {
    GEQ = 1,
    LEQ = 2
  }

  CswLinearExpression plus (CswLinearExpression e1, CswLinearExpression e2) nothrow => e1.plus(e2);
  CswLinearExpression plus (CswNumber e1, CswLinearExpression e2) nothrow => (new CswLinearExpression(e1)).plus(e2);
  CswLinearExpression plus (CswVariable e1, CswLinearExpression e2) nothrow => (new CswLinearExpression(e1)).plus(e2);
  CswLinearExpression plus (CswLinearExpression e1, CswVariable e2) nothrow => e1.plus(new CswLinearExpression(e2));
  CswLinearExpression plus (CswVariable e1, CswNumber e2) nothrow => (new CswLinearExpression(e1)).plus(new CswLinearExpression(e2));
  CswLinearExpression plus (CswNumber e1, CswVariable e2) nothrow => (new CswLinearExpression(e1)).plus(new CswLinearExpression(e2));
  CswLinearExpression minus (CswLinearExpression e1, CswLinearExpression e2) nothrow => e1.minus(e2);
  CswLinearExpression minus (CswNumber e1, CswLinearExpression e2) nothrow => (new CswLinearExpression(e1)).minus(e2);
  CswLinearExpression minus (CswLinearExpression e1, CswNumber e2) nothrow => e1.minus(new CswLinearExpression(e2));
  CswLinearExpression times (CswLinearExpression e1, CswLinearExpression e2) => e1.times(e2);
  CswLinearExpression times (CswLinearExpression e1, CswVariable e2) => e1.times(new CswLinearExpression(e2));
  CswLinearExpression times (CswVariable e1, CswLinearExpression e2) => (new CswLinearExpression(e1)).times(e2);
  CswLinearExpression times (CswLinearExpression e1, CswNumber e2) => e1.times(new CswLinearExpression(e2));
  CswLinearExpression times (CswNumber e1, CswLinearExpression e2) => (new CswLinearExpression(e1)).times(e2);
  CswLinearExpression times (CswNumber n, CswVariable clv) nothrow => new CswLinearExpression(clv, n);
  CswLinearExpression times (CswVariable clv, CswNumber n) nothrow => new CswLinearExpression(clv, n);
  CswLinearExpression divide (CswLinearExpression e1, CswLinearExpression e2) => e1.divide(e2);

  bool approx (CswNumber a, CswNumber b) pure @safe nothrow @nogc {
    import std.math : abs;
    enum CswNumber epsilon = 1.0e-8;
    if (a == 0.0) return (abs(b) < epsilon);
    if (b == 0.0) return (abs(a) < epsilon);
    return (abs(a-b) < abs(a)*epsilon);
  }

  bool approx (CswVariable clv, CswNumber b) pure @safe nothrow @nogc => approx(clv.value, b);
  bool approx (CswNumber a, CswVariable clv) pure @safe nothrow @nogc => approx(a, clv.value);

  CswStrength Strength (string name) @safe nothrow @nogc {
    switch (name) {
      case "required": return Csw.Required;
      case "strong": return Csw.Strong;
      case "medium": return Csw.Medium;
      case "weak": return Csw.Weak;
      default: assert(0, "invalid strength name");
    }
  }

  private enum SWMult = 1000.0;
  CswNumber Strength (in CswNumber w1, in CswNumber w2, in CswNumber w3) @safe nothrow @nogc =>
    w3+w2*SWMult+w1*(SWMult*SWMult);

  enum Required = Strength(1000, 1000, 1000);
  enum Strong = Strength(1, 0, 0);
  enum Medium = Strength(0, 1, 0);
  enum Weak = Strength(0, 0, 1);

  private bool isRequiredStrength (CswStrength str) @safe pure nothrow @nogc => (str >= Required);
}


// ////////////////////////////////////////////////////////////////////////// //
// constraints
class CswConstraint {
private:
  static uint mCstIndex;

  @property static uint newIndex () @trusted nothrow @nogc {
    if (++mCstIndex == 0) assert(0, "out of constraint indexes");
    return mCstIndex;
  }

  uint cindex;
  CswStrength mStrength = void;
  CswNumber mWeight;

public:
  override string toString () const {
    import std.string : format;
    // example output: weak:[0,0,1] {1} (23 + -1*[update.height:23]
    return format("%s {%s} (%s", mStrength, weight, expressionStr);
  }

  abstract @property string expressionStr () const;

@nogc:
@safe:
nothrow:
  this (in CswStrength strength=Csw.Required, CswNumber weight=1.0) {
    cindex = newIndex;
    mStrength = strength;
    mWeight = weight;
  }

  abstract @property CswLinearExpression expression ();

  pure {
    @property bool isEditConstraint () const => false;
    @property bool isInequality () const => false;
    @property bool isRequired () const => Csw.isRequiredStrength(mStrength);
    @property bool isStayConstraint () const => false;
  }

final:
  @property ref CswStrength strength () => mStrength;
  @property void strength (in CswStrength v) => mStrength = v;

  @property CswNumber weight () const pure => mWeight;
  @property void weight (CswNumber v) => mWeight = v;
}


class CswEditOrStayConstraint : CswConstraint {
  protected CswVariable mVariable;
  // cache the expression
  private CswLinearExpression mExpression;

public:
  // add missing bracket -> see CswConstraint#ToString(...)
  override string toString () const => super.toString()~")";
  override @property string expressionStr () const => mExpression.toString;

@safe:
nothrow:
  this (CswVariable var, in CswStrength strength=Csw.Required, CswNumber weight=1.0) {
    super(strength, weight);
    mVariable = var;
    mExpression = new CswLinearExpression(mVariable, -1.0, mVariable.value);
  }

@nogc:
  final @property CswVariable variable () pure => mVariable;
  override @property CswLinearExpression expression () pure => mExpression;
}


class CswEditConstraint : CswEditOrStayConstraint {
  override string toString () const => "edit"~super.toString();
@safe:
nothrow:
  this (CswVariable clv, in CswStrength strength=Csw.Required, CswNumber weight=1.0) => super(clv, strength, weight);
  override @property bool isEditConstraint () const pure @nogc => true;
}


public class CswLinearConstraint : CswConstraint {
protected:
  CswLinearExpression mExpression;

public:
  override @property string expressionStr () const => mExpression.toString;

@safe:
nothrow:
  this (CswLinearExpression cle, in CswStrength strength=Csw.Required, CswNumber weight=1.0) {
    super(strength, weight);
    mExpression = cle;
  }
  override @property CswLinearExpression expression () pure @nogc => mExpression;
  //protected final void setExpression (CswLinearExpression expr) => mExpression = expr;
}


public class CswStayConstraint : CswEditOrStayConstraint {
  override string toString () const => "stay"~super.toString();
@safe:
nothrow:
  this (CswVariable var, in CswStrength strength=Csw.Weak, CswNumber weight=1.0) => super(var, strength, weight);
  override @property bool isStayConstraint () const pure @nogc => true;
}


class CswLinearEquation : CswLinearConstraint {
  private enum buildCtor(string args, string body) =
    `this (`~args~`, in CswStrength strength=Csw.Required, CswNumber weight=1.0) {`~body~`}`;

  override string toString () const => super.toString()~" = 0)";
nothrow:
  @safe {
    mixin(buildCtor!("CswLinearExpression cle", q{ super(cle, strength, weight); }));
  }

  mixin(buildCtor!("CswAbstractVariable clv, CswLinearExpression cle", q{
    super(cle, strength, weight);
    mExpression.addVariable(clv, -1.0);
  }));

  mixin(buildCtor!("CswAbstractVariable clv, CswNumber val", q{
    super(new CswLinearExpression(val), strength, weight);
    mExpression.addVariable(clv, -1.0);
  }));

  mixin(buildCtor!("CswLinearExpression cle, CswAbstractVariable clv", q{
    super(cast(CswLinearExpression)cle.clone(), strength, weight);
    mExpression.addVariable(clv, -1.0);
  }));

  mixin(buildCtor!("CswLinearExpression cle1, CswLinearExpression cle2", q{
    super(cast(CswLinearExpression)cle1.clone(), strength, weight);
    mExpression.addExpression(cle2, -1.0);
  }));

  mixin(buildCtor!("CswAbstractVariable cle, CswAbstractVariable clv", q{
    this(new CswLinearExpression(cle), clv, strength, weight);
  }));
}


class CswLinearInequality : CswLinearConstraint {
  private enum buildCtor(string args, string opr, string sup, string adder="addVariable") =
    `this (`~args~`, in CswStrength strength=Csw.Required, CswNumber weight=1.0) {`~
      sup~
      `switch (op) {`~
      `  case Csw.CompOp.GEQ:`~
      `    mExpression.multiplyMe(-1.0);`~
      `    mExpression.`~adder~`(`~opr~`);`~
      `    break;`~
      `  case Csw.CompOp.LEQ:`~
      `    mExpression.`~adder~`(`~opr~`, -1.0);`~
      `    break;`~
      `  default:`~
      `    throw new CswErrorInternalError("Invalid operator in CswLinearInequality constructor");`~
      `}`~
    `}`;

  this (CswLinearExpression cle, in CswStrength strength=Csw.Required, CswNumber weight=1.0) @safe nothrow {
    super(cle, strength, weight);
  }

  mixin(buildCtor!("CswVariable clv1, Csw.CompOp op, CswVariable clv2",
    `clv1`,
    `super(new CswLinearExpression(clv2), strength, weight);`));

  mixin(buildCtor!("CswVariable clv, Csw.CompOp op, CswNumber val",
    `clv`,
    `super(new CswLinearExpression(val), strength, weight);`));

  mixin(buildCtor!("CswLinearExpression cle1, Csw.CompOp op, CswLinearExpression cle2",
    `cle1`,
    `super(cast(CswLinearExpression)cle2.clone(), strength, weight);`,
    `addExpression`));

  mixin(buildCtor!("CswAbstractVariable clv, Csw.CompOp op, CswLinearExpression cle",
    `clv`,
    `super(cast(CswLinearExpression)cle.clone(), strength, weight);`));

  mixin(buildCtor!("CswLinearExpression cle, Csw.CompOp op, CswAbstractVariable clv",
    `clv`,
    `super(cast(CswLinearExpression)cle.clone(), strength, weight);`));

  override @property bool isInequality () const @safe pure nothrow @nogc => true;

  public override string toString () const => super.toString()~" >= 0)";
}


// ////////////////////////////////////////////////////////////////////////// //
// expressions
class CswLinearExpression {
private:
  CswNumber mConstant;

  struct Term {
    CswAbstractVariable var;
    CswNumber num;
  }

  Term[uint] mTerms; // from CswVariable to CswNumber, key is `vindex`

public:
  /// Create 'semi-valid' zero constant
  this () @safe nothrow => this(0.0);
  /// Create constant
  this (CswNumber num) @safe nothrow => this(null, 0.0, num);
  // / Create variable with multiplier
  // this (CswAbstractVariable clv, CswNumber multiplier=1.0) @safe nothrow => this(clv, multiplier, 0.0);
  /// Create either variable with multiplier or constant (internal constructor).
  /// Used in CswEditOrStayConstraint
  this (CswAbstractVariable clv, CswNumber multiplier=1.0, CswNumber constant=0.0) @safe nothrow {
    //Csw.gcln("new CswLinearExpression");
    mConstant = constant;
    if (clv !is null) mTerms[clv.vindex] = Term(clv, multiplier);
  }

  /// For use by the clone method
  protected this (in CswNumber constant, Term[uint] terms) @trusted nothrow {
    //Csw.gcln("clone CswLinearExpression");
    mConstant = constant;
    // '_aaApply2' is not nothrow %-(
    try {
      foreach (ref clv; terms.byValue) mTerms[clv.var.vindex] = clv;
    } catch (Exception) {}
  }

  /// Clone this expression
  CswLinearExpression clone () @safe nothrow => new CswLinearExpression(mConstant, mTerms);

  /// Multiply this expression by scalar
  CswLinearExpression multiplyMe (in CswNumber x) @trusted nothrow @nogc {
    mConstant *= x;
    foreach (ref cld; mTerms.byValue) cld.num *= x;
    return this;
  }

  final CswLinearExpression times (in CswNumber x) @safe nothrow => clone().multiplyMe(x);

  final CswLinearExpression times (CswLinearExpression expr) {
    if (isConstant) return expr.times(mConstant);
    if (!expr.isConstant) {
      //import csw.errors : CswErrorNonlinearExpression;
      throw new CswErrorNonlinearExpression("CswLinearExpression times(): expr is not constant");
    }
    return times(expr.mConstant);
  }

  final CswLinearExpression plus (CswLinearExpression expr) nothrow => clone().addExpression(expr, 1.0);
  final CswLinearExpression plus (CswVariable var) nothrow => clone().addVariable(var, 1.0);

  final CswLinearExpression minus (CswLinearExpression expr) nothrow => clone().addExpression(expr, -1.0);
  final CswLinearExpression minus (CswVariable var) nothrow => clone().addVariable(var, -1.0);

  CswLinearExpression divide (in CswNumber x) {
    if (Csw.approx(x, 0.0)) {
      //import csw.errors : CswErrorNonlinearExpression;
      throw new CswErrorNonlinearExpression("CswLinearExpression divide(): division by zero");
    }
    return times(1.0/x);
  }

  final CswLinearExpression divide (CswLinearExpression expr) {
    if (!expr.isConstant) {
      //import csw.errors : CswErrorNonlinearExpression;
      throw new CswErrorNonlinearExpression("CswLinearExpression divide(): expr is not constant");
    }
    return divide(expr.mConstant);
  }

  final CswLinearExpression divFrom (CswLinearExpression expr) {
    if (!isConstant) {
      //import csw.errors : CswErrorNonlinearExpression;
      throw new CswErrorNonlinearExpression("CswLinearExpression divFrom(): division by non-constant");
    }
    if (Csw.approx(mConstant, 0.0)) {
      //import csw.errors : CswErrorNonlinearExpression;
      throw new CswErrorNonlinearExpression("CswLinearExpression divFrom(): division by zero");
    }
    return expr.divide(mConstant);
  }

  final CswLinearExpression subtractFrom (CswLinearExpression expr) nothrow => expr.minus(this);

  final CswLinearExpression opBinary(string op) (in CswNumber n) if (op == "*") => this.times(n);
  final CswLinearExpression opBinary(string op) (CswLinearExpression expr) if (op == "*") => this.times(expr);

  final CswLinearExpression opBinary(string op) (in CswNumber n) if (op == "/") => this.divide(n);
  final CswLinearExpression opBinary(string op) (CswLinearExpression expr) if (op == "/") => this.divide(expr);

  final CswLinearExpression opBinary(string op) (CswLinearExpression expr) if (op == "+") => this.plus(expr);
  final CswLinearExpression opBinary(string op) (CswVariable var) if (op == "+") => this.plus(var);

  final CswLinearExpression opBinary(string op) (CswLinearExpression expr) if (op == "-") => this.minus(expr);
  final CswLinearExpression opBinary(string op) (CswVariable var) if (op == "-") => this.minus(var);

  /// Add n*expr to this expression from another expression expr.
  /// Notify the solver if a variable is added or deleted from this
  /// expression.
  final CswLinearExpression addExpression (CswLinearExpression expr, in CswNumber n=1.0,
                                           CswAbstractVariable subject=null, CswTableau solver=null) nothrow
  {
    incrementConstant(n*expr.constant);
    // '_aaApply2' is not nothrow
    try {
      foreach (ref clv; expr.mTerms.byValue) addVariable(clv.var, clv.num*n, subject, solver);
      return this;
    } catch(Exception) {
      assert(0);
    }
  }

  /// Add a term c*v to this expression.  If the expression already
  /// contains a term involving v, add c to the existing coefficient.
  /// If the new coefficient is approximately 0, delete v.  Notify the
  /// solver if v appears or disappears from this expression.
  final CswLinearExpression addVariable (CswAbstractVariable v, in CswNumber c=1.0,
                                         CswAbstractVariable subject=null, CswTableau solver=null) nothrow
  {
    assert(v !is null);
    // body largely duplicated below
    if (auto coeff = v.vindex in mTerms) {
      CswNumber newCoefficient = coeff.num+c;
      if (Csw.approx(newCoefficient, 0.0)) {
        mTerms.remove(v.vindex);
        if (subject !is null && solver !is null) solver.noteRemovedVariable(v, subject);
      } else {
        coeff.num = newCoefficient;
      }
    } else {
      if (!Csw.approx(c, 0.0)) {
        mTerms[v.vindex] = Term(v, c);
        if (subject !is null && solver !is null) solver.noteAddedVariable(v, subject);
      }
    }
    return this;
  }

  final CswLinearExpression setVariable (CswAbstractVariable v, CswNumber c) nothrow {
    //assert(c != 0.0);
    assert(v !is null);
    if (auto tt = v.vindex in mTerms) {
      tt.num = c;
    } else {
      mTerms[v.vindex] = Term(v, c);
    }
    return this;
  }

  /// Return a pivotable variable in this expression.  (It is an error
  /// if this expression is constant -- signal ExCLInternalError in
  /// that case).  Return null if no pivotable variables
  final CswAbstractVariable anyPivotableVariable () {
    if (isConstant) {
      //import csw.errors : CswErrorInternalError;
      throw new CswErrorInternalError("anyPivotableVariable called on a constant");
    }
    foreach (ref clv; mTerms.byValue) if (clv.var.isPivotable) return clv.var;
    // No pivotable variables, so just return null, and let the caller error if needed
    return null;
  }

  /// Replace var with a symbolic expression expr that is equal to it.
  /// If a variable has been added to this expression that wasn't there
  /// before, or if a variable has been dropped from this expression
  /// because it now has a coefficient of 0, inform the solver.
  /// PRECONDITIONS:
  ///   var occurs with a non-zero coefficient in this expression.
  final void substituteOut (CswAbstractVariable var, CswLinearExpression expr, CswAbstractVariable subject,
                            CswTableau solver) nothrow
  {
    CswNumber multiplier = mTerms[var.vindex].num;
    mTerms.remove(var.vindex);
    incrementConstant(multiplier*expr.constant);
    foreach (ref clv; expr.mTerms.byValue) {
      immutable coeff = clv.num;
      if (auto dOldCoeff = clv.var.vindex in mTerms) {
        immutable oldCoeff = dOldCoeff.num;
        CswNumber newCoeff = oldCoeff+multiplier*coeff;
        if (Csw.approx(newCoeff, 0.0)) {
          mTerms.remove(dOldCoeff.var.vindex);
          solver.noteRemovedVariable(dOldCoeff.var, subject);
        } else {
          dOldCoeff.num = newCoeff;
        }
      } else {
        // did not have that variable
        mTerms[clv.var.vindex] = Term(clv.var, multiplier*coeff);
        solver.noteAddedVariable(clv.var, subject);
      }
    }
  }

  /// This linear expression currently represents the equation
  /// oldSubject=self.  Destructively modify it so that it represents
  /// the equation newSubject=self.
  ///
  /// Precondition: newSubject currently has a nonzero coefficient in
  /// this expression.
  ///
  /// NOTES
  ///   Suppose this expression is c + a*newSubject + a1*v1 + ... + an*vn.
  ///
  ///   Then the current equation is
  ///       oldSubject = c + a*newSubject + a1*v1 + ... + an*vn.
  ///   The new equation will be
  ///        newSubject = -c/a + oldSubject/a - (a1/a)*v1 - ... - (an/a)*vn.
  ///   Note that the term involving newSubject has been dropped.
  final void changeSubject (CswAbstractVariable aOldSubject, CswAbstractVariable aNewSubject) nothrow {
    assert(aOldSubject !is null);
    assert(aOldSubject !is aNewSubject);
    immutable ns = newSubject(aNewSubject);
    if (auto cld = aOldSubject.vindex in mTerms) {
      cld.num = ns;
    } else {
      mTerms[aOldSubject.vindex] = Term(aOldSubject, ns);
    }
  }

  /// This linear expression currently represents the equation self=0.  Destructively modify it so
  /// that subject=self represents an equivalent equation.
  ///
  /// Precondition: subject must be one of the variables in this expression.
  /// NOTES
  ///   Suppose this expression is
  ///     c + a*subject + a1*v1 + ... + an*vn
  ///   representing
  ///     c + a*subject + a1*v1 + ... + an*vn = 0
  /// The modified expression will be
  ///    subject = -c/a - (a1/a)*v1 - ... - (an/a)*vn
  ///   representing
  ///    subject = -c/a - (a1/a)*v1 - ... - (an/a)*vn
  ///
  /// Note that the term involving subject has been dropped.
  /// Returns the reciprocal, so changeSubject can use it, too
  final CswNumber newSubject (CswAbstractVariable subject) nothrow {
    assert(subject !is null);
    immutable coeff = mTerms[subject.vindex].num;
    mTerms.remove(subject.vindex);
    immutable reciprocal = 1.0/coeff;
    multiplyMe(-reciprocal);
    return reciprocal;
  }

  /// Return the coefficient corresponding to variable var, i.e.,
  /// the 'ci' corresponding to the 'vi' that var is:
  ///      v1*c1 + v2*c2 + .. + vn*cn + c
  final CswNumber coefficientFor (CswAbstractVariable var) const @safe nothrow @nogc {
    assert(var !is null);
    auto coeff = var.vindex in mTerms;
    return (coeff !is null ? coeff.num : 0.0);
  }

  final @property CswNumber constant () const @safe pure nothrow @nogc => mConstant;
  final @property void constant (CswNumber v) @safe nothrow @nogc => mConstant = v;

  final void incrementConstant (CswNumber c) @safe nothrow @nogc => mConstant = mConstant+c;

  final @property bool isConstant () const @safe pure nothrow @nogc => (mTerms.length == 0);

  static CswLinearExpression plus (CswLinearExpression e1, CswLinearExpression e2) => e1.plus(e2);
  static CswLinearExpression minus (CswLinearExpression e1, CswLinearExpression e2) => e1.minus(e2);
  static CswLinearExpression times (CswLinearExpression e1, CswLinearExpression e2) => e1.times(e2);
  static CswLinearExpression divide (CswLinearExpression e1, CswLinearExpression e2) => e1.divide(e2);

  override string toString () const {
    import std.conv : to;
    string s;
    if (!Csw.approx(mConstant, 0.0) || mTerms.length == 0) return to!string(mConstant);
    bool first = true;
    foreach (immutable clv; mTerms.byValue) {
      import std.string : format;
      s ~= format((first ? "%s*%s" : " + %s*%s"), clv.num, clv.var);
      first = false;
    }
    return s;
  }

  // required for parser
  static CswLinearExpression doMath (dchar op, CswLinearExpression e1, CswLinearExpression e2) {
    //import csw.errors : CswErrorInvalidMathOp;
    switch (op) {
      case '+': return plus(e1, e2);
      case '-': return minus(e1, e2);
      case '*': return times(e1, e2);
      case '/': return divide(e1, e2);
      default: throw new CswErrorInvalidMathOp("CswLinearExpression doMath(): invalid operation");
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
// tableau
private class CswTableau {
protected:
  struct Col {
    CswAbstractVariable var;
    CswAbstractVariable[uint] set;
  }

  // mColumns is a mapping from variables which occur in expressions to the
  // set of basic variables whose expressions contain them
  // i.e., it's a mapping from variables in expressions (a column) to the
  // set of rows that contain them.
  Col[uint] mColumns; // from CswAbstractVariable to set of variables, key is vindex

  struct Row {
    CswAbstractVariable var;
    CswLinearExpression expr;
  }

  // mRows maps basic variables to the expressions for that row in the tableau
  Row[uint] mRows; // from CswAbstractVariable to CswLinearExpression, key is vindex

  // collection of basic variables that have infeasible rows (used when reoptimizing)
  CswAbstractVariable[uint] mInfeasibleRows; // key is vindex

  // set of rows where the basic variable is external
  // this was added to the Java/C++/C# versions to reduce time in setExternalVariables()
  CswAbstractVariable[uint] mExternalRows; // key is vindex

  // set of external variables which are parametric
  // this was added to the Java/C++/C# versions to reduce time in setExternalVariables()
  CswAbstractVariable[uint] mExternalParametricVars; // key is vindex

public:
  /// Constructor is protected, since this only supports an ADT for
  /// the CswSimplexSolver class.
  protected this () @safe nothrow @nogc {}

  /// Variable v has been removed from an expression. If the
  /// expression is in a tableau the corresponding basic variable is
  /// subject (or if subject is nil then it's in the objective function).
  /// Update the column cross-indices.
  final void noteRemovedVariable (CswAbstractVariable v, CswAbstractVariable subject) nothrow {
    if (subject !is null) mColumns[v.vindex].set.remove(subject.vindex);
  }

  /// v has been added to the linear expression for subject
  /// update column cross indices.
  final void noteAddedVariable (CswAbstractVariable v, CswAbstractVariable subject) nothrow {
    if (subject !is null) insertColVar(v, subject);
  }

  /// Returns information about the tableau's internals.
  ///
  /// Originally from Michael Noth <noth@cs.washington.edu>
  ///
  /// Returns:
  ///   String containing the information.
  string getInternalInfo () const {
    import std.string : format;
    string s = "Tableau Information:\n";
    s ~= format("rows: %s (= %s constraints)", mRows.length, mRows.length-1);
    s ~= format("\nColumns: %s", mColumns.length);
    s ~= format("\nInfeasible rows: %s", mInfeasibleRows.length);
    s ~= format("\nExternal basic variables: %s", mExternalRows.length);
    s ~= format("\nExternal parametric variables: %s", mExternalParametricVars.length);
    return s;
  }

  override string toString () const {
    import std.string : format;
    string s = "Tableau:\n";
    foreach (immutable ev; mRows.byValue) s ~= format("%s <==> %s\n", ev.var, ev.expr);

    s ~= format("\nColumns:\n%s", mColumns);
    s ~= format("\nInfeasible rows: %s", mInfeasibleRows);

    s ~= format("\nExternal basic variables: %s", mExternalRows);
    s ~= format("\nExternal parametric variables: %s", mExternalParametricVars);

    return s;
  }

  /// Convenience function to insert a variable into
  /// the set of rows stored at mColumns[paramVar],
  /// creating a new set if needed.
  private final void insertColVar (CswAbstractVariable paramVar, CswAbstractVariable rowvar) nothrow {
    assert(paramVar !is null);
    assert(rowvar !is null);
    if (auto rowset = paramVar.vindex in mColumns) {
      rowset.set[rowvar.vindex] = rowvar;
    } else {
      //CswAbstractVariable[CswAbstractVariable] rs;
      Col rs;
      rs.var = paramVar;
      rs.set[rowvar.vindex] = rowvar;
      mColumns[paramVar.vindex] = rs;
    }
  }

  // Add v=expr to the tableau, update column cross indices
  // v becomes a basic variable
  // expr is now owned by CswTableau class,
  // and CswTableau is responsible for deleting it
  // (also, expr better be allocated on the heap!).
  protected final void addRow (CswAbstractVariable var, CswLinearExpression expr) nothrow {
    assert(var !is null);
    assert(expr !is null);
    // for each variable in expr, add var to the set of rows which
    // have that variable in their expression
    mRows[var.vindex] = Row(var, expr);
    // FIXME: check correctness!
    foreach (ref clv; expr.mTerms.byValue) {
      insertColVar(clv.var, var);
      if (clv.var.isExternal) mExternalParametricVars[clv.var.vindex] = clv.var;
    }
    if (var.isExternal) mExternalRows[var.vindex] = var;
  }

  // Remove v from the tableau -- remove the column cross indices for v
  // and remove v from every expression in rows in which v occurs
  protected final void removeColumn (CswAbstractVariable var) nothrow {
    assert(var !is null);
    // remove the rows with the variables in varset
    if (auto rows = var.vindex in mColumns) {
      mColumns.remove(var.vindex);
      foreach (ref clv; rows.set.byValue) {
        auto expr = mRows[clv.vindex].expr;
        expr.mTerms.remove(var.vindex);
        //clv.expr.mTerms.remove(var.vindex);
      }
    } else {
      //Csw.trdebugfln("Could not find var %s in mColumns", var);
    }
    if (var.isExternal) {
      mExternalRows.remove(var.vindex);
      mExternalParametricVars.remove(var.vindex);
    }
  }

  // Remove the basic variable v from the tableau row v=expr
  // Then update column cross indices.
  protected final CswLinearExpression removeRow (CswAbstractVariable var) nothrow {
    auto expr = mRows[var.vindex].expr;
    assert(expr !is null); // just in case
    // For each variable in this expression, update
    // the column mapping and remove the variable from the list
    // of rows it is known to be in.
    foreach (ref clv; expr.mTerms.byValue) {
      if (auto varset = clv.var.vindex in mColumns) {
        varset.set.remove(var.vindex);
      }
    }
    mInfeasibleRows.remove(var.vindex);
    if (var.isExternal) mExternalRows.remove(var.vindex);
    mRows.remove(var.vindex);
    return expr;
  }

  // Replace all occurrences of oldVar with expr, and update column cross indices
  // oldVar should now be a basic variable.
  protected final void substituteOut (CswAbstractVariable oldVar, CswLinearExpression expr) nothrow {
    auto varset = mColumns[oldVar.vindex];
    foreach (auto v; varset.set.byValue) {
      auto row = mRows[v.vindex].expr;
      row.substituteOut(oldVar, expr, v, this);
      if (v.isRestricted && row.constant < 0.0) mInfeasibleRows[v.vindex] = v;
    }
    if (oldVar.isExternal) {
      mExternalRows[oldVar.vindex] = oldVar;
      mExternalParametricVars.remove(oldVar.vindex);
    }
    mColumns.remove(oldVar.vindex);
  }

  //final @property auto columns () const @safe pure nothrow @nogc => mColumns;
  //final @property auto rows () const @safe pure nothrow @nogc => mRows;

  // Return true if and only if the variable subject is in the columns keys
  protected final bool columnsHasKey (CswAbstractVariable subject) const nothrow @nogc => (subject.vindex in mColumns) !is null;

  protected final CswLinearExpression rowExpression (CswAbstractVariable v) nothrow @nogc {
    assert(v !is null);
    auto res = v.vindex in mRows;
    return (res ? res.expr : null);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
// solver
// CswEditInfo is privately-used class
// that just wraps a constraint, its positive and negative
// error variables, and its prior edit constant.
// It is used as values in mEditVarMap, and replaces
// the parallel vectors of error variables and previous edit
// constants from the Smalltalk version of the code.
private class CswEditInfo {
private:
  CswConstraint mCtr;
  CswSlackVariable mSVEditPlus;
  CswSlackVariable mSVEditMinus;
  CswNumber mPrevEditConstant;
  usize mIndex;

public:
@safe:
nothrow:
@nogc:
  this (CswConstraint cn, CswSlackVariable eplus, CswSlackVariable eminus, CswNumber prevEditConstant, usize i) {
    mCtr = cn;
    mSVEditPlus = eplus;
    mSVEditMinus = eminus;
    mPrevEditConstant = prevEditConstant;
    mIndex = i;
  }

final:
pure:
  @property usize index () const => mIndex;
  @property CswConstraint constraint () pure => mCtr;
  @property CswSlackVariable editPlus () pure => mSVEditPlus;
  @property CswSlackVariable editMinus () pure => mSVEditMinus;

  @property CswNumber prevEditConstant () const => mPrevEditConstant;
  @property void prevEditConstant (CswNumber v) => mPrevEditConstant = v;
}

// ////////////////////////////////////////////////////////////////////////// //
// main worker class -- cassowary simplex solver
//
class CswSimplexSolver : CswTableau {
private:
  // The array of negative error vars for the stay constraints
  // (need both positive and negative since they have only non-negative values).
  CswAbstractVariable[] mStayMinusErrorVars;

  // The array of positive error vars for the stay constraints
  // (need both positive and negative since they have only non-negative values).
  CswAbstractVariable[] mStayPlusErrorVars;

  // Give error variables for a non-required constraints,
  // maps to CswSlackVariable-s.
  // Map CswConstraint to set of CswVariable.
  struct ErrVar {
    CswConstraint cst;
    CswAbstractVariable[uint] vars;
  }

  ErrVar[uint] mErrorVars; // key is cindex

  // Return a lookup table giving the marker variable for
  // each constraints (used when deleting a constraint).
  // Map CswConstraint to CswVariable.
  struct MKV {
    CswConstraint cst;
    CswAbstractVariable var;
  }

  MKV[uint] mMarkerVars; // key is cindex

  CswObjectiveVariable mObjective;

  // Map edit variables to CswEditInfo-s.
  // CswEditInfo instances contain all the information for an
  // edit constraints (the edit plus/minus vars, the index [for old-style
  // resolve(ArrayList...)] interface), and the previous value.
  // (CswEditInfo replaces the parallel vectors from the Smalltalk impl.)
  struct EVM {
    CswAbstractVariable var;
    CswEditInfo edit;
  }

  EVM[uint] mEditVarMap; // key is vindex

  uint mSlackCounter;
  uint mArtificialCounter;
  uint mDummyCounter;

  CswNumber[2] mResolvePair;

  CswNumber mEpsilon;

  bool mOptimizeAutomatically;
  bool mNeedsSolving;

  usize[] mStackEdCns; // stack

  CswVariable[string] mVarMap;
  string[string] mDefineMap; // TODO: defines with args

public:
final:
  /// Constructor initializes the fields, and creaties the objective row.
  this () @safe nothrow {
    mResolvePair[0] = 0.0;
    mResolvePair[1] = 0.0;

    mObjective = new CswObjectiveVariable("Z");

    mSlackCounter = 0;
    mArtificialCounter = 0;
    mDummyCounter = 0;
    mEpsilon = 1e-8;

    mOptimizeAutomatically = true;
    mNeedsSolving = false;

    CswLinearExpression e = new CswLinearExpression();
    mRows[mObjective.vindex] = Row(mObjective, e);

    mStackEdCns ~= 0;
  }

  /// Convenience function for creating a linear inequality constraint.
  CswSimplexSolver addLowerBound (CswAbstractVariable v, CswNumber lower) {
    CswLinearInequality cn = new CswLinearInequality(v, Csw.CompOp.GEQ, new CswLinearExpression(lower));
    return addConstraint(cn);
  }

  /// Convenience function for creating a linear inequality constraint.
  CswSimplexSolver addUpperBound (CswAbstractVariable v, CswNumber upper) {
    CswLinearInequality cn = new CswLinearInequality(v, Csw.CompOp.LEQ, new CswLinearExpression(upper));
    return addConstraint(cn);
  }

  /// Convenience function for creating a pair of linear inequality constraints.
  CswSimplexSolver addBounds (CswAbstractVariable v, CswNumber lower, CswNumber upper) {
    addLowerBound(v, lower);
    addUpperBound(v, upper);
    return this;
  }

  /// Add a constraint to the solver.
  ///
  /// Params:
  ///   cn = The constraint to be added.
  CswSimplexSolver addConstraint (CswConstraint cn) {
    CswSlackVariable[2] ePlusEMinus;
    CswNumber prevEConstant = 0.0;
    CswLinearExpression expr = newExpression(cn, /* output to: */ ePlusEMinus, prevEConstant);

    bool cAddedOkDirectly = false;
    try {
      cAddedOkDirectly = tryAddingDirectly(expr);
      if (!cAddedOkDirectly) {
        // could not add directly
        addWithArtificialVariable(expr);
      }
    } catch (CswErrorRequiredFailure rf) {
      throw rf;
      // wtf?!
    }

    mNeedsSolving = true;
    if (cn.isEditConstraint) {
      immutable i = mEditVarMap.length;
      CswEditConstraint cnEdit = cast(CswEditConstraint)cn;
      CswSlackVariable clvEplus = ePlusEMinus[0];
      CswSlackVariable clvEminus = ePlusEMinus[1];
      mEditVarMap[cnEdit.variable.vindex] = EVM(cnEdit.variable, new CswEditInfo(cnEdit, clvEplus, clvEminus, prevEConstant, i));
    }

    if (mOptimizeAutomatically) {
      optimize(mObjective);
      setExternalVariables();
    }
    return this;
  }

  CswSimplexSolver addConstraint (string s) => addConstraint(CswParseConstraint(s, this));

  CswSimplexSolver registerVariable (CswVariable var) nothrow {
    mVarMap[var.name] = var;
    return this;
  }

  CswSimplexSolver registerVariable (string name, CswNumber value) nothrow {
    mVarMap[name] = new CswVariable(name, value);
    return this;
  }

  debug package void dumpVars () const {
    import iv.writer;
    writeln("=== VARS ===");
    foreach (auto v; mVarMap) writeln(" ", v);
    writeln("============");
  }

  /// Same as AddConstraint, throws no exceptions.
  ///
  /// Returns:
  ///   false if the constraint resulted in an unsolvable system, otherwise true.
  bool addConstraintNoException (CswConstraint cn) nothrow {
    try {
      addConstraint(cn);
      return true;
    } catch (CswErrorRequiredFailure) {
      return false;
    } catch (Exception) {
      assert(0);
    }
  }

  /// Add an edit constraint for a variable with a given strength.
  ///
  /// Params:
  ///   v = Variable to add an edit constraint to.
  ///   strength = Strength of the edit constraint.
  CswSimplexSolver addEditVar (CswVariable v, in CswStrength strength=Csw.Strong) {
    try {
      CswEditConstraint cnEdit = new CswEditConstraint(v, strength);
      return addConstraint(cnEdit);
    } catch (CswErrorRequiredFailure) {
      // should not get this
      //import csw.errors : CswErrorInternalError;
      throw new CswErrorInternalError("required failure when adding an edit variable");
    }
  }

  /// Remove the edit constraint previously added.
  ///
  /// Params:
  ///   v = Variable to which the edit constraint was added before.
  CswSimplexSolver removeEditVar (CswAbstractVariable v) {
    CswEditInfo cei = mEditVarMap[v.vindex].edit;
    CswConstraint cn = cei.constraint;
    removeConstraint(cn);
    return this;
  }

  /// Marks the start of an edit session.
  ///
  /// beginEdit should be called before sending resolve()
  /// messages, after adding the appropriate edit variables.
  CswSimplexSolver beginEdit () {
    assert(mEditVarMap.length > 0, "mEditVarMap.length == 0");
    // may later want to do more in here
    mInfeasibleRows = mInfeasibleRows.default; //mInfeasibleRows.clear();
    resetStayConstants();
    mStackEdCns ~= mEditVarMap.length;
    return this;
  }

  /// Marks the end of an edit session.
  ///
  /// endEdit should be called after editing has finished for now, it
  /// just removes all edit variables.
  CswSimplexSolver endEdit () {
    assert(mEditVarMap.length > 0, "mEditVarMap.length == 0");
    resolve();
    mStackEdCns.length = mStackEdCns.length-1; //mStackEdCns.Pop();
    int n = mStackEdCns[$-1]; // peek
    removeEditVarsTo(n);
    // may later want to do more in hore
    return this;
  }

  /// Eliminates all the edit constraints that were added.
  CswSimplexSolver removeAllEditVars (int n) {
    return removeEditVarsTo(0);
  }

  /// Remove the last added edit vars to leave only
  /// a specific number left.
  ///
  /// Params:
  ///   n = Number of edit variables to keep.
  CswSimplexSolver removeEditVarsTo (int n) {
    try {
      // using '.keys', 'cause mEditVarMap can be modified inside loop
      foreach (auto v; mEditVarMap.values) {
        //CswEditInfo cei = mEditVarMap[v.var.vindex].edit;
        auto cei = v.edit;
        if (cei.index >= n) removeEditVar(v.var);
      }
      assert(mEditVarMap.length == n, "mEditVarMap.length != n");
      return this;
    } catch (CswErrorConstraintNotFound) {
      // should not get this
      //import csw.errors : CswErrorInternalError;
      throw new CswErrorInternalError("constraint not found in removeEditVarsTo");
    }
  }

  /// Add a stay of the given strength (default to CswStrength#weak)
  /// of a variable to the tableau..
  ///
  /// Params:
  ///   v = Variable to add the stay constraint to.
  CswSimplexSolver addStay (CswVariable v, in CswStrength strength=Csw.Weak, CswNumber weight=1.0) {
    CswStayConstraint cn = new CswStayConstraint(v, strength, weight);
    return addConstraint(cn);
  }

  CswSimplexSolver addStay (string name, in CswStrength strength=Csw.Weak, CswNumber weight=1.0) {
    if (auto var = name in mVarMap) {
      CswStayConstraint cn = new CswStayConstraint(*var, strength, weight);
      return addConstraint(cn);
    } else {
      debug { import iv.writer; errwriteln("addStay: can't find variable '", name, "'"); }
      throw new CswErrorNoVariable("addStay: can't find variable '"~name~"'");
    }
  }

  CswVariable variable (string name) {
    if (auto var = name in mVarMap) {
      return *var;
    } else {
      debug { import iv.writer; errwriteln("addStay: can't find variable '", name, "'"); }
      throw new CswErrorNoVariable("solver: can't find variable '"~name~"'");
    }
  }
  bool hasVariable (string name) const @safe pure nothrow @nogc => (name in mVarMap) !is null;

  CswVariable opIndex (string name) => this.variable(name);
  CswNumber opIndexAssign (CswNumber value, string name) { registerVariable(name, value); return value; }

  bool hasDefine (string name) const @safe pure nothrow @nogc => (name in mDefineMap) !is null;
  string define (string name) @safe => mDefineMap[name];
  void setDefine (string name, string value) @safe {
    assert(name.length > 0);
    if (value.length == 0) {
      mDefineMap.remove(name);
    } else {
      mDefineMap[name] = value;
    }
  }
  void removeDefine (string name) @safe => setDefine(name, null);


  /// Remove a constraint from the tableau.
  /// Also remove any error variable associated with it.
  CswSimplexSolver removeConstraint (CswConstraint cn) {
    mNeedsSolving = true;
    resetStayConstants();

    CswLinearExpression zRow = rowExpression(mObjective);
    auto eVars = cn.cindex in mErrorVars;
    if (eVars !is null) {
      foreach (auto clv; eVars.vars.byValue) {
        CswLinearExpression expr = rowExpression(clv);
        if (expr is null) {
          zRow.addVariable(clv, -cn.weight*cn.strength, mObjective, this);
        } else {
          // the error variable was in the basis
          zRow.addExpression(expr, -cn.weight*cn.strength, mObjective, this);
        }
      }
    }

    /*
    immutable markerVarsCount = mMarkerVars.length;
    CswAbstractVariable marker = mMarkerVars[cn];
    mMarkerVars.remove(cn);

    if (markerVarsCount == mMarkerVars.length) {
      // key was not found
      throw new CswErrorConstraintNotFound("removeConstraint: constraint not found");
    }
    */
    CswAbstractVariable marker;
    if (auto mv = cn.cindex in mMarkerVars) {
      marker = mv.var;
      mMarkerVars.remove(cn.cindex);
    } else {
      throw new CswErrorConstraintNotFound("removeConstraint: constraint not found");
    }

    if (rowExpression(marker) is null) {
      // not in the basis, so need to do some more work
      auto col = mColumns[marker.vindex];
      CswAbstractVariable exitVar = null;
      CswNumber minRatio = 0.0;
      foreach (auto v; col.set) {
        if (v.isRestricted) {
          CswLinearExpression expr = rowExpression(v);
          CswNumber coeff = expr.coefficientFor(marker);
          if (coeff < 0.0) {
            CswNumber r = -expr.constant/coeff;
            if (exitVar is null || r < minRatio) {
              minRatio = r;
              exitVar = v;
            }
          }
        }
      }

      if (exitVar is null) {
        foreach (auto v; col.set) {
          if (v.isRestricted) {
            CswLinearExpression expr = rowExpression(v);
            CswNumber coeff = expr.coefficientFor(marker);
            CswNumber r = expr.constant/coeff;
            if (exitVar is null || r < minRatio) {
              minRatio = r;
              exitVar = v;
            }
          }
        }
      }

      if (exitVar is null) {
        // exitVar is still null
        if (col.set.length == 0) {
          removeColumn(marker);
        } else {
          // put first element in exitVar
          exitVar = col.set.byValue.front;
        }
      }

      if (exitVar !is null) pivot(marker, exitVar);
    }

    if (rowExpression(marker) !is null) removeRow(marker);

    if (eVars !is null) {
      foreach (auto v; eVars.vars.byValue) {
        // FIXME: decide wether to use equals or !=
        if (v.vindex != marker.vindex) {
          removeColumn(v);
          // v = null; // is read-only, cannot be set to null
        }
      }
    }

    if (cn.isStayConstraint) {
      if (eVars !is null) {
        foreach (auto i; 0..mStayPlusErrorVars.length) {
          eVars.vars.remove(mStayPlusErrorVars[i].vindex);
          eVars.vars.remove(mStayMinusErrorVars[i].vindex);
        }
      }
    } else if (cn.isEditConstraint) {
      assert(eVars !is null, "eVars is null");
      CswEditConstraint cnEdit = cast(CswEditConstraint)cn;
      CswVariable clv = cnEdit.variable;
      CswEditInfo cei = mEditVarMap[clv.vindex].edit;
      CswSlackVariable clvEditMinus = cei.editMinus;
      removeColumn(clvEditMinus);
      mEditVarMap.remove(clv.vindex);
    }

    // FIXME: do the remove at top
    if (eVars !is null) {
      //WTF?
      //FIXME: mErrorVars.remove(eVars);
      mErrorVars.remove(cn.cindex);
    }
    marker = null;

    if (mOptimizeAutomatically) {
      optimize(mObjective);
      setExternalVariables();
    }

    return this;
  }

  /// Re-solve the current collection of constraints for new values
  /// for the constants of the edit variables.
  ///
  /// Deprecated. Use suggestValue(...) then resolve(). If you must
  /// use this, be sure to not use it if you remove an edit variable
  /// (or edit constraints) from the middle of a list of edits, and
  /// then try to resolve with this function (you'll get the wrong
  /// answer, because the indices will be wrong in the CswEditInfo
  /// objects).
  void resolve (CswNumber[] newEditConstants) {
    foreach (ref ev; mEditVarMap.byValue) {
      //CswEditInfo cei = mEditVarMap[v];
      auto v = ev.var;
      auto cei = ev.edit;
      immutable i = cei.index;
      try {
        if (i < newEditConstants.length) suggestValue(v, newEditConstants[i]);
      } catch (CswError) {
        //import csw.errors : CswErrorInternalError;
        throw new CswErrorInternalError("Error during resolve");
      }
    }
    resolve();
  }

  /// Convenience function for resolve-s of two variables.
  void resolve (CswNumber x, CswNumber y) {
    mResolvePair[0] = x;
    mResolvePair[1] = y;
    resolve(mResolvePair);
  }

  /// Re-solve the current collection of constraints, given the new
  /// values for the edit variables that have already been
  /// suggested (see suggestValue() method).
  void resolve () {
    dualOptimize();
    setExternalVariables();
    mInfeasibleRows = mInfeasibleRows.default; //mInfeasibleRows.clear();
    resetStayConstants();
  }

  /// suggest a new value for an edit variable.
  ///
  /// The variable needs to be added as an edit variable and
  /// beginEdit() needs to be called before this is called.
  /// The tableau will not be solved completely until after resolve()
  /// has been called.
  CswSimplexSolver suggestValue (CswAbstractVariable v, CswNumber x) {
    if (auto ceiv = v.vindex in mEditVarMap) {
      auto cei = ceiv.edit;
      immutable i = cei.index;
      CswSlackVariable clvEditPlus = cei.editPlus;
      CswSlackVariable clvEditMinus = cei.editMinus;
      CswNumber delta = x-cei.prevEditConstant;
      cei.prevEditConstant = x;
      deltaEditConstant(delta, clvEditPlus, clvEditMinus);
      return this;
    } else {
      debug { import iv.writer; errwriteln("suggestValue for variable ", v.toString(), ", but var is not an edit variable"); }
      throw new CswError("suggestValue!");
    }
  }

  /// Controls wether optimization and setting of external variables is done
  /// automatically or not.
  ///
  /// By default it is done automatically and solve() never needs
  /// to be explicitly called by client code. If `autoSolve` is
  /// put to false, then solve() needs to be invoked explicitly
  /// before using variables' values.
  @property bool autoSolve () const @safe pure nothrow @nogc => mOptimizeAutomatically;
  @property void autoSolve (bool v) @safe nothrow @nogc => mOptimizeAutomatically = v;

  CswSimplexSolver solve () {
    if (mNeedsSolving) {
      optimize(mObjective);
      setExternalVariables();
    }
    return this;
  }

  CswSimplexSolver setEditedValue (CswVariable v, CswNumber n) {
    if (!containsVariable(v)) {
      v.changeValue(n);
      return this;
    }
    if (!Csw.approx(n, v.value)) {
      addEditVar(v);
      beginEdit();
      try {
        suggestValue(v, n);
      } catch (CswError) {
        // just added it above, so we shouldn't get an error
        //import csw.errors : CswErrorInternalError;
        throw new CswErrorInternalError("Error in setEditedValue");
      }
      endEdit();
    }
    return this;
  }

  bool containsVariable (CswVariable v) nothrow => columnsHasKey(v) || (rowExpression(v) !is null);

  CswSimplexSolver addVar (CswVariable v) {
    if (!containsVariable(v)) {
      try {
        addStay(v);
      } catch (CswErrorRequiredFailure) {
        // cannot have a required failure, since we add w/ weak
        //import csw.errors : CswErrorInternalError;
        throw new CswErrorInternalError("Error in AddVar -- required failure is impossible");
      }
    }
    return this;
  }

  /// Returns information about the solver's internals.
  ///
  /// Originally from Michael Noth <noth@cs.washington.edu>
  ///
  /// Returns:
  ///   String containing the information.
  override string getInternalInfo () const {
    import std.string : format;
    string result = super.getInternalInfo();
    result ~= "\nSolver info:\n";
    result ~= "Stay Error Variables: ";
    result ~= "%s".format(mStayPlusErrorVars.length+mStayMinusErrorVars.length);
    result ~= " (%s +, ".format(mStayPlusErrorVars.length);
    result ~= "%s -)\n".format(mStayMinusErrorVars.length);
    result ~= "Edit Variables: %s".format(mEditVarMap.length);
    result ~= "\n";
    return result;
  }

  string getDebugInfo () const {
    string result = toString();
    result ~= getInternalInfo();
    result ~= "\n";
    return result;
  }

  override string toString () const {
    import std.string : format;
    string result = super.toString();
    result ~= "\nmStayPlusErrorVars: %s".format(mStayPlusErrorVars);
    result ~= "\nmStayMinusErrorVars: %s".format(mStayMinusErrorVars);
    result ~= "\n";
    return result;
  }

  //// END PUBLIC INTERFACE ////

  // Add the constraint expr=0 to the inequality tableau using an
  // artificial variable.
  //
  // To do this, create an artificial variable av and add av=expr
  // to the inequality tableau, then make av be 0 (raise an exception
  // if we can't attain av=0).
  protected void addWithArtificialVariable (CswLinearExpression expr) {
    CswSlackVariable av = new CswSlackVariable(++mArtificialCounter, "a");
    CswObjectiveVariable az = new CswObjectiveVariable("az");
    CswLinearExpression azRow = /*(CswLinearExpression)*/ expr.clone();

    addRow(az, azRow);
    addRow(av, expr);

    optimize(az);

    CswLinearExpression azTableauRow = rowExpression(az);
    if (!Csw.approx(azTableauRow.constant, 0.0)) {
      removeRow(az);
      removeColumn(av);
      throw new CswErrorRequiredFailure("!!!");
    }

    // see if av is a basic variable
    CswLinearExpression e = rowExpression(av);

    if (e !is null) {
      // find another variable in this row and pivot,
      // so that av becomes parametric
      if (e.isConstant) {
        // if there isn't another variable in the row
        // then the tableau contains the equation av=0 --
        // just delete av's row
        removeRow(av);
        removeRow(az);
        return;
      }
      CswAbstractVariable entryVar = e.anyPivotableVariable();
      pivot(entryVar, av);
    }
    assert(rowExpression(av) is null, "rowExpression(av) == null)");
    removeColumn(av);
    removeRow(az);
  }

  // Try to add expr directly to the tableau without creating an
  // artificial variable.
  //
  // We are trying to add the constraint expr=0 to the appropriate
  // tableau.
  //
  // Returns:
  //   True if successful and false if not.
  protected bool tryAddingDirectly (CswLinearExpression expr) {
    CswAbstractVariable subject = chooseSubject(expr);
    if (subject is null) return false;
    expr.newSubject(subject);
    if (columnsHasKey(subject)) substituteOut(subject, expr);
    addRow(subject, expr);
    return true; // succesfully added directly
  }

  // Try to choose a subject (a variable to become basic) from
  // among the current variables in expr.
  //
  // We are trying to add the constraint expr=0 to the tableaux.
  // If expr constains any unrestricted variables, then we must choose
  // an unrestricted variable as the subject. Also if the subject is
  // new to the solver, we won't have to do any substitutions, so we
  // prefer new variables to ones that are currently noted as parametric.
  // If expr contains only restricted variables, if there is a restricted
  // variable with a negative coefficient that is new to the solver we can
  // make that the subject. Otherwise we can't find a subject, so return nil.
  // (In this last case we have to add an artificial variable and use that
  // variable as the subject -- this is done outside this method though.)
  protected CswAbstractVariable chooseSubject (CswLinearExpression expr) {
    CswAbstractVariable subject = null; // the current best subject, if any

    bool foundUnrestricted = false;
    bool foundNewRestricted = false;

    //auto terms = expr.mTerms;
    foreach (ref clv; expr.mTerms.byValue) {
      //CswNumber c = terms[v];
      auto v = clv.var;
      immutable c = clv.num;
      if (foundUnrestricted) {
        if (!v.isRestricted) {
          if (!columnsHasKey(v)) return v;
        }
      } else {
        // we haven't found an restricted variable yet
        if (v.isRestricted) {
          if (!foundNewRestricted && !v.isDummy && c < 0.0) {
            auto col = v.vindex in mColumns;
            if (col is null || (col.set.length == 1 && columnsHasKey(mObjective))) {
              subject = v;
              foundNewRestricted = true;
            }
          }
        } else {
          subject = v;
          foundUnrestricted = true;
        }
      }
    }
    if (subject !is null) return subject;

    CswNumber coeff = 0.0;
    foreach (ref clv; expr.mTerms.byValue) {
      //CswNumber c = terms[v];
      auto v = clv.var;
      immutable c = clv.num;
      if (!v.isDummy) return null; // nope, no luck
      if (!columnsHasKey(v)) {
        subject = v;
        coeff = c;
      }
    }

    if (!Csw.approx(expr.constant, 0.0)) throw new CswErrorRequiredFailure("!!!");
    if (coeff > 0.0) expr.multiplyMe(-1);

    return subject;
  }

  // Make a new linear Expression representing the constraint cn,
  // replacing any basic variables with their defining expressions.
  // Normalize if necessary so that the Constant is non-negative.
  // If the constraint is non-required give its error variables an
  // appropriate weight in the objective function.
  protected CswLinearExpression newExpression (CswConstraint cn, out CswSlackVariable[2] ePlusEMinus,
                                               out CswNumber prevEConstant)
  {
    CswLinearExpression cnExpr = cn.expression;
    CswLinearExpression expr = new CswLinearExpression(cnExpr.constant);
    CswSlackVariable slackVar = new CswSlackVariable();
    CswDummyVariable dummyVar = new CswDummyVariable();
    CswSlackVariable eminus = new CswSlackVariable();
    CswSlackVariable eplus = new CswSlackVariable();
    //auto cnTerms = cnExpr.terms;
    foreach (ref clv; cnExpr.mTerms.byValue) {
      //CswNumber c = cnTerms[v];
      auto v = clv.var;
      immutable c = clv.num;
      CswLinearExpression e = rowExpression(v);
      if (e is null) expr.addVariable(v, c); else expr.addExpression(e, c);
    }
    if (cn.isInequality) {
      // cn is an inequality, so Add a slack variable. The original constraint
      // is expr>=0, so that the resulting equality is expr-slackVar=0. If cn is
      // also non-required Add a negative error variable, giving:
      //
      //    expr - slackVar = -errorVar
      //
      // in other words:
      //
      //    expr - slackVar + errorVar = 0
      //
      // Since both of these variables are newly created we can just Add
      // them to the Expression (they can't be basic).
      ++mSlackCounter;
      slackVar = new CswSlackVariable(mSlackCounter, "s");
      expr.setVariable(slackVar, -1);
      mMarkerVars[cn.cindex] = MKV(cn, slackVar);
      if (!cn.isRequired) {
        ++mSlackCounter;
        eminus = new CswSlackVariable(mSlackCounter, "em");
        expr.setVariable(eminus, 1.0);
        CswLinearExpression zRow = rowExpression(mObjective);
        zRow.setVariable(eminus, cn.strength*cn.weight);
        insertErrorVar(cn, eminus);
        noteAddedVariable(eminus, mObjective);
      }
    } else {
      // cn is an equality
      if (cn.isRequired) {
        // Add a dummy variable to the Expression to serve as a marker for this constraint.
        // The dummy variable is never allowed to enter the basis when pivoting.
        ++mDummyCounter;
        dummyVar = new CswDummyVariable(mDummyCounter, "d");
        expr.setVariable(dummyVar, 1.0);
        mMarkerVars[cn.cindex] = MKV(cn, dummyVar);
      } else {
        // cn is a non-required equality. Add a positive and a negative error
        // variable, making the resulting constraint
        //       expr = eplus - eminus
        // in other words:
        //       expr - eplus + eminus = 0
        ++mSlackCounter;
        eplus = new CswSlackVariable(mSlackCounter, "ep");
        eminus = new CswSlackVariable(mSlackCounter, "em");

        expr.setVariable(eplus, -1.0);
        expr.setVariable(eminus, 1.0);
        mMarkerVars[cn.cindex] = MKV(cn, eplus);
        CswLinearExpression zRow = rowExpression(mObjective);
        immutable swCoeff = cn.strength*cn.weight;
        zRow.setVariable(eplus, swCoeff);
        noteAddedVariable(eplus, mObjective);
        zRow.setVariable(eminus, swCoeff);
        noteAddedVariable(eminus, mObjective);
        insertErrorVar(cn, eminus);
        insertErrorVar(cn, eplus);
        if (cn.isStayConstraint) {
          mStayPlusErrorVars ~= eplus;
          mStayMinusErrorVars ~= eminus;
        } else if (cn.isEditConstraint) {
          ePlusEMinus[0] = eplus;
          ePlusEMinus[1] = eminus;
          prevEConstant = cnExpr.constant;
        }
      }
    }
    // the Constant in the Expression should be non-negative. If necessary
    // normalize the Expression by multiplying by -1
    if (expr.constant < 0) expr.multiplyMe(-1);
    return expr;
  }

  // Minimize the value of the objective.
  //
  // The tableau should already be feasible.
  protected void optimize (CswObjectiveVariable zVar) {
    CswLinearExpression zRow = rowExpression(zVar);
    assert(zRow !is null, "zRow != null");
    CswAbstractVariable entryVar = null;
    CswAbstractVariable exitVar = null;
    for (;;) {
      CswNumber objectiveCoeff = 0;
      //auto terms = zRow.terms;
      // Find the most negative coefficient in the objective function (ignoring
      // the non-pivotable dummy variables). If all coefficients are positive
      // we're done
      foreach (ref clv; zRow.mTerms.byValue) {
        //CswNumber c = terms[v];
        auto v = clv.var;
        immutable c = clv.num;
        if (v.isPivotable && c < objectiveCoeff) {
          objectiveCoeff = c;
          entryVar = v;
        }
      }
      if (objectiveCoeff >= -mEpsilon || entryVar is null) return;
      // choose which variable to move out of the basis
      // Only consider pivotable basic variables
      // (i.e. restricted, non-dummy variables)
      CswNumber minRatio = CswNumber.max;
      auto columnVars = mColumns[entryVar.vindex];
      CswNumber r = 0.0;
      foreach (auto v; columnVars.set) {
        if (v.isPivotable) {
          CswLinearExpression expr = rowExpression(v);
          CswNumber coeff = expr.coefficientFor(entryVar);
          if (coeff < 0.0) {
            r = -expr.constant/coeff;
            // Bland's anti-cycling rule:
            // if multiple variables are about the same,
            // always pick the lowest via some total
            // ordering -- I use their addresses in memory
            //    if (r < minRatio ||
            //              (c.approx(r, minRatio) &&
            //               v.get_pclv() < exitVar.get_pclv()))
            if (r < minRatio) {
              minRatio = r;
              exitVar = v;
            }
          }
        }
      }
      // If minRatio is still nil at this point, it means that the
      // objective function is unbounded, i.e. it can become
      // arbitrarily negative.  This should never happen in this
      // application.
      if (minRatio == CswNumber.max) {
        //import csw.errors : CswErrorInternalError;
        throw new CswErrorInternalError("Objective function is unbounded in optimize");
      }
      pivot(entryVar, exitVar);
    }
  }

  // Fix the constants in the equations representing the edit constraints.
  //
  // Each of the non-required edits will be represented by an equation
  // of the form:
  //   v = c + eplus - eminus
  // where v is the variable with the edit, c is the previous edit value,
  // and eplus and eminus are slack variables that hold the error in
  // satisfying the edit constraint. We are about to change something,
  // and we want to fix the constants in the equations representing
  // the edit constraints. If one of eplus and eminus is basic, the other
  // must occur only in the expression for that basic error variable.
  // (They can't both be basic.) Fix the constant in this expression.
  // Otherwise they are both non-basic. Find all of the expressions
  // in which they occur, and fix the constants in those. See the
  // UIST paper for details.
  // (This comment was for ResetEditConstants(), but that is now
  // gone since it was part of the screwey vector-based interface
  // to resolveing. --02/16/99 gjb)
  protected void deltaEditConstant (CswNumber delta, CswAbstractVariable plusErrorVar, CswAbstractVariable minusErrorVar) {
    CswLinearExpression exprPlus = rowExpression(plusErrorVar);
    if (exprPlus !is null) {
      exprPlus.incrementConstant(delta);
      if (exprPlus.constant < 0.0) mInfeasibleRows[plusErrorVar.vindex] = plusErrorVar;
      return;
    }

    CswLinearExpression exprMinus = rowExpression(minusErrorVar);
    if (exprMinus !is null) {
      exprMinus.incrementConstant(-delta);
      if (exprMinus.constant < 0.0) mInfeasibleRows[minusErrorVar.vindex] = minusErrorVar;
      return;
    }

    auto columnVars = mColumns[minusErrorVar.vindex];
    foreach (auto basicVar; columnVars.set) {
      CswLinearExpression expr = rowExpression(basicVar);
      //assert(expr != null, "expr != null");
      CswNumber c = expr.coefficientFor(minusErrorVar);
      expr.incrementConstant(c*delta);
      if (basicVar.isRestricted && expr.constant < 0.0) mInfeasibleRows[basicVar.vindex] = basicVar;
    }
  }

  // Re-optimize using the dual simplex algorithm.
  //
  // We have set new values for the constants in the edit constraints.
  protected void dualOptimize () {
    CswLinearExpression zRow = rowExpression(mObjective);
    while (mInfeasibleRows.length) {
      // get first var
      CswAbstractVariable exitVar = mInfeasibleRows.byValue.front;
      mInfeasibleRows.remove(exitVar.vindex);
      CswAbstractVariable entryVar = null;
      CswLinearExpression expr = rowExpression(exitVar);
      if (expr !is null) {
        if (expr.constant < 0.0) {
          CswNumber ratio = CswNumber.max;
          CswNumber r;
          //auto terms = expr.terms;
          foreach (ref clv; expr.mTerms.byValue) {
            //CswNumber c = terms[v];
            auto v = clv.var;
            immutable c = clv.num;
            if (c > 0.0 && v.isPivotable) {
              CswNumber zc = zRow.coefficientFor(v);
              r = zc / c; // FIXME: zc / c or zero, as CswSymbolicWeigth-s
              if (r < ratio) {
                entryVar = v;
                ratio = r;
              }
            }
          }
          if (ratio == CswNumber.max) {
            //import csw.errors : CswErrorInternalError;
            throw new CswErrorInternalError("ratio == nil (Double.MaxValue) in dualOptimize");
          }
          pivot(entryVar, exitVar);
        }
      }
    }
  }

  // Do a pivot. Move entryVar into the basis and move exitVar
  // out of the basis.
  //
  // We could for example make entryVar a basic variable and
  // make exitVar a parametric variable.
  protected void pivot (CswAbstractVariable entryVar, CswAbstractVariable exitVar) {
    // the entryVar might be non-pivotable if we're doing a
    // removeConstraint -- otherwise it should be a pivotable
    // variable -- enforced at call sites, hopefully.
    // expr is the Expression for the exit variable (about to leave the basis) --
    // so that the old tableau includes the equation:
    //   exitVar = expr
    CswLinearExpression expr = removeRow(exitVar);
    // Compute an Expression for the entry variable.  Since expr has
    // been deleted from the tableau we can destructively modify it to
    // build this Expression.
    expr.changeSubject(exitVar, entryVar);
    substituteOut(entryVar, expr);
    addRow(entryVar, expr);
  }

  // Fix the constants in the equations representing the stays.
  //
  // Each of the non-required stays will be represented by an equation
  // of the form
  //   v = c + eplus - eminus
  // where v is the variable with the stay, c is the previous value
  // of v, and eplus and eminus are slack variables that hold the error
  // in satisfying the stay constraint. We are about to change something,
  // and we want to fix the constants in the equations representing the
  // stays. If both eplus and eminus are nonbasic they have value 0
  // in the current solution, meaning the previous stay was exactly
  // satisfied. In this case nothing needs to be changed. Otherwise one
  // of them is basic, and the other must occur only in the expression
  // for that basic error variable. Reset the constant of this
  // expression to 0.
  protected void resetStayConstants () {
    foreach (immutable i; 0..mStayPlusErrorVars.length) {
      CswLinearExpression expr = rowExpression(mStayPlusErrorVars[i]);
      if (expr is null) expr = rowExpression(mStayMinusErrorVars[i]);
      if (expr !is null) expr.constant = 0.0;
    }
  }

  // CswSet the external variables known to this solver to their appropriate values.
  //
  // CswSet each external basic variable to its value, and set each external parametric
  // variable to 0. (It isn't clear that we will ever have external parametric
  // variables -- every external variable should either have a stay on it, or have an
  // equation that defines it in terms of other external variables that do have stays.
  // For the moment I'll put this in though.) Variables that are internal to the solver
  // don't actually store values -- their values are just implicit in the tableau -- so
  // we don't need to set them.
  protected void setExternalVariables () {
    foreach (auto v; mExternalParametricVars.byValue) {
      if (rowExpression(v) !is null) {
        debug { import iv.writer; errwriteln("Error: variable ", v.toString(), "in mExternalParametricVars is basic"); }
        continue;
      }
      auto vv = cast(CswVariable)v;
      vv.changeValue(0.0);
    }
    foreach (auto v; mExternalRows.byValue) {
      CswLinearExpression expr = rowExpression(v);
      auto vv = cast(CswVariable)v;
      vv.changeValue(expr.constant);
    }
    mNeedsSolving = false;
  }

  // Protected convenience function to insert an error variable
  // into the mErrorVars set, creating the mapping with Add as necessary.
  protected void insertErrorVar (CswConstraint cn, CswAbstractVariable var) {
    if (auto cnset = cn.cindex in mErrorVars) {
      cnset.vars[var.vindex] = var;
    } else {
      //CswAbstractVariable[CswAbstractVariable] ev;
      ErrVar ev;
      ev.cst = cn;
      ev.vars[var.vindex] = var;
      mErrorVars[cn.cindex] = ev;
    }
  }

public:
  @property ref CswVariable[string] varMap () @safe nothrow @nogc => mVarMap;
  @property void varMap (ref CswVariable[string] v) @safe nothrow @nogc => mVarMap = v;
}


// ////////////////////////////////////////////////////////////////////////// //
// variables
class CswAbstractVariable {
private:
  static uint mVarIndex; // so we can't have more that 0xffffffff variables for the thread lifetime

  @property static uint newVarIndex () @trusted nothrow @nogc {
    if (++mVarIndex == 0) assert(0, "too many variables in Cassowary!"); // the thing that should not be
    return mVarIndex;
  }

private:
  uint vindex;

public:
  string name;

public:
@safe:
nothrow:
  this () => name = buildIndexedName("v", (vindex = newVarIndex));
  this (string aname) @nogc { vindex = newVarIndex; name = aname; }
  this (uint varnumber, string prefix) => name = buildIndexedName(prefix, (vindex = newVarIndex), varnumber);

  const pure @nogc {
    @property bool isDummy () const => false;
    abstract @property bool isExternal ();
    abstract @property bool isPivotable ();
    abstract @property bool isRestricted ();
  }

  @property static uint count () @nogc => mVarIndex;

  override string toString () const nothrow => "["~name~":abstract]";

protected:
  // 4294967296
  static string buildIndexedName (string pfx, uint idx, uint num=uint.max) @trusted nothrow {
    char[21] n;
    usize pos = n.length;
    // secondary index
    if (num != uint.max) {
      do {
        n[--pos] = num%10+'0';
        num /= 10;
      } while (num != 0);
      n[--pos] = '#';
    }
    // primary index
    do {
      n[--pos] = idx%10+'0';
      idx /= 10;
    } while (idx != 0);
    import std.exception : assumeUnique;
    auto res = new char[](pfx.length+(n.length-pos));
    if (pfx.length) res[0..pfx.length] = pfx[];
    res[pfx.length..$] = n[pos..$];
    return res.assumeUnique;
  }

  template HasStr (string s, T...) {
    static if (T.length == 0)
      enum HasStr = false;
    else static if (T[0] == s)
      enum HasStr = true;
    else
      enum HasStr = HasStr!(s, T[1..$]);
  }

  template IFS (bool v, string t="true", string f="false") {
    static if (v)
      enum IFS = t;
    else
      enum IFS = f;
  }

  template GenTypes (T...) {
    private enum dum = HasStr!("dummy", T);
    private enum ext = HasStr!("extern", T) || HasStr!("external", T);
    private enum piv = HasStr!("pivot", T) || HasStr!("pivotable", T);
    private enum res = HasStr!("restricted", T);
    enum GenTypes =
      "override @property bool isDummy () const @safe pure nothrow @nogc => "~IFS!(dum)~";\n"~
      "override @property bool isExternal () const @safe pure nothrow @nogc => "~IFS!(ext)~";\n"~
      "override @property bool isPivotable () const @safe pure nothrow @nogc => "~IFS!(piv)~";\n"~
      "override @property bool isRestricted () const @safe pure nothrow @nogc => "~IFS!(res)~";\n";
  }
}


class CswDummyVariable : CswAbstractVariable {
  this () @safe nothrow => super();
  this (string name) @safe nothrow @nogc => super(name);
  this (uint varnumber, string prefix) @safe nothrow => super(varnumber, prefix);
  override string toString () const nothrow => "["~name~":dummy]";
  mixin(GenTypes!("dummy", "restricted"));
}


class CswSlackVariable : CswAbstractVariable {
  this () @safe nothrow => super();
  this (string name) @safe nothrow @nogc => super(name);
  this (uint varnumber, string prefix) @safe nothrow => super(varnumber, prefix);
  override string toString () const nothrow => "["~name~":slack]";
  mixin(GenTypes!("pivotable", "restricted"));
}


class CswObjectiveVariable : CswAbstractVariable {
  this () @safe nothrow => super();
  this (string name) @safe nothrow @nogc => super(name);
  this (uint varnumber, string prefix) @safe nothrow => super(varnumber, prefix);
  override string toString () const nothrow => "["~name~":obj]";
  mixin(GenTypes!());
}


class CswVariable : CswAbstractVariable {
private:
  CswNumber mValue;

public:
  @safe nothrow {
    this () { super(); mValue = 0.0; }
    this (CswNumber value) { super(); mValue = value; }
    this (string name, CswNumber value=0.0) @nogc { super(name); mValue = value; }
    this (uint number, string prefix, CswNumber value=0.0) { super(number, prefix); mValue = value; }
    this (ref CswVariable[string] varMap, string name, CswNumber value=0.0) { this(name, value); varMap[name] = this; }
  }

  override string toString () const nothrow @trusted/*gdc*/ {
    try {
      import std.conv : to;
      return "["~name~":"~to!string(mValue)~"]";
    } catch (Exception) {
      return "["~name~":???]";
    }
  }

  mixin(GenTypes!("external"));

  // Change the value held -- should *not* use this if the variable is
  // in a solver -- use addEditVar() and suggestValue() interface instead
  @property CswNumber value () const @safe pure nothrow @nogc => mValue;
  @property void value (CswNumber v) @safe nothrow @nogc => mValue = v;

  // Permit overriding in subclasses in case something needs to be
  // done when the value is changed by the solver
  // may be called when the value hasn't actually changed -- just
  // means the solver is setting the external variable
  public void changeValue (CswNumber value) @safe pure nothrow @nogc => mValue = value;

  // construct expressions
  mixin(buildOpBin!(`*/`, `CswNumber`));
  mixin(buildOpBin!(`+-*/`, `CswLinearExpression`));
  mixin(buildOpBin!(`+-`, `CswVariable`));

  // convert variable to CswLinearExpression
  final T opCast(T : CswLinearExpression) () => new CswLinearExpression(this);

private:
  template buildOpBinConstraint(string ops) {
    static if (ops.length > 1)
      enum buildOpBinConstraint = `op == "`~ops[0]~`" || `~buildOpBinConstraint!(ops[1..$]);
    else
      enum buildOpBinConstraint = `op == "`~ops~`"`;
  }

  enum buildOpBin(string ops, string argtype) =
    `final CswLinearExpression opBinary(string op) (`~argtype~` n)`~
    `if (`~buildOpBinConstraint!ops~`) {`~
    `  auto e0 = new CswLinearExpression(this);`~
    `  mixin("return e0"~op~"n;");`~
    `}`;
}


// ////////////////////////////////////////////////////////////////////////// //
// parser
private:
debug import iv.writer;
debug(CswParser) import iv.writer;
debug(CswTokenizer) import iv.writer;


// ////////////////////////////////////////////////////////////////////////// //
struct Token {
  static immutable string oneChars = "=+-*/()[]<>,;:"; // WARNING! keep in sync with Type enum!
  enum Type {
    EOF,
    Id,
    Number,
    EqEq, GEq, LEq, // multichar tokens
    // here starts one-char tokens; must be in sync with oneChars
    Eq, Plus, Minus, Times, Divide, LParen, RParen, LBrac, RBrac, Less, Great, Comma, Semicolon, Colon
  }

  usize pos; // token position in stream
  Type type = Type.EOF;
  CswNumber n;
  string s;

  @property bool isEOF () const @safe pure nothrow @nogc => (type == Type.EOF);
  @property bool isEOX () const @safe pure nothrow @nogc => (type == Type.EOF || type == Type.Semicolon);
  @property bool isId () const @safe pure nothrow @nogc => (type == Type.Id);
  @property bool isNumber () const @safe pure nothrow @nogc => (type == Type.Number);
  @property bool isPunct () const @safe pure nothrow @nogc => (type > Type.Number && type <= Type.max);

  string toString () const {
    import std.conv : to;
    switch (type) {
      case Type.EOF: return "{EOF}";
      case Type.Id: return "{id:"~s~"}";
      case Type.Number: return "{num:"~to!string(n)~"}";
      case Type.EqEq: return "==";
      case Type.GEq: return ">=";
      case Type.LEq: return "<=";
      default:
        if (type >= Type.Eq && type <= Type.max) return to!string(oneChars[type-Type.Eq]);
        return "{invalid}";
    }
  }
}


void skipBlanks (ref ParserData st) {
  import std.uni;
  for (;;) {
    auto ch = st.getChar();
    if (ch == 0) return; // end of stream
    if (ch <= 32 || std.uni.isWhite(ch)) continue; // skip this char
    // slash-slash or slash-star?
    if (ch == '/') {
      ch = st.getChar(); // skip first slash
      if (ch == '*') {
        // multiline comment
        for (;;) {
          ch = st.getChar();
          // star-slash?
          if (ch == '*') {
            ch = st.getChar();
            if (ch == '/') break;
          }
        }
        continue;
      }
      // slash-slash?
      if (ch != '/') {
        // alas, unget 'em both
        st.ungetChar(ch);
        st.ungetChar('/');
        return;
      }
      ch = '#'; // comment-to-eol
    }
    // comment-to-eol?
    if (ch == '#') {
      do { ch = st.getChar(); } while (ch != 0 && ch != '\n');
      continue;
    }
    // other non-white and non-comment chars
    st.ungetChar(ch);
    return;
  }
}


Token getToken (ref ParserData st) {
  static bool isId (dchar ch) {
    import std.uni : isAlpha;
    return
      (ch >= '0' && ch <= '9') ||
      (ch >= 'A' && ch <= 'Z') ||
      (ch >= 'a' && ch <= 'z') ||
      ch == '_' || ch == '.' ||
      isAlpha(ch);
  }

  dchar ch;

  skipBlanks(st);
  st.lastTokenPos = st.pos;
  ch = st.getChar();
  debug(CswTokenizer) writeln("lastTokenPos=", st.lastTokenPos, "; ch=", ch);
  if (ch == 0) return Token(st.lastTokenPos, Token.Type.EOF);

  // try "{?}="
  if (ch == '<' || ch == '>' || ch == '=') {
    dchar ch1 = st.getChar();
    debug(CswTokenizer) writeln(" ?2char; ch=", ch, "; ch1=", ch1);
    if (ch1 == '=') {
      Token.Type tt = void;
      final switch (ch) {
        case '<': tt = Token.Type.LEq; break;
        case '>': tt = Token.Type.GEq; break;
        case '=': tt = Token.Type.EqEq; break;
      }
      return Token(st.lastTokenPos, tt);
    }
    // restore char
    st.ungetChar(ch1);
  }

  // one-char token?
  if (ch < 127) {
    import std.string : indexOf;
    debug(CswTokenizer) writeln(" ?punct; ch=", ch);
    auto pp = Token.oneChars.indexOf(cast(char)ch);
    if (pp >= 0) return Token(st.lastTokenPos, cast(Token.Type)(Token.Type.Eq+pp));
  }

  // number?
  if (ch >= '0' && ch <= '9') {
    CswNumber n = 0.0;
    while (ch >= '0' && ch <= '9') {
      n = n*10+ch-'0';
      ch = st.getChar();
    }
    if (ch == '.') {
      CswNumber frc = 0.1;
      ch = st.getChar();
      while (ch >= '0' && ch <= '9') {
        n += (ch-'0')*frc;
        frc /= 10.0;
        ch = st.getChar();
      }
    }
    st.ungetChar(ch);
    debug(CswTokenizer) writeln(" number=", n);
    return Token(st.lastTokenPos, Token.Type.Number, n);
  }

  // id?
  if (ch != '.' && isId(ch)) {
    import std.array : appender;
    auto id = appender!string();
    while (isId(ch)) {
      id.put(ch);
      ch = st.getChar();
    }
    st.ungetChar(ch);
    debug(CswTokenizer) writeln(" id=", id.data);
    return Token(st.lastTokenPos, Token.Type.Id, 0.0, id.data);
  }

  throw new CswErrorParser("invalid token");
  assert(0);
}


// ////////////////////////////////////////////////////////////////////////// //
struct Operator {
  enum Assoc { None, Left, Right, Unary }
  dchar math;
  Token.Type ttype = Token.Type.EOF;
  Assoc assoc = Assoc.None;
  int prio = -666;

  string toString () const {
    import std.conv : to;
    string s = "["~to!string(math)~"]";
    final switch (assoc) {
      case Assoc.None: s ~= " (none)"; break;
      case Assoc.Left: s ~= " (left)"; break;
      case Assoc.Right: s ~= " (right)"; break;
      case Assoc.Unary: s ~= " (unary)"; break;
    }
    s ~= " (pr:"~to!string(prio)~")";
    return s;
  }
}


struct Term {
  enum Type { EOF, Number, Var, Expr, Operator }

  Type type = Type.EOF;
  CswNumber n;
  CswVariable v;
  CswLinearExpression e;
  Operator op = void;

  this (CswNumber an) @safe nothrow @nogc { type = Type.Number; n = an; }
  this (CswVariable av) @safe nothrow @nogc { type = Type.Var; v = av; }
  this (CswLinearExpression ae) @safe nothrow @nogc { type = Type.Expr; e = ae; }
  this (in Operator aop) @safe nothrow @nogc { type = Type.Operator; op = aop; }

  @property bool isEOF () const @safe pure nothrow @nogc => (type == Type.EOF);
  @property bool isNumber () const @safe pure nothrow @nogc => (type == Type.Number);
  @property bool isVar () const @safe pure nothrow @nogc => (type == Type.Var);
  @property bool isExpr () const @safe pure nothrow @nogc => (type == Type.Expr);
  @property bool isOperator () const @safe pure nothrow @nogc => (type == Type.Operator);

  T opCast(T : CswLinearExpression) () {
    switch (type) {
      case Type.Number: return new CswLinearExpression(n);
      case Type.Var: return new CswLinearExpression(v);
      case Type.Expr: return e;
      default: throw new CswErrorParser(`can't cast term to CswLinearExpression`);
    }
  }

  string toString () const {
    import std.conv : to;
    final switch (type) {
      case Type.EOF: return "<EOF>";
      case Type.Number: return "{num:"~to!string(n)~"}";
      case Type.Var: return "{var:"~v.toString()~"}";
      case Type.Expr: return "{expr:"~e.toString()~"}";
      case Type.Operator: return "{op:"~op.toString()~"}";
    }
  }
}


static immutable Operator[/*$*/] operators = [
  {'(', Token.Type.LParen, Operator.Assoc.Left, -1},
  {')', Token.Type.RParen, Operator.Assoc.None, -1},
  //{"**", Token.Type.EOF, Operator.Assoc.Right, 4},
  //{"^", Token.Type.EOF, Operator.Assoc.Right, 4},
  {'*', Token.Type.Times, Operator.Assoc.Left, 2},
  {'/', Token.Type.Divide, Operator.Assoc.Left, 2},
  {'+', Token.Type.Plus, Operator.Assoc.Left, 1},
  {'-', Token.Type.Minus, Operator.Assoc.Left, 1},
];

static immutable Operator opUnaryMinus = {'-', Token.Type.Minus, Operator.Assoc.Unary, 3};


// ////////////////////////////////////////////////////////////////////////// //
struct ParserData {
  enum ExprMode { Constraint, SimpleMath }

  string sstr;
  CswSimplexSolver solver;
  ExprMode mode = ExprMode.Constraint;
  usize pos; // current stream position
  usize lastTokenPos;
  Token tk;
  bool tkValid;
  dchar[4] savedCh;
  usize savedChCount;

  void ungetChar (dchar ch) {
    if (savedChCount == savedCh.length) throw new CswErrorParser("too many ungetChar()s");
    if (ch != 0) {
      import std.utf : codeLength;
      usize clen = codeLength!dchar(ch);
      if (pos > clen) pos -= clen; else pos = 0;
      savedCh[savedChCount++] = ch;
    }
  }

  dchar getChar () {
    usize clen = void;
    dchar ch = void;
    if (savedChCount) {
      import std.utf : codeLength;
      ch = savedCh[--savedChCount];
      clen = codeLength!dchar(ch);
    } else {
      import std.utf : decodeFront;
      if (sstr.length == 0) return 0; // 0 means EOF
      ch = sstr.decodeFront(clen);
    }
    pos += clen;
    if (ch == 0) ch = ' ';
    return ch;
  }

  //FIXME: make this faster!
  void prependString (string s) {
    if (s.length) {
      while (savedChCount) {
        import std.conv : to;
        sstr = to!string(savedCh[--savedChCount])~sstr;
      }
      sstr = s~" "~sstr;
    }
  }

  Token nextToken () {
    if (tkValid) {
      tkValid = false;
      return tk;
    }
    return getToken(this);
  }

  Token peekToken () {
    if (!tkValid) {
      tk = getToken(this);
      tkValid = true;
    }
    return tk;
  }

  void ungetToken (Token atk) {
    if (atk.isEOF) return;
    if (tkValid) throw new CswErrorParser("internal ungetToken error");
    tkValid = true;
    tk = atk;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
Term term (ref ParserData st) {
again:
  auto tk = st.nextToken();
  if (tk.isEOX) {
    st.ungetToken(tk);
    return Term();
  }
  if (tk.isNumber) return Term(tk.n);
  // id?
  if (tk.isId) {
    // variable?
    if (st.solver.hasVariable(tk.s)) {
      debug(CswParser) writeln("Term: var '", tk.s, "'");
      auto v = st.solver[tk.s];
      if (st.mode == ParserData.ExprMode.Constraint) return Term(v);
      return Term(v.value); // just a number
    }
    // define?
    if (st.solver.hasDefine(tk.s)) {
      // insert and reparse
      // TODO: limit insertions!
      auto val = st.solver.define(tk.s);
      debug(CswParser) writeln("Term: define '", tk.s, "' = '", val, "'");
      st.prependString(val);
      goto again;
    }
    debug(CswParser) { errwriteln("var not found: '", tk.s, "'"); }
    throw new CswErrorParser("var not found: '"~tk.s~"'");
  }
  // operator?
  if (tk.isPunct) {
    // this can be converted to AA, but...
    debug(CswParser) writeln("trying punct: ", tk.type);
    foreach (immutable op; operators) {
      if (op.ttype == tk.type) {
        // got it!
        debug(CswParser) writeln(" GOT PUNCT!");
        return Term(op);
      }
    }
  }
  //
  //debug(CswParser) writeln("rest: '", st.sstr, "'");
  debug(CswParser) writeln("tk: '", tk, "'");
  st.ungetToken(tk);
  return Term(); // assume EOF
}


// ////////////////////////////////////////////////////////////////////////// //
Term expr (ref ParserData st) {
  int privBooster = 0;
  Term[256] stack, queue; // this should be enough for everyone, hehe
  usize sp, qp; // autoinit

  void doOperator (ref Term tk) {
    debug(CswParser) writeln("doOperator: ", tk);
    assert(tk.isOperator);
    if (tk.op.assoc == Operator.Assoc.Unary) {
      if (qp < 1) throw new CswErrorParser("invalid expression");
      debug(CswParser) writeln("op0: ", queue[qp-1]);
      if (tk.op.math == '+') return; // no-op
      if (queue[qp-1].isNumber) {
        queue[qp-1].n = -queue[qp-1].n;
      } else {
        auto eres = (cast(CswLinearExpression)queue[qp-1])*(-1.0);
        queue[qp-1] = Term(eres);
      }
      return;
    }
    // for now we has only 2ops, so...
    if (qp < 2) throw new CswErrorParser("invalid expression");
    debug(CswParser) writeln("op0: ", queue[qp-2]);
    debug(CswParser) writeln("op1: ", queue[qp-1]);
    // let's do that in this funny way
    if (queue[qp-2].isNumber && queue[qp-1].isNumber) {
      // both operands are numbers, do a little optimisation here
      switch (tk.op.math) {
        case '+': queue[qp-2].n += queue[qp-1].n; --qp; return;
        case '-': queue[qp-2].n -= queue[qp-1].n; --qp; return;
        case '*': queue[qp-2].n *= queue[qp-1].n; --qp; return;
        case '/': queue[qp-2].n /= queue[qp-1].n; --qp; return;
        default:
      }
    }
    // if one of the operans is number (0.0 or 1.0), do a little optimisation too
    // check 1st
    if (queue[qp-2].isNumber) {
      if (queue[qp-2].n == 0.0) {
        // annihilate both, replace with zero
        if (tk.op.math == '+') { queue[qp-2] = queue[qp-1]; --qp; return; } // no-op
        else if (tk.op.math == '-') {
          // negate
          auto eres = (cast(CswLinearExpression)queue[qp-1])*(-1.0);
          queue[qp-2] = Term(eres);
          --qp;
          return;
        }
        else if (tk.op.math == '*') { --qp; return; } // this is 0.0
      } else if (queue[qp-2].n == 1.0) {
        if (tk.op.math == '*' || tk.op.math == '/') {
          // no-op
          queue[qp-2] = queue[qp-1];
          --qp;
          return;
        }
      }
    }
    // check 2nd
    else if (queue[qp-1].isNumber) {
      if (queue[qp-1].n == 0.0) {
        if (tk.op.math == '+' || tk.op.math == '-') { --qp; return; } // no-op
        else if (tk.op.math == '*') {
          // no-op
          queue[qp-2] = queue[qp-1];
          --qp;
          return;
        }
      }
      else if (queue[qp-1].n == 1.0) {
        // leave only first operand
        if (tk.op.math == '*') { --qp; return; } // no-op
      }
    }
    // do it the hard way
    auto eres = CswLinearExpression.doMath(tk.op.math,
                                           cast(CswLinearExpression)queue[qp-2],
                                           cast(CswLinearExpression)queue[qp-1]);
    --qp; // drop the last operand
    // and replace the first one
    queue[qp-1] = Term(eres);
  }

  for (;;) {
    auto tk = term(st);
    if (tk.isEOF) throw new CswErrorParser("unexpected end of expression");
    debug(CswParser) writeln("arg: ", tk);

    // odd logic here: don't actually stack the parens: don't need to
    if (tk.isOperator) {
      if (tk.op.ttype == Token.Type.Plus) continue; // unary plus is actually no-op
      if (tk.op.ttype == Token.Type.Minus) {
        // unary minus
        if (sp > 0 && stack[sp-1].isOperator && stack[sp-1].op.ttype == Token.Type.Minus) {
          // two unary minuses gives no-op
          --sp;
          continue;
        }
        if (sp >= stack.length) throw new CswErrorParser("expression too complex");
        stack[sp++] = Term(opUnaryMinus);
        continue;
      }
      // LParen is the only other operator allowed here
      if (tk.op.ttype == Token.Type.LParen) {
        privBooster += 100; // must be higher than max priority
        if (privBooster < 0) throw new CswErrorParser("too many parens"); // booster overflowed, heh
        continue;
      }
      throw new CswErrorParser("invalid expression");
    }
    // numbers, vars and exprs are ok here (actually, there can be no expr)
    assert(!tk.isExpr);

    // put argument to queue
    if (qp >= queue.length) throw new CswErrorParser("expression too complex");
    queue[qp++] = tk;

    // now process operators
    {
another_operator:
      tk = term(st);
      debug(CswParser) writeln("opr: ", tk);
      if (tk.isEOF) {
        //if (privBooster) throw new CswErrorParser("unmatched '('");
        debug(CswParser) writeln("EXPR DONE");
        break; // out of main loop
      }

      if (!tk.isOperator) throw new CswErrorParser("operator expected, got "~tk.toString);
      if (tk.op.ttype == Token.type.LParen) throw new CswErrorParser("unexpected '(' (internal error)");

      bool isRParen = (tk.op.ttype == Token.type.RParen);
      if (tk.op.prio > 0) {
        // normal operator
        tk.op.prio += privBooster;
      } else if (isRParen) {
        // RParen
        if (privBooster < 100) throw new CswErrorParser("unmatched ')'");
        tk.op.prio = privBooster;
      }

      // process operator stack
      while (sp) {
        auto t = &stack[sp-1];
        if (t.op.prio <= tk.op.prio) {
          // stacked prio is less or equal to current
          // stop popping if priorities arent equal or operator on the stack is right-associative
          if (t.op.prio != tk.op.prio || t.op.assoc == Operator.Assoc.Right) break;
        }
        if (tk.op.assoc == Operator.Assoc.Unary && t.op.assoc != Operator.Assoc.Unary) break; // unaries can apply only unaries
        // do current operator
        doOperator(*t);
        --sp;
      }

      if (isRParen) {
        privBooster -= 100;
        goto another_operator;
      }

      if (sp >= stack.length) throw new CswErrorParser("expression too complex");
      stack[sp++] = tk;
      debug(CswParser) writeln("psh: ", tk);
    }
  }
  if (privBooster) throw new CswErrorParser("unmatched '('");
  debug(CswParser) writeln("doing operators");
  // done, now process all stacked operators
  foreach_reverse (ref tk; stack[0..sp]) doOperator(tk);
  if (qp != 1) throw new CswErrorParser("invalid expression");
  debug(CswParser) writeln("RESULT: ", queue[0]);
  return queue[0];
}


// ////////////////////////////////////////////////////////////////////////// //
// <required|weak|medium|strong[:weight]>
// <w0,w1,w2[:weight]>
// return true if strength was here, current token is ">"
bool parseStrength (ref ParserData st, ref CswStrength str, ref CswNumber weight) {
  auto tk = st.peekToken();
  // strength?
  if (tk.type == Token.Type.LBrac || tk.type == Token.Type.Less) {
    tk = st.nextToken(); // read brc
    auto end = (tk.type == Token.Type.LBrac ? Token.Type.RBrac : Token.Type.Great);
    tk = st.nextToken();
    if (tk.type == Token.Type.Id) {
      // named
      switch (tk.s) {
        case "required": str = Csw.Required; break;
        case "weak": str = Csw.Weak; break;
        case "medium": str = Csw.Medium; break;
        case "strong": str = Csw.Strong; break;
        default: throw new CswErrorParser("invalid strength: '"~tk.s~"'");
      }
      tk = st.nextToken();
    } else if (tk.type != end && tk.type != Token.Type.Colon) {
      // numeric
      CswNumber[3] nn = void;
      foreach (immutable idx; 0..nn.length) {
        if (!tk.isNumber) throw new CswErrorParser("strength number expected");
        nn[idx] = tk.n;
        tk = st.nextToken();
        if (idx != nn.length-1) {
          if (tk.type != Token.Type.Comma) throw new CswErrorParser("comma expected");
          tk = st.nextToken();
        }
      }
      str = Csw.Strength(nn[0], nn[1], nn[2]);
    }
    // parse weight
    if (tk.type == Token.Type.Colon) {
      tk = st.nextToken();
      if (!tk.isNumber) throw new CswErrorParser("weight number expected");
      weight = tk.n;
      tk = st.nextToken();
    }
    // check for closing bracket
    if (tk.type != end) throw new CswErrorParser(end == Token.Type.RBrac ? "']' expected" : "'>' expected");
    return true;
  } else {
    return false;
  }
}


// <required|weak|medium|strong[:weight]> expr eqop expr
// <w0,w1,w2[:weight]> expr eqop expr
// default <required>
CswConstraint constraint (ref ParserData st) {
  CswStrength str = Csw.Required; // default strength
  CswNumber weight = 1.0; // default weight
  parseStrength(st, str, weight);
  // left part
  auto ex0 = expr(st);
  // operator
  auto tk = st.nextToken();
  if (tk.type == Token.Type.Eq || tk.type == Token.Type.EqEq) {
    // equation
    auto ex1 = expr(st);
    //tk = st.nextToken();
    //if (!tk.isEOF) throw new CswErrorParser("invalid constraint expression");
    return new CswLinearEquation(cast(CswLinearExpression)ex0, cast(CswLinearExpression)ex1, str, weight);
  } else if (tk.type == Token.Type.LEq || tk.type == Token.Type.GEq) {
    // inequation
    auto cop = (tk.type == Token.Type.LEq ? Csw.CompOp.LEQ : Csw.CompOp.GEQ);
    auto ex1 = expr(st);
    //tk = st.nextToken();
    //if (!tk.isEOF) throw new CswErrorParser("invalid constraint expression");
    return new CswLinearInequality(cast(CswLinearExpression)ex0, cop, cast(CswLinearExpression)ex1, str, weight);
  } else {
    throw new CswErrorParser("invalid constraint expression");
  }
  assert(0);
}


// ////////////////////////////////////////////////////////////////////////// //
public CswConstraint CswParseConstraint (string s, CswSimplexSolver solver) {
  try {
    auto st = ParserData(s, solver, ParserData.ExprMode.Constraint);
    auto res = constraint(st);
    if (!st.peekToken().isEOF) throw new CswErrorParser("invalid constraint expression");
    return res;
  } catch (CswErrorParser e) {
    debug { import iv.writer; errwriteln("PARSE ERROR IN: '", s, "'"); }
    throw e;
  }
  assert(0);
}


// ////////////////////////////////////////////////////////////////////////// //
public CswNumber CswParseSimpleMath (string s, CswSimplexSolver solver) {
  try {
    auto st = ParserData(s, solver, ParserData.ExprMode.SimpleMath);
    auto ex = expr(st);
    if (!st.peekToken().isEOF) throw new CswErrorParser("invalid simple math expression");
    if (!ex.isNumber) throw new CswErrorParser("invalid simple math expression");
    return ex.n;
  } catch (CswErrorParser e) {
    debug { import iv.writer; errwriteln("PARSE ERROR (", e.msg, ") IN: '", s, "'"); }
    throw e;
  }
  assert(0);
}


// ////////////////////////////////////////////////////////////////////////// //
public void CswParseScript (string s, CswSimplexSolver solver) {

  //TODO: don't duplicate stays (?)
  // var[(stay|normal)] varlist ;
  // varlist: vardef, varlist | vardef | {empty}
  // vardef: [<stay|normal>] varname[=simplemath]
  static void processVar (ref ParserData st) {
    debug(CswScript) writeln("var-start");
    bool isAllStay = false;
    auto tk = st.peekToken();
    // strength
    if (tk.type == Token.Type.LParen) {
      // this must be 'stay'
      st.nextToken(); // skip LParen
      tk = st.nextToken();
      if (!tk.isId || (tk.s != "stay" && tk.s != "normal")) throw new CswErrorParser("'stay' expected");
      isAllStay = (tk.s == "stay");
      tk = st.nextToken();
      if (tk.type != Token.Type.RParen) throw new CswErrorParser("')' expected");
      tk = st.peekToken();
    }
    // varlist
    while (!tk.isEOX) {
      CswStrength str = Csw.Weak; // default strength
      CswNumber weight = 1.0; // default weight
      bool isStay = isAllStay;
      tk = st.nextToken(); // Id or Less, skipped
      // '<stay>'?
      if (tk.type == Token.Type.Less) {
        tk = st.nextToken(); // Id
        if (!tk.isId || (tk.s != "stay" && tk.s != "normal")) throw new CswErrorParser("'stay' expected");
        isStay = (tk.s == "stay");
        // '['?
        if (st.peekToken().type == Token.Type.LBrac) parseStrength(st, str, weight);
        tk = st.nextToken(); // Great
        if (tk.type != Token.Type.Great) throw new CswErrorParser("'>' expected");
        tk = st.nextToken(); // Id
        debug(CswScript) writeln(" isStay is ", isStay);
      }
      if (!tk.isId) throw new CswErrorParser("identifier expected");
      auto varname = tk.s;
      CswNumber varvalue = 0.0; // default variable value is zero
      debug(CswScript) writeln(" varname is ", varname);
      if (st.peekToken().type == Token.Type.Eq) {
        // do initializer
        st.nextToken(); // skip '='
        st.mode = ParserData.ExprMode.SimpleMath;
        auto ex = expr(st);
        if (!ex.isNumber) throw new CswErrorParser("invalid variable init expression");
        varvalue = ex.n;
      }
      debug(CswScript) writeln("var '", varname, "' = ", varvalue, " stay=", isStay);
      st.solver.registerVariable(varname, varvalue);
      if (isStay) st.solver.addStay(varname, str, weight);
      tk = st.peekToken();
      debug(CswScript) writeln("tk: ", tk, "; isEOX: ", tk.isEOX);
      // comma or EOX
      if (!tk.isEOX) {
        if (tk.type != Token.Type.Comma) throw new CswErrorParser("',' expected");
        tk = st.nextToken(); // skip comma
      }
    }
    debug(CswScript) writeln("var-end");
    //debug(CswScript) st.solver.dumpVars();
  }

  // define name = {tokens};
  static void processDefine (ref ParserData st) {
    debug(CswScript) writeln("define-start");
    while (!st.peekToken().isEOX) {
      auto tk = st.nextToken(); // Id
      if (!tk.isId) throw new CswErrorParser("identifier expected");
      auto defname = tk.s;
      tk = st.nextToken(); // should be '='
      if (tk.type != Token.Type.Eq) throw new CswErrorParser("'=' expected");
      // now cheat: remember current string and start skipping tokens
      auto saveds = st.sstr; // we'll need this
      tk = st.peekToken();
      while (!tk.isEOX && tk.type != Token.Type.Comma) {
        st.nextToken(); // skip this token
        tk = st.peekToken();
      }
      // now cut skipped part of the string and strip spaces
      import std.string : strip;
      saveds = saveds[0..$-st.sstr.length].strip;
      while (saveds.length > 0 && (saveds[$-1] == ';' || saveds[$-1] == ',')) saveds = saveds[0..$-1];
      if (saveds.length == 0) throw new CswErrorParser("empty defines are not allowed");
      debug(CswScript) writeln("name='", defname, "'; value='", saveds, "'");
      st.solver.setDefine(defname, saveds);
      if (!tk.isEOX) {
        if (tk.type != Token.Type.Comma) throw new CswErrorParser("',' expected");
        tk = st.nextToken(); // skip comma
      }
    }
    debug(CswScript) writeln("define-end");
  }

  static void processUndefine (ref ParserData st) {
    st.nextToken(); // eat keyword
    assert(0);
  }

  static void processPrint (ref ParserData st) {
    debug(CswScript) writeln("print-start");
    while (!st.peekToken().isEOX) {
      auto tk = st.nextToken(); // eat Id
      if (!tk.isId) throw new CswErrorParser("identifier expected");
      if (!st.solver.hasVariable(tk.s)) {
        import iv.writer;
        writeln("*** UNKNOWN VARIABLE: '", tk.s, "'");
      } else {
        import iv.writer;
        writeln(st.solver[tk.s]);
      }
      tk = st.peekToken();
      if (!tk.isEOX) {
        if (tk.type != Token.Type.Comma) throw new CswErrorParser("',' expected");
        st.nextToken(); // skip comma
      }
    }
    debug(CswScript) writeln("print-end");
  }

  static void processConstraint (ref ParserData st) {
    debug(CswScript) writeln("constraint-start");
    st.mode = ParserData.ExprMode.Constraint;
    auto cs = constraint(st);
    if (!st.peekToken().isEOX) throw new CswErrorParser("';' expected");
    debug(CswScript) writeln("constraint: ", cs);
    st.solver.addConstraint(cs);
    debug(CswScript) writeln("constraint-start");
  }

  auto st = ParserData(s, solver); // mode is irrelevant here
  try {
    auto tk = st.nextToken();
    while (!tk.isEOF) {
      if (!tk.isEOX) {
        // check for keywords
        if (tk.isId) {
          debug(CswScript) writeln("ID: ", tk.s);
          switch (tk.s) {
            case "var": processVar(st); break;
            case "define": processDefine(st); break;
            case "undefine": processUndefine(st); break;
            case "print": processPrint(st); break;
            default: st.ungetToken(tk); processConstraint(st); break;
          }
        } else {
          st.ungetToken(tk);
          processConstraint(st);
        }
        if (!st.peekToken().isEOX) throw new CswErrorParser("invalid script expression");
      }
      // skip semicolong
      while (st.peekToken().type == Token.Type.Semicolon) st.nextToken();
      tk = st.nextToken();
    }
  } catch (CswErrorParser e) {
    debug {
      import iv.writer;
      errwriteln("PARSE ERROR IN SCRIPT: ", e.msg);
      errwriteln("POSITION: ", st.lastTokenPos);
    }
    //writeln(s[0..st.lastTokenPos]);
    //writeln(s[0..st.pos]);
    throw e;
  }
}
