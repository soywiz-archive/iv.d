/*
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
module iv.vmath2d.creatori;

import iv.vmath2d.math2d;
import iv.vmath2d.vxstore;


// ////////////////////////////////////////////////////////////////////////// //
// xRadius -- the rounding X radius
// yRadius -- the rounding Y radius
// segments -- the number of segments to subdivide the edges
void roundedRect(VS) (ref VS vstore, double width, double height, double xRadius, double yRadius, int segments) if (IsGoodVertexStorage!VS) {
  alias VT = VertexStorageVT!VS;
  if (yRadius > height/2 || xRadius > width/2) throw new Exception("rounding amount can't be more than half the height and width respectively");
  if (segments < 0) throw new Exception("segments must be zero or more");

  if (segments == 0) {
    vstore ~= VT(cast(VT.Float)width*cast(VT.Float)0.5-cast(VT.Float)xRadius, -cast(VT.Float)height*cast(VT.Float)0.5);
    vstore ~= VT(cast(VT.Float)width*cast(VT.Float)0.5, -cast(VT.Float)height*cast(VT.Float)0.5+cast(VT.Float)yRadius);

    vstore ~= VT(cast(VT.Float)width*cast(VT.Float)0.5, cast(VT.Float)height*cast(VT.Float)0.5-cast(VT.Float)yRadius);
    vstore ~= VT(cast(VT.Float)width*cast(VT.Float)0.5-cast(VT.Float)xRadius, cast(VT.Float)height*cast(VT.Float)0.5);

    vstore ~= VT(-cast(VT.Float)width*cast(VT.Float)0.5+cast(VT.Float)xRadius, cast(VT.Float)height*cast(VT.Float)0.5);
    vstore ~= VT(-cast(VT.Float)width*cast(VT.Float)0.5, cast(VT.Float)height*cast(VT.Float)0.5-cast(VT.Float)yRadius);

    vstore ~= VT(-cast(VT.Float)width*cast(VT.Float)0.5, -cast(VT.Float)height*cast(VT.Float)0.5+cast(VT.Float)yRadius);
    vstore ~= VT(-cast(VT.Float)width*cast(VT.Float)0.5+cast(VT.Float)xRadius, -cast(VT.Float)height*cast(VT.Float)0.5);
  } else {
    mixin(ImportCoreMath!(VT.Float, "cos", "sin"));
    import std.math : PI;
    int numberOfEdges = segments*4+8;

    VT.Float stepSize = cast(VT.Float)(PI*2)/(numberOfEdges-4);
    int perPhase = numberOfEdges/4;

    VT posOffset = VT(cast(VT.Float)width/2-cast(VT.Float)xRadius, cast(VT.Float)height/2-cast(VT.Float)yRadius);
    vstore ~= posOffset+VT(cast(VT.Float)xRadius, 0/*-cast(VT.Float)yRadius+cast(VT.Float)yRadius*/);
    int phase = 0;
    foreach (immutable int i; 1..numberOfEdges) {
      if (i-perPhase == 0 || i-perPhase*3 == 0) {
        posOffset.x = -posOffset.x;
        --phase;
      } else if (i-perPhase*2 == 0) {
        posOffset.y = -posOffset.y;
        --phase;
      }
      vstore ~= posOffset+VT(cast(VT.Float)xRadius*cast(VT.Float)cos(stepSize*-(i+phase)), -cast(VT.Float)yRadius*cast(VT.Float)sin(stepSize*-(i+phase)));
    }
  }
}

// numberOfEdges -- the number of edges
void circle(VS, FT:double) (ref VS vstore, FT radius, int numberOfEdges) if (IsGoodVertexStorage!(VS, VecN!(2, FT))) {
  ellipse(vstore, radius, radius, numberOfEdges);
}

// xRadius -- width of the ellipse
// yRadius -- height of the ellipse
// numberOfEdges -- the number of edges
void ellipse(VS) (ref VS vstore, double xRadius, double yRadius, int numberOfEdges) if (IsGoodVertexStorage!VS) {
  alias VT = VertexStorageVT!VS;
  mixin(ImportCoreMath!(VT.Float, "cos", "sin"));
  import std.math : PI;
  VT.Float stepSize = cast(VT.Float)(PI*2)/numberOfEdges;
  vstore ~= VT(cast(VT.Float)xRadius, 0);
  foreach_reverse (immutable int i; 1..numberOfEdges) {
    vstore ~= VT(cast(VT.Float)xRadius*cast(VT.Float)cos(stepSize*i), -cast(VT.Float)yRadius*cast(VT.Float)sin(stepSize*i));
  }
}

void arc(VS) (ref VS vstore, double radians, int sides, double radius) if (IsGoodVertexStorage!VS) {
alias VT = VertexStorageVT!VS;
  mixin(ImportCoreMath!(VT.Float, "cos", "sin"));
  if (radians <= 0) throw new Exception("the arc needs to be larger than 0");
  if (sides <= 1) throw new Exception("The arc needs to have more than 1 sides");
  if (radius <= 0) throw new Exception("The arc needs to have a radius larger than 0");
  VT.Float stepSize = radians/sides;
  foreach_reverse (immutable int i; 1..sides) {
    vstore ~= VT(radius*cast(VT.Float)cos(stepSize*i), radius*cast(VT.Float)sin(stepSize*i));
  }
}

// height -- height (inner height + 2 * radius) of the capsule
// endRadius -- radius of the capsule ends
// edges -- the number of edges of the capsule ends. the more edges, the more it resembles an capsule
void capsule(VS) (ref VS vstore, double height, double endRadius, int edges) if (IsGoodVertexStorage!VS) {
  if (endRadius >= height/2) throw new Exception("The radius must be lower than height/2: higher values of radius would create a circle, and not a half circle");
  return capsule(vstore, height, endRadius, edges, endRadius, edges);
}

// height -- height (inner height + radii) of the capsule
// topRadius -- radius of the top
// topEdges -- the number of edges of the top. the more edges, the more it resembles an capsule
// bottomRadius -- radius of bottom
// bottomEdges -- the number of edges of the bottom. the more edges, the more it resembles an capsule
void capsule(VS) (ref VS vstore, double height, double topRadius, int topEdges, double bottomRadius, int bottomEdges) if (IsGoodVertexStorage!VS) {
  alias VT = VertexStorageVT!VS;
  mixin(ImportCoreMath!(VT.Float, "cos", "sin"));
  import std.math : PI;

  if (height <= 0) throw new Exception("height must be longer than 0");
  if (topRadius <= 0) throw new Exception("the top radius must be more than 0");
  if (topEdges <= 0) throw new Exception("top edges must be more than 0");
  if (bottomRadius <= 0) throw new Exception("the bottom radius must be more than 0");
  if (bottomEdges <= 0) throw new Exception("bottom edges must be more than 0");
  if (topRadius >= height/2) throw new Exception("the top radius must be lower than height/2: higher values of top radius would create a circle, and not a half circle");
  if (bottomRadius >= height/2) throw new Exception("the bottom radius must be lower than height/2: higher values of bottom radius would create a circle, and not a half circle");

  VT.Float newHeight = (cast(VT.Float)height-cast(VT.Float)topRadius-cast(VT.Float)bottomRadius)*cast(VT.Float)0.5;

  // top
  vstore ~= VT(cast(VT.Float)topRadius, newHeight);

  VT.Float stepSize = cast(VT.Float)PI/topEdges;
  foreach (immutable int i; 1..topEdges) {
    vstore ~= VT(cast(VT.Float)topRadius*cast(VT.Float)cos(stepSize*i), cast(VT.Float)topRadius*cast(VT.Float)sin(stepSize*i)+newHeight);
  }

  vstore ~= VT(-cast(VT.Float)topRadius, newHeight);

  // bottom
  vstore ~= VT(-cast(VT.Float)bottomRadius, -newHeight);

  stepSize = cast(VT.Float)PI/bottomEdges;
  foreach (immutable int i; 1..bottomEdges) {
    vstore ~= VT(-cast(VT.Float)bottomRadius*cast(VT.Float)cos(stepSize*i), -cast(VT.Float)bottomRadius*cast(VT.Float)sin(stepSize*i)-newHeight);
  }

  vstore ~= VT(cast(VT.Float)bottomRadius, -newHeight);
}

// radius -- the radius
// numberOfTeeth -- the number of teeth
// tipPercentage -- the tip percentage
// toothHeight -- height of the tooth
void gear(VS) (ref VS vstore, double radius, int numberOfTeeth, double tipPercentage, double toothHeight) if (IsGoodVertexStorage!VS) {
  alias VT = VertexStorageVT!VS;
  mixin(ImportCoreMath!(VT.Float, "cos", "sin"));
  import std.math : PI;

  VT.Float stepSize = cast(VT.Float)(PI*2)/numberOfTeeth;
  tipPercentage /= cast(VT.Float)100;
  if (tipPercentage < 0) tipPercentage = 0; else if (tipPercentage > 1) tipPercentage = 1;
  VT.Float toothTipStepSize = (stepSize/cast(VT.Float)2)*tipPercentage;

  VT.Float toothAngleStepSize = (stepSize-(toothTipStepSize*cast(VT.Float)2))/cast(VT.Float)2;

  foreach_reverse (immutable int i; 0..numberOfTeeth) {
    if (toothTipStepSize > 0) {
      vstore ~= VT(radius*cast(VT.Float)cos(stepSize*i+toothAngleStepSize*2f+toothTipStepSize), -radius*cast(VT.Float)sin(stepSize*i+toothAngleStepSize*2f+toothTipStepSize));
      vstore ~= VT((radius+toothHeight)*cast(VT.Float)cos(stepSize*i+toothAngleStepSize+toothTipStepSize), -(radius+toothHeight)*cast(VT.Float)sin(stepSize*i+toothAngleStepSize+toothTipStepSize));
    }
    vstore ~= VT((radius+toothHeight)*cast(VT.Float)cos(stepSize*i+toothAngleStepSize), -(radius+toothHeight)*cast(VT.Float)sin(stepSize*i+toothAngleStepSize));
    vstore ~= VT(radius*cast(VT.Float)cos(stepSize*i), -radius*cast(VT.Float)sin(stepSize*i));
  }
}
