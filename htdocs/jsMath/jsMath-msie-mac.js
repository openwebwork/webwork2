/*
 *  jsMath-msie-mac.js
 *  
 *  Part of the jsMath package for mathematics on the web.
 *
 *  This file makes changes needed for use with MSIE on the Mac.
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
 *  Mac MSIE has problems accessing a number of the characters in
 *  the TeX fonts, so we replace them by other characters when
 *  possible.
 */

jsMath.UpdateTeXfonts({

  cmr10: {
    '3':  {c: '<FONT FACE="Symbol">L</FONT>', tclass: 'normal'},
    '5':  {c: '<FONT FACE="Symbol">P</FONT>', tclass: 'normal'},
    '10': {c: '<FONT FACE="Symbol">W</FONT>', tclass: 'normal'},
    '16': {c: '&#x0131;', tclass: 'normal'},
    '20': {c: '&#xAD;'},
    '22': {c: '&#xAF;', tclass: 'normal', w: .3},
    '25': {c: '&#xDF;', tclass: 'normal'},
    '26': {c: '&#xE6;', tclass: 'normal'},
    '27': {c: '&#x153;', tclass: 'normal'}
  },

  cmmi10: {
    '3':  {c: '<I><FONT FACE="Symbol">L</FONT></I>', tclass: 'normal'},
    '5':  {c: '<I><FONT FACE="Symbol">P</FONT></I>', tclass: 'normal'},
    '10': {c: '<I><FONT FACE="Symbol">W</FONT></I>', tclass: 'normal'},
    '15': {c: '<I><FONT FACE="Symbol">e</FONT></I>', tclass: 'normal'},
    '16': {c: '<I><FONT FACE="Symbol">z</FONT></I>', tclass: 'normal'},
    '20': {c: '<I><FONT FACE="Symbol">k</FONT></I>', tclass: 'normal'},
    '22': {c: '<I><FONT FACE="Symbol">m</FONT></I>', tclass: 'normal'},
    '25': {c: '<I><FONT FACE="Symbol">p</FONT></I>', tclass: 'normal'},
    '26': {c: '<I><FONT FACE="Symbol">r</FONT></I>', tclass: 'normal'},
    '27': {c: '<I><FONT FACE="Symbol">s</FONT></I>', tclass: 'normal'}
  },

  cmsy10: {
    '3':  {c: '<SPAN STYLE="vertical-align:-.3em">*</SPAN>', tclass: 'normal'},
    '5':  {c: '&#x389;', tclass: 'normal'},
    '10': {c: '&otimes;', tclass: 'normal'},
    '15': {c: '&#x2022;', tclass: 'normal'},
    '16': {c: '&#x224D;', tclass: 'normal'},
    '20': {c: '&le;', tclass: 'normal'},
    '22': {c: '&le;', tclass: 'normal'},
    '25': {c: '&#x2248;', tclass: 'normal'},
    '26': {c: '<FONT FACE="Symbol">&#xCC;</FONT>', tclass: 'normal'},
    '27': {c: '<FONT FACE="Symbol">&#xC9;</FONT>', tclass: 'normal'}
  },

  cmex10: {
    '3':  {c: '<SPAN STYLE="font-size: 67%">&#x69;</SPAN>'},
    '5':  {c: '<SPAN STYLE="font-size: 67%">&#x6B;</SPAN>'},
    '10': {c: '<SPAN STYLE="font-size: 67%">&#x44;</SPAN>'},
    '15': {c: '<SPAN STYLE="font-size: 55%">&#xC2;</SPAN>'},
    '16': {c: '<SPAN STYLE="font-size: 83%">&#xB5;</SPAN>'},
    '20': {c: '<SPAN STYLE="font-size: 83%">"</SPAN>'},
    '22': {c: '<SPAN STYLE="font-size: 83%">$</SPAN>'},
    '25': {c: '<SPAN STYLE="font-size: 83%">\'</SPAN>'},
    '26': {c: '<SPAN STYLE="font-size: 83%">(</SPAN>'},
    '27': {c: '<SPAN STYLE="font-size: 83%">)</SPAN>'}
  },

  cmti10: {
    '3':  {c: '<I><FONT FACE="Symbol">L</FONT></I>', tclass: 'normal'},
    '5':  {c: '<I><FONT FACE="Symbol">P</FONT></I>', tclass: 'normal'},
    '10': {c: '<I><FONT FACE="Symbol">W</FONT></I>', tclass: 'normal'},
    '16': {c: '<I>&#x0131;</I>', tclass: 'normal'},
    '20': {c: '<I>&#xAD;</I>'},
    '22': {c: '<I>&#xAF;</I>', tclass: 'normal', w: .3},
    '25': {c: '<I>&#xDF;</I>', tclass: 'normal'},
    '26': {c: '<I>&#xE6;</I>', tclass: 'normal'},
    '27': {c: '<I>&#x153;</I>', tclass: 'normal'}
  },

  cmbx10: {
    '3':  {c: '<B><FONT FACE="Symbol">L</FONT></B>', tclass: 'normal'},
    '5':  {c: '<B><FONT FACE="Symbol">P</FONT></B>', tclass: 'normal'},
    '10': {c: '<B><FONT FACE="Symbol">W</FONT></B>', tclass: 'normal'},
    '16': {c: '<B>&#x0131;</B>', tclass: 'normal'},
    '20': {c: '<B>&#xAD;</B>'},
    '22': {c: '<B>&#xAF;</B>', tclass: 'normal', w: .3},
    '25': {c: '<B>&#xDF;</B>', tclass: 'normal'},
    '26': {c: '<B>&#xE6;</B>', tclass: 'normal'},
    '27': {c: '<B>&#x153;</B>', tclass: 'normal'}
  }
});

/*
 *  MSIE crashes if it changes the page too quickly, so we add a
 *  delay between processing math entries.  Unfortunately, this really
 *  slows down math in MSIE on the mac.
 */

jsMath.Add(jsMath,{

  msieProcess: jsMath.Process,
  msieProcessBeforeShowing: jsMath.ProcessBeforeShowing,

  Process: function () {
    // we need to delay a bit before starting to process the page
    //   in order to avoid an MSIE display bug
    setTimeout('jsMath.msieProcess()',jsMath.delay);
  },

  ProcessBeforeShowing: function () {
    // we need to delay a bit before starting to process the page
    //   in order to avoid an MSIE display bug
    window.status = "Processing Math...";
    setTimeout('jsMath.msieProcessBeforeShowing()',5*jsMath.delay);
  }

});

jsMath.delay = 50;  // hope this is enogh of a delay!

