/*
 *  jsMath-fallback-mac-msie.js
 *  
 *  Part of the jsMath package for mathematics on the web.
 *
 *  This file makes changes needed by Internet Explorer on the Mac
 *  for when the TeX fonts are not available.
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
 *  Fix the default non-TeX-font characters to work with MSIE
 *
 */

jsMath.UpdateTeXfonts({
  cmr10: {
    '0':  {c: 'G', tclass: 'greek'},
    '1':  {c: 'D', tclass: 'greek'},
    '2':  {c: 'Q', tclass: 'greek'},
    '3':  {c: 'L', tclass: 'greek'},
    '4':  {c: 'X', tclass: 'greek'},
    '5':  {c: 'P', tclass: 'greek'},
    '6':  {c: 'S', tclass: 'greek'},
    '7':  {c: '&#161;', tclass: 'greek'},
    '8':  {c: 'F', tclass: 'greek'},
    '9':  {c: 'Y', tclass: 'greek'},
    '10': {c: 'W', tclass: 'greek'},
    '22': {c: '<SPAN STYLE="position:relative; top:.1em">&#96;</SPAN>', tclass: 'symbol3'}
  },
  
  cmti10: {
    '0':  {c: '<I>G</I>', tclass: 'greek'},
    '1':  {c: '<I>D</I>', tclass: 'greek'},
    '2':  {c: '<I>Q</I>', tclass: 'greek'},
    '3':  {c: '<I>L</I>', tclass: 'greek'},
    '4':  {c: '<I>X</I>', tclass: 'greek'},
    '5':  {c: '<I>P</I>', tclass: 'greek'},
    '6':  {c: '<I>S</I>', tclass: 'greek'},
    '7':  {c: '<I>&#161;</I>', tclass: 'greek'},
    '8':  {c: '<I>F</I>', tclass: 'greek'},
    '9':  {c: '<I>Y</I>', tclass: 'greek'},
    '10': {c: '<I>W</I>', tclass: 'greek'},
    '22': {c: '<SPAN STYLE="position:relative; top:.1em">&#96;</SPAN>', tclass: 'symbol3'}
  },
  
  cmbx10: {
    '0':  {c: '<B>G</B>', tclass: 'greek'},
    '1':  {c: '<B>D</B>', tclass: 'greek'},
    '2':  {c: '<B>Q</B>', tclass: 'greek'},
    '3':  {c: '<B>L</B>', tclass: 'greek'},
    '4':  {c: '<B>X</B>', tclass: 'greek'},
    '5':  {c: '<B>P</B>', tclass: 'greek'},
    '6':  {c: '<B>S</B>', tclass: 'greek'},
    '7':  {c: '<B>&#161;</B>', tclass: 'greek'},
    '8':  {c: '<B>F</B>', tclass: 'greek'},
    '9':  {c: '<B>Y</B>', tclass: 'greek'},
    '10': {c: '<B>W</B>', tclass: 'greek'},
    '22': {c: '<SPAN STYLE="position:relative; top:.1em">&#96;</SPAN>', tclass: 'symbol3'}
  },
  cmmi10: {
    '0':  {c: '<I>G</I>', tclass: 'greek'},
    '1':  {c: '<I>D</I>', tclass: 'greek'},
    '2':  {c: '<I>Q</I>', tclass: 'greek'},
    '3':  {c: '<I>L</I>', tclass: 'greek'},
    '4':  {c: '<I>X</I>', tclass: 'greek'},
    '5':  {c: '<I>P</I>', tclass: 'greek'},
    '6':  {c: '<I>S</I>', tclass: 'greek'},
    '7':  {c: '<I>&#161;</I>', tclass: 'greek'},
    '8':  {c: '<I>F</I>', tclass: 'greek'},
    '9':  {c: '<I>Y</I>', tclass: 'greek'},
    '10': {c: '<I>W</I>', tclass: 'greek'},
    '11': {c: 'a', tclass: 'greek'},
    '12': {c: 'b', tclass: 'greek'},
    '13': {c: 'g', tclass: 'greek'},
    '14': {c: 'd', tclass: 'greek'},
    '15': {c: 'e', tclass: 'greek'},
    '16': {c: 'z', tclass: 'greek'},
    '17': {c: 'h', tclass: 'greek'},
    '18': {c: 'q', tclass: 'greek'},
    '19': {c: 'i', tclass: 'greek'},
    '20': {c: 'k', tclass: 'greek'},
    '21': {c: 'l', tclass: 'greek'},
    '22': {c: 'm', tclass: 'greek'},
    '23': {c: 'n', tclass: 'greek'},
    '24': {c: 'x', tclass: 'greek'},
    '25': {c: 'p', tclass: 'greek'},
    '26': {c: 'r', tclass: 'greek'},
    '27': {c: 's', tclass: 'greek'},
    '28': {c: 't', tclass: 'greek'},
    '29': {c: 'u', tclass: 'greek'},
    '30': {c: 'f', tclass: 'greek'},
    '31': {c: 'c', tclass: 'greek'},
    '32': {c: 'y', tclass: 'greek'},
    '33': {c: 'w', tclass: 'greek'},
//  '41':  // leftharpoondown
//  '43':  // rightharpoondown   
//  '44':  // hook left
//  '45':  // hook right 
//  '92':  // natural
    '94': {c: '<SPAN STYLE="position:relative; top:.3em">&#xFE36;</SPAN>'},
    '95': {c: '<SPAN STYLE="position:relative; top:-.2em">&#xFE35;</SPAN>'}
//  '127': // half-circle down accent?
  },

  cmsy10: {
    '0':  {c: '&ndash;', tclass: 'normal'},
    '11': {c: '<SPAN STYLE="font-size: 70%">&#x25EF;</SPAN><SPAN STYLE="position:relative; margin-left:-.5em; top:.1em; margin-right:.3em">/</SPAN>', tclass: 'normal'},
    '16': {c: '<SPAN STYLE="position:relative;top:-.1em; font-size: 67%">&#xFE35;</SPAN><SPAN STYLE="position:relative;top:.1em;font-size:67%;margin-left:-1em">&#xFE36;</SPAN>', tclass: 'normal'},
    '48': {c: '<SPAN STYLE="font-size: 133%; margin-left:-.1em; margin-right: -.6em; position: relative; top:.4em">&#x2032;</SPAN>'},
    '93': {c: '&#x222A;<SPAN STYLE="font-size: 50%; margin-left:-1.3em; position: relative; top:-.3em; margin-right:.6em">+</SPAN>'},
    '96': {c: '<SPAN STYLE="font-size:67%; position:relative; top:-.3em;">|</SPAN><SPAN STYLE="position:relative; top:-.15em; margin-left:-.1em">&ndash;</SPAN>', tclass: 'normal'},
    '104': {c: '<SPAN STYLE="position:relative; top:.2em; margin-left:-.6em">&#x3008;</SPAN>'},
    '105': {c: '<SPAN STYLE="position:relative; top:.2em; margin-right:-.6em">&#x3009;</SPAN>'},
    '109': {c: '&#x21D1;<SPAN STYLE="position:relative; top:.1em; margin-left:-1em">&#x21D3;</SPAN>'},
    '110': {c: '\\', d:0, tclass: 'normal'}
//  '111': // wr
//, '113': // amalg
//  '116': // sqcup
//  '117': // sqcap
//  '118': // sqsubseteq
//  '119': // sqsupseteq
  },

  cmex10: {
    '10': {c: '<SPAN STYLE="position:relative; top:.1em; margin-left:-.6em">&#x3008;</SPAN>'},
    '11': {c: '<SPAN STYLE="position:relative; top:.1em; margin-right:-.6em">&#x3009;</SPAN>'},
    '14': {c: '/'}, '15': {c: '\\'},
    '28': {c: '<SPAN STYLE="position:relative; top:.05em; margin-left:-.6em">&#x3008;</SPAN>'},
    '29': {c: '<SPAN STYLE="position:relative; top:.05em; margin-right:-.6em">&#x3009;</SPAN>'},
    '30': {c: '/'}, '31': {c: '\\'},
    '42': {c: '<SPAN STYLE="margin-left:-.6em">&#x3008;</SPAN>'},
    '43': {c: '<SPAN STYLE="margin-right:-.6em">&#x3009;</SPAN>'},
    '44': {c: '/'}, '45': {c: '\\'},
    '46': {c: '/'}, '47': {c: '\\'},
    '68': {c: '<SPAN STYLE="margin-left:-.6em">&#x3008;</SPAN>'},
    '69': {c: '<SPAN STYLE="margin-right:-.6em">&#x3009;</SPAN>'},
//  '70':  // sqcup
//  '71':  // big sqcup
    '72': {ic: 0},  '73': {ic: 0},
    '82': {tclass: 'bigop1cx', ic: .15}, '90': {tclass: 'bigop2cx', ic:.6},
    '85': {c: '&#x222A;<SPAN STYLE="font-size: 50%; margin-left:-1.25em; position: relative; top:-.3em; margin-right:.6em">+</SPAN>'},
    '93': {c: '&#x222A;<SPAN STYLE="font-size: 50%; margin-left:-1.25em; position: relative; top:-.3em; margin-right:.6em">+</SPAN>'},
//  '96': // coprod
//  '97': // big coprod
    '98': {c: '&#xFE3F;', h: 0.722, w: .58, tclass: 'wide1'},
    '99': {c: '&#xFE3F;', h: 0.722, w: .58, tclass: 'wide2'},
    '100': {c: '&#xFE3F;', h: 0.722, w: .58, tclass: 'wide3'},
    '101': {c: '~', h: 0.722, w: .42, tclass: 'wide1a'},
    '102': {c: '~', h: 0.8, w: .73, tclass: 'wide2a'},
    '103': {c: '~', h: 0.8, w: 1.1, tclass: 'wide3a'}
  }

});

jsMath.UpdateStyles({
  '.arrow1':  'font-family: Osaka; position: relative; top: .125em; margin: -1px',
  '.arrow2':  'font-family: Osaka; position: relative; top: .1em; margin:-1px',
  '.bigop1':  'font-family: Symbol; font-size: 110%; position:relative; top: .8em; margin:-.05em',
  '.bigop1b': 'font-family: Symbol; font-size: 140%; position: relative; top: .8em; margin:-.1em',
  '.bigop1c': 'font-family: Osaka; font-size: 125%; position:relative; top: .85em; margin:-.3em',
  '.bigop1cx':'font-family: Apple Chancery; font-size: 125%; position:relative; top: .7em; margin:-.1em',
  '.bigop2':  'font-family: Symbol; font-size: 175%; position:relative; top: .8em; margin:-.07em',
  '.bigop2a': 'font-family: Baskerville; font-size: 175%; position: relative; top: .65em',
  '.bigop2b': 'font-family: Symbol; font-size: 175%; position: relative; top: .8em; margin:-.07em',
  '.bigop2c': 'font-family: Osaka; font-size: 230%; position:relative; top: .85em; margin:-.35em',
  '.bigop2cx':'font-family: Apple Chancery; font-size: 250%; position:relative; top: .6em; margin-left:-.1em; margin-right:-.2em',
  '.delim1b': 'font-family: Times; font-size: 150%; position:relative; top:.8em',
  '.delim2b': 'font-family: Times; font-size: 210%; position:relative; top:.75em;',
  '.delim3b': 'font-family: Times; font-size: 300%; position:relative; top:.7em;',
  '.delim4b': 'font-family: Times; font-size: 400%; position:relative; top:.65em;',
  '.symbol3': 'font-family: Symbol',
  '.wide1':   'font-size: 50%; position: relative; top:-1.1em',
  '.wide2':   'font-size: 80%; position: relative; top:-.7em',
  '.wide3':   'font-size: 125%; position: relative; top:-.5em',
  '.wide1a':  'font-size: 75%; position: relative; top:-.5em',
  '.wide2a':  'font-size: 133%; position: relative; top: -.15em',
  '.wide3a':  'font-size: 200%; position: relative; top: -.05em',
  '.greek':   'font-family: Symbol'
});

jsMath.InitStyles();

