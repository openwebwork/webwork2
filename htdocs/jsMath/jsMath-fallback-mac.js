/*
 *  jsMath-fallback-mac.js
 *  
 *  Part of the jsMath package for mathematics on the web.
 *
 *  This file makes changes needed for when the TeX fonts are not available
 *  with a browser on the Mac.
 *
 *  ---------------------------------------------------------------------
 *
 *  jsMath is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  jsMath is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with jsMath; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */



/********************************************************************
 *
 *  Here we replace the TeX character mappings by equivalent unicode
 *  points when possible, and adjust the character dimensions
 *  based on the fonts we hope we get them from (the styles are set
 *  to try to use the best characters available in the standard
 *  fonts).
 */

jsMath.Add(jsMath.TeX,{

  cmr10: [
    // 00 - 0F
    {c: '&Gamma;', tclass: 'greek'},
    {c: '&Delta;', tclass: 'greek'},
    {c: '&Theta;', tclass: 'greek'},
    {c: '&Lambda;', tclass: 'greek'},
    {c: '&Xi;', tclass: 'greek'},
    {c: '&Pi;', tclass: 'greek'},
    {c: '&Sigma;', tclass: 'greek'},
    {c: '&Upsilon;', tclass: 'greek'},
    {c: '&Phi;', tclass: 'greek'},
    {c: '&Psi;', tclass: 'greek'},
    {c: '&Omega;', tclass: 'greek'},
    {c: 'ff', ic: 0.0778, krn: {'39': 0.0778, '63': 0.0778, '33': 0.0778, '41': 0.0778, '93': 0.0778}, lig: {'105': 14, '108': 15}, tclass: 'normal'},
    {c: 'fi', tclass: 'normal'},
    {c: 'fl', tclass: 'normal'},
    {c: 'ffi', tclass: 'normal'},
    {c: 'ffl', tclass: 'normal'},
    // 10 - 1F
    {c: '&#x131;', a:0, tclass: 'normal'},
    {c: 'j', d:.2, tclass: 'normal'},
    {c: '&#x60;', tclass: 'accent'},
    {c: '&#xB4;', tclass: 'accent'},
    {c: '&#x2C7;', tclass: 'accent'},
    {c: '&#x2D8;', tclass: 'accent'},
    {c: '<SPAN STYLE="position:relative; top:.1em">&#x2C9;</SPAN>', tclass: 'accent'},
    {c: '&#x2DA;', tclass: 'accent'},
    {c: '&#x0327;', tclass: 'normal'},
    {c: '&#xDF;', tclass: 'normal'},
    {c: '&#xE6;', a:0, tclass: 'normal'},
    {c: '&#x153;', a:0, tclass: 'normal'},
    {c: '&#xF8;', tclass: 'normal'},
    {c: '&#xC6;', tclass: 'normal'},
    {c: '&#x152;', tclass: 'normal'},
    {c: '&#xD8;', tclass: 'normal'},
    // 20 - 2F
    {c: '?', krn: {'108': -0.278, '76': -0.319}, tclass: 'normal'},
    {c: '!', lig: {'96': 60}, tclass: 'normal'},
    {c: '&#x201D;', tclass: 'normal'},
    {c: '#', tclass: 'normal'},
    {c: '$', tclass: 'normal'},
    {c: '%', tclass: 'normal'},
    {c: '&amp;', tclass: 'normal'},
    {c: '&#x2019;', krn: {'63': 0.111, '33': 0.111}, lig: {'39': 34}, tclass: 'normal'},
    {c: '(', d:.2, tclass: 'normal'},
    {c: ')', d:.2, tclass: 'normal'},
    {c: '*', tclass: 'normal'},
    {c: '+', a:.1, tclass: 'normal'},
    {c: ',', a:-.3, d:.2, w: 0.278, tclass: 'normal'},
    {c: '-', a:0, lig: {'45': 123}, tclass: 'normal'},
    {c: '.', a:-.25, tclass: 'normal'},
    {c: '/', tclass: 'normal'},
    // 30 - 3F
    {c: '0', tclass: 'normal'},
    {c: '1', tclass: 'normal'},
    {c: '2', tclass: 'normal'},
    {c: '3', tclass: 'normal'},
    {c: '4', tclass: 'normal'},
    {c: '5', tclass: 'normal'},
    {c: '6', tclass: 'normal'},
    {c: '7', tclass: 'normal'},
    {c: '8', tclass: 'normal'},
    {c: '9', tclass: 'normal'},
    {c: ':', tclass: 'normal'},
    {c: ';', tclass: 'normal'},
    {c: '&#xA1;', tclass: 'normal'},
    {c: '=', a:0, d:-.1, tclass: 'normal'},
    {c: '&#xBF;', tclass: 'normal'},
    {c: '?', lig: {'96': 62}, tclass: 'normal'},
    // 40 - 4F
    {c: '@', tclass: 'normal'},
    {c: 'A', krn: {'116': -0.0278, '67': -0.0278, '79': -0.0278, '71': -0.0278, '85': -0.0278, '81': -0.0278, '84': -0.0833, '89': -0.0833, '86': -0.111, '87': -0.111}, tclass: 'normal'},
    {c: 'B', tclass: 'normal'},
    {c: 'C', tclass: 'normal'},
    {c: 'D', krn: {'88': -0.0278, '87': -0.0278, '65': -0.0278, '86': -0.0278, '89': -0.0278}, tclass: 'normal'},
    {c: 'E', tclass: 'normal'},
    {c: 'F', krn: {'111': -0.0833, '101': -0.0833, '117': -0.0833, '114': -0.0833, '97': -0.0833, '65': -0.111, '79': -0.0278, '67': -0.0278, '71': -0.0278, '81': -0.0278}, tclass: 'normal'},
    {c: 'G', tclass: 'normal'},
    {c: 'H', tclass: 'normal'},
    {c: 'I', krn: {'73': 0.0278}, tclass: 'normal'},
    {c: 'J', tclass: 'normal'},
    {c: 'K', krn: {'79': -0.0278, '67': -0.0278, '71': -0.0278, '81': -0.0278}, tclass: 'normal'},
    {c: 'L', krn: {'84': -0.0833, '89': -0.0833, '86': -0.111, '87': -0.111}, tclass: 'normal'},
    {c: 'M', tclass: 'normal'},
    {c: 'N', tclass: 'normal'},
    {c: 'O', krn: {'88': -0.0278, '87': -0.0278, '65': -0.0278, '86': -0.0278, '89': -0.0278}, tclass: 'normal'},
    // 50 - 5F
    {c: 'P', krn: {'65': -0.0833, '111': -0.0278, '101': -0.0278, '97': -0.0278, '46': -0.0833, '44': -0.0833}, tclass: 'normal'},
    {c: 'Q', d: 1, tclass: 'normal'},
    {c: 'R', krn: {'116': -0.0278, '67': -0.0278, '79': -0.0278, '71': -0.0278, '85': -0.0278, '81': -0.0278, '84': -0.0833, '89': -0.0833, '86': -0.111, '87': -0.111}, tclass: 'normal'},
    {c: 'S', tclass: 'normal'},
    {c: 'T', krn: {'121': -0.0278, '101': -0.0833, '111': -0.0833, '114': -0.0833, '97': -0.0833, '65': -0.0833, '117': -0.0833}, tclass: 'normal'},
    {c: 'U', tclass: 'normal'},
    {c: 'V', ic: 0.0139, krn: {'111': -0.0833, '101': -0.0833, '117': -0.0833, '114': -0.0833, '97': -0.0833, '65': -0.111, '79': -0.0278, '67': -0.0278, '71': -0.0278, '81': -0.0278}, tclass: 'normal'},
    {c: 'W', ic: 0.0139, krn: {'111': -0.0833, '101': -0.0833, '117': -0.0833, '114': -0.0833, '97': -0.0833, '65': -0.111, '79': -0.0278, '67': -0.0278, '71': -0.0278, '81': -0.0278}, tclass: 'normal'},
    {c: 'X', krn: {'79': -0.0278, '67': -0.0278, '71': -0.0278, '81': -0.0278}, tclass: 'normal'},
    {c: 'Y', ic: 0.025, krn: {'101': -0.0833, '111': -0.0833, '114': -0.0833, '97': -0.0833, '65': -0.0833, '117': -0.0833}, tclass: 'normal'},
    {c: 'Z', tclass: 'normal'},
    {c: '[', d:.1, tclass: 'normal'},
    {c: '&#x201C;', tclass: 'normal'},
    {c: ']', d:.1, tclass: 'normal'},
    {c: '&#x2C6;', tclass: 'accent'},
    {c: '&#x2D9;', tclass: 'accent'},
    // 60 - 6F
    {c: '&#x2018;', lig: {'96': 92}, tclass: 'normal'},
    {c: 'a', a:0, krn: {'118': -0.0278, '106': 0.0556, '121': -0.0278, '119': -0.0278}, tclass: 'normal'},
    {c: 'b', krn: {'101': 0.0278, '111': 0.0278, '120': -0.0278, '100': 0.0278, '99': 0.0278, '113': 0.0278, '118': -0.0278, '106': 0.0556, '121': -0.0278, '119': -0.0278}, tclass: 'normal'},
    {c: 'c', a:0, krn: {'104': -0.0278, '107': -0.0278}, tclass: 'normal'},
    {c: 'd', tclass: 'normal'},
    {c: 'e', a:0, tclass: 'normal'},
    {c: 'f', ic: 0.0778, krn: {'39': 0.0778, '63': 0.0778, '33': 0.0778, '41': 0.0778, '93': 0.0778}, lig: {'105': 12, '102': 11, '108': 13}, tclass: 'normal'},
    {c: 'g', a:0, d:1, ic: 0.0139, krn: {'106': 0.0278}, tclass: 'normal'},
    {c: 'h', krn: {'116': -0.0278, '117': -0.0278, '98': -0.0278, '121': -0.0278, '118': -0.0278, '119': -0.0278}, tclass: 'normal'},
    {c: 'i', tclass: 'normal'},
    {c: 'j', d:1, tclass: 'normal'},
    {c: 'k', krn: {'97': -0.0556, '101': -0.0278, '97': -0.0278, '111': -0.0278, '99': -0.0278}, tclass: 'normal'},
    {c: 'l', tclass: 'normal'},
    {c: 'm', a:0, krn: {'116': -0.0278, '117': -0.0278, '98': -0.0278, '121': -0.0278, '118': -0.0278, '119': -0.0278}, tclass: 'normal'},
    {c: 'n', a:0, krn: {'116': -0.0278, '117': -0.0278, '98': -0.0278, '121': -0.0278, '118': -0.0278, '119': -0.0278}, tclass: 'normal'},
    {c: 'o', a:0, krn: {'101': 0.0278, '111': 0.0278, '120': -0.0278, '100': 0.0278, '99': 0.0278, '113': 0.0278, '118': -0.0278, '106': 0.0556, '121': -0.0278, '119': -0.0278}, tclass: 'normal'},
    // 70 - 7F
    {c: 'p', a:0, d:1, krn: {'101': 0.0278, '111': 0.0278, '120': -0.0278, '100': 0.0278, '99': 0.0278, '113': 0.0278, '118': -0.0278, '106': 0.0556, '121': -0.0278, '119': -0.0278}, tclass: 'normal'},
    {c: 'q', a:0, d:1, tclass: 'normal'},
    {c: 'r', a:0, tclass: 'normal'},
    {c: 's', a:0, tclass: 'normal'},
    {c: 't', krn: {'121': -0.0278, '119': -0.0278}, tclass: 'normal'},
    {c: 'u', a:0, krn: {'119': -0.0278}, tclass: 'normal'},
    {c: 'v', a:0, ic: 0.0139, krn: {'97': -0.0556, '101': -0.0278, '97': -0.0278, '111': -0.0278, '99': -0.0278}, tclass: 'normal'},
    {c: 'w', a:0, ic: 0.0139, krn: {'101': -0.0278, '97': -0.0278, '111': -0.0278, '99': -0.0278}, tclass: 'normal'},
    {c: 'x', a:0, tclass: 'normal'},
    {c: 'y', a:0, d:1, ic: 0.0139, krn: {'111': -0.0278, '101': -0.0278, '97': -0.0278, '46': -0.0833, '44': -0.0833}, tclass: 'normal'},
    {c: 'z', a:0, tclass: 'normal'},
    {c: '&#x2013;', a:.1, ic: 0.0278, lig: {'45': 124}, tclass: 'normal'},
    {c: '&#x2014;', a:.1, ic: 0.0278, tclass: 'normal'},
    {c: '&#x2DD;', tclass: 'accent'},
    {c: '&#x2DC;', tclass: 'accent'},
    {c: '&#xA8;', tclass: 'accent'}
  ],
  
  cmmi10: [
    // 00 - 0F
    {c: '<I>&Gamma;</I>', ic: 0.139, krn: {'61': -0.0556, '59': -0.111, '58': -0.111, '127': 0.0833}, tclass: 'greek'},
    {c: '<I>&Delta;</I>', krn: {'127': 0.167}, tclass: 'greek'},
    {c: '<I>&Theta;</I>', ic: 0.0278, krn: {'127': 0.0833}, tclass: 'greek'},
    {c: '<I>&Lambda;</I>', krn: {'127': 0.167}, tclass: 'greek'},
    {c: '<I>&Xi;</I>', ic: 0.0757, krn: {'127': 0.0833}, tclass: 'greek'},
    {c: '<I>&Pi;</I>', ic: 0.0812, krn: {'61': -0.0556, '59': -0.0556, '58': -0.0556, '127': 0.0556}, tclass: 'greek'},
    {c: '<I>&Sigma;</I>', ic: 0.0576, krn: {'127': 0.0833}, tclass: 'greek'},
    {c: '<I>&Upsilon;</I>', ic: 0.139, krn: {'61': -0.0556, '59': -0.111, '58': -0.111, '127': 0.0556}, tclass: 'greek'},
    {c: '<I>&Phi;</I>', krn: {'127': 0.0833}, tclass: 'greek'},
    {c: '<I>&Psi;</I>', ic: 0.11, krn: {'61': -0.0556, '59': -0.0556, '58': -0.0556, '127': 0.0556}, tclass: 'greek'},
    {c: '<I>&Omega;</I>', ic: 0.0502, krn: {'127': 0.0833}, tclass: 'greek'},
    {c: '&alpha;', a:0, ic: 0.0037, krn: {'127': 0.0278}, tclass: 'greek'},
    {c: '&beta;', d:1, ic: 0.0528, krn: {'127': 0.0833}, tclass: 'greek'},
    {c: '&gamma;', a:0, d:1, ic: 0.0556, tclass: 'greek'},
    {c: '&delta;', ic: 0.0378, krn: {'59': -0.0556, '58': -0.0556, '127': 0.0556}, tclass: 'greek'},
    {c: '&epsilon;', a:0, krn: {'127': 0.0556}, tclass: 'lucida'},
    // 10 - 1F
    {c: '&zeta;', d:1, ic: 0.0738, krn: {'127': 0.0833}, tclass: 'greek'},
    {c: '&eta;', a:0, d:1, ic: 0.0359, krn: {'127': 0.0556}, tclass: 'greek'},
    {c: '&theta;', ic: 0.0278, krn: {'127': 0.0833}, tclass: 'greek'},
    {c: '&iota;', a:0, krn: {'127': 0.0556}, tclass: 'greek'},
    {c: '&kappa;', a:0, tclass: 'greek'},
    {c: '&lambda;', tclass: 'greek'},
    {c: '&mu;', a:0, d:1, krn: {'127': 0.0278}, tclass: 'greek'},
    {c: '&nu;', a:0, ic: 0.0637, krn: {'59': -0.0556, '58': -0.0556, '127': 0.0278}, tclass: 'greek'},
    {c: '&xi;', d:1, ic: 0.046, krn: {'127': 0.111}, tclass: 'greek'},
    {c: '&pi;', a:0, ic: 0.0359, tclass: 'greek'},
    {c: '&rho;', a:0, d:1, krn: {'127': 0.0833}, tclass: 'greek'},
    {c: '&sigma;', a:0, ic: 0.0359, krn: {'59': -0.0556, '58': -0.0556}, tclass: 'greek'},
    {c: '&tau;', a:0, ic: 0.113, krn: {'59': -0.0556, '58': -0.0556, '127': 0.0278}, tclass: 'greek'},
    {c: '&upsilon;', a:0, ic: 0.0359, krn: {'127': 0.0278}, tclass: 'greek'},
    {c: '&phi;', a:.1, d:1, krn: {'127': 0.0833}, tclass: 'greek'},
    {c: '&chi;', a:0, d:1, krn: {'127': 0.0556}, tclass: 'greek'},
    // 20 - 2F
    {c: '&psi;', a:.1, d:1, ic: 0.0359, krn: {'127': 0.111}, tclass: 'greek'},
    {c: '&omega;', a:0, ic: 0.0359, tclass: 'greek'},
    {c: '&epsilon;', a:0, krn: {'127': 0.0833}, tclass: 'greek'},
    {c: '&#x3D1;', krn: {'127': 0.0833}, tclass: 'normal'},
    {c: '&#x3D6;', a:0, ic: 0.0278, tclass: 'normal'},
    {c: '&#x3F1;', a:0, d:1, krn: {'127': 0.0833}, tclass: 'normal'},
    {c: '&#x3C2;', a:0, d:1, ic: 0.0799, krn: {'127': 0.0833}, tclass: 'normal'},
    {c: '&#x3D5;', a:.1, d:1, krn: {'127': 0.0833}, tclass: 'normal'},
    {c: '&#x21BC;', a:0, d:-.2, tclass: 'harpoon'},
    {c: '&#x21BD;', a:0, d:-.1, tclass: 'harpoon'},
    {c: '&#x21C0;', a:0, d:-.2, tclass: 'harpoon'},
    {c: '&#x21C1;', a:0, d:-.1, tclass: 'harpoon'},
    {c: '<SPAN STYLE="font-size: 133%; position:relative; top:.1em; margin:-.2em; left:-.05em">&#x02D3;</SPAN>', a:.1, tclass: 'lucida'},
    {c: '<SPAN STYLE="font-size: 133%; position:relative; top:.1em; margin:-.2em; left:-.05em">&#x02D2;</SPAN>', a:.1, tclass: 'lucida'},
    {c: '<SPAN STYLE="font-size:50%">&#x25B7;</SPAN>', tclass: 'symbol'},
    {c: '<SPAN STYLE="font-size:50%">&#x25C1;</SPAN>', tclass: 'symbol'},
    // 30 - 3F
    {c: '0', tclass: 'normal'},
    {c: '1', tclass: 'normal'},
    {c: '2', tclass: 'normal'},
    {c: '3', tclass: 'normal'},
    {c: '4', tclass: 'normal'},
    {c: '5', tclass: 'normal'},
    {c: '6', tclass: 'normal'},
    {c: '7', tclass: 'normal'},
    {c: '8', tclass: 'normal'},
    {c: '9', tclass: 'normal'},
    {c: '.', a:-.3, tclass: 'normal'},
    {c: ',', a:-.3, d:.2, tclass: 'normal'},
    {c: '&lt;', a:.1, tclass: 'normal'},
    {c: '<SPAN STYLE="font-size:133%; position:relative; top:.1em">/</SPAN>', d:.1, krn: {'1': -0.0556, '65': -0.0556, '77': -0.0556, '78': -0.0556, '89': 0.0556, '90': -0.0556}, tclass: 'normal'},
    {c: '&gt;', a:.1, tclass: 'normal'},
    {c: '<SPAN STYLE="font-size:50%">&#x2605;</SPAN>', a:0, tclass: 'symbol'},
    // 40 - 4F
    {c: '&#x2202;', ic: 0.0556, krn: {'127': 0.0833}, tclass: 'normal'},
    {c: '<I>A</I>', krn: {'127': 0.139}, tclass: 'normal'},
    {c: '<I>B</I>', ic: 0.0502, krn: {'127': 0.0833}, tclass: 'normal'},
    {c: '<I>C</I>', ic: 0.0715, krn: {'61': -0.0278, '59': -0.0556, '58': -0.0556, '127': 0.0833}, tclass: 'normal'},
    {c: '<I>D</I>', ic: 0.0278, krn: {'127': 0.0556}, tclass: 'normal'},
    {c: '<I>E</I>', ic: 0.0576, krn: {'127': 0.0833}, tclass: 'normal'},
    {c: '<I>F</I>', ic: 0.139, krn: {'61': -0.0556, '59': -0.111, '58': -0.111, '127': 0.0833}, tclass: 'normal'},
    {c: '<I>G</I>', krn: {'127': 0.0833}, tclass: 'normal'},
    {c: '<I>H</I>', ic: 0.0812, krn: {'61': -0.0556, '59': -0.0556, '58': -0.0556, '127': 0.0556}, tclass: 'normal'},
    {c: '<I>I</I>', ic: 0.0785, krn: {'127': 0.111}, tclass: 'normal'},
    {c: '<I>J</I>', ic: 0.0962, krn: {'61': -0.0556, '59': -0.111, '58': -0.111, '127': 0.167}, tclass: 'normal'},
    {c: '<I>K</I>', ic: 0.0715, krn: {'61': -0.0556, '59': -0.0556, '58': -0.0556, '127': 0.0556}, tclass: 'normal'},
    {c: '<I>L</I>', krn: {'127': 0.0278}, tclass: 'normal'},
    {c: '<I>M</I>', ic: 0.109, krn: {'61': -0.0556, '59': -0.0556, '58': -0.0556, '127': 0.0833}, tclass: 'normal'},
    {c: '<I>N</I>', ic: 0.109, krn: {'61': -0.0833, '61': -0.0278, '59': -0.0556, '58': -0.0556, '127': 0.0833}, tclass: 'normal'},
    {c: '<I>O</I>', ic: 0.0278, krn: {'127': 0.0833}, tclass: 'normal'},
    // 50 - 5F
    {c: '<I>P</I>', ic: 0.139, krn: {'61': -0.0556, '59': -0.111, '58': -0.111, '127': 0.0833}, tclass: 'normal'},
    {c: '<I>Q</I>', d:1, krn: {'127': 0.0833}, tclass: 'normal'},
    {c: '<I>R</I>', ic: 0.00773, krn: {'127': 0.0833}, tclass: 'normal'},
    {c: '<I>S</I>', ic: 0.0576, krn: {'61': -0.0556, '59': -0.0556, '58': -0.0556, '127': 0.0833}, tclass: 'normal'},
    {c: '<I>T</I>', ic: 0.139, krn: {'61': -0.0278, '59': -0.0556, '58': -0.0556, '127': 0.0833}, tclass: 'normal'},
    {c: '<I>U</I>', ic: 0.109, krn: {'59': -0.111, '58': -0.111, '61': -0.0556, '127': 0.0278}, tclass: 'normal'},
    {c: '<I>V</I>', ic: 0.222, krn: {'59': -0.167, '58': -0.167, '61': -0.111}, tclass: 'normal'},
    {c: '<I>W</I>', ic: 0.139, krn: {'59': -0.167, '58': -0.167, '61': -0.111}, tclass: 'normal'},
    {c: '<I>X</I>', ic: 0.0785, krn: {'61': -0.0833, '61': -0.0278, '59': -0.0556, '58': -0.0556, '127': 0.0833}, tclass: 'normal'},
    {c: '<I>Y</I>', ic: 0.222, krn: {'59': -0.167, '58': -0.167, '61': -0.111}, tclass: 'normal'},
    {c: '<I>Z</I>', ic: 0.0715, krn: {'61': -0.0556, '59': -0.0556, '58': -0.0556, '127': 0.0833}, tclass: 'normal'},
    {c: '&#x266D;', tclass: 'symbol2'},
    {c: '&#x266E;', tclass: 'symbol2'},
    {c: '&#x266F;', tclass: 'symbol2'},
    {c: '<SPAN STYLE="position: relative; top:.5em">&#x2323;</SPAN>', a:0, d:-.1, tclass: 'normal'},
    {c: '<SPAN STYLE="position: relative; top:-.3em">&#x2322;</SPAN>', a:0, d:-.1, tclass: 'normal'},
    // 60 - 6F
    {c: '&#x2113;', krn: {'127': 0.111}, tclass: 'symbol'},
    {c: '<I>a</I>', a:0, tclass: 'normal'},
    {c: '<I>b</I>', tclass: 'normal'},
    {c: '<I>c</I>', a:0, krn: {'127': 0.0556}, tclass: 'normal'},
    {c: '<I>d</I>', krn: {'89': 0.0556, '90': -0.0556, '106': -0.111, '102': -0.167, '127': 0.167}, tclass: 'normal'},
    {c: '<I>e</I>', a:0, krn: {'127': 0.0556}, tclass: 'normal'},
    {c: '<I>f</I>', d:1, ic: 0.108, krn: {'59': -0.0556, '58': -0.0556, '127': 0.167}, tclass: 'normal'},
    {c: '<I>g</I>', a:0, d:1, ic: 0.0359, krn: {'127': 0.0278}, tclass: 'normal'},
    {c: '<I>h</I>', krn: {'127': -0.0278}, tclass: 'normal'},
    {c: '<I>i</I>', tclass: 'normal'},
    {c: '<I>j</I>', d:1, ic: 0.0572, krn: {'59': -0.0556, '58': -0.0556}, tclass: 'normal'},
    {c: '<I>k</I>', ic: 0.0315, tclass: 'normal'},
    {c: '<I>l</I>', ic: 0.0197, krn: {'127': 0.0833}, tclass: 'normal'},
    {c: '<I>m</I>', a:0, tclass: 'normal'},
    {c: '<I>n</I>', a:0, tclass: 'normal'},
    {c: '<I>o</I>', a:0, krn: {'127': 0.0556}, tclass: 'normal'},
    // 70 - 7F
    {c: '<I>p</I>', a:0, d:1, krn: {'127': 0.0833}, tclass: 'normal'},
    {c: '<I>q</I>', a:0, d:1, ic: 0.0359, krn: {'127': 0.0833}, tclass: 'normal'},
    {c: '<I>r</I>', a:0, ic: 0.0278, krn: {'59': -0.0556, '58': -0.0556, '127': 0.0556}, tclass: 'normal'},
    {c: '<I>s</I>', a:0, krn: {'127': 0.0556}, tclass: 'normal'},
    {c: '<I>t</I>', krn: {'127': 0.0833}, tclass: 'normal'},
    {c: '<I>u</I>', a:0, krn: {'127': 0.0278}, tclass: 'normal'},
    {c: '<I>v</I>', a:0, ic: 0.0359, krn: {'127': 0.0278}, tclass: 'normal'},
    {c: '<I>w</I>', a:0, ic: 0.0269, krn: {'127': 0.0833}, tclass: 'normal'},
    {c: '<I>x</I>', a:0, krn: {'127': 0.0278}, tclass: 'normal'},
    {c: '<I>y</I>', a:0, d:1, ic: 0.0359, krn: {'127': 0.0556}, tclass: 'normal'},
    {c: '<I>z</I>', a:0, ic: 0.044, krn: {'127': 0.0556}, tclass: 'normal'},
    {c: '<I>&#x131;</I>', a:0, krn: {'127': 0.0278}, tclass: 'normal'},
    {c: '<I>j</I>', d:1, krn: {'127': 0.0833}, tclass: 'normal'},
    {c: '&#x2118;', a:0, d:1, krn: {'127': 0.111}, tclass: 'normal'},
    {c: '<SPAN STYLE="position:relative; left: .4em; top: -.8em; font-size: 50%">&#x2192;</SPAN>', ic: 0.154, tclass: 'symbol'},
    {c: '&#x0311;', ic: 0.399, tclass: 'normal'}
  ],

  cmsy10: [
    // 00 - 0F
    {c: '&#x2212;', a:.1, tclass: 'symbol'},
    {c: '&#xB7;', a:0, d:-.2, tclass: 'symbol'},
    {c: '&#xD7;', a:0, tclass: 'symbol'},
    {c: '<SPAN STYLE="position:relative; top:.3em">&#x2A;</SPAN>', a:0, tclass: 'symbol'},
    {c: '&#xF7;', a:0, tclass: 'symbol'},
    {c: '&#x25CA;', tclass: 'lucida'},
    {c: '&#xB1;', a:.1, tclass: 'symbol'},
    {c: '&#x2213;', tclass: 'symbol'},
    {c: '&#x2295;', tclass: 'symbol'},
    {c: '&#x2296;', tclass: 'symbol'},
    {c: '&#x2297;', tclass: 'symbol'},
    {c: '&#x2298;', tclass: 'symbol'},
    {c: '&#x2299;', tclass: 'symbol3'},
    {c: '&#x25EF;', tclass: 'symbol'},
    {c: '<SPAN STYLE="position:relative; top:.25em;">&#xB0;</SPAN>', a:0, d:-.1, tclass: 'symbol'},
    {c: '&#x2022;', a:0, d:-.2, tclass: 'symbol'},
    // 10 - 1F
    {c: '&#x224D;', a:.1, tclass: 'symbol'},
    {c: '&#x2261;', a:.1, tclass: 'symbol'},
    {c: '&#x2286;', tclass: 'symbol'},
    {c: '&#x2287;', tclass: 'symbol'},
    {c: '&#x2264;', tclass: 'symbol'},
    {c: '&#x2265;', tclass: 'symbol'},
    {c: '&#x227C;', tclass: 'symbol'},
    {c: '&#x227D;', tclass: 'symbol'},
    {c: '~', a:0, d: -.2, tclass: 'normal'},
    {c: '&#x2248;', a:.1, d:-.1, tclass: 'symbol'},
    {c: '&#x2282;', tclass: 'symbol'},
    {c: '&#x2283;', tclass: 'symbol'},
    {c: '&#x226A;', tclass: 'symbol'},
    {c: '&#x226B;', tclass: 'symbol'},
    {c: '&#x227A;', tclass: 'symbol'},
    {c: '&#x227B;', tclass: 'symbol'},
    // 20 - 2F
    {c: '&#x2190;', a:0, d:-.15, tclass: 'arrow1'},
    {c: '&#x2192;', a:0, d:-.15, tclass: 'arrow1'},
    {c: '&#x2191;', h:1, tclass: 'arrow1a'},
    {c: '&#x2193;', h:1, tclass: 'arrow1a'},
    {c: '&#x2194;', a:0, tclass: 'arrow1'},
    {c: '&#x2197;', h:1, tclass: 'arrows'},
    {c: '&#x2198;', h:1, tclass: 'arrows'},
    {c: '&#x2243;', a: .1, tclass: 'symbol'},
    {c: '&#x21D0;', a:.1, tclass: 'arrow2'},
    {c: '&#x21D2;', a:.1, tclass: 'arrow2'},
    {c: '&#x21D1;', h:.9, d:.1, tclass: 'arrow2a'},
    {c: '&#x21D3;', h:.9, d:.1, tclass: 'arrow2a'},
    {c: '&#x21D4;', a:.1, tclass: 'arrow2'},
    {c: '&#x2196;', h:1, tclass: 'arrows'},
    {c: '&#x2199;', h:1, tclass: 'arrows'},
    {c: '&#x221D;', a:.1, tclass: 'symbol'},
    // 30 - 3F
    {c: '<SPAN STYLE="font-size: 133%; margin-right: -.1em; position: relative; top:.4em">&#x2032;</SPAN>', a: 0, tclass: 'lucida'},
    {c: '&#x221E;', a:.1, tclass: 'symbol'},
    {c: '&#x2208;', tclass: 'symbol'},
    {c: '&#x220B;', tclass: 'symbol'},
    {c: '&#x25B3;', tclass: 'symbol'},
    {c: '&#x25BD;', tclass: 'symbol'},
    {c: '/', tclass: 'symbol'},
    {c: '<SPAN STYLE="font-size:50%; position:relative; top:-.3em; margin-right:-.2em">|</SPAN>', a:0, tclass: 'normal'},
    {c: '&#x2200;', tclass: 'symbol'},
    {c: '&#x2203;', tclass: 'symbol'},
    {c: '&#xAC;', a:0, d:-.1, tclass: 'symbol1'},
    {c: '&#x2205;', tclass: 'symbol'},
    {c: '&#x211C;', tclass: 'symbol'},
    {c: '&#x2111;', tclass: 'symbol'},
    {c: '&#x22A4;', tclass: 'symbol'},
    {c: '&#x22A5;', tclass: 'symbol'},
    // 40 - 4F
    {c: '&#x2135;', tclass: 'symbol'},
    {c: 'A', krn: {'48': 0.194}, tclass: 'cal'},
    {c: 'B', ic: 0.0304, krn: {'48': 0.139}, tclass: 'cal'},
    {c: 'C', ic: 0.0583, krn: {'48': 0.139}, tclass: 'cal'},
    {c: 'D', ic: 0.0278, krn: {'48': 0.0833}, tclass: 'cal'},
    {c: 'E', ic: 0.0894, krn: {'48': 0.111}, tclass: 'cal'},
    {c: 'F', ic: 0.0993, krn: {'48': 0.111}, tclass: 'cal'},
    {c: 'G', d:.2, ic: 0.0593, krn: {'48': 0.111}, tclass: 'cal'},
    {c: 'H', ic: 0.00965, krn: {'48': 0.111}, tclass: 'cal'},
    {c: 'I', ic: 0.0738, krn: {'48': 0.0278}, tclass: 'cal'},
    {c: 'J', d:.2, ic: 0.185, krn: {'48': 0.167}, tclass: 'cal'},
    {c: 'K', ic: 0.0144, krn: {'48': 0.0556}, tclass: 'cal'},
    {c: 'L', krn: {'48': 0.139}, tclass: 'cal'},
    {c: 'M', krn: {'48': 0.139}, tclass: 'cal'},
    {c: 'N', ic: 0.147, krn: {'48': 0.0833}, tclass: 'cal'},
    {c: 'O', ic: 0.0278, krn: {'48': 0.111}, tclass: 'cal'},
    // 50 - 5F
    {c: 'P', ic: 0.0822, krn: {'48': 0.0833}, tclass: 'cal'},
    {c: 'Q', d:.2, krn: {'48': 0.111}, tclass: 'cal'},
    {c: 'R', krn: {'48': 0.0833}, tclass: 'cal'},
    {c: 'S', ic: 0.075, krn: {'48': 0.139}, tclass: 'cal'},
    {c: 'T', ic: 0.254, krn: {'48': 0.0278}, tclass: 'cal'},
    {c: 'U', ic: 0.0993, krn: {'48': 0.0833}, tclass: 'cal'},
    {c: 'V', ic: 0.0822, krn: {'48': 0.0278}, tclass: 'cal'},
    {c: 'W', ic: 0.0822, krn: {'48': 0.0833}, tclass: 'cal'},
    {c: 'X', ic: 0.146, krn: {'48': 0.139}, tclass: 'cal'},
    {c: 'Y', ic: 0.0822, krn: {'48': 0.0833}, tclass: 'cal'},
    {c: 'Z', ic: 0.0794, krn: {'48': 0.139}, tclass: 'cal'},
    {c: '&#x22C3;', tclass: 'symbol'},
    {c: '&#x22C2;', tclass: 'symbol'},
    {c: '&#x228E;', tclass: 'symbol'},
    {c: '&#x22C0;', tclass: 'symbol'},
    {c: '&#x22C1;', tclass: 'symbol'},
    // 60 - 6F
    {c: '&#x22A2;', tclass: 'symbol'},
    {c: '&#x22A3;', tclass: 'symbol2'},
    {c: '&#xF8F0;', a:.3, d:.2, tclass: 'normal'},
    {c: '&#xF8FB;', a:.3, d:.2, tclass: 'normal'},
    {c: '&#xF8EE;', a:.3, d:.2, tclass: 'normal'},
    {c: '&#xF8F9;', a:.3, d:.2, tclass: 'normal'},
    {c: '{', d:.2, tclass: 'normal'},
    {c: '}', d:.2, tclass: 'normal'},
    {c: '&#x3008;', a:.3, d:.2, tclass: 'normal'},
    {c: '&#x3009;', a:.3, d:.2, tclass: 'normal'},
    {c: '|', d:.1, tclass: 'vertical'},
    {c: '||', d:.1, tclass: 'vertical'},
    {c: '&#x2195;', h:1, d:.15, tclass: 'arrow1a'},
    {c: '&#x21D5;', a:.2, d:.1, tclass: 'arrows'},
    {c: '<SPAN STYLE="margin:-.1em">&#x2216;</SPAN>', a:.3, d:.1, tclass: 'lucida'},
    {c: '<SPAN STYLE="font-size: 75%; margin:-.3em">&#x2240;</SPAN>', tclass: 'symbol'},
    // 70 - 7F
    {c: '<SPAN STYLE="position:relative; top: .86em">&#x221A;</SPAN>', h:.04, d:.9, tclass: 'lucida'},
    {c: '&#x2210;', a:.4, tclass: 'symbol'},
    {c: '&#x2207;', tclass: 'symbol'},
    {c: '&#x222B;', h:1, d:.1, ic: 0.111, tclass: 'root'},
    {c: '&#x2294;', tclass: 'symbol'},
    {c: '&#x2293;', tclass: 'symbol'},
    {c: '&#x2291;', tclass: 'symbol'},
    {c: '&#x2292;', tclass: 'symbol'},
    {c: '&#xA7;', d:.1, tclass: 'normal'},
    {c: '&#x2020;', d:.1, tclass: 'normal'},
    {c: '&#x2021;', d:.1, tclass: 'normal'},
    {c: '&#xB6;', a:.3, d:.1, tclass: 'lucida'},
    {c: '&#x2663;', tclass: 'symbol'},
    {c: '&#x2666;', tclass: 'symbol'},
    {c: '&#x2665;', tclass: 'symbol'},
    {c: '&#x2660;', tclass: 'symbol'}
  ],

  cmex10: [
    // 00 - 0F
    {c: '(', h: 0.04, d: 1.16, n: 16, tclass: 'delim1'},
    {c: ')', h: 0.04, d: 1.16, n: 17, tclass: 'delim1'},
    {c: '[', h: 0.04, d: 1.16, n: 104, tclass: 'delim1'},
    {c: ']', h: 0.04, d: 1.16, n: 105, tclass: 'delim1'},
    {c: '&#xF8F0', h: 0.04, d: 1.16, n: 106, tclass: 'delim1'},
    {c: '&#xF8FB;', h: 0.04, d: 1.16, n: 107, tclass: 'delim1'},
    {c: '&#xF8EE;', h: 0.04, d: 1.16, n: 108, tclass: 'delim1'},
    {c: '&#xF8F9;', h: 0.04, d: 1.16, n: 109, tclass: 'delim1'},
    {c: '{', h: 0.04, d: 1.16, n: 110, tclass: 'delim1'},
    {c: '}', h: 0.04, d: 1.16, n: 111, tclass: 'delim1'},
    {c: '&#x3008;', h: 0.04, d: 1.16, n: 68, tclass: 'delim1c'},
    {c: '&#x3009;', h: 0.04, d: 1.16, n: 69, tclass: 'delim1c'},
    {c: '|', h:.7, d:.15, delim: {rep: 12}, tclass: 'vertical1'},
    {c: '||', h:.7, d:.15, delim: {rep: 13}, tclass: 'vertical1'},
    {c: '&#x2215;', h: 0.04, d: 1.16, n: 46, tclass: 'delim1b'},
    {c: '&#x2216;', h: 0.04, d: 1.16, n: 47, tclass: 'delim1b'},
    // 10 - 1F
    {c: '(', h: 0.04, d: 1.76, n: 18, tclass: 'delim2'},
    {c: ')', h: 0.04, d: 1.76, n: 19, tclass: 'delim2'},
    {c: '(', h: 0.04, d: 2.36, n: 32, tclass: 'delim3'},
    {c: ')', h: 0.04, d: 2.36, n: 33, tclass: 'delim3'},
    {c: '[', h: 0.04, d: 2.36, n: 34, tclass: 'delim3'},
    {c: ']', h: 0.04, d: 2.36, n: 35, tclass: 'delim3'},
    {c: '&#xF8F0;', h: 0.04, d: 2.36, n: 36, tclass: 'delim3'},
    {c: '&#xF8FB;', h: 0.04, d: 2.36, n: 37, tclass: 'delim3'},
    {c: '&#xF8EE;', h: 0.04, d: 2.36, n: 38, tclass: 'delim3'},
    {c: '&#xF8F9;', h: 0.04, d: 2.36, n: 39, tclass: 'delim3'},
    {c: '<SPAN STYLE="margin: -.1em">{</SPAN>', h: 0.04, d: 2.36, n: 40, tclass: 'delim3'},
    {c: '<SPAN STYLE="margin: -.1em">}</SPAN>', h: 0.04, d: 2.36, n: 41, tclass: 'delim3'},
    {c: '&#x3008;', h: 0.04, d: 2.36, n: 42, tclass: 'delim3c'},
    {c: '&#x3009;', h: 0.04, d: 2.36, n: 43, tclass: 'delim3c'},
    {c: '&#x2215;', h: 0.04, d: 2.36, n: 44, tclass: 'delim3b'},
    {c: '&#x2216;', h: 0.04, d: 2.36, n: 45, tclass: 'delim3b'},
    // 20 - 2F
    {c: '(', h: 0.04, d: 2.96, n: 48, tclass: 'delim4'},
    {c: ')', h: 0.04, d: 2.96, n: 49, tclass: 'delim4'},
    {c: '[', h: 0.04, d: 2.96, n: 50, tclass: 'delim4'},
    {c: ']', h: 0.04, d: 2.96, n: 51, tclass: 'delim4'},
    {c: '&#xF8F0;', h: 0.04, d: 2.96, n: 52, tclass: 'delim4'},
    {c: '&#xF8FB;', h: 0.04, d: 2.96, n: 53, tclass: 'delim4'},
    {c: '&#xF8EE;', h: 0.04, d: 2.96, n: 54, tclass: 'delim4'},
    {c: '&#xF8F9;', h: 0.04, d: 2.96, n: 55, tclass: 'delim4'},
    {c: '<SPAN STYLE="margin: -.1em">{</SPAN>', h: 0.04, d: 2.96, n: 56, tclass: 'delim4'},
    {c: '<SPAN STYLE="margin: -.1em">}</SPAN>', h: 0.04, d: 2.96, n: 57, tclass: 'delim4'},
    {c: '&#x3008;', h: 0.04, d: 2.96, tclass: 'delim4c'},
    {c: '&#x3009;', h: 0.04, d: 2.96, tclass: 'delim4c'},
    {c: '&#x2215;', h: 0.04, d: 2.96, tclass: 'delim4b'},
    {c: '&#x2216;', h: 0.04, d: 2.96, tclass: 'delim4b'},
    {c: '&#x2215;', h: 0.04, d: 1.76, n: 30, tclass: 'delim2b'},
    {c: '&#x2216;', h: 0.04, d: 1.76, n: 31, tclass: 'delim2b'},
    // 30 - 3F
    {c: '&#xF8EB;', h: .85, d: .2, delim: {top: 48, bot: 64, rep: 66}, tclass: 'normal'},
    {c: '&#xF8F6;', h: .85, d: .2, delim: {top: 49, bot: 65, rep: 67}, tclass: 'normal'},
    {c: '&#xF8EE;', h: .85, d: .2, delim: {top: 50, bot: 52, rep: 54}, tclass: 'normal'},
    {c: '&#xF8F9;', h: .85, d: .2, delim: {top: 51, bot: 53, rep: 55}, tclass: 'normal'},
    {c: '&#xF8F0;', h: .85, d: .2, delim: {bot: 52, rep: 54}, tclass: 'normal'},
    {c: '&#xF8FB;', h: .85, d: .2, delim: {bot: 53, rep: 55}, tclass: 'normal'},
    {c: '&#xF8EF;', h: .85, d: .2, delim: {top: 50, rep: 54}, tclass: 'normal'},
    {c: '&#xF8FA;', h: .85, d: .2, delim: {top: 51, rep: 55}, tclass: 'normal'},
    {c: '&#xF8F1;', h: .85, d: .2, delim: {top: 56, mid: 60, bot: 58, rep: 62}, tclass: 'normal'},
    {c: '&#xF8FC;', h: .85, d: .2, delim: {top: 57, mid: 61, bot: 59, rep: 62}, tclass: 'normal'},
    {c: '&#xF8F3;', h: .85, d: .2, delim: {top: 56, bot: 58, rep: 62}, tclass: 'normal'},
    {c: '&#xF8FE;', h: .85, d: .2, delim: {top: 57, bot: 59, rep: 62}, tclass: 'normal'},
    {c: '&#xF8F2;', h: .85, d: .2, delim: {rep: 63}, tclass: 'normal'},
    {c: '&#xF8FD;', h: .85, d: .2, delim: {rep: 119}, tclass: 'normal'},
    {c: '&#xF8F4;', h: .85, d: .2, delim: {rep: 62}, tclass: 'normal'},
    {c: '|', h: .7, d: .15, delim: {top: 120, bot: 121, rep: 63}, tclass: 'vertical2'},
    // 40 - 4F
    {c: '&#xF8ED;', h: .85, d: .2, delim: {top: 56, bot: 59, rep: 62}, tclass: 'normal'},
    {c: '&#xF8F8;', h: .85, d: .2, delim: {top: 57, bot: 58, rep: 62}, tclass: 'normal'},
    {c: '&#xF8EC;', h: .85, d: .2, delim: {rep: 66}, tclass: 'normal'},
    {c: '&#xF8F7;', h: .85, d: .2, delim: {rep: 67}, tclass: 'normal'},
    {c: '&#x3008;', h: 0.04, d: 1.76, n: 28, tclass: 'delim2c'},
    {c: '&#x3009;', h: 0.04, d: 1.76, n: 29, tclass: 'delim2c'},
    {c: '&#x2294;', h: 0, d: 1, n: 71, tclass: 'bigop1'},
    {c: '&#x2294;', h: 0.1, d: 1.5, tclass: 'bigop2'},
    {c: '&#x222E;', h: 0, d: 1.11, ic: 0.095, n: 73, tclass: 'bigop1c'},
    {c: '&#x222E;', h: 0, d: 2.22, ic: 0.222, tclass: 'bigop2c'},
    {c: '&#x2299;', h: 0, d: 1, n: 75, tclass: 'bigop1'},
    {c: '&#x2299;', h: 0.1, d: 1.5, tclass: 'bigop2'},
    {c: '&#x2295;', h: 0, d: 1, n: 77, tclass: 'bigop1'},
    {c: '&#x2295;', h: 0.1, d: 1.5, tclass: 'bigop2'},
    {c: '&#x2297;', h: 0, d: 1, n: 79, tclass: 'bigop1'},
    {c: '&#x2297;', h: 0.1, d: 1.5, tclass: 'bigop2'},
    // 50 - 5F
    {c: '&#x2211;', h: 0, d: 1, n: 88, tclass: 'bigop1a'},
    {c: '&#x220F;', h: 0, d: 1, n: 89, tclass: 'bigop1a'},
    {c: '&#x222B;', h: 0, d: 1.11, ic: 0.095, n: 90, tclass: 'bigop1c'},
    {c: '&#x222A;', h: 0, d: 1, n: 91, tclass: 'bigop1b'},
    {c: '&#x2229;', h: 0, d: 1, n: 92, tclass: 'bigop1b'},
    {c: '&#x228E;', h: 0, d: 1, n: 93, tclass: 'bigop1b'},
    {c: '&#x2227;', h: 0, d: 1, n: 94, tclass: 'bigop1'},
    {c: '&#x2228;', h: 0, d: 1, n: 95, tclass: 'bigop1'},
    {c: '&#x2211;', h: 0.1, d: 1.6, tclass: 'bigop2a'},
    {c: '&#x220F;', h: 0.1, d: 1.5, tclass: 'bigop2a'},
    {c: '&#x222B;', h: 0, d: 2.22, ic: 0.222, tclass: 'bigop2c'},
    {c: '&#x222A;', h: 0.1, d: 1.5, tclass: 'bigop2b'},
    {c: '&#x2229;', h: 0.1, d: 1.5, tclass: 'bigop2b'},
    {c: '&#x228E;', h: 0.1, d: 1.5, tclass: 'bigop2b'},
    {c: '&#x2227;', h: 0.1, d: 1.5, tclass: 'bigop2'},
    {c: '&#x2228;', h: 0.1, d: 1.5, tclass: 'bigop2'},
    // 60 - 6F
    {c: '&#x2210;', h: 0, d: 1, n: 97, tclass: 'bigop1a'},
    {c: '&#x2210;', h: 0.1, d: 1.5, tclass: 'bigop2a'},
    {c: '&#xFE3F;', h: 0.722, w: .65, n: 99, tclass: 'wide1'},
    {c: '&#xFE3F;', h: 0.85, w: 1.1, n: 100, tclass: 'wide2'},
    {c: '&#xFE3F;', h: 0.99, w: 1.65, tclass: 'wide3'},
    {c: '&#x2053;', h: 0.722, w: .75, n: 102, tclass: 'wide1a'},
    {c: '&#x2053;', h: 0.8, w: 1.35, n: 103, tclass: 'wide2a'},
    {c: '&#x2053;', h: 0.99, w: 2, tclass: 'wide3a'},
    {c: '[', h: 0.04, d: 1.76, n: 20, tclass: 'delim2'},
    {c: ']', h: 0.04, d: 1.76, n: 21, tclass: 'delim2'},
    {c: '&#xF8F0;', h: 0.04, d: 1.76, n: 22, tclass: 'delim2'},
    {c: '&#xF8FB;', h: 0.04, d: 1.76, n: 23, tclass: 'delim2'},
    {c: '&#xF8EE;', h: 0.04, d: 1.76, n: 24, tclass: 'delim2'},
    {c: '&#xF8F9', h: 0.04, d: 1.76, n: 25, tclass: 'delim2'},
    {c: '<SPAN STYLE="margin: -.1em">{</SPAN>', h: 0.04, d: 1.76, n: 26, tclass: 'delim2'},
    {c: '<SPAN STYLE="margin: -.1em">}</SPAN>', h: 0.04, d: 1.76, n: 27, tclass: 'delim2'},
    // 70 - 7F
    {c: '<SPAN STYLE="font-size: 125%; position:relative; top:.95em">&#x221A;</SPAN>', h: 0.04, d: 1.16, n: 113, tclass: 'root'},
    {c: '<SPAN STYLE="font-size: 190%; position:relative; top:.925em">&#x221A;</SPAN>', h: 0.04, d: 1.76, n: 114, tclass: 'root'},
    {c: '<SPAN STYLE="font-size: 250%; position:relative; top:.925em">&#x221A;</SPAN>', h: 0.06, d: 2.36, n: 115, tclass: 'root'},
    {c: '<SPAN STYLE="font-size: 320%; position:relative; top:.92em">&#x221A;</SPAN>', h: 0.08, d: 2.96, n: 116, tclass: 'root'},
    {c: '<SPAN STYLE="font-size: 400%; position:relative; top:.92em">&#x221A;</SPAN>', h: 0.1, d: 3.75, n: 117, tclass: 'root'},
    {c: '<SPAN STYLE="font-size: 500%; position:relative; top:.9em">&#x221A;</SPAN>', h: .12, d: 4.5, n: 118, tclass: 'root'},
    {c: '<SPAN STYLE="font-size: 625%; position:relative; top:.9em">&#x221A;</SPAN>', h: .14, d: 5.7, tclass: 'root'},
    {c: '||', h:.65, d:.15, delim: {top: 126, bot: 127, rep: 119}, tclass: 'vertical2'},
    {c: '&#x25B5;', h:.4, delim: {top: 120, rep: 63}, tclass: 'arrow1b'},
    {c: '&#x25BF;', h:.38, delim: {bot: 121, rep: 63}, tclass: 'arrow1b'},
    {c: '<SPAN STYLE="font-size: 67%; position:relative; top:.35em; margin-left:-.5em">&#x256D;</SPAN>', h:.1, tclass: 'symbol'},
    {c: '<SPAN STYLE="font-size: 67%; position:relative; top:.35em; margin-right:-.5em">&#x256E;</SPAN>', h:.1, tclass: 'symbol'},
    {c: '<SPAN STYLE="font-size: 67%; position:relative; top:.35em; margin-left:-.5em">&#x2570;</SPAN>', h:.1, tclass: 'symbol'},
    {c: '<SPAN STYLE="font-size: 67%; position:relative; top:.35em; margin-right:-.5em">&#x256F;</SPAN>', h:.1, tclass: 'symbol'},
    {c: '&#x25B5;', h:.5, delim: {top: 126, rep: 119}, tclass: 'arrow2b'},
    {c: '&#x25BF;', h:.6, d:-.1, delim: {bot: 127, rep: 119}, tclass: 'arrow2b'}
  ],
  
  cmti10: [
    // 00 - 0F
    {c: '<I>&Gamma;</I>', tclass: 'greek', ic: 0.133},
    {c: '<I>&Delta;</I>', tclass: 'greek'},
    {c: '<I>&Theta;</I>', tclass: 'greek', ic: 0.094},
    {c: '<I>&Lambda;</I>', tclass: 'greek'},
    {c: '<I>&Xi;</I>', tclass: 'greek', ic: 0.153},
    {c: '<I>&Pi;</I>', tclass: 'greek', ic: 0.164},
    {c: '<I>&Sigma;</I>', tclass: 'greek', ic: 0.12},
    {c: '<I>&Upsilon;</I>', tclass: 'greek', ic: 0.111},
    {c: '<I>&Phi;</I>', tclass: 'greek', ic: 0.0599},
    {c: '<I>&Psi;</I>', tclass: 'greek', ic: 0.111},
    {c: '<I>&Omega;</I>', tclass: 'greek', ic: 0.103},
    {c: '<I>ff</I>', ic: 0.0778, krn: {'39': 0.0778, '63': 0.0778, '33': 0.0778, '41': 0.0778, '93': 0.0778}, lig: {'105': 14, '108': 15}, tclass: 'normal', ic: 0.212, krn: {'39': 0.104, '63': 0.104, '33': 0.104, '41': 0.104, '93': 0.104}, lig: {'105': 14, '108': 15}},
    {c: '<I>fi</I>', tclass: 'normal', ic: 0.103},
    {c: '<I>fl</I>', tclass: 'normal', ic: 0.103},
    {c: '<I>ffi</I>', tclass: 'normal', ic: 0.103},
    {c: '<I>ffl</I>', tclass: 'normal', ic: 0.103},
    // 10 - 1F
    {c: '<I>&#x131;</I>', a:0, tclass: 'normal', ic: 0.0767},
    {c: '<I>j</I>', d:.2, tclass: 'normal', ic: 0.0374},
    {c: '<I>&#x60;</I>', tclass: 'accent'},
    {c: '<I>&#xB4;</I>', tclass: 'accent', ic: 0.0969},
    {c: '<I>&#x2C7;</I>', tclass: 'accent', ic: 0.083},
    {c: '<I>&#x2D8;</I>', tclass: 'accent', ic: 0.108},
    {c: '<I>&#x2C9;</I>', tclass: 'accent', ic: 0.103},
    {c: '<I>&#x2DA;</I>', tclass: 'accent'},
    {c: '<I>?</I>', tclass: 'normal', d: 0.17, w: 0.46},
    {c: '<I>&#xDF;</I>', tclass: 'normal', ic: 0.105},
    {c: '<I>&#xE6;</I>', a:0, tclass: 'normal', ic: 0.0751},
    {c: '<I>&#x153;</I>', a:0, tclass: 'normal', ic: 0.0751},
    {c: '<I>&#xF8;</I>', tclass: 'normal', ic: 0.0919},
    {c: '<I>&#xC6;</I>', tclass: 'normal', ic: 0.12},
    {c: '<I>&#x152;</I>', tclass: 'normal', ic: 0.12},
    {c: '<I>&#xD8;</I>', tclass: 'normal', ic: 0.094},
    // 20 - 2F
    {c: '<I>?</I>', krn: {'108': -0.278, '76': -0.319}, tclass: 'normal', krn: {'108': -0.256, '76': -0.321}},
    {c: '<I>!</I>', lig: {'96': 60}, tclass: 'normal', ic: 0.124, lig: {'96': 60}},
    {c: '<I>&#x201D;</I>', tclass: 'normal', ic: 0.0696},
    {c: '<I>#</I>', tclass: 'normal', ic: 0.0662},
    {c: '<I>$</I>', tclass: 'normal'},
    {c: '<I>%</I>', tclass: 'normal', ic: 0.136},
    {c: '<I>&amp;</I>', tclass: 'normal', ic: 0.0969},
    {c: '<I>&#x2019;</I>', krn: {'63': 0.111, '33': 0.111}, lig: {'39': 34}, tclass: 'normal', ic: 0.124, krn: {'63': 0.102, '33': 0.102}, lig: {'39': 34}},
    {c: '<I>(</I>', d:.2, tclass: 'normal', ic: 0.162},
    {c: '<I>)</I>', d:.2, tclass: 'normal', ic: 0.0369},
    {c: '<I>*</I>', tclass: 'normal', ic: 0.149},
    {c: '<I>+</I>', a:.1, tclass: 'normal', ic: 0.0369},
    {c: '<I>,</I>', a:-.3, d:.2, w: 0.278, tclass: 'normal'},
    {c: '<I>-</I>', a:0, lig: {'45': 123}, tclass: 'normal', ic: 0.0283, lig: {'45': 123}},
    {c: '<I>.</I>', a:-.25, tclass: 'normal'},
    {c: '<I>/</I>', tclass: 'normal', ic: 0.162},
    // 30 - 3F
    {c: '<I>0</I>', tclass: 'normal', ic: 0.136},
    {c: '<I>1</I>', tclass: 'normal', ic: 0.136},
    {c: '<I>2</I>', tclass: 'normal', ic: 0.136},
    {c: '<I>3</I>', tclass: 'normal', ic: 0.136},
    {c: '<I>4</I>', tclass: 'normal', ic: 0.136},
    {c: '<I>5</I>', tclass: 'normal', ic: 0.136},
    {c: '<I>6</I>', tclass: 'normal', ic: 0.136},
    {c: '<I>7</I>', tclass: 'normal', ic: 0.136},
    {c: '<I>8</I>', tclass: 'normal', ic: 0.136},
    {c: '<I>9</I>', tclass: 'normal', ic: 0.136},
    {c: '<I>:</I>', tclass: 'normal', ic: 0.0582},
    {c: '<I>;</I>', tclass: 'normal', ic: 0.0582},
    {c: '<I>&#xA1;</I>', tclass: 'normal', ic: 0.0756},
    {c: '<I>=</I>', a:0, d:-.1, tclass: 'normal', ic: 0.0662},
    {c: '<I>&#xBF;</I>', tclass: 'normal'},
    {c: '<I>?</I>', lig: {'96': 62}, tclass: 'normal', ic: 0.122, lig: {'96': 62}},
    // 40 - 4F
    {c: '<I>@</I>', tclass: 'normal', ic: 0.096},
    {c: '<I>A</I>', krn: {'116': -0.0278, '67': -0.0278, '79': -0.0278, '71': -0.0278, '85': -0.0278, '81': -0.0278, '84': -0.0833, '89': -0.0833, '86': -0.111, '87': -0.111}, tclass: 'normal', krn: {'110': -0.0256, '108': -0.0256, '114': -0.0256, '117': -0.0256, '109': -0.0256, '116': -0.0256, '105': -0.0256, '67': -0.0256, '79': -0.0256, '71': -0.0256, '104': -0.0256, '98': -0.0256, '85': -0.0256, '107': -0.0256, '118': -0.0256, '119': -0.0256, '81': -0.0256, '84': -0.0767, '89': -0.0767, '86': -0.102, '87': -0.102, '101': -0.0511, '97': -0.0511, '111': -0.0511, '100': -0.0511, '99': -0.0511, '103': -0.0511, '113': -0.0511}},
    {c: '<I>B</I>', tclass: 'normal', ic: 0.103},
    {c: '<I>C</I>', tclass: 'normal', ic: 0.145},
    {c: '<I>D</I>', krn: {'88': -0.0278, '87': -0.0278, '65': -0.0278, '86': -0.0278, '89': -0.0278}, tclass: 'normal', ic: 0.094, krn: {'88': -0.0256, '87': -0.0256, '65': -0.0256, '86': -0.0256, '89': -0.0256}},
    {c: '<I>E</I>', tclass: 'normal', ic: 0.12},
    {c: '<I>F</I>', krn: {'111': -0.0833, '101': -0.0833, '117': -0.0833, '114': -0.0833, '97': -0.0833, '65': -0.111, '79': -0.0278, '67': -0.0278, '71': -0.0278, '81': -0.0278}, tclass: 'normal', ic: 0.133, krn: {'111': -0.0767, '101': -0.0767, '117': -0.0767, '114': -0.0767, '97': -0.0767, '65': -0.102, '79': -0.0256, '67': -0.0256, '71': -0.0256, '81': -0.0256}},
    {c: '<I>G</I>', tclass: 'normal', ic: 0.0872},
    {c: '<I>H</I>', tclass: 'normal', ic: 0.164},
    {c: '<I>I</I>', krn: {'73': 0.0278}, tclass: 'normal', ic: 0.158},
    {c: '<I>J</I>', tclass: 'normal', ic: 0.14},
    {c: '<I>K</I>', krn: {'79': -0.0278, '67': -0.0278, '71': -0.0278, '81': -0.0278}, tclass: 'normal', ic: 0.145, krn: {'79': -0.0256, '67': -0.0256, '71': -0.0256, '81': -0.0256}},
    {c: '<I>L</I>', krn: {'84': -0.0833, '89': -0.0833, '86': -0.111, '87': -0.111}, tclass: 'normal', krn: {'84': -0.0767, '89': -0.0767, '86': -0.102, '87': -0.102, '101': -0.0511, '97': -0.0511, '111': -0.0511, '100': -0.0511, '99': -0.0511, '103': -0.0511, '113': -0.0511}},
    {c: '<I>M</I>', tclass: 'normal', ic: 0.164},
    {c: '<I>N</I>', tclass: 'normal', ic: 0.164},
    {c: '<I>O</I>', krn: {'88': -0.0278, '87': -0.0278, '65': -0.0278, '86': -0.0278, '89': -0.0278}, tclass: 'normal', ic: 0.094, krn: {'88': -0.0256, '87': -0.0256, '65': -0.0256, '86': -0.0256, '89': -0.0256}},
    // 50 - 5F
    {c: '<I>P</I>', krn: {'65': -0.0833, '111': -0.0278, '101': -0.0278, '97': -0.0278, '46': -0.0833, '44': -0.0833}, tclass: 'normal', ic: 0.103, krn: {'65': -0.0767}},
    {c: '<I>Q</I>', d: 1, tclass: 'normal', ic: 0.094},
    {c: '<I>R</I>', krn: {'116': -0.0278, '67': -0.0278, '79': -0.0278, '71': -0.0278, '85': -0.0278, '81': -0.0278, '84': -0.0833, '89': -0.0833, '86': -0.111, '87': -0.111}, tclass: 'normal', ic: 0.0387, krn: {'110': -0.0256, '108': -0.0256, '114': -0.0256, '117': -0.0256, '109': -0.0256, '116': -0.0256, '105': -0.0256, '67': -0.0256, '79': -0.0256, '71': -0.0256, '104': -0.0256, '98': -0.0256, '85': -0.0256, '107': -0.0256, '118': -0.0256, '119': -0.0256, '81': -0.0256, '84': -0.0767, '89': -0.0767, '86': -0.102, '87': -0.102, '101': -0.0511, '97': -0.0511, '111': -0.0511, '100': -0.0511, '99': -0.0511, '103': -0.0511, '113': -0.0511}},
    {c: '<I>S</I>', tclass: 'normal', ic: 0.12},
    {c: '<I>T</I>', krn: {'121': -0.0278, '101': -0.0833, '111': -0.0833, '114': -0.0833, '97': -0.0833, '65': -0.0833, '117': -0.0833}, tclass: 'normal', ic: 0.133, krn: {'121': -0.0767, '101': -0.0767, '111': -0.0767, '114': -0.0767, '97': -0.0767, '117': -0.0767, '65': -0.0767}},
    {c: '<I>U</I>', tclass: 'normal', ic: 0.164},
    {c: '<I>V</I>', ic: 0.0139, krn: {'111': -0.0833, '101': -0.0833, '117': -0.0833, '114': -0.0833, '97': -0.0833, '65': -0.111, '79': -0.0278, '67': -0.0278, '71': -0.0278, '81': -0.0278}, tclass: 'normal', ic: 0.184, krn: {'111': -0.0767, '101': -0.0767, '117': -0.0767, '114': -0.0767, '97': -0.0767, '65': -0.102, '79': -0.0256, '67': -0.0256, '71': -0.0256, '81': -0.0256}},
    {c: '<I>W</I>', ic: 0.0139, krn: {'111': -0.0833, '101': -0.0833, '117': -0.0833, '114': -0.0833, '97': -0.0833, '65': -0.111, '79': -0.0278, '67': -0.0278, '71': -0.0278, '81': -0.0278}, tclass: 'normal', ic: 0.184, krn: {'65': -0.0767}},
    {c: '<I>X</I>', krn: {'79': -0.0278, '67': -0.0278, '71': -0.0278, '81': -0.0278}, tclass: 'normal', ic: 0.158, krn: {'79': -0.0256, '67': -0.0256, '71': -0.0256, '81': -0.0256}},
    {c: '<I>Y</I>', ic: 0.025, krn: {'101': -0.0833, '111': -0.0833, '114': -0.0833, '97': -0.0833, '65': -0.0833, '117': -0.0833}, tclass: 'normal', ic: 0.194, krn: {'101': -0.0767, '111': -0.0767, '114': -0.0767, '97': -0.0767, '117': -0.0767, '65': -0.0767}},
    {c: '<I>Z</I>', tclass: 'normal', ic: 0.145},
    {c: '<I>[</I>', d:.1, tclass: 'normal', ic: 0.188},
    {c: '<I>&#x201C;</I>', tclass: 'normal', ic: 0.169},
    {c: '<I>]</I>', d:.1, tclass: 'normal', ic: 0.105},
    {c: '<I>&#x2C6;</I>', tclass: 'accent', ic: 0.0665},
    {c: '<I>&#x2D9;</I>', tclass: 'accent', ic: 0.118},
    // 60 - 6F
    {c: '<I>&#x2018;</I>', lig: {'96': 92}, tclass: 'normal', ic: 0.124, lig: {'96': 92}},
    {c: '<I>a</I>', a:0, krn: {'118': -0.0278, '106': 0.0556, '121': -0.0278, '119': -0.0278}, tclass: 'normal', ic: 0.0767},
    {c: '<I>b</I>', krn: {'101': 0.0278, '111': 0.0278, '120': -0.0278, '100': 0.0278, '99': 0.0278, '113': 0.0278, '118': -0.0278, '106': 0.0556, '121': -0.0278, '119': -0.0278}, tclass: 'normal', ic: 0.0631, krn: {'101': -0.0511, '97': -0.0511, '111': -0.0511, '100': -0.0511, '99': -0.0511, '103': -0.0511, '113': -0.0511}},
    {c: '<I>c</I>', a:0, krn: {'104': -0.0278, '107': -0.0278}, tclass: 'normal', ic: 0.0565, krn: {'101': -0.0511, '97': -0.0511, '111': -0.0511, '100': -0.0511, '99': -0.0511, '103': -0.0511, '113': -0.0511}},
    {c: '<I>d</I>', tclass: 'normal', ic: 0.103, krn: {'108': 0.0511}},
    {c: '<I>e</I>', a:0, tclass: 'normal', ic: 0.0751, krn: {'101': -0.0511, '97': -0.0511, '111': -0.0511, '100': -0.0511, '99': -0.0511, '103': -0.0511, '113': -0.0511}},
    {c: '<I>f</I>', ic: 0.0778, krn: {'39': 0.0778, '63': 0.0778, '33': 0.0778, '41': 0.0778, '93': 0.0778}, lig: {'105': 12, '102': 11, '108': 13}, tclass: 'normal', ic: 0.212, krn: {'39': 0.104, '63': 0.104, '33': 0.104, '41': 0.104, '93': 0.104}, lig: {'105': 12, '102': 11, '108': 13}},
    {c: '<I>g</I>', a:0, d:1, ic: 0.0139, krn: {'106': 0.0278}, tclass: 'normal', ic: 0.0885},
    {c: '<I>h</I>', krn: {'116': -0.0278, '117': -0.0278, '98': -0.0278, '121': -0.0278, '118': -0.0278, '119': -0.0278}, tclass: 'normal', ic: 0.0767},
    {c: '<I>i</I>', tclass: 'normal', ic: 0.102},
    {c: '<I>j</I>', d:1, tclass: 'normal', ic: 0.145},
    {c: '<I>k</I>', krn: {'97': -0.0556, '101': -0.0278, '97': -0.0278, '111': -0.0278, '99': -0.0278}, tclass: 'normal', ic: 0.108},
    {c: '<I>l</I>', tclass: 'normal', ic: 0.103, krn: {'108': 0.0511}},
    {c: '<I>m</I>', a:0, krn: {'116': -0.0278, '117': -0.0278, '98': -0.0278, '121': -0.0278, '118': -0.0278, '119': -0.0278}, tclass: 'normal', ic: 0.0767},
    {c: '<I>n</I>', a:0, krn: {'116': -0.0278, '117': -0.0278, '98': -0.0278, '121': -0.0278, '118': -0.0278, '119': -0.0278}, tclass: 'normal', ic: 0.0767, krn: {'39': -0.102}},
    {c: '<I>o</I>', a:0, krn: {'101': 0.0278, '111': 0.0278, '120': -0.0278, '100': 0.0278, '99': 0.0278, '113': 0.0278, '118': -0.0278, '106': 0.0556, '121': -0.0278, '119': -0.0278}, tclass: 'normal', ic: 0.0631, krn: {'101': -0.0511, '97': -0.0511, '111': -0.0511, '100': -0.0511, '99': -0.0511, '103': -0.0511, '113': -0.0511}},
    // 70 - 7F
    {c: '<I>p</I>', a:0, d:1, krn: {'101': 0.0278, '111': 0.0278, '120': -0.0278, '100': 0.0278, '99': 0.0278, '113': 0.0278, '118': -0.0278, '106': 0.0556, '121': -0.0278, '119': -0.0278}, tclass: 'normal', ic: 0.0631, krn: {'101': -0.0511, '97': -0.0511, '111': -0.0511, '100': -0.0511, '99': -0.0511, '103': -0.0511, '113': -0.0511}},
    {c: '<I>q</I>', a:0, d:1, tclass: 'normal', ic: 0.0885},
    {c: '<I>r</I>', a:0, tclass: 'normal', ic: 0.108, krn: {'101': -0.0511, '97': -0.0511, '111': -0.0511, '100': -0.0511, '99': -0.0511, '103': -0.0511, '113': -0.0511}},
    {c: '<I>s</I>', a:0, tclass: 'normal', ic: 0.0821},
    {c: '<I>t</I>', krn: {'121': -0.0278, '119': -0.0278}, tclass: 'normal', ic: 0.0949},
    {c: '<I>u</I>', a:0, krn: {'119': -0.0278}, tclass: 'normal', ic: 0.0767},
    {c: '<I>v</I>', a:0, ic: 0.0139, krn: {'97': -0.0556, '101': -0.0278, '97': -0.0278, '111': -0.0278, '99': -0.0278}, tclass: 'normal', ic: 0.108},
    {c: '<I>w</I>', a:0, ic: 0.0139, krn: {'101': -0.0278, '97': -0.0278, '111': -0.0278, '99': -0.0278}, tclass: 'normal', ic: 0.108, krn: {'108': 0.0511}},
    {c: '<I>x</I>', a:0, tclass: 'normal', ic: 0.12},
    {c: '<I>y</I>', a:0, d:1, ic: 0.0139, krn: {'111': -0.0278, '101': -0.0278, '97': -0.0278, '46': -0.0833, '44': -0.0833}, tclass: 'normal', ic: 0.0885},
    {c: '<I>z</I>', a:0, tclass: 'normal', ic: 0.123},
    {c: '<I>&#x2013;</I>', a:.1, ic: 0.0278, lig: {'45': 124}, tclass: 'normal', ic: 0.0921, lig: {'45': 124}},
    {c: '<I>&#x2014;</I>', a:.1, ic: 0.0278, tclass: 'normal', ic: 0.0921},
    {c: '<I>&#x2DD;</I>', tclass: 'accent', ic: 0.122},
    {c: '<I>&#x2DC;</I>', tclass: 'accent', ic: 0.116},
    {c: '<I>&#xA8;</I>', tclass: 'accent'}
  ],
  
  cmbx10: [
    // 00 - 0F
    {c: '<B>&Gamma;</B>', tclass: 'greek'},
    {c: '<B>&Delta;</B>', tclass: 'greek'},
    {c: '<B>&Theta;</B>', tclass: 'greek'},
    {c: '<B>&Lambda;</B>', tclass: 'greek'},
    {c: '<B>&Xi;</B>', tclass: 'greek'},
    {c: '<B>&Pi;</B>', tclass: 'greek'},
    {c: '<B>&Sigma;</B>', tclass: 'greek'},
    {c: '<B>&Upsilon;</B>', tclass: 'greek'},
    {c: '<B>&Phi;</B>', tclass: 'greek'},
    {c: '<B>&Psi;</B>', tclass: 'greek'},
    {c: '<B>&Omega;</B>', tclass: 'greek'},
    {c: '<B>ff</B>', ic: 0.0778, krn: {'39': 0.0778, '63': 0.0778, '33': 0.0778, '41': 0.0778, '93': 0.0778}, lig: {'105': 14, '108': 15}, tclass: 'normal'},
    {c: '<B>fi</B>', tclass: 'normal'},
    {c: '<B>fl</B>', tclass: 'normal'},
    {c: '<B>ffi</B>', tclass: 'normal'},
    {c: '<B>ffl</B>', tclass: 'normal'},
    // 10 - 1F
    {c: '<B>&#x131;</B>', a:0, tclass: 'normal'},
    {c: '<B>j</B>', d:.2, tclass: 'normal'},
    {c: '<B>&#x60;</B>', tclass: 'accent'},
    {c: '<B>&#xB4;</B>', tclass: 'accent'},
    {c: '<B>&#x2C7;</B>', tclass: 'accent'},
    {c: '<B>&#x2D8;</B>', tclass: 'accent'},
    {c: '<B>&#x2C9;</B>', tclass: 'accent'},
    {c: '<B>&#x2DA;</B>', tclass: 'accent'},
    {c: '<B>?</B>', tclass: 'normal'},
    {c: '<B>&#xDF;</B>', tclass: 'normal'},
    {c: '<B>&#xE6;</B>', a:0, tclass: 'normal'},
    {c: '<B>&#x153;</B>', a:0, tclass: 'normal'},
    {c: '<B>&#xF8;</B>', tclass: 'normal'},
    {c: '<B>&#xC6;</B>', tclass: 'normal'},
    {c: '<B>&#x152;</B>', tclass: 'normal'},
    {c: '<B>&#xD8;</B>', tclass: 'normal'},
    // 20 - 2F
    {c: '<B>?</B>', krn: {'108': -0.278, '76': -0.319}, tclass: 'normal'},
    {c: '<B>!</B>', lig: {'96': 60}, tclass: 'normal'},
    {c: '<B>&#x201D;</B>', tclass: 'normal'},
    {c: '<B>#</B>', tclass: 'normal'},
    {c: '<B>$</B>', tclass: 'normal'},
    {c: '<B>%</B>', tclass: 'normal'},
    {c: '<B>&amp;</B>', tclass: 'normal'},
    {c: '<B>&#x2019;</B>', krn: {'63': 0.111, '33': 0.111}, lig: {'39': 34}, tclass: 'normal'},
    {c: '<B>(</B>', d:.2, tclass: 'normal'},
    {c: '<B>)</B>', d:.2, tclass: 'normal'},
    {c: '<B>*</B>', tclass: 'normal'},
    {c: '<B>+</B>', a:.1, tclass: 'normal'},
    {c: '<B>,</B>', a:-.3, d:.2, w: 0.278, tclass: 'normal'},
    {c: '<B>-</B>', a:0, lig: {'45': 123}, tclass: 'normal'},
    {c: '<B>.</B>', a:-.25, tclass: 'normal'},
    {c: '<B>/</B>', tclass: 'normal'},
    // 30 - 3F
    {c: '<B>0</B>', tclass: 'normal'},
    {c: '<B>1</B>', tclass: 'normal'},
    {c: '<B>2</B>', tclass: 'normal'},
    {c: '<B>3</B>', tclass: 'normal'},
    {c: '<B>4</B>', tclass: 'normal'},
    {c: '<B>5</B>', tclass: 'normal'},
    {c: '<B>6</B>', tclass: 'normal'},
    {c: '<B>7</B>', tclass: 'normal'},
    {c: '<B>8</B>', tclass: 'normal'},
    {c: '<B>9</B>', tclass: 'normal'},
    {c: '<B>:</B>', tclass: 'normal'},
    {c: '<B>;</B>', tclass: 'normal'},
    {c: '<B>&#xA1;</B>', tclass: 'normal'},
    {c: '<B>=</B>', a:0, d:-.1, tclass: 'normal'},
    {c: '<B>&#xBF;</B>', tclass: 'normal'},
    {c: '<B>?</B>', lig: {'96': 62}, tclass: 'normal'},
    // 40 - 4F
    {c: '<B>@</B>', tclass: 'normal'},
    {c: '<B>A</B>', krn: {'116': -0.0278, '67': -0.0278, '79': -0.0278, '71': -0.0278, '85': -0.0278, '81': -0.0278, '84': -0.0833, '89': -0.0833, '86': -0.111, '87': -0.111}, tclass: 'normal'},
    {c: '<B>B</B>', tclass: 'normal'},
    {c: '<B>C</B>', tclass: 'normal'},
    {c: '<B>D</B>', krn: {'88': -0.0278, '87': -0.0278, '65': -0.0278, '86': -0.0278, '89': -0.0278}, tclass: 'normal'},
    {c: '<B>E</B>', tclass: 'normal'},
    {c: '<B>F</B>', krn: {'111': -0.0833, '101': -0.0833, '117': -0.0833, '114': -0.0833, '97': -0.0833, '65': -0.111, '79': -0.0278, '67': -0.0278, '71': -0.0278, '81': -0.0278}, tclass: 'normal'},
    {c: '<B>G</B>', tclass: 'normal'},
    {c: '<B>H</B>', tclass: 'normal'},
    {c: '<B>I</B>', krn: {'73': 0.0278}, tclass: 'normal'},
    {c: '<B>J</B>', tclass: 'normal'},
    {c: '<B>K</B>', krn: {'79': -0.0278, '67': -0.0278, '71': -0.0278, '81': -0.0278}, tclass: 'normal'},
    {c: '<B>L</B>', krn: {'84': -0.0833, '89': -0.0833, '86': -0.111, '87': -0.111}, tclass: 'normal'},
    {c: '<B>M</B>', tclass: 'normal'},
    {c: '<B>N</B>', tclass: 'normal'},
    {c: '<B>O</B>', krn: {'88': -0.0278, '87': -0.0278, '65': -0.0278, '86': -0.0278, '89': -0.0278}, tclass: 'normal'},
    // 50 - 5F
    {c: '<B>P</B>', krn: {'65': -0.0833, '111': -0.0278, '101': -0.0278, '97': -0.0278, '46': -0.0833, '44': -0.0833}, tclass: 'normal'},
    {c: '<B>Q</B>', d: 1, tclass: 'normal'},
    {c: '<B>R</B>', krn: {'116': -0.0278, '67': -0.0278, '79': -0.0278, '71': -0.0278, '85': -0.0278, '81': -0.0278, '84': -0.0833, '89': -0.0833, '86': -0.111, '87': -0.111}, tclass: 'normal'},
    {c: '<B>S</B>', tclass: 'normal'},
    {c: '<B>T</B>', krn: {'121': -0.0278, '101': -0.0833, '111': -0.0833, '114': -0.0833, '97': -0.0833, '65': -0.0833, '117': -0.0833}, tclass: 'normal'},
    {c: '<B>U</B>', tclass: 'normal'},
    {c: '<B>V</B>', ic: 0.0139, krn: {'111': -0.0833, '101': -0.0833, '117': -0.0833, '114': -0.0833, '97': -0.0833, '65': -0.111, '79': -0.0278, '67': -0.0278, '71': -0.0278, '81': -0.0278}, tclass: 'normal'},
    {c: '<B>W</B>', ic: 0.0139, krn: {'111': -0.0833, '101': -0.0833, '117': -0.0833, '114': -0.0833, '97': -0.0833, '65': -0.111, '79': -0.0278, '67': -0.0278, '71': -0.0278, '81': -0.0278}, tclass: 'normal'},
    {c: '<B>X</B>', krn: {'79': -0.0278, '67': -0.0278, '71': -0.0278, '81': -0.0278}, tclass: 'normal'},
    {c: '<B>Y</B>', ic: 0.025, krn: {'101': -0.0833, '111': -0.0833, '114': -0.0833, '97': -0.0833, '65': -0.0833, '117': -0.0833}, tclass: 'normal'},
    {c: '<B>Z</B>', tclass: 'normal'},
    {c: '<B>[</B>', d:.1, tclass: 'normal'},
    {c: '<B>&#x201C;</B>', tclass: 'normal'},
    {c: '<B>]</B>', d:.1, tclass: 'normal'},
    {c: '<B>&#x2C6;</B>', tclass: 'accent'},
    {c: '<B>&#x2D9;</B>', tclass: 'accent'},
    // 60 - 6F
    {c: '<B>&#x2018;</B>', lig: {'96': 92}, tclass: 'normal'},
    {c: '<B>a</B>', a:0, krn: {'118': -0.0278, '106': 0.0556, '121': -0.0278, '119': -0.0278}, tclass: 'normal'},
    {c: '<B>b</B>', krn: {'101': 0.0278, '111': 0.0278, '120': -0.0278, '100': 0.0278, '99': 0.0278, '113': 0.0278, '118': -0.0278, '106': 0.0556, '121': -0.0278, '119': -0.0278}, tclass: 'normal'},
    {c: '<B>c</B>', a:0, krn: {'104': -0.0278, '107': -0.0278}, tclass: 'normal'},
    {c: '<B>d</B>', tclass: 'normal'},
    {c: '<B>e</B>', a:0, tclass: 'normal'},
    {c: '<B>f</B>', ic: 0.0778, krn: {'39': 0.0778, '63': 0.0778, '33': 0.0778, '41': 0.0778, '93': 0.0778}, lig: {'105': 12, '102': 11, '108': 13}, tclass: 'normal'},
    {c: '<B>g</B>', a:0, d:1, ic: 0.0139, krn: {'106': 0.0278}, tclass: 'normal'},
    {c: '<B>h</B>', krn: {'116': -0.0278, '117': -0.0278, '98': -0.0278, '121': -0.0278, '118': -0.0278, '119': -0.0278}, tclass: 'normal'},
    {c: '<B>i</B>', tclass: 'normal'},
    {c: '<B>j</B>', d:1, tclass: 'normal'},
    {c: '<B>k</B>', krn: {'97': -0.0556, '101': -0.0278, '97': -0.0278, '111': -0.0278, '99': -0.0278}, tclass: 'normal'},
    {c: '<B>l</B>', tclass: 'normal'},
    {c: '<B>m</B>', a:0, krn: {'116': -0.0278, '117': -0.0278, '98': -0.0278, '121': -0.0278, '118': -0.0278, '119': -0.0278}, tclass: 'normal'},
    {c: '<B>n</B>', a:0, krn: {'116': -0.0278, '117': -0.0278, '98': -0.0278, '121': -0.0278, '118': -0.0278, '119': -0.0278}, tclass: 'normal'},
    {c: '<B>o</B>', a:0, krn: {'101': 0.0278, '111': 0.0278, '120': -0.0278, '100': 0.0278, '99': 0.0278, '113': 0.0278, '118': -0.0278, '106': 0.0556, '121': -0.0278, '119': -0.0278}, tclass: 'normal'},
    // 70 - 7F
    {c: '<B>p</B>', a:0, d:1, krn: {'101': 0.0278, '111': 0.0278, '120': -0.0278, '100': 0.0278, '99': 0.0278, '113': 0.0278, '118': -0.0278, '106': 0.0556, '121': -0.0278, '119': -0.0278}, tclass: 'normal'},
    {c: '<B>q</B>', a:0, d:1, tclass: 'normal'},
    {c: '<B>r</B>', a:0, tclass: 'normal'},
    {c: '<B>s</B>', a:0, tclass: 'normal'},
    {c: '<B>t</B>', krn: {'121': -0.0278, '119': -0.0278}, tclass: 'normal'},
    {c: '<B>u</B>', a:0, krn: {'119': -0.0278}, tclass: 'normal'},
    {c: '<B>v</B>', a:0, ic: 0.0139, krn: {'97': -0.0556, '101': -0.0278, '97': -0.0278, '111': -0.0278, '99': -0.0278}, tclass: 'normal'},
    {c: '<B>w</B>', a:0, ic: 0.0139, krn: {'101': -0.0278, '97': -0.0278, '111': -0.0278, '99': -0.0278}, tclass: 'normal'},
    {c: '<B>x</B>', a:0, tclass: 'normal'},
    {c: '<B>y</B>', a:0, d:1, ic: 0.0139, krn: {'111': -0.0278, '101': -0.0278, '97': -0.0278, '46': -0.0833, '44': -0.0833}, tclass: 'normal'},
    {c: '<B>z</B>', a:0, tclass: 'normal'},
    {c: '<B>&#x2013;</B>', a:.1, ic: 0.0278, lig: {'45': 124}, tclass: 'normal'},
    {c: '<B>&#x2014;</B>', a:.1, ic: 0.0278, tclass: 'normal'},
    {c: '<B>&#x2DD;</B>', tclass: 'accent'},
    {c: '<B>&#x2DC;</B>', tclass: 'accent'},
    {c: '<B>&#xA8;</B>', tclass: 'accent'}
  ]
});


/*
 *  We need to replace the jsMath.Box.TeX function in order to use the
 *  different font metrics in thie tables above, and to handle the
 *  scaling better.
 */

jsMath.Add(jsMath.Box,{
  TeX: function (c,font,style,size) {
    c = jsMath.TeX[font][c];
    if (c.h != null) {c.a = c.h-1.1*jsMath.TeX.x_height; if (c.d == 1) {c.d += .0001}}
    var box = this.Text(c.c,c.tclass,style,size,c.a,c.d);
    var scale = jsMath.Typeset.TeX(style,size).scale;
    if (c.bh != null) {
      box.bh = c.bh * scale;
      box.bd = c.bd * scale;
    } else {
      var h = box.bd+box.bh;
      var ph = Math.round(h*jsMath.em);
      if (h > jsMath.hd) {
        box.bd = c.bd = jsMath.EmBoxFor(jsMath.HTML.Class(c.tclass,c.c)
                          + '<IMG SRC="'+jsMath.blank+'" STYLE="'
                          + 'width: 1; height: '+ph+'px">').h - h;
        box.bh = h - box.bd;
      }
      c.bh = box.bh/scale;
      c.bd = box.bd/scale;
    }
    if (jsMath.msieFontBug) {
      // hack to avoid Font changing back to the default
      // font when a unicode reference is not followed
      // by a letter or number
      box.html += '<SPAN STYLE="display: none">x</SPAN>'
    }
    return box;
  }
});

jsMath.UpdateStyles({
    '.cmr10':          'font-family: serif',
    '.lucida':         'font-family: Lucida Grande',
    '.asymbol':        'font-family: Apple Symbols; font-size: 115%',
    '.cal':            'font-family: Apple Chancery',
    '.arrows':         'font-family: Hiragino Mincho Pro',
    '.arrow1':         'font-family: Hiragino Mincho Pro; position: relative; top: .075em; margin: -1px',
    '.arrow1a':        'font-family: Hiragino Mincho Pro; margin:-.3em',
    '.arrow1b':        'font-family: AppleGothic; font-size: 50%',
    '.arrow2':         'font-family: Symbol; font-size: 140%; position: relative; top: .1em; margin:-1px',
    '.arrow2a':        'font-family: Symbol',
    '.arrow2b':        'font-family: AppleGothic; font-size: 67%',
    '.harpoon':        'font-family: AppleGothic; font-size: 90%',
    '.symbol':         'font-family: Hiragino Mincho Pro',
    '.symbol2':        'font-family: Hiragino Mincho Pro; margin:-.2em',
    '.symbol3':        'font-family: AppleGothic',
    '.delim1':         'font-family: Times; font-size: 133%; position:relative; top:.75em',
    '.delim1b':        'font-family: Hiragino Mincho Pro; font-size: 133%; position:relative; top:.8em; margin: -.1em',
    '.delim1c':        'font-family: Symbol; font-size: 120%; position:relative; top:.8em;',
    '.delim2':         'font-family: Baskerville; font-size: 180%; position:relative; top:.75em',
    '.delim2b':        'font-family: Hiragino Mincho Pro; font-size: 190%; position:relative; top:.8em; margin: -.1em',
    '.delim2c':        'font-family: Symbol; font-size: 167%; position:relative; top:.8em;',
    '.delim3':         'font-family: Baskerville; font-size: 250%; position:relative; top:.725em',
    '.delim3b':        'font-family: Hiragino Mincho Pro; font-size: 250%; position:relative; top:.8em; margin: -.1em',
    '.delim3c':        'font-family: symbol; font-size: 240%; position:relative; top:.775em;',
    '.delim4':         'font-family: Baskerville; font-size: 325%; position:relative; top:.7em',
    '.delim4b':        'font-family: Hiragino Mincho Pro; font-size: 325%; position:relative; top:.8em; margin: -.1em',
    '.delim4c':        'font-family: Symbol; font-size: 300%; position:relative; top:.8em;',
    '.vertical':       'font-family: Copperplate',
    '.vertical1':      'font-family: Copperplate; font-size: 85%; margin: .15em;',
    '.vertical2':      'font-family: Copperplate; font-size: 85%; margin: .17em;',
    '.greek':          'font-family: Symbol',
    '.bigop1':         'font-family: Hiragino Mincho Pro; font-size: 133%; position: relative; top: .85em; margin:-.05em',
    '.bigop1a':        'font-family: Baskerville; font-size: 100%; position: relative; top: .775em;',
    '.bigop1b':        'font-family: Hiragino Mincho Pro; font-size: 160%; position: relative; top: .7em; margin:-.1em',
    '.bigop1c':        'font-family: Apple Symbols; font-size: 125%; position: relative; top: .75em; margin:-.1em;',
    '.bigop2':         'font-family: Hiragino Mincho Pro; font-size: 200%; position: relative; top: .8em; margin:-.07em',
    '.bigop2a':        'font-family: Baskerville; font-size: 175%; position: relative; top: .7em;',
    '.bigop2b':        'font-family: Hiragino Mincho Pro; font-size: 270%; position: relative; top: .62em; margin:-.1em',
    '.bigop2c':        'font-family: Apple Symbols; font-size: 250%; position: relative; top: .7em; margin:-.17em;',
    '.wide1':          'font-size: 67%; position: relative; top:-.8em',
    '.wide2':          'font-size: 110%; position: relative; top:-.5em',
    '.wide3':          'font-size: 175%; position: relative; top:-.32em',
    '.wide1a':         'font-size: 75%; position: relative; top:-.5em',
    '.wide2a':         'font-size: 133%; position: relative; top: -.15em',
    '.wide3a':         'font-size: 200%; position: relative; top: -.05em',
    '.root':           'font-family: Baskerville;',
    '.accent':         'position: relative; top: .02em'
});

/*
 *  Check for ability to access Apple Symbols font
 */

jsMath.noAppleSymbols =  (jsMath.BBoxFor('&#x2223;').w ==
    jsMath.BBoxFor('<SPAN STYLE="font-family: Apple Symbols">&#x2223;</SPAN>').w);

if (jsMath.noAppleSymbols) {
  jsMath.UpdateTeXfonts({
    cmsy10: {
      '16': {c: '<SPAN STYLE="position:relative;top:.25em; font-size: 67%">&#x2323;</SPAN><SPAN STYLE="position:relative;top:-.15em;font-size:67%;margin-left:-1em">&#x2322;</SPAN>', tclass: 'normal'},
      '22': {c: '&#x227A;<SPAN STYLE="position:relative;top:.3em; margin-left:-1em">&mdash;</SPAN>', tclass: 'normal'},
      '23': {c: '&#x227B;<SPAN STYLE="position:relative;top:.3em; margin-left:-1em">&mdash;</SPAN>', tclass: 'normal'},
      '91': {c: '&#x222A;'},
      '92': {c: '&#x2229;'},
      '93': {c: '&#x222A;<SPAN STYLE="font-size: 50%; margin-left:-1.1em; position: relative; top:-.3em; margin-right:.4em">+</SPAN>'},
      '94': {c: '&#x2227;'},
      '95': {c: '&#x2228;'},
      '96': {c: '|<SPAN STYLE="position:relative; top:-.15em; margin-left:-.1em">&ndash;</SPAN>', tclass: 'normal'},
      '109': {c: '&#x21D1;<SPAN STYLE="position:relative; top:.1em; margin-left:-.6em">&#x21D3;</SPAN>', h:.9, d:.2, tclass: 'arrow2a'}
    },
    
    cmex10: {
      '85': {c: '&#x222A;<SPAN STYLE="font-size: 50%; margin-left:-1.1em; position: relative; top:-.3em; margin-right:.4em">+</SPAN>'},
      '93': {c: '&#x222A;<SPAN STYLE="font-size: 50%; margin-left:-1.1em; position: relative; top:-.3em; margin-right:.4em">+</SPAN>'}
    }
  });

  jsMath.Macro('rightleftharpoons','\\unicode{x21CC}');
} else {
  jsMath.UpdateStyles({
    '.harpoon':   'font-family: Apple Symbols; font-size: 125%'
  });
  
}


//
//  Adjust for OmniWeb
//
if (navigator.accentColorName) {
  jsMath.UpdateTeXfonts({
    cmsy10: {
      '55':  {c: '<SPAN STYLE="font-size: 75%; position:relative; left:.3em; top:-.15em; margin-left:-.3em">&#x02EB;</SPAN>'},
      '104': {c: '<SPAN STYLE="position:relative; top:.2em; margin-left:-.55em">&#x3008;</SPAN>'},
      '105': {c: '<SPAN STYLE="position:relative; top:.2em; margin-right:-.55em">&#x3009;</SPAN>'}
    }
  });
  
  jsMath.UpdateStyles({
    '.arrow2':   'font-family: Symbol; font-size: 100%; position: relative; top: -.1em; margin:-1px'
  });
  
  if (jsMath.noAppleSymbols) {
    jsMath.UpdateTeXfonts({
      cmsy10: {
        '22': {c: '&#x227A;<SPAN STYLE="position:relative;top:.25em; margin-left:-.8em; margin-right:.2em">&ndash;</SPAN>', tclass: 'normal'},
        '23': {c: '&#x227B;<SPAN STYLE="position:relative;top:.25em; margin-left:-.7em; margin-right:.1em">&ndash;</SPAN>', tclass: 'normal'},
        '96': {c: '<SPAN STYLE="font-size:80%; position:relative; top:-.15em">|</SPAN><SPAN STYLE="position:relative; top:-.1em; margin-left:-.1em">&ndash;</SPAN>', tclass: 'normal'}
      }
    });
  }
  
}

//
//  Check for Mozilla
//
if (jsMath.hidden.ATTRIBUTE_NODE) {
  document.writeln('<SCRIPT SRC="'+jsMath.root+'jsMath-fallback-mac-mozilla.js"></SCRIPT>');
}
//
//  Check for MSIE
//
if (jsMath.spanHeightVaries) {
  document.writeln('<SCRIPT SRC="'+jsMath.root+'jsMath-fallback-mac-msie.js"></SCRIPT>');
}


/*
 *  Reinstall Styles and fonts
 */

jsMath.InitStyles();
jsMath.InitTeXfonts();

/*
 *  No access to TeX "not" character, so fake this
 */
jsMath.Macro('not','\\mathrel{\\rlap{\\kern 4mu/}}');


jsMath.absoluteHeightVaries = 1;

jsMath.defaultH = 0.8;