/*
 *  jsMath-fallback-mac-mozzilla.js
 *  
 *  Part of the jsMath package for mathematics on the web.
 *
 *  This file makes changes needed by Mozilla-based browsers on the Mac
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
 *  Fix the default non-TeX-font characters to work with Mozilla
 *
 */

jsMath.UpdateTeXfonts({
  cmmi10: {
//  '41':  // leftharpoondown
//  '43':  // rightharpoondown    
    '44': {c: '<SPAN STYLE="position:relative; top:.15em; margin-right:-.1em; margin-left:-.2em">&#x02D3;</SPAN>'},
    '45': {c: '<SPAN STYLE="position:relative; top:.15em; margin-right:-.1em; margin-left:-.2em">&#x02D2;</SPAN>'},
    '47': {c: '<SPAN STYLE="font-size:60%">&#x25C1;</SPAN>'},
//  '92':  // natural
    '126': {c: '<SPAN STYLE="position:relative; left: .3em; top: -.7em; font-size: 50%">&#x2192;</SPAN>'}
  },

  cmsy10: {
    '0':  {c: '&ndash;', tclass: 'normal'},
    '11': {c: '<SPAN STYLE="font-size: 70%">&#x25EF;</SPAN><SPAN STYLE="position:relative; margin-left:-.5em; top:.1em; margin-right:.3em">/</SPAN>', tclass: 'normal'},
    '42': {c: '&#x2963;'}, '43': {c: '&#x2965'},
    '48': {c: '<SPAN STYLE="font-size: 133%; margin-right: -.75em; position: relative; top:.4em">&#x2032;</SPAN>', tclass: 'normal'},
    '93': {c: '&#x222A;<SPAN STYLE="font-size: 50%; margin-left:-1.3em; position: relative; top:-.3em; margin-right:.6em">+</SPAN>'},
    '104': {c: '<SPAN STYLE="position:relative; top:.15em; margin-left:-.6em">&#x3008;</SPAN>'},
    '105': {c: '<SPAN STYLE="position:relative; top:.15em; margin-right:-.6em">&#x3009;</SPAN>'},
    '109': {c: '&#x2963;<SPAN STYLE="position:relative; top:.1em; margin-left:-1em">&#x2965;</SPAN>'}
//, '116':  // sqcup
//  '117':  // sqcap
//  '118':  // sqsubseteq
//  '119':  // sqsupseteq
  },
  
  cmex10: {
    '10': {c: '<SPAN STYLE="position:relative; top:.1em; margin-left:-.6em">&#x3008;</SPAN>'},
    '11': {c: '<SPAN STYLE="position:relative; top:.1em; margin-right:-.6em">&#x3009;</SPAN>'},
    '14': {c: '/'}, '15': {c: '\\'},
    '28': {c: '<SPAN STYLE="position:relative; top:.1em; margin-left:-.6em">&#x3008;</SPAN>'},
    '29': {c: '<SPAN STYLE="position:relative; top:.1em; margin-right:-.6em">&#x3009;</SPAN>'},
    '30': {c: '/'}, '31': {c: '\\'},
    '42': {c: '<SPAN STYLE="position:relative; top:.1em; margin-left:-.6em">&#x3008;</SPAN>'},
    '43': {c: '<SPAN STYLE="position:relative; top:.1em; margin-right:-.6em">&#x3009;</SPAN>'},
    '44': {c: '/'}, '45': {c: '\\'},
    '46': {c: '/'}, '47': {c: '\\'},
    '68': {c: '<SPAN STYLE="position:relative; top:.1em; margin-left:-.6em">&#x3008;</SPAN>'},
    '69': {c: '<SPAN STYLE="position:relative; top:.1em; margin-right:-.6em">&#x3009;</SPAN>'},
//  '70':  // sqcup
//  '71':  // big sqcup
    '72': {ic: .194},  '73': {ic: .444},
    '82': {tclass: 'bigop1cx', ic: .15}, '90': {tclass: 'bigop2cx', ic:.6},
    '85': {c: '&#x222A;<SPAN STYLE="font-size: 50%; margin-left:-1.3em; position: relative; top:-.3em; margin-right:.6em">+</SPAN>'},
    '93': {c: '&#x222A;<SPAN STYLE="font-size: 50%; margin-left:-1.3em; position: relative; top:-.3em; margin-right:.6em">+</SPAN>'}
  }
  
});

jsMath.UpdateStyles({
  '.symbol':  'font-family: Osaka',
  '.arrow1':  'font-family: Osaka; position: relative; top: .125em; margin: -1px',
  '.arrow2':  'font-family: AppleGothic; font-size: 100%; position:relative; top: .11em; margin:-1px',
  '.bigop1':  'font-family: AppleGothic; font-size: 110%; position:relative; top: .9em; margin:-.05em',
  '.bigop1b': 'font-family: Osaka; font-size: 140%; position: relative; top: .8em; margin:-.1em',
  '.bigop1c': 'font-family: AppleGothic; font-size: 125%; position:relative; top: .85em; margin:-.3em',
  '.bigop1cx':'font-family: Apple Chancery; font-size: 125%; position:relative; top: .7em; margin:-.1em',
  '.bigop2':  'font-family: AppleGothic; font-size: 175%; position:relative; top: .85em; margin:-.1em',
  '.bigop2b': 'font-family: Osaka; font-size: 200%; position: relative; top: .75em; margin:-.15em',
  '.bigop2c': 'font-family: AppleGothic; font-size: 300%; position:relative; top: .75em; margin:-.35em',
  '.bigop2cx':'font-family: Apple Chancery; font-size: 250%; position:relative; top: .7em; margin-left:-.1em; margin-right:-.2em',
  '.delim1b': 'font-family: Times; font-size: 150%; position:relative; top:.8em; margin:.01em',
  '.delim2b': 'font-family: Times; font-size: 210%; position:relative; top:.8em; margin:.01em',
  '.delim3b': 'font-family: Times; font-size: 300%; position:relative; top:.75em; margin:.01em',
  '.delim4b': 'font-family: Times; font-size: 400%; position:relative; top:.725em; margin:.01em',
});


/*
 *  replace \not and \joinrel with better dimensions
 */

jsMath.Macro('not','\\mathrel{\\rlap{\\kern 3mu/}}');
jsMath.Macro('joinrel','\\mathrel{\\kern-3mu}');


/*
 *  Reinstall the styles
 */

jsMath.InitStyles();

