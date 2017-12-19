module testgestures;

import iv.pdollar0;


void addTestGestures (DPGestureList gl) {
  assert(gl !is null);
  // down-right
  gl.appendGesture("quit",
    DPPoint(10,10,1),DPPoint(10,90,1),
    DPPoint(10,90,2),DPPoint(90,90,2),
  );
  gl.appendGesture("T",
    DPPoint(30,7,1),DPPoint(103,7,1),
    DPPoint(66,7,2),DPPoint(66,87,2)
  );
  gl.appendGesture("N",
    DPPoint(177,92,1),DPPoint(177,2,1),
    DPPoint(182,1,2),DPPoint(246,95,2),
    DPPoint(247,87,3),DPPoint(247,1,3)
  );
  gl.appendGesture("D",
    DPPoint(345,9,1),DPPoint(345,87,1),
    DPPoint(351,8,2),DPPoint(363,8,2),DPPoint(372,9,2),DPPoint(380,11,2),DPPoint(386,14,2),DPPoint(391,17,2),DPPoint(394,22,2),DPPoint(397,28,2),DPPoint(399,34,2),DPPoint(400,42,2),DPPoint(400,50,2),DPPoint(400,56,2),DPPoint(399,61,2),DPPoint(397,66,2),DPPoint(394,70,2),DPPoint(391,74,2),DPPoint(386,78,2),DPPoint(382,81,2),DPPoint(377,83,2),DPPoint(372,85,2),DPPoint(367,87,2),DPPoint(360,87,2),DPPoint(355,88,2),DPPoint(349,87,2)
  );
  gl.appendGesture("P",
    DPPoint(507,8,1),DPPoint(507,87,1),
    DPPoint(513,7,2),DPPoint(528,7,2),DPPoint(537,8,2),DPPoint(544,10,2),DPPoint(550,12,2),DPPoint(555,15,2),DPPoint(558,18,2),DPPoint(560,22,2),DPPoint(561,27,2),DPPoint(562,33,2),DPPoint(561,37,2),DPPoint(559,42,2),DPPoint(556,45,2),DPPoint(550,48,2),DPPoint(544,51,2),DPPoint(538,53,2),DPPoint(532,54,2),DPPoint(525,55,2),DPPoint(519,55,2),DPPoint(513,55,2),DPPoint(510,55,2)
  );
  gl.appendGesture("X",
    DPPoint(30,146,1),DPPoint(106,222,1),
    DPPoint(30,225,2),DPPoint(106,146,2)
  );
  gl.appendGesture("H",
    DPPoint(188,137,1),DPPoint(188,225,1),
    DPPoint(188,180,2),DPPoint(241,180,2),
    DPPoint(241,137,3),DPPoint(241,225,3)
  );
  gl.appendGesture("I",
    DPPoint(371,149,1),DPPoint(371,221,1),
    DPPoint(341,149,2),DPPoint(401,149,2),
    DPPoint(341,221,3),DPPoint(401,221,3)
  );
  gl.appendGesture("exclamation",
    DPPoint(526,142,1),DPPoint(526,204,1),
    DPPoint(526,221,2)
  );
  gl.appendGesture("line",
    DPPoint(12,347,1),DPPoint(119,347,1)
  );
  gl.appendGesture("five-point star",
    DPPoint(177,396,1),DPPoint(223,299,1),DPPoint(262,396,1),DPPoint(168,332,1),DPPoint(278,332,1),DPPoint(184,397,1)
  );
  gl.appendGesture("clear",
    DPPoint(382,310,1),DPPoint(377,308,1),DPPoint(373,307,1),DPPoint(366,307,1),DPPoint(360,310,1),DPPoint(356,313,1),DPPoint(353,316,1),DPPoint(349,321,1),DPPoint(347,326,1),DPPoint(344,331,1),DPPoint(342,337,1),DPPoint(341,343,1),DPPoint(341,350,1),DPPoint(341,358,1),DPPoint(342,362,1),DPPoint(344,366,1),DPPoint(347,370,1),DPPoint(351,374,1),DPPoint(356,379,1),DPPoint(361,382,1),DPPoint(368,385,1),DPPoint(374,387,1),DPPoint(381,387,1),DPPoint(390,387,1),DPPoint(397,385,1),DPPoint(404,382,1),DPPoint(408,378,1),DPPoint(412,373,1),DPPoint(416,367,1),DPPoint(418,361,1),DPPoint(419,353,1),DPPoint(418,346,1),DPPoint(417,341,1),DPPoint(416,336,1),DPPoint(413,331,1),DPPoint(410,326,1),DPPoint(404,320,1),DPPoint(400,317,1),DPPoint(393,313,1),DPPoint(392,312,1),
    DPPoint(418,309,2),DPPoint(337,390,2)
  );
  gl.appendGesture("arrowhead",
    DPPoint(506,349,1),DPPoint(574,349,1),
    DPPoint(525,306,2),DPPoint(584,349,2),DPPoint(525,388,2)
  );
  /*
  gl.appendGesture("pitchfork",
    DPPoint(38,470,1),DPPoint(36,476,1),DPPoint(36,482,1),DPPoint(37,489,1),DPPoint(39,496,1),DPPoint(42,500,1),DPPoint(46,503,1),DPPoint(50,507,1),DPPoint(56,509,1),DPPoint(63,509,1),DPPoint(70,508,1),DPPoint(75,506,1),DPPoint(79,503,1),DPPoint(82,499,1),DPPoint(85,493,1),DPPoint(87,487,1),DPPoint(88,480,1),DPPoint(88,474,1),DPPoint(87,468,1),
    DPPoint(62,464,2),DPPoint(62,571,2)
  );
  */
  gl.appendGesture("six-point star",
    DPPoint(177,554,1),DPPoint(223,476,1),DPPoint(268,554,1),DPPoint(183,554,1),
    DPPoint(177,490,2),DPPoint(223,568,2),DPPoint(268,490,2),DPPoint(183,490,2)
  );
  gl.appendGesture("asterisk",
    DPPoint(325,499,1),DPPoint(417,557,1),
    DPPoint(417,499,2),DPPoint(325,557,2),
    DPPoint(371,486,3),DPPoint(371,571,3)
  );
  /*
  gl.appendGesture("half-note",
    DPPoint(546,465,1),DPPoint(546,531,1),
    DPPoint(540,530,2),DPPoint(536,529,2),DPPoint(533,528,2),DPPoint(529,529,2),DPPoint(524,530,2),DPPoint(520,532,2),DPPoint(515,535,2),DPPoint(511,539,2),DPPoint(508,545,2),DPPoint(506,548,2),DPPoint(506,554,2),DPPoint(509,558,2),DPPoint(512,561,2),DPPoint(517,564,2),DPPoint(521,564,2),DPPoint(527,563,2),DPPoint(531,560,2),DPPoint(535,557,2),DPPoint(538,553,2),DPPoint(542,548,2),DPPoint(544,544,2),DPPoint(546,540,2),DPPoint(546,536,2)
  );
  */
}
