/*****************************************************************************
 * 
 *  jsMath: Mathematics on the Web
 *  
 *  Version: 1.2ww
 *  
 *  This jsMath package makes it possible to display mathematics in HTML pages
 *  that are viewable by a wide range of browsers on both the Mac and the IBM PC,
 *  including browsers that don't process MathML.  See
 *  
 *            http://www.math.union.edu/locate/jsMath
 *
 *  for the latest version, and for documentation on how to use jsMath.
 * 
 *  Copyright (c) 2004 by Davide P. Cervone.
 *
 *  This program is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU General Public License
 *  as published by the Free Software Foundation; either version 2
 *  of the License.
 *  
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *  
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 *  
 *****************************************************************************/

/*
 *  Prevent running everything again if this file is loaded twice
 */
if (window.jsMath) {

  /*
   *  We've been loaded a second time, so we want to do asynchronous
   *  processing instead.
   *
   *  First, mark that we have made the patches, and that we aren't
   *  processing math at the moment.
   *  Save a copy of the original ProcessComplete function,
   *   and replace ProcessComplete with on that does the old
   *   function, then looks for more math to process.  If there
   *   is some, continue processing, otherwise say we are done.
   *
   *  Now make ProcessBeforeShowing check to see if we
   *    are already processing (in which case, we'll keep doing so
   *    until there is no more math), otherwise,
   *    start processing the math.
   */
  if (!jsMath.WW_patched) {
    jsMath.WW_patched = 1;
    jsMath.isProcessing = 0;

    jsMath.OldProcessComplete = jsMath.ProcessComplete;

    jsMath.ProcessComplete = function () {
      jsMath.OldProcessComplete();
      jsMath.element = jsMath.GetMathElements();
      if (jsMath.element.length > 0) {
        window.status = 'Processing Math...';
	setTimeout('jsMath.ProcessElements(0)',jsMath.delay);
      } else {
        jsMath.isProcessing = 0;
      }
    }

    jsMath.ProcessBeforeShowing = function () {
      if (!jsMath.isProcessing) {
        jsMath.isProcessing = 1;
	jsMath.Process();
      }
    }

  }

} else {

//
// debugging routine
// 
function ShowObject (obj,spaces) {
  var s = ''; if (!spaces) {spaces = ""}
  for (var i in obj) {
    if (obj[i] != null) {
      if (typeof(obj[i]) == "object") {
        s += spaces + i + ": {\n"
          + ShowObject(obj[i],spaces + '  ')
          + spaces + "}\n";
      } else if (typeof(obj[i]) != "function") {
        s += spaces + i + ': ' + obj[i] + "\n";
      }
    }
  }
  return s;
}

/***************************************************************************/
//
//  Check for DOM support
//
if (!document.getElementById || !document.childNodes || !document.createElement) {
  alert('The mathematics on this page requires W3C DOM support in its JavaScript. '
      + 'Unfortunately, your browser doesn\'t seem to have this.');
} else {

/***************************************************************************/

var jsMath = {

  //
  //  Name of image files
  //
  blank: "blank.gif",
  black: "black.gif",
  
  //
  //  The TeX font parameters
  //
  TeX: {
    thinmuskip:   3/18,
    medmuskip:    4/18,
    thickmuskip:  5/18,

    x_height:    .430554,
    quad:        1,
    num1:        .676508,
    num2:        .393732,
    num3:        .44373,
    denom1:      .685951,
    denom2:      .344841,
    sup1:        .412892,
    sup2:        .362892,
    sup3:        .288888,
    sub1:        .15,
    sub2:        .247217,
    sup_drop:    .386108,
    sub_drop:    .05,
    delim1:     2.39,
    delim2:     1.0             + .1,  //  just a bit bigger
    axis_height: .25,
    default_rule_thickness: .04,
    big_op_spacing1:  .111111   - .1,  //  a little less space here
    big_op_spacing2:  .166666   - .05, //
    big_op_spacing3:  .2        - .1,  //
    big_op_spacing4:  .6        - .05, //
    big_op_spacing5:  .1        - .025, //

    integer:          6553.6,     // conversion of em's to TeX internal integer
    scriptspace:         .05,
    nulldelimiterspace:  .12,
    delimiterfactor:     901,
    delimitershortfall:  .5
  },
  TeXscript: {}, TeXscriptscript: {},
  
  allowAbsolute: 1,    // tells if browser can nest absolutely positioned
                       //   SPANs inside relative SPANs
  absoluteOffsetY: -.05,   // height adjustment when absolute position is used
  allowAbsoluteDelim: 0,
  renameOK: 1,         // tells if brower will find a tag whose name
                       //   has been set via setAttributes
  separateNetgativeSkips: 0,  // MSIE doesn't do negative left margins
  noEmptySpans: 0,            // empty spans are/aren't allowed
  lineH: 1,                   // for MSIE span height adjustments

  delay: 1,       // delay for asynchronous math processing
  
  defaultH: 0,    // default height for characters with no height specified

  //
  //  Debugging flags
  //
  show: {
    BBox:           false,
    Baseline:       false,
    Top:            false
  },
  
  //
  //  The styles needed for the TeX fonts
  //
  styles: {
    '.script':         'font-size: 75%',
    '.scriptscript':   'font-size: 60%',
  
    '.cmr10':          'font-family: cmr10',
    '.cmbx10':         'font-family: cmbx10, cmr10',
    '.cmti10':         'font-family: cmti10, cmr10',
    '.cmmi10':         'font-family: cmmi10',
    '.cmsy10':         'font-family: cmsy10',
    '.cmex10':         'font-family: cmex10',
    '.arial':          'font-family: Arial unicode MS',

    '.normal':         'font-family: serif; font-style: normal; font-size: 115%',
    '.math':           'font-family: serif; font-style: normal; color: grey33; font-size: 75%',
    '.typeset':        'font-family: serif; font-style: normal; font-size: 115%',
    '.mathlink':       'text-decoration: none',
    '.mathHD':         'border-width: 0; width: 1px; margin-right: -1px',
  
    '.error':          'font-size: 10pt; font-style: italic; '
                         + 'background-color: #FFFFCC; padding: 1; '
                         + 'border-width: 1; border-style: solid; border-color: #CC0000'
  },

  
  /***************************************************************************/

  /*
   *  Get the width and height (in pixels) of an HTML string
   */
  BBoxFor: function (s) {
    this.hidden.innerHTML = s;
    var bbox = {w: this.hidden.offsetWidth, h: this.hidden.offsetHeight};
    this.hidden.innerHTML = '';    // avoid MSIE bug on the Mac
    return bbox;
  },

  /*
   *  Get the width and height (in ems) of an HTML string
   */
  EmBoxFor: function (s) {
    var bbox = this.BBoxFor(s);
    return {w: bbox.w/this.em, h: bbox.h/this.em};
  },

  /*
   *  Determine if the "top" of a <SPAN> is always at the same height
   *  or varies with the height of the rest of the line (MSIE).
   */
  TestSpanHeight: function () {
    this.hidden.innerHTML = '<SPAN><IMG SRC="'+jsMath.blank+'" STYLE="height: 2em"></SPAN>';
    var span = this.hidden.getElementsByTagName('SPAN')[0];
    var img  = this.hidden.getElementsByTagName('IMG')[0];
    this.spanHeightVaries = (span.offsetHeight == img.offsetHeight);
    this.hidden.innerHTML = '';
  },
  
  /*
   *  Determine if the NAME attribute of a tag can be changed
   *  using the setAttribute function, and then be properly
   *  returned by getElementByName.
   */
  TestRenameOK: function () {
    this.hidden.innerHTML = '<SPAN ID="jsMath.test"></SPAN>';
    var test = document.getElementById('jsMath.test');
    test.setAttribute('NAME','jsMath_test');
    this.renameOK = (document.getElementsByName('jsMath_test').length > 0);
    this.hidden.innerHTML = '';
  },
  
  /*
   *  Check for the availability of TeX fonts.  We do this by looking at
   *  the width and height of a character in the cmex10 font.  The cmex10
   *  font has depth considerably greater than most characters' widths (the
   *  whole font has the depth of the character with greatest depth).  This
   *  is not the case for most fonts, so if we can access cmex10, the
   *  height of a character should be much bigger than the width.
   *  Otherwise, if we don't have cmex10, we'll get a character in another
   *  font with normal height and width.  In this case, we insert a message
   *  pointing the user to the jsMath site, and load one of the fallback
   *  definitions.
   *  
   *  ### still need a jsMath-fallback-unix.js file ###
   */
  CheckFonts: function () {
    var wh = this.BBoxFor('<SPAN STYLE="font-family: cmex10">'+this.TeX.cmex10[1].c+'</SPAN>');
    if (wh.w*3 > wh.h || wh.h == 0) {
      this.NoFontMessage();
      if (navigator.platform == 'Win32') {
        document.writeln('<SCRIPT SRC="'+this.root+'jsMath-fallback-pc.js"></SCRIPT>');
      } else if (navigator.platform == 'MacPPC') {
        document.writeln('<SCRIPT SRC="'+this.root+'jsMath-fallback-mac.js"></SCRIPT>');
      }
      document.writeln('<SCRIPT>jsMath.AddMessage()</SCRIPT>');
    }
  },

  /*
   *  The message for when no TeX fonts.  You can eliminate this message
   *  by including
   *  
   *      <SCRIPT>jsMath.NoFontMessage = function () {}</SCRIPT>
   *
   *  in your HTML file, if you want.  Be this means the user may not know
   *  that he or she can get a better version of your page.
   */
  NoFontMessage: function () {
    document.writeln
      ('<CENTER><DIV STYLE="padding: 10; border-style: solid; border-width:3;'
      +' border-color: #DD0000; background-color: #FFF8F8; width: 75%; text-align: left">'
      +'<SMALL><FONT COLOR="#AA0000"><B>Warning:</B>\n'
      +'It looks like you don\'t have the TeX math fonts installed.\n'
      +'The mathematics on this page may not look right without them.\n'
      +'The <A HREF="http://www.math.union.edu/locate/jsMath/" TARGET="_blank">'
      +'jsMath Home Page</A> has information on how to download the\n'
      +'needed fonts.  In the meantime, we will do the best we can\n'
      +'with the fonts you have, but it may not be pretty and some equations\n'
      +'may not be rendered correctly.\n'
      +'</FONT></SMALL></DIV></CENTER><p><HR><p>');
  },
  
  // for additional browser messages
  AddMessage: function () {},

  /*
   *  Initialize jsMath.  This determines the em size, and a variety
   *  of other parameters used throughout jsMath.
   */
  Init: function() {
    this.em = this.BBoxFor('<DIV STYLE="width: 1em; height: 1em"></DIV>').w;
    var h = this.BBoxFor('x').h;    // Line height and depth to baseline
    var d = this.BBoxFor('x<IMG SRC="'+jsMath.black+'" HEIGHT="'+h+'" WIDTH="1">').h - h;
    this.h = (h-d)/this.em; this.d = d/this.em;
    this.hd = this.h + this.d;
    this.ph = h-d; this.pd = d;
    if (this.lineH == null) {this.lineH = this.h}
    
    this.InitTeXfonts();
    
    this.TeX.x_height = this.EmBoxFor('<SPAN CLASS="cmr10">M</SPAN>').w/2;
    this.TeX.M_height = this.TeX.x_height*(26/14);
    this.TeX.h = this.h; this.TeX.d = this.d; this.TeX.hd = this.hd;

    // factor for \big and its brethren
    this.p_height = (this.TeX.cmex10[0].h+this.TeX.cmex10[0].d) / .85;

    //  Fix sizes for script and scriptscript sizes
    //  ### these factors should be in a parameter somewhere ##
    for (var i in this.TeX) {
      if (typeof(this.TeX[i]) != 'object') {
        this.TeXscript[i] = .75*this.TeX[i];
        this.TeXscriptscript[i] = .6*this.TeX[i];
      }
    }
    
    this.initialized = 1;

  },

  /*
   *  Find the root URL for the jsMath files (so we can load
   *  the other .js and .gif files
   */
  InitSource: function () {
    var script = document.getElementsByTagName('SCRIPT');
    var src = script[script.length-1].getAttribute('SRC');
    if (src.match('(^|/)jsMath.js$')) {
      this.root = src.replace(/jsMath.js$/,'');
      this.blank = this.root + this.blank;
      this.black = this.root + this.black;
    }
  },
  
  /*
   *  Look up the default height and depth for the TeX fonts
   *  and set the skewchar
   */
  InitTeXfonts: function () {
    for (var i = 0; i < this.TeX.fam.length; i++) {
      if (this.TeX.fam[i]) {
        var font = this.TeX[this.TeX.fam[i]];
        var WH = this.EmBoxFor('<SPAN CLASS="'+this.TeX.fam[i]+'">'+font[65].c+'</SPAN>');
        font.hd = WH.h;
        font.d = this.EmBoxFor('<SPAN CLASS="'+this.TeX.fam[i]+'">'+ font[65].c +
          '<IMG SRC="'+jsMath.black+'" STYLE="height:'+font.hd+'em; width:1"></SPAN>').h 
          - font.hd;
        font.h = font.hd - font.d;
        font.dh = .05;
        if (i == 1) {font.skewchar = 0177} else if (i == 2) {font.skewchar = 060}
      }
    }
  },
  
  /*
   *  Test for browser characteristics, and adjust the font table
   *  to overcome specific browser bugs
   */
  InitBrowser: function () {
    this.isSafari = navigator.userAgent.match(/Safari/);
    this.TestSpanHeight();
    this.TestRenameOK();

    //
    //  Check for bug-filled Internet Explorer
    //
    if (this.spanHeightVaries) {
      if (navigator.platform == 'Win32') {
        this.UpdateTeXfonts({
          cmr10:  {'10': {c: '&Omega;', tclass: 'normal'}},
          cmmi10: {'10': {c: '<I>&Omega;</I>', tclass: 'normal'}},
          cmmi10: {'126': {c: '&#x7E;<SPAN STYLE="margin-left:.1em"></SPAN>'}},
          cmsy10: {'10': {c: '&#x2297;', tclass: 'arial'}},
          cmex10: {'10': {c: '<SPAN STYLE="font-size: 67%">D</SPAN>'}},
          cmti10: {'10': {c: '<I>&Omega;</I>', tclass: 'normal'}},
          cmbx10: {'10': {c: '<B>&Omega;</B>', tclass: 'normal'}}
        });
        this.allowAbsoluteDelim = 1;
        this.separateNegativeSkips = 1;
        this.lineH = 1.03;
        this.msieFontBug = 1; this.msieIntegralBug = 1;
	jsMath.Macro('joinrel','\\mathrel{\\kern-5mu}'),
        jsMath.Macro('longmapsto','\\mapstochar\\kern-.54em\\char{cmsy10}{0}\\joinrel\\rightarrow');
      } else if (navigator.platform == 'MacPPC') {
        document.writeln('<SCRIPT SRC="'+this.root+'jsMath-msie-mac.js"></SCRIPT>');
      }
      jsMath.Macro('not','\\mathrel{\\rlap{\\kern3mu/}}');
      jsMath.Parser.prototype.macros.angle = ['Replace','ord','<FONT FACE="Symbol">&#x8B;</FONT>','normal'];
    }

    //
    //  Look for Netscape/Mozilla (any flavor)
    //
    if (this.hidden.ATTRIBUTE_NODE) {
      if (navigator.platform == 'MacPPC') {
        this.UpdateTeXfonts({
          cmr10:  {'10': {c: '&Omega;', tclass: 'normal'}},
          cmmi10: {'10': {c: '<I>&Omega;</I>', tclass: 'normal'}},
          cmsy10: {'10': {c: '&otimes;', tclass: 'normal'}},
          cmex10: {'10': {c: '<SPAN STYLE="font-size: 67%">D</SPAN>'}},
          cmti10: {'10': {c: '<I>&Omega;</I>', tclass: 'normal'}},
          cmbx10: {'10': {c: '<B>&Omega;</B>', tclass: 'normal'}}
        });
      } else {
        document.writeln('<SCRIPT SRC="'+this.root+'jsMath-mozilla.js"></SCRIPT>');
      }
      for (var i = 0; i < this.TeX.fam.length; i++) {
        if (this.TeX.fam[i]) 
          {this.styles['.'+this.TeX.fam[i]] += '; position: relative'}
      }
      this.allowAbsoluteDelim = 1;
      this.separateSkips = 1;
      jsMath.Macro('not','\\mathrel{\\rlap{\\kern3mu/}}');
    }

    //
    //  Look for OmniWeb
    //
    if (navigator.accentColorName) {
      this.allowAbsolute = 0;
    }
    
    //
    //  Look for Opera
    //
    if (navigator.userAgent.search(" Opera ") >= 0) {
      this.isOpera = 1;
      if (navigator.platform == 'MacPPC') {
        this.UpdateTeXfonts({
          cmr10:  {
            '10': {c: '&Omega;', tclass: 'normal'},
            '20': {c: '&#x2C7;', tclass: 'normal'}
          },
          cmmi10: {
            '10': {c: '<I>&Omega;</I>', tclass: 'normal'},
            '20': {c: '&kappa;', tclass: 'normal'}
          },
          cmsy10: {
            '10': {c: '&otimes;', tclass: 'normal'},
            '20': {c: '&#x2264;', tclass: 'normal'}
          },
          cmex10: {
            '10': {c: '<SPAN STYLE="font-size: 67%">D</SPAN>'},
            '20': {c: '<SPAN STYLE="font-size: 82%">"</SPAN>'}
          },
          cmti10: {
            '10': {c: '<I>&Omega;</I>', tclass: 'normal'},
            '20': {c: '<I>&#x2C7;</I>', tclass: 'normal'}
          },
          cmbx10: {
            '10': {c: '<B>&Omega;</B>', tclass: 'normal'},
            '20': {c: '<B>&#x2C7;</B>', tclass: 'normal'}
          }
        });
      }
      this.allowAbsolute = 0;
      jsMath.delay = 10;
    }

    //
    //  Look for Safari
    //
    if (this.isSafari) {
      var version = navigator.userAgent.match("Safari/([0-9]+)")[1];
      if (version < 125) {this.allowAbsolute = 0; this.oldSafari = 1}
      for (var i = 0; i < this.TeX.fam.length; i++)
        {if (this.TeX.fam[i] != '') {this.TeX[this.TeX.fam[i]].dh = .1}}
      this.TeX.axis_height += .05;
//    this.allowAbsoluteDelim = ! this.oldSafari;
    }

    //
    // Change some routines depending on the browser
    // 
    if (this.allowAbsoluteDelim) {
      jsMath.Box.DelimExtend = jsMath.Box.DelimExtendAbsolute;
    } else {
      jsMath.Box.DelimExtend = jsMath.Box.DelimExtendRelative;
    }
    
    if (this.separateNegativeSkips) {
      jsMath.HTML.Place = jsMath.HTML.PlaceSeparateNegative;
      jsMath.Typeset.prototype.Place = jsMath.Typeset.prototype.PlaceSeparateNegative;
    } else if (this.separateSkips) {
      jsMath.HTML.Place = jsMath.HTML.PlaceSeparateSkips;
      jsMath.Typeset.prototype.Place = jsMath.Typeset.prototype.PlaceSeparateSkips;
    }
    
    if (this.noEmptySpans) {jsMath.HTML.Spacer = jsMath.HTML.SpacerImage}

  },
  
  /*
   *  Send the style definitions to the browser (these may be adjusted
   *  by the browser-specific code)
   */
  InitStyles: function () {
    document.writeln('<STYLE TYPE="text/css">');
    for (var id in this.styles)
      {document.writeln('  '+id+'  {'+this.styles[id]+'}')}
    document.writeln('</STYLE>');
  },
  
  /*
   *  Update specific parameters for a limited number of font entries
   */
  UpdateTeXfonts: function (change) {
    for (var font in change) {
      for (var code in change[font]) {
        for (var id in change[font][code]) {
          this.TeX[font][code][id] = change[font][code][id];
        }
      }
    }
  },
  
  /*
   *  Update the character code for every character in a list
   *  of fonts
   */
  UpdateTeXfontCodes: function (change) {
    for (var font in change) {
      for (var i = 0; i < change[font].length; i++) {
        this.TeX[font][i].c = change[font][i];
      }
    }
  },
  
  /*
   *  Add a collection of styles to the style list
   */
  UpdateStyles: function (styles) {
    for (var i in styles) {this.styles[i] = styles[i]}
  },

  /*
   *  Manage JavaScript objects:
   *  
   *      Add:      simply add items to an object
   *      Package:  add items to an object prototype
   */
  Add: function (obj,def) {for (var id in def) {obj[id] = def[id]}},
  Package: function (obj,def) {this.Add(obj.prototype,def)}
  
}


/***************************************************************************/

jsMath.Add(jsMath.TeX,{

  //  The TeX math atom types (see Appendix G of the TeXbook)
  atom: ['ord', 'op', 'bin', 'rel', 'open', 'close', 'punct', 'ord'],

  //  The TeX font families
  fam: ['cmr10','cmmi10','cmsy10','cmex10','cmti10','','cmbx10'],

  /*
   *  The following are the TeX font mappings and metrics.  The metric
   *  information comes directly from the TeX .tfm files, and the
   *  character mappings are for the TrueType TeX fonts.  Browser-specific
   *  adjustments are made to these tables in the InitBrowser() routine
   */
  cmr10: [
    // 00 - 0F
    {c: '&#xA1;', h: 0.683, w: 0.625},
    {c: '&#xA2;', h: 0.683, w: 0.833},
    {c: '&#xA3;', h: 0.683, w: 0.778},
    {c: '&#xA4;', h: 0.683, w: 0.694},
    {c: '&#xA5;', h: 0.683, w: 0.667},
    {c: '&#xA6;', h: 0.683, w: 0.75},
    {c: '&#xA7;', h: 0.683, w: 0.722},
    {c: '&#xA8;', h: 0.683, w: 0.778},
    {c: '&#xA9;', h: 0.683, w: 0.722},
    {c: '&#xAA;', h: 0.683, w: 0.778},
    {c: '&#xAD;', h: 0.683, w: 0.722},
    {c: '&#xAE;', h: 0.694, w: 0.583, ic: 0.0778, krn: {'39': 0.0778, '63': 0.0778, '33': 0.0778, '41': 0.0778, '93': 0.0778}, lig: {'105': 14, '108': 15}},
    {c: '&#xAF;', h: 0.694, w: 0.556},
    {c: '&#xB0;', h: 0.694, w: 0.556},
    {c: '&#xB1;', h: 0.694, w: 0.833},
    {c: '&#xB2;', h: 0.694, w: 0.833},
    // 10 - 1F
    {c: '&#xB3;', h: 0.431, w: 0.278},
    {c: '&#xB4;', h: 0.431, d: 0.194, w: 0.306},
    {c: '&#xB5;', h: 0.694, w: 0.5},
    {c: '&#xB6;', h: 0.694, w: 0.5},
    {c: '&#x2219;', h: 0.628, w: 0.5},
    {c: '&#xB8;', h: 0.694, w: 0.5},
    {c: '&#xB9;', h: 0.568, w: 0.5},
    {c: '&#xBA;', h: 0.694, w: 0.75},
    {c: '&#xBB;', d: 0.17, w: 0.444},
    {c: '&#xBC;', h: 0.694, w: 0.5},
    {c: '&#xBD;', h: 0.431, w: 0.722},
    {c: '&#xBE;', h: 0.431, w: 0.778},
    {c: '&#xBF;', h: 0.528, d: 0.0972, w: 0.5},
    {c: '&#xC0;', h: 0.683, w: 0.903},
    {c: '&#xC1;', h: 0.683, w: 1.01},
    {c: '&#xC2;', h: 0.732, d: 0.0486, w: 0.778},
    // 20 - 2F
    {c: '&#xC3;', h: 0.431, w: 0.278, krn: {'108': -0.278, '76': -0.319}},
    {c: '!', h: 0.694, w: 0.278, lig: {'96': 60}},
    {c: '"', h: 0.694, w: 0.5},
    {c: '#', h: 0.694, d: 0.194, w: 0.833},
    {c: '$', h: 0.75, d: 0.0556, w: 0.5},
    {c: '%', h: 0.75, d: 0.0556, w: 0.833},
    {c: '&#x26;', h: 0.694, w: 0.778},
    {c: '\'', h: 0.694, w: 0.278, krn: {'63': 0.111, '33': 0.111}, lig: {'39': 34}},
    {c: '(', h: 0.75, d: 0.25, w: 0.389},
    {c: ')', h: 0.75, d: 0.25, w: 0.389},
    {c: '*', h: 0.75, w: 0.5},
    {c: '+', h: 0.583, d: 0.0833, w: 0.778},
    {c: ',', h: 0.106, d: 0.194, w: 0.278},
    {c: '-', h: 0.431, w: 0.333, lig: {'45': 123}},
    {c: '.', h: 0.106, w: 0.278},
    {c: '/', h: 0.75, d: 0.25, w: 0.5},
    // 30 - 3F
    {c: '0', h: 0.644, w: 0.5},
    {c: '1', h: 0.644, w: 0.5},
    {c: '2', h: 0.644, w: 0.5},
    {c: '3', h: 0.644, w: 0.5},
    {c: '4', h: 0.644, w: 0.5},
    {c: '5', h: 0.644, w: 0.5},
    {c: '6', h: 0.644, w: 0.5},
    {c: '7', h: 0.644, w: 0.5},
    {c: '8', h: 0.644, w: 0.5},
    {c: '9', h: 0.644, w: 0.5},
    {c: ':', h: 0.431, w: 0.278},
    {c: ';', h: 0.431, d: 0.194, w: 0.278},
    {c: '&#x3C;', h: 0.5, d: 0.194, w: 0.278},
    {c: '=', h: 0.367, d: -0.133, w: 0.778},
    {c: '&#x3E;', h: 0.5, d: 0.194, w: 0.472},
    {c: '?', h: 0.694, w: 0.472, lig: {'96': 62}},
    // 40 - 4F
    {c: '@', h: 0.694, w: 0.778},
    {c: 'A', h: 0.683, w: 0.75, krn: {'116': -0.0278, '67': -0.0278, '79': -0.0278, '71': -0.0278, '85': -0.0278, '81': -0.0278, '84': -0.0833, '89': -0.0833, '86': -0.111, '87': -0.111}},
    {c: 'B', h: 0.683, w: 0.708},
    {c: 'C', h: 0.683, w: 0.722},
    {c: 'D', h: 0.683, w: 0.764, krn: {'88': -0.0278, '87': -0.0278, '65': -0.0278, '86': -0.0278, '89': -0.0278}},
    {c: 'E', h: 0.683, w: 0.681},
    {c: 'F', h: 0.683, w: 0.653, krn: {'111': -0.0833, '101': -0.0833, '117': -0.0833, '114': -0.0833, '97': -0.0833, '65': -0.111, '79': -0.0278, '67': -0.0278, '71': -0.0278, '81': -0.0278}},
    {c: 'G', h: 0.683, w: 0.785},
    {c: 'H', h: 0.683, w: 0.75},
    {c: 'I', h: 0.683, w: 0.361, krn: {'73': 0.0278}},
    {c: 'J', h: 0.683, w: 0.514},
    {c: 'K', h: 0.683, w: 0.778, krn: {'79': -0.0278, '67': -0.0278, '71': -0.0278, '81': -0.0278}},
    {c: 'L', h: 0.683, w: 0.625, krn: {'84': -0.0833, '89': -0.0833, '86': -0.111, '87': -0.111}},
    {c: 'M', h: 0.683, w: 0.917},
    {c: 'N', h: 0.683, w: 0.75},
    {c: 'O', h: 0.683, w: 0.778, krn: {'88': -0.0278, '87': -0.0278, '65': -0.0278, '86': -0.0278, '89': -0.0278}},
    // 50 - 5F
    {c: 'P', h: 0.683, w: 0.681, krn: {'65': -0.0833, '111': -0.0278, '101': -0.0278, '97': -0.0278, '46': -0.0833, '44': -0.0833}},
    {c: 'Q', h: 0.683, d: 0.194, w: 0.778},
    {c: 'R', h: 0.683, w: 0.736, krn: {'116': -0.0278, '67': -0.0278, '79': -0.0278, '71': -0.0278, '85': -0.0278, '81': -0.0278, '84': -0.0833, '89': -0.0833, '86': -0.111, '87': -0.111}},
    {c: 'S', h: 0.683, w: 0.556},
    {c: 'T', h: 0.683, w: 0.722, krn: {'121': -0.0278, '101': -0.0833, '111': -0.0833, '114': -0.0833, '97': -0.0833, '65': -0.0833, '117': -0.0833}},
    {c: 'U', h: 0.683, w: 0.75},
    {c: 'V', h: 0.683, w: 0.75, ic: 0.0139, krn: {'111': -0.0833, '101': -0.0833, '117': -0.0833, '114': -0.0833, '97': -0.0833, '65': -0.111, '79': -0.0278, '67': -0.0278, '71': -0.0278, '81': -0.0278}},
    {c: 'W', h: 0.683, w: 1.03, ic: 0.0139, krn: {'111': -0.0833, '101': -0.0833, '117': -0.0833, '114': -0.0833, '97': -0.0833, '65': -0.111, '79': -0.0278, '67': -0.0278, '71': -0.0278, '81': -0.0278}},
    {c: 'X', h: 0.683, w: 0.75, krn: {'79': -0.0278, '67': -0.0278, '71': -0.0278, '81': -0.0278}},
    {c: 'Y', h: 0.683, w: 0.75, ic: 0.025, krn: {'101': -0.0833, '111': -0.0833, '114': -0.0833, '97': -0.0833, '65': -0.0833, '117': -0.0833}},
    {c: 'Z', h: 0.683, w: 0.611},
    {c: '[', h: 0.75, d: 0.25, w: 0.278},
    {c: '\\', h: 0.694, w: 0.5},
    {c: ']', h: 0.75, d: 0.25, w: 0.278},
    {c: '^', h: 0.694, w: 0.5},
    {c: '_', h: 0.668, w: 0.278},
    // 60 - 6F
    {c: '&#x60;', h: 0.694, w: 0.278, lig: {'96': 92}},
    {c: 'a', h: 0.431, w: 0.5, krn: {'118': -0.0278, '106': 0.0556, '121': -0.0278, '119': -0.0278}},
    {c: 'b', h: 0.694, w: 0.556, krn: {'101': 0.0278, '111': 0.0278, '120': -0.0278, '100': 0.0278, '99': 0.0278, '113': 0.0278, '118': -0.0278, '106': 0.0556, '121': -0.0278, '119': -0.0278}},
    {c: 'c', h: 0.431, w: 0.444, krn: {'104': -0.0278, '107': -0.0278}},
    {c: 'd', h: 0.694, w: 0.556},
    {c: 'e', h: 0.431, w: 0.444},
    {c: 'f', h: 0.694, w: 0.306, ic: 0.0778, krn: {'39': 0.0778, '63': 0.0778, '33': 0.0778, '41': 0.0778, '93': 0.0778}, lig: {'105': 12, '102': 11, '108': 13}},
    {c: 'g', h: 0.431, d: 0.194, w: 0.5, ic: 0.0139, krn: {'106': 0.0278}},
    {c: 'h', h: 0.694, w: 0.556, krn: {'116': -0.0278, '117': -0.0278, '98': -0.0278, '121': -0.0278, '118': -0.0278, '119': -0.0278}},
    {c: 'i', h: 0.668, w: 0.278},
    {c: 'j', h: 0.668, d: 0.194, w: 0.306},
    {c: 'k', h: 0.694, w: 0.528, krn: {'97': -0.0556, '101': -0.0278, '97': -0.0278, '111': -0.0278, '99': -0.0278}},
    {c: 'l', h: 0.694, w: 0.278},
    {c: 'm', h: 0.431, w: 0.833, krn: {'116': -0.0278, '117': -0.0278, '98': -0.0278, '121': -0.0278, '118': -0.0278, '119': -0.0278}},
    {c: 'n', h: 0.431, w: 0.556, krn: {'116': -0.0278, '117': -0.0278, '98': -0.0278, '121': -0.0278, '118': -0.0278, '119': -0.0278}},
    {c: 'o', h: 0.431, w: 0.5, krn: {'101': 0.0278, '111': 0.0278, '120': -0.0278, '100': 0.0278, '99': 0.0278, '113': 0.0278, '118': -0.0278, '106': 0.0556, '121': -0.0278, '119': -0.0278}},
    // 70 - 7F
    {c: 'p', h: 0.431, d: 0.194, w: 0.556, krn: {'101': 0.0278, '111': 0.0278, '120': -0.0278, '100': 0.0278, '99': 0.0278, '113': 0.0278, '118': -0.0278, '106': 0.0556, '121': -0.0278, '119': -0.0278}},
    {c: 'q', h: 0.431, d: 0.194, w: 0.528},
    {c: 'r', h: 0.431, w: 0.392},
    {c: 's', h: 0.431, w: 0.394},
    {c: 't', h: 0.615, w: 0.389, krn: {'121': -0.0278, '119': -0.0278}},
    {c: 'u', h: 0.431, w: 0.556, krn: {'119': -0.0278}},
    {c: 'v', h: 0.431, w: 0.528, ic: 0.0139, krn: {'97': -0.0556, '101': -0.0278, '97': -0.0278, '111': -0.0278, '99': -0.0278}},
    {c: 'w', h: 0.431, w: 0.722, ic: 0.0139, krn: {'101': -0.0278, '97': -0.0278, '111': -0.0278, '99': -0.0278}},
    {c: 'x', h: 0.431, w: 0.528},
    {c: 'y', h: 0.431, d: 0.194, w: 0.528, ic: 0.0139, krn: {'111': -0.0278, '101': -0.0278, '97': -0.0278, '46': -0.0833, '44': -0.0833}},
    {c: 'z', h: 0.431, w: 0.444},
    {c: '&#x7B;', h: 0.431, w: 0.5, ic: 0.0278, lig: {'45': 124}},
    {c: '&#x7C;', h: 0.431, w: 1, ic: 0.0278},
    {c: '&#x7D;', h: 0.694, w: 0.5},
    {c: '&#x7E;', h: 0.668, w: 0.5},
    {c: '&#xC4;', h: 0.668, w: 0.5}
  ],
  
  cmmi10: [
    // 00 - 0F
    {c: '&#xA1;', h: 0.683, w: 0.615, ic: 0.139, krn: {'61': -0.0556, '59': -0.111, '58': -0.111, '127': 0.0833}},
    {c: '&#xA2;', h: 0.683, w: 0.833, krn: {'127': 0.167}},
    {c: '&#xA3;', h: 0.683, w: 0.763, ic: 0.0278, krn: {'127': 0.0833}},
    {c: '&#xA4;', h: 0.683, w: 0.694, krn: {'127': 0.167}},
    {c: '&#xA5;', h: 0.683, w: 0.742, ic: 0.0757, krn: {'127': 0.0833}},
    {c: '&#xA6;', h: 0.683, w: 0.831, ic: 0.0812, krn: {'61': -0.0556, '59': -0.0556, '58': -0.0556, '127': 0.0556}},
    {c: '&#xA7;', h: 0.683, w: 0.78, ic: 0.0576, krn: {'127': 0.0833}},
    {c: '&#xA8;', h: 0.683, w: 0.583, ic: 0.139, krn: {'61': -0.0556, '59': -0.111, '58': -0.111, '127': 0.0556}},
    {c: '&#xA9;', h: 0.683, w: 0.667, krn: {'127': 0.0833}},
    {c: '&#xAA;', h: 0.683, w: 0.612, ic: 0.11, krn: {'61': -0.0556, '59': -0.0556, '58': -0.0556, '127': 0.0556}},
    {c: '&#xAD;', h: 0.683, w: 0.772, ic: 0.0502, krn: {'127': 0.0833}},
    {c: '&#xAE;', h: 0.431, w: 0.64, ic: 0.0037, krn: {'127': 0.0278}},
    {c: '&#xAF;', h: 0.694, d: 0.194, w: 0.566, ic: 0.0528, krn: {'127': 0.0833}},
    {c: '&#xB0;', h: 0.431, d: 0.194, w: 0.518, ic: 0.0556},
    {c: '&#xB1;', h: 0.694, w: 0.444, ic: 0.0378, krn: {'59': -0.0556, '58': -0.0556, '127': 0.0556}},
    {c: '&#xB2;', h: 0.431, w: 0.406, krn: {'127': 0.0556}},
    // 10 - 1F
    {c: '&#xB3;', h: 0.694, d: 0.194, w: 0.438, ic: 0.0738, krn: {'127': 0.0833}},
    {c: '&#xB4;', h: 0.431, d: 0.194, w: 0.497, ic: 0.0359, krn: {'127': 0.0556}},
    {c: '&#xB5;', h: 0.694, w: 0.469, ic: 0.0278, krn: {'127': 0.0833}},
    {c: '&#xB6;', h: 0.431, w: 0.354, krn: {'127': 0.0556}},
    {c: '&#x2219;', h: 0.431, w: 0.576},
    {c: '&#xB8;', h: 0.694, w: 0.583},
    {c: '&#xB9;', h: 0.431, d: 0.194, w: 0.603, krn: {'127': 0.0278}},
    {c: '&#xBA;', h: 0.431, w: 0.494, ic: 0.0637, krn: {'59': -0.0556, '58': -0.0556, '127': 0.0278}},
    {c: '&#xBB;', h: 0.694, d: 0.194, w: 0.438, ic: 0.046, krn: {'127': 0.111}},
    {c: '&#xBC;', h: 0.431, w: 0.57, ic: 0.0359},
    {c: '&#xBD;', h: 0.431, d: 0.194, w: 0.517, krn: {'127': 0.0833}},
    {c: '&#xBE;', h: 0.431, w: 0.571, ic: 0.0359, krn: {'59': -0.0556, '58': -0.0556}},
    {c: '&#xBF;', h: 0.431, w: 0.437, ic: 0.113, krn: {'59': -0.0556, '58': -0.0556, '127': 0.0278}},
    {c: '&#xC0;', h: 0.431, w: 0.54, ic: 0.0359, krn: {'127': 0.0278}},
    {c: '&#xC1;', h: 0.694, d: 0.194, w: 0.596, krn: {'127': 0.0833}},
    {c: '&#xC2;', h: 0.431, d: 0.194, w: 0.626, krn: {'127': 0.0556}},
    // 20 - 2F
    {c: '&#xC3;', h: 0.694, d: 0.194, w: 0.651, ic: 0.0359, krn: {'127': 0.111}},
    {c: '!', h: 0.431, w: 0.622, ic: 0.0359},
    {c: '"', h: 0.431, w: 0.466, krn: {'127': 0.0833}},
    {c: '#', h: 0.694, w: 0.591, krn: {'127': 0.0833}},
    {c: '$', h: 0.431, w: 0.828, ic: 0.0278},
    {c: '%', h: 0.431, d: 0.194, w: 0.517, krn: {'127': 0.0833}},
    {c: '&#x26;', h: 0.431, d: 0.0972, w: 0.363, ic: 0.0799, krn: {'127': 0.0833}},
    {c: '\'', h: 0.431, d: 0.194, w: 0.654, krn: {'127': 0.0833}},
    {c: '(', h: 0.367, d: -0.133, w: 1},
    {c: ')', h: 0.367, d: -0.133, w: 1},
    {c: '*', h: 0.367, d: -0.133, w: 1},
    {c: '+', h: 0.367, d: -0.133, w: 1},
    {c: ',', h: 0.464, d: -0.0363, w: 0.278},
    {c: '-', h: 0.464, d: -0.0363, w: 0.278},
    {c: '.', h: 0.465, d: -0.0347, w: 0.5},
    {c: '/', h: 0.465, d: -0.0347, w: 0.5},
    // 30 - 3F
    {c: '0', h: 0.431, w: 0.5},
    {c: '1', h: 0.431, w: 0.5},
    {c: '2', h: 0.431, w: 0.5},
    {c: '3', h: 0.431, d: 0.194, w: 0.5},
    {c: '4', h: 0.431, d: 0.194, w: 0.5},
    {c: '5', h: 0.431, d: 0.194, w: 0.5},
    {c: '6', h: 0.644, w: 0.5},
    {c: '7', h: 0.431, d: 0.194, w: 0.5},
    {c: '8', h: 0.644, w: 0.5},
    {c: '9', h: 0.431, d: 0.194, w: 0.5},
    {c: ':', h: 0.106, w: 0.278},
    {c: ';', h: 0.106, d: 0.194, w: 0.278},
    {c: '&#x3C;', h: 0.539, d: 0.0391, w: 0.778},
    {c: '=', h: 0.75, d: 0.25, w: 0.5, krn: {'1': -0.0556, '65': -0.0556, '77': -0.0556, '78': -0.0556, '89': 0.0556, '90': -0.0556}},
    {c: '&#x3E;', h: 0.539, d: 0.0391, w: 0.778},
    {c: '?', h: 0.465, d: -0.0347, w: 0.5},
    // 40 - 4F
    {c: '@', h: 0.694, w: 0.531, ic: 0.0556, krn: {'127': 0.0833}},
    {c: 'A', h: 0.683, w: 0.75, krn: {'127': 0.139}},
    {c: 'B', h: 0.683, w: 0.759, ic: 0.0502, krn: {'127': 0.0833}},
    {c: 'C', h: 0.683, w: 0.715, ic: 0.0715, krn: {'61': -0.0278, '59': -0.0556, '58': -0.0556, '127': 0.0833}},
    {c: 'D', h: 0.683, w: 0.828, ic: 0.0278, krn: {'127': 0.0556}},
    {c: 'E', h: 0.683, w: 0.738, ic: 0.0576, krn: {'127': 0.0833}},
    {c: 'F', h: 0.683, w: 0.643, ic: 0.139, krn: {'61': -0.0556, '59': -0.111, '58': -0.111, '127': 0.0833}},
    {c: 'G', h: 0.683, w: 0.786, krn: {'127': 0.0833}},
    {c: 'H', h: 0.683, w: 0.831, ic: 0.0812, krn: {'61': -0.0556, '59': -0.0556, '58': -0.0556, '127': 0.0556}},
    {c: 'I', h: 0.683, w: 0.44, ic: 0.0785, krn: {'127': 0.111}},
    {c: 'J', h: 0.683, w: 0.555, ic: 0.0962, krn: {'61': -0.0556, '59': -0.111, '58': -0.111, '127': 0.167}},
    {c: 'K', h: 0.683, w: 0.849, ic: 0.0715, krn: {'61': -0.0556, '59': -0.0556, '58': -0.0556, '127': 0.0556}},
    {c: 'L', h: 0.683, w: 0.681, krn: {'127': 0.0278}},
    {c: 'M', h: 0.683, w: 0.97, ic: 0.109, krn: {'61': -0.0556, '59': -0.0556, '58': -0.0556, '127': 0.0833}},
    {c: 'N', h: 0.683, w: 0.803, ic: 0.109, krn: {'61': -0.0833, '61': -0.0278, '59': -0.0556, '58': -0.0556, '127': 0.0833}},
    {c: 'O', h: 0.683, w: 0.763, ic: 0.0278, krn: {'127': 0.0833}},
    // 50 - 5F
    {c: 'P', h: 0.683, w: 0.642, ic: 0.139, krn: {'61': -0.0556, '59': -0.111, '58': -0.111, '127': 0.0833}},
    {c: 'Q', h: 0.683, d: 0.194, w: 0.791, krn: {'127': 0.0833}},
    {c: 'R', h: 0.683, w: 0.759, ic: 0.00773, krn: {'127': 0.0833}},
    {c: 'S', h: 0.683, w: 0.613, ic: 0.0576, krn: {'61': -0.0556, '59': -0.0556, '58': -0.0556, '127': 0.0833}},
    {c: 'T', h: 0.683, w: 0.584, ic: 0.139, krn: {'61': -0.0278, '59': -0.0556, '58': -0.0556, '127': 0.0833}},
    {c: 'U', h: 0.683, w: 0.683, ic: 0.109, krn: {'59': -0.111, '58': -0.111, '61': -0.0556, '127': 0.0278}},
    {c: 'V', h: 0.683, w: 0.583, ic: 0.222, krn: {'59': -0.167, '58': -0.167, '61': -0.111}},
    {c: 'W', h: 0.683, w: 0.944, ic: 0.139, krn: {'59': -0.167, '58': -0.167, '61': -0.111}},
    {c: 'X', h: 0.683, w: 0.828, ic: 0.0785, krn: {'61': -0.0833, '61': -0.0278, '59': -0.0556, '58': -0.0556, '127': 0.0833}},
    {c: 'Y', h: 0.683, w: 0.581, ic: 0.222, krn: {'59': -0.167, '58': -0.167, '61': -0.111}},
    {c: 'Z', h: 0.683, w: 0.683, ic: 0.0715, krn: {'61': -0.0556, '59': -0.0556, '58': -0.0556, '127': 0.0833}},
    {c: '[', h: 0.75, w: 0.389},
    {c: '\\', h: 0.694, d: 0.194, w: 0.389},
    {c: ']', h: 0.694, d: 0.194, w: 0.389},
    {c: '^', h: 0.358, d: -0.142, w: 1},
    {c: '_', h: 0.358, d: -0.142, w: 1},
    // 60 - 6F
    {c: '&#x60;', h: 0.694, w: 0.417, krn: {'127': 0.111}},
    {c: 'a', h: 0.431, w: 0.529},
    {c: 'b', h: 0.694, w: 0.429},
    {c: 'c', h: 0.431, w: 0.433, krn: {'127': 0.0556}},
    {c: 'd', h: 0.694, w: 0.52, krn: {'89': 0.0556, '90': -0.0556, '106': -0.111, '102': -0.167, '127': 0.167}},
    {c: 'e', h: 0.431, w: 0.466, krn: {'127': 0.0556}},
    {c: 'f', h: 0.694, d: 0.194, w: 0.49, ic: 0.108, krn: {'59': -0.0556, '58': -0.0556, '127': 0.167}},
    {c: 'g', h: 0.431, d: 0.194, w: 0.477, ic: 0.0359, krn: {'127': 0.0278}},
    {c: 'h', h: 0.694, w: 0.576, krn: {'127': -0.0278}},
    {c: 'i', h: 0.66, w: 0.345},
    {c: 'j', h: 0.66, d: 0.194, w: 0.412, ic: 0.0572, krn: {'59': -0.0556, '58': -0.0556}},
    {c: 'k', h: 0.694, w: 0.521, ic: 0.0315},
    {c: 'l', h: 0.694, w: 0.298, ic: 0.0197, krn: {'127': 0.0833}},
    {c: 'm', h: 0.431, w: 0.878},
    {c: 'n', h: 0.431, w: 0.6},
    {c: 'o', h: 0.431, w: 0.485, krn: {'127': 0.0556}},
    // 70 - 7F
    {c: 'p', h: 0.431, d: 0.194, w: 0.503, krn: {'127': 0.0833}},
    {c: 'q', h: 0.431, d: 0.194, w: 0.446, ic: 0.0359, krn: {'127': 0.0833}},
    {c: 'r', h: 0.431, w: 0.451, ic: 0.0278, krn: {'59': -0.0556, '58': -0.0556, '127': 0.0556}},
    {c: 's', h: 0.431, w: 0.469, krn: {'127': 0.0556}},
    {c: 't', h: 0.615, w: 0.361, krn: {'127': 0.0833}},
    {c: 'u', h: 0.431, w: 0.572, krn: {'127': 0.0278}},
    {c: 'v', h: 0.431, w: 0.485, ic: 0.0359, krn: {'127': 0.0278}},
    {c: 'w', h: 0.431, w: 0.716, ic: 0.0269, krn: {'127': 0.0833}},
    {c: 'x', h: 0.431, w: 0.572, krn: {'127': 0.0278}},
    {c: 'y', h: 0.431, d: 0.194, w: 0.49, ic: 0.0359, krn: {'127': 0.0556}},
    {c: 'z', h: 0.431, w: 0.465, ic: 0.044, krn: {'127': 0.0556}},
    {c: '&#x7B;', h: 0.431, w: 0.322, krn: {'127': 0.0278}},
    {c: '&#x7C;', h: 0.431, d: 0.194, w: 0.384, krn: {'127': 0.0833}},
    {c: '&#x7D;', h: 0.431, d: 0.194, w: 0.636, krn: {'127': 0.111}},
    {c: '&#x7E;', h: 0.714, w: 0.5, ic: 0.154},
    {c: '&#xC4;', h: 0.694, w: 0.278, ic: 0.399}
  ],

  cmsy10: [
    // 00 - 0F
    {c: '&#xA1;', h: 0.583, d: 0.0833, w: 0.778},
    {c: '&#xA2;', h: 0.444, d: -0.0556, w: 0.278},
    {c: '&#xA3;', h: 0.583, d: 0.0833, w: 0.778},
    {c: '&#xA4;', h: 0.465, d: -0.0347, w: 0.5},
    {c: '&#xA5;', h: 0.583, d: 0.0833, w: 0.778},
    {c: '&#xA6;', h: 0.444, d: -0.0556, w: 0.5},
    {c: '&#xA7;', h: 0.583, d: 0.0833, w: 0.778},
    {c: '&#xA8;', h: 0.583, d: 0.0833, w: 0.778},
    {c: '&#xA9;', h: 0.583, d: 0.0833, w: 0.778},
    {c: '&#xAA;', h: 0.583, d: 0.0833, w: 0.778},
    {c: '&#xAD;', h: 0.583, d: 0.0833, w: 0.778},
    {c: '&#xAE;', h: 0.583, d: 0.0833, w: 0.778},
    {c: '&#xAF;', h: 0.583, d: 0.0833, w: 0.778},
    {c: '&#xB0;', h: 0.694, d: 0.194, w: 1},
    {c: '&#xB1;', h: 0.444, d: -0.0556, w: 0.5},
    {c: '&#xB2;', h: 0.444, d: -0.0556, w: 0.5},
    // 10 - 1F
    {c: '&#xB3;', h: 0.464, d: -0.0363, w: 0.778},
    {c: '&#xB4;', h: 0.464, d: -0.0363, w: 0.778},
    {c: '&#xB5;', h: 0.636, d: 0.136, w: 0.778},
    {c: '&#xB6;', h: 0.636, d: 0.136, w: 0.778},
    {c: '&#x2219;', h: 0.636, d: 0.136, w: 0.778},
    {c: '&#xB8;', h: 0.636, d: 0.136, w: 0.778},
    {c: '&#xB9;', h: 0.636, d: 0.136, w: 0.778},
    {c: '&#xBA;', h: 0.636, d: 0.136, w: 0.778},
    {c: '&#xBB;', h: 0.367, d: -0.133, w: 0.778},
    {c: '&#xBC;', h: 0.483, d: -0.0169, w: 0.778},
    {c: '&#xBD;', h: 0.539, d: 0.0391, w: 0.778},
    {c: '&#xBE;', h: 0.539, d: 0.0391, w: 0.778},
    {c: '&#xBF;', h: 0.539, d: 0.0391, w: 1},
    {c: '&#xC0;', h: 0.539, d: 0.0391, w: 1},
    {c: '&#xC1;', h: 0.539, d: 0.0391, w: 0.778},
    {c: '&#xC2;', h: 0.539, d: 0.0391, w: 0.778},
    // 20 - 2F
    {c: '&#xC3;', h: 0.367, d: -0.133, w: 1},
    {c: '!', h: 0.367, d: -0.133, w: 1},
    {c: '"', h: 0.694, d: 0.194, w: 0.5},
    {c: '#', h: 0.694, d: 0.194, w: 0.5},
    {c: '$', h: 0.367, d: -0.133, w: 1},
    {c: '%', h: 0.694, d: 0.194, w: 1},
    {c: '&#x26;', h: 0.694, d: 0.194, w: 1},
    {c: '\'', h: 0.464, d: -0.0363, w: 0.778},
    {c: '(', h: 0.367, d: -0.133, w: 1},
    {c: ')', h: 0.367, d: -0.133, w: 1},
    {c: '*', h: 0.694, d: 0.194, w: 0.611},
    {c: '+', h: 0.694, d: 0.194, w: 0.611},
    {c: ',', h: 0.367, d: -0.133, w: 1},
    {c: '-', h: 0.694, d: 0.194, w: 1},
    {c: '.', h: 0.694, d: 0.194, w: 1},
    {c: '/', h: 0.431, w: 0.778},
    // 30 - 3F
    {c: '0', h: 0.556, w: 0.275},
    {c: '1', h: 0.431, w: 1},
    {c: '2', h: 0.539, d: 0.0391, w: 0.667},
    {c: '3', h: 0.539, d: 0.0391, w: 0.667},
    {c: '4', h: 0.694, d: 0.194, w: 0.889},
    {c: '5', h: 0.694, d: 0.194, w: 0.889},
    {c: '6', h: 0.694, d: 0.194, w: 0},
    {c: '7', h: 0.367, d: -0.133, w: 0},
    {c: '8', h: 0.694, w: 0.556},
    {c: '9', h: 0.694, w: 0.556},
    {c: ':', h: 0.431, w: 0.667},
    {c: ';', h: 0.75, d: 0.0556, w: 0.5},
    {c: '&#x3C;', h: 0.694, w: 0.722},
    {c: '=', h: 0.694, w: 0.722},
    {c: '&#x3E;', h: 0.694, w: 0.778},
    {c: '?', h: 0.694, w: 0.778},
    // 40 - 4F
    {c: '@', h: 0.694, w: 0.611},
    {c: 'A', h: 0.683, w: 0.798, krn: {'48': 0.194}},
    {c: 'B', h: 0.683, w: 0.657, ic: 0.0304, krn: {'48': 0.139}},
    {c: 'C', h: 0.683, w: 0.527, ic: 0.0583, krn: {'48': 0.139}},
    {c: 'D', h: 0.683, w: 0.771, ic: 0.0278, krn: {'48': 0.0833}},
    {c: 'E', h: 0.683, w: 0.528, ic: 0.0894, krn: {'48': 0.111}},
    {c: 'F', h: 0.683, w: 0.719, ic: 0.0993, krn: {'48': 0.111}},
    {c: 'G', h: 0.683, d: 0.0972, w: 0.595, ic: 0.0593, krn: {'48': 0.111}},
    {c: 'H', h: 0.683, w: 0.845, ic: 0.00965, krn: {'48': 0.111}},
    {c: 'I', h: 0.683, w: 0.545, ic: 0.0738, krn: {'48': 0.0278}},
    {c: 'J', h: 0.683, d: 0.0972, w: 0.678, ic: 0.185, krn: {'48': 0.167}},
    {c: 'K', h: 0.683, w: 0.762, ic: 0.0144, krn: {'48': 0.0556}},
    {c: 'L', h: 0.683, w: 0.69, krn: {'48': 0.139}},
    {c: 'M', h: 0.683, w: 1.2, krn: {'48': 0.139}},
    {c: 'N', h: 0.683, w: 0.82, ic: 0.147, krn: {'48': 0.0833}},
    {c: 'O', h: 0.683, w: 0.796, ic: 0.0278, krn: {'48': 0.111}},
    // 50 - 5F
    {c: 'P', h: 0.683, w: 0.696, ic: 0.0822, krn: {'48': 0.0833}},
    {c: 'Q', h: 0.683, d: 0.0972, w: 0.817, krn: {'48': 0.111}},
    {c: 'R', h: 0.683, w: 0.848, krn: {'48': 0.0833}},
    {c: 'S', h: 0.683, w: 0.606, ic: 0.075, krn: {'48': 0.139}},
    {c: 'T', h: 0.683, w: 0.545, ic: 0.254, krn: {'48': 0.0278}},
    {c: 'U', h: 0.683, w: 0.626, ic: 0.0993, krn: {'48': 0.0833}},
    {c: 'V', h: 0.683, w: 0.613, ic: 0.0822, krn: {'48': 0.0278}},
    {c: 'W', h: 0.683, w: 0.988, ic: 0.0822, krn: {'48': 0.0833}},
    {c: 'X', h: 0.683, w: 0.713, ic: 0.146, krn: {'48': 0.139}},
    {c: 'Y', h: 0.683, d: 0.0972, w: 0.668, ic: 0.0822, krn: {'48': 0.0833}},
    {c: 'Z', h: 0.683, w: 0.725, ic: 0.0794, krn: {'48': 0.139}},
    {c: '[', h: 0.556, w: 0.667},
    {c: '\\', h: 0.556, w: 0.667},
    {c: ']', h: 0.556, w: 0.667},
    {c: '^', h: 0.556, w: 0.667},
    {c: '_', h: 0.556, w: 0.667},
    // 60 - 6F
    {c: '&#x60;', h: 0.694, w: 0.611},
    {c: 'a', h: 0.694, w: 0.611},
    {c: 'b', h: 0.75, d: 0.25, w: 0.444},
    {c: 'c', h: 0.75, d: 0.25, w: 0.444},
    {c: 'd', h: 0.75, d: 0.25, w: 0.444},
    {c: 'e', h: 0.75, d: 0.25, w: 0.444},
    {c: 'f', h: 0.75, d: 0.25, w: 0.5},
    {c: 'g', h: 0.75, d: 0.25, w: 0.5},
    {c: 'h', h: 0.75, d: 0.25, w: 0.389},
    {c: 'i', h: 0.75, d: 0.25, w: 0.389},
    {c: 'j', h: 0.75, d: 0.25, w: 0.278},
    {c: 'k', h: 0.75, d: 0.25, w: 0.5},
    {c: 'l', h: 0.75, d: 0.25, w: 0.5},
    {c: 'm', h: 0.75, d: 0.25, w: 0.611},
    {c: 'n', h: 0.75, d: 0.25, w: 0.5},
    {c: 'o', h: 0.694, d: 0.194, w: 0.278},
    // 70 - 7F
    {c: 'p', h: 0.04, d: 0.96, w: 0.833},
    {c: 'q', h: 0.683, w: 0.75},
    {c: 'r', h: 0.683, w: 0.833},
    {c: 's', h: 0.694, d: 0.194, w: 0.417, ic: 0.111},
    {c: 't', h: 0.556, w: 0.667},
    {c: 'u', h: 0.556, w: 0.667},
    {c: 'v', h: 0.636, d: 0.136, w: 0.778},
    {c: 'w', h: 0.636, d: 0.136, w: 0.778},
    {c: 'x', h: 0.694, d: 0.194, w: 0.444},
    {c: 'y', h: 0.694, d: 0.194, w: 0.444},
    {c: 'z', h: 0.694, d: 0.194, w: 0.444},
    {c: '&#x7B;', h: 0.694, d: 0.194, w: 0.611},
    {c: '&#x7C;', h: 0.694, d: 0.13, w: 0.778},
    {c: '&#x7D;', h: 0.694, d: 0.13, w: 0.778},
    {c: '&#x7E;', h: 0.694, d: 0.13, w: 0.778},
    {c: '&#xC4;', h: 0.694, d: 0.13, w: 0.778}
  ],

  cmex10: [
    // 00 - 0F
    {c: '&#xA1;', h: 0.04, d: 1.16, w: 0.458, n: 16},
    {c: '&#xA2;', h: 0.04, d: 1.16, w: 0.458, n: 17},
    {c: '&#xA3;', h: 0.04, d: 1.16, w: 0.417, n: 104},
    {c: '&#xA4;', h: 0.04, d: 1.16, w: 0.417, n: 105},
    {c: '&#xA5;', h: 0.04, d: 1.16, w: 0.472, n: 106},
    {c: '&#xA6;', h: 0.04, d: 1.16, w: 0.472, n: 107},
    {c: '&#xA7;', h: 0.04, d: 1.16, w: 0.472, n: 108},
    {c: '&#xA8;', h: 0.04, d: 1.16, w: 0.472, n: 109},
    {c: '&#xA9;', h: 0.04, d: 1.16, w: 0.583, n: 110},
    {c: '&#xAA;', h: 0.04, d: 1.16, w: 0.583, n: 111},
    {c: '&#xAD;', h: 0.04, d: 1.16, w: 0.472, n: 68},
    {c: '&#xAE;', h: 0.04, d: 1.16, w: 0.472, n: 69},
    {c: '&#xAF;', d: 0.6, w: 0.333, delim: {rep: 12}},
    {c: '&#xB0;', d: 0.6, w: 0.556, delim: {rep: 13}},
    {c: '&#xB1;', h: 0.04, d: 1.16, w: 0.578, n: 46},
    {c: '&#xB2;', h: 0.04, d: 1.16, w: 0.578, n: 47},
    // 10 - 1F
    {c: '&#xB3;', h: 0.04, d: 1.76, w: 0.597, n: 18},
    {c: '&#xB4;', h: 0.04, d: 1.76, w: 0.597, n: 19},
    {c: '&#xB5;', h: 0.04, d: 2.36, w: 0.736, n: 32},
    {c: '&#xB6;', h: 0.04, d: 2.36, w: 0.736, n: 33},
    {c: '&#x2219;', h: 0.04, d: 2.36, w: 0.528, n: 34},
    {c: '&#xB8;', h: 0.04, d: 2.36, w: 0.528, n: 35},
    {c: '&#xB9;', h: 0.04, d: 2.36, w: 0.583, n: 36},
    {c: '&#xBA;', h: 0.04, d: 2.36, w: 0.583, n: 37},
    {c: '&#xBB;', h: 0.04, d: 2.36, w: 0.583, n: 38},
    {c: '&#xBC;', h: 0.04, d: 2.36, w: 0.583, n: 39},
    {c: '&#xBD;', h: 0.04, d: 2.36, w: 0.75, n: 40},
    {c: '&#xBE;', h: 0.04, d: 2.36, w: 0.75, n: 41},
    {c: '&#xBF;', h: 0.04, d: 2.36, w: 0.75, n: 42},
    {c: '&#xC0;', h: 0.04, d: 2.36, w: 0.75, n: 43},
    {c: '&#xC1;', h: 0.04, d: 2.36, w: 1.04, n: 44},
    {c: '&#xC2;', h: 0.04, d: 2.36, w: 1.04, n: 45},
    // 20 - 2F
    {c: '&#xC3;', h: 0.04, d: 2.96, w: 0.792, n: 48},
    {c: '!', h: 0.04, d: 2.96, w: 0.792, n: 49},
    {c: '"', h: 0.04, d: 2.96, w: 0.583, n: 50},
    {c: '#', h: 0.04, d: 2.96, w: 0.583, n: 51},
    {c: '$', h: 0.04, d: 2.96, w: 0.639, n: 52},
    {c: '%', h: 0.04, d: 2.96, w: 0.639, n: 53},
    {c: '&#x26;', h: 0.04, d: 2.96, w: 0.639, n: 54},
    {c: '\'', h: 0.04, d: 2.96, w: 0.639, n: 55},
    {c: '(', h: 0.04, d: 2.96, w: 0.806, n: 56},
    {c: ')', h: 0.04, d: 2.96, w: 0.806, n: 57},
    {c: '*', h: 0.04, d: 2.96, w: 0.806},
    {c: '+', h: 0.04, d: 2.96, w: 0.806},
    {c: ',', h: 0.04, d: 2.96, w: 1.28},
    {c: '-', h: 0.04, d: 2.96, w: 1.28},
    {c: '.', h: 0.04, d: 1.76, w: 0.811, n: 30},
    {c: '/', h: 0.04, d: 1.76, w: 0.811, n: 31},
    // 30 - 3F
    {c: '0', h: 0.04, d: 1.76, w: 0.875, delim: {top: 48, bot: 64, rep: 66}},
    {c: '1', h: 0.04, d: 1.76, w: 0.875, delim: {top: 49, bot: 65, rep: 67}},
    {c: '2', h: 0.04, d: 1.76, w: 0.667, delim: {top: 50, bot: 52, rep: 54}},
    {c: '3', h: 0.04, d: 1.76, w: 0.667, delim: {top: 51, bot: 53, rep: 55}},
    {c: '4', h: 0.04, d: 1.76, w: 0.667, delim: {bot: 52, rep: 54}},
    {c: '5', h: 0.04, d: 1.76, w: 0.667, delim: {bot: 53, rep: 55}},
    {c: '6', d: 0.6, w: 0.667, delim: {top: 50, rep: 54}},
    {c: '7', d: 0.6, w: 0.667, delim: {top: 51, rep: 55}},
    {c: '8', d: 0.9, w: 0.889, delim: {top: 56, mid: 60, bot: 58, rep: 62}},
    {c: '9', d: 0.9, w: 0.889, delim: {top: 57, mid: 61, bot: 59, rep: 62}},
    {c: ':', d: 0.9, w: 0.889, delim: {top: 56, bot: 58, rep: 62}},
    {c: ';', d: 0.9, w: 0.889, delim: {top: 57, bot: 59, rep: 62}},
    {c: '&#x3C;', d: 1.8, w: 0.889, delim: {rep: 63}},
    {c: '=', d: 1.8, w: 0.889, delim: {rep: 119}},
    {c: '&#x3E;', d: 0.3, w: 0.889, delim: {rep: 62}},
    {c: '?', d: 0.6, w: 0.667, delim: {top: 120, bot: 121, rep: 63}},
    // 40 - 4F
    {c: '@', h: 0.04, d: 1.76, w: 0.875, delim: {top: 56, bot: 59, rep: 62}},
    {c: 'A', h: 0.04, d: 1.76, w: 0.875, delim: {top: 57, bot: 58, rep: 62}},
    {c: 'B', d: 0.6, w: 0.875, delim: {rep: 66}},
    {c: 'C', d: 0.6, w: 0.875, delim: {rep: 67}},
    {c: 'D', h: 0.04, d: 1.76, w: 0.611, n: 28},
    {c: 'E', h: 0.04, d: 1.76, w: 0.611, n: 29},
    {c: 'F', d: 1, w: 0.833, n: 71},
    {c: 'G', h: 0.1, d: 1.5, w: 1.11},
    {c: 'H', d: 1.11, w: 0.472, ic: 0.194, n: 73},
    {c: 'I', d: 2.22, w: 0.556, ic: 0.444},
    {c: 'J', d: 1, w: 1.11, n: 75},
    {c: 'K', h: 0.1, d: 1.5, w: 1.51},
    {c: 'L', d: 1, w: 1.11, n: 77},
    {c: 'M', h: 0.1, d: 1.5, w: 1.51},
    {c: 'N', d: 1, w: 1.11, n: 79},
    {c: 'O', h: 0.1, d: 1.5, w: 1.51},
    // 50 - 5F
    {c: 'P', d: 1, w: 1.06, n: 88},
    {c: 'Q', d: 1, w: 0.944, n: 89},
    {c: 'R', d: 1.11, w: 0.472, ic: 0.194, n: 90},
    {c: 'S', d: 1, w: 0.833, n: 91},
    {c: 'T', d: 1, w: 0.833, n: 92},
    {c: 'U', d: 1, w: 0.833, n: 93},
    {c: 'V', d: 1, w: 0.833, n: 94},
    {c: 'W', d: 1, w: 0.833, n: 95},
    {c: 'X', h: 0.1, d: 1.5, w: 1.44},
    {c: 'Y', h: 0.1, d: 1.5, w: 1.28},
    {c: 'Z', d: 2.22, w: 0.556, ic: 0.444},
    {c: '[', h: 0.1, d: 1.5, w: 1.11},
    {c: '\\', h: 0.1, d: 1.5, w: 1.11},
    {c: ']', h: 0.1, d: 1.5, w: 1.11},
    {c: '^', h: 0.1, d: 1.5, w: 1.11},
    {c: '_', h: 0.1, d: 1.5, w: 1.11},
    // 60 - 6F
    {c: '&#x60;', d: 1, w: 0.944, n: 97},
    {c: 'a', h: 0.1, d: 1.5, w: 1.28},
    {c: 'b', h: 0.722, w: 0.556, n: 99},
    {c: 'c', h: 0.75, w: 1, n: 100},
    {c: 'd', h: 0.75, w: 1.44},
    {c: 'e', h: 0.722, w: 0.556, n: 102},
    {c: 'f', h: 0.75, w: 1, n: 103},
    {c: 'g', h: 0.75, w: 1.44},
    {c: 'h', h: 0.04, d: 1.76, w: 0.472, n: 20},
    {c: 'i', h: 0.04, d: 1.76, w: 0.472, n: 21},
    {c: 'j', h: 0.04, d: 1.76, w: 0.528, n: 22},
    {c: 'k', h: 0.04, d: 1.76, w: 0.528, n: 23},
    {c: 'l', h: 0.04, d: 1.76, w: 0.528, n: 24},
    {c: 'm', h: 0.04, d: 1.76, w: 0.528, n: 25},
    {c: 'n', h: 0.04, d: 1.76, w: 0.667, n: 26},
    {c: 'o', h: 0.04, d: 1.76, w: 0.667, n: 27},
    // 70 - 7F
    {c: 'p', h: 0.04, d: 1.16, w: 1, n: 113},
    {c: 'q', h: 0.04, d: 1.76, w: 1, n: 114},
    {c: 'r', h: 0.04, d: 2.36, w: 1, n: 115},
    {c: 's', h: 0.04, d: 2.96, w: 1, n: 116},
    {c: 't', d: 1.8, w: 1.06, delim: {top: 118, bot: 116, rep: 117}},
    {c: 'u', d: 0.6, w: 1.06},
    {c: 'v', h: 0.04, d: 0.56, w: 1.06},
    {c: 'w', d: 0.6, w: 0.778, delim: {top: 126, bot: 127, rep: 119}},
    {c: 'x', d: 0.6, w: 0.667, delim: {top: 120, rep: 63}},
    {c: 'y', d: 0.6, w: 0.667, delim: {bot: 121, rep: 63}},
    {c: 'z', h: 0.12, w: 0.45},
    {c: '&#x7B;', h: 0.12, w: 0.45},
    {c: '&#x7C;', h: 0.12, w: 0.45},
    {c: '&#x7D;', h: 0.12, w: 0.45},
    {c: '&#x7E;', d: 0.6, w: 0.778, delim: {top: 126, rep: 119}},
    {c: '&#xC4;', d: 0.6, w: 0.778, delim: {bot: 127, rep: 119}}
  ],
  
  cmti10: [
    // 00 - 0F
    {c: '&#xA1;', h: 0.683, w: 0.627, ic: 0.133},
    {c: '&#xA2;', h: 0.683, w: 0.818},
    {c: '&#xA3;', h: 0.683, w: 0.767, ic: 0.094},
    {c: '&#xA4;', h: 0.683, w: 0.692},
    {c: '&#xA5;', h: 0.683, w: 0.664, ic: 0.153},
    {c: '&#xA6;', h: 0.683, w: 0.743, ic: 0.164},
    {c: '&#xA7;', h: 0.683, w: 0.716, ic: 0.12},
    {c: '&#xA8;', h: 0.683, w: 0.767, ic: 0.111},
    {c: '&#xA9;', h: 0.683, w: 0.716, ic: 0.0599},
    {c: '&#xAA;', h: 0.683, w: 0.767, ic: 0.111},
    {c: '&#xAD;', h: 0.683, w: 0.716, ic: 0.103},
    {c: '&#xAE;', h: 0.694, d: 0.194, w: 0.613, ic: 0.212, krn: {'39': 0.104, '63': 0.104, '33': 0.104, '41': 0.104, '93': 0.104}, lig: {'105': 14, '108': 15}},
    {c: '&#xAF;', h: 0.694, d: 0.194, w: 0.562, ic: 0.103},
    {c: '&#xB0;', h: 0.694, d: 0.194, w: 0.588, ic: 0.103},
    {c: '&#xB1;', h: 0.694, d: 0.194, w: 0.882, ic: 0.103},
    {c: '&#xB2;', h: 0.694, d: 0.194, w: 0.894, ic: 0.103},
    // 10 - 1F
    {c: '&#xB3;', h: 0.431, w: 0.307, ic: 0.0767},
    {c: '&#xB4;', h: 0.431, d: 0.194, w: 0.332, ic: 0.0374},
    {c: '&#xB5;', h: 0.694, w: 0.511},
    {c: '&#xB6;', h: 0.694, w: 0.511, ic: 0.0969},
    {c: '&#x2219;', h: 0.628, w: 0.511, ic: 0.083},
    {c: '&#xB8;', h: 0.694, w: 0.511, ic: 0.108},
    {c: '&#xB9;', h: 0.562, w: 0.511, ic: 0.103},
    {c: '&#xBA;', h: 0.694, w: 0.831},
    {c: '&#xBB;', d: 0.17, w: 0.46},
    {c: '&#xBC;', h: 0.694, d: 0.194, w: 0.537, ic: 0.105},
    {c: '&#xBD;', h: 0.431, w: 0.716, ic: 0.0751},
    {c: '&#xBE;', h: 0.431, w: 0.716, ic: 0.0751},
    {c: '&#xBF;', h: 0.528, d: 0.0972, w: 0.511, ic: 0.0919},
    {c: '&#xC0;', h: 0.683, w: 0.883, ic: 0.12},
    {c: '&#xC1;', h: 0.683, w: 0.985, ic: 0.12},
    {c: '&#xC2;', h: 0.732, d: 0.0486, w: 0.767, ic: 0.094},
    // 20 - 2F
    {c: '&#xC3;', h: 0.431, w: 0.256, krn: {'108': -0.256, '76': -0.321}},
    {c: '!', h: 0.694, w: 0.307, ic: 0.124, lig: {'96': 60}},
    {c: '"', h: 0.694, w: 0.514, ic: 0.0696},
    {c: '#', h: 0.694, d: 0.194, w: 0.818, ic: 0.0662},
    {c: '$', h: 0.694, w: 0.769},
    {c: '%', h: 0.75, d: 0.0556, w: 0.818, ic: 0.136},
    {c: '&#x26;', h: 0.694, w: 0.767, ic: 0.0969},
    {c: '\'', h: 0.694, w: 0.307, ic: 0.124, krn: {'63': 0.102, '33': 0.102}, lig: {'39': 34}},
    {c: '(', h: 0.75, d: 0.25, w: 0.409, ic: 0.162},
    {c: ')', h: 0.75, d: 0.25, w: 0.409, ic: 0.0369},
    {c: '*', h: 0.75, w: 0.511, ic: 0.149},
    {c: '+', h: 0.562, d: 0.0567, w: 0.767, ic: 0.0369},
    {c: ',', h: 0.106, d: 0.194, w: 0.307},
    {c: '-', h: 0.431, w: 0.358, ic: 0.0283, lig: {'45': 123}},
    {c: '.', h: 0.106, w: 0.307},
    {c: '/', h: 0.75, d: 0.25, w: 0.511, ic: 0.162},
    // 30 - 3F
    {c: '0', h: 0.644, w: 0.511, ic: 0.136},
    {c: '1', h: 0.644, w: 0.511, ic: 0.136},
    {c: '2', h: 0.644, w: 0.511, ic: 0.136},
    {c: '3', h: 0.644, w: 0.511, ic: 0.136},
    {c: '4', h: 0.644, d: 0.194, w: 0.511, ic: 0.136},
    {c: '5', h: 0.644, w: 0.511, ic: 0.136},
    {c: '6', h: 0.644, w: 0.511, ic: 0.136},
    {c: '7', h: 0.644, d: 0.194, w: 0.511, ic: 0.136},
    {c: '8', h: 0.644, w: 0.511, ic: 0.136},
    {c: '9', h: 0.644, w: 0.511, ic: 0.136},
    {c: ':', h: 0.431, w: 0.307, ic: 0.0582},
    {c: ';', h: 0.431, d: 0.194, w: 0.307, ic: 0.0582},
    {c: '&#x3C;', h: 0.5, d: 0.194, w: 0.307, ic: 0.0756},
    {c: '=', h: 0.367, d: -0.133, w: 0.767, ic: 0.0662},
    {c: '&#x3E;', h: 0.5, d: 0.194, w: 0.511},
    {c: '?', h: 0.694, w: 0.511, ic: 0.122, lig: {'96': 62}},
    // 40 - 4F
    {c: '@', h: 0.694, w: 0.767, ic: 0.096},
    {c: 'A', h: 0.683, w: 0.743, krn: {'110': -0.0256, '108': -0.0256, '114': -0.0256, '117': -0.0256, '109': -0.0256, '116': -0.0256, '105': -0.0256, '67': -0.0256, '79': -0.0256, '71': -0.0256, '104': -0.0256, '98': -0.0256, '85': -0.0256, '107': -0.0256, '118': -0.0256, '119': -0.0256, '81': -0.0256, '84': -0.0767, '89': -0.0767, '86': -0.102, '87': -0.102, '101': -0.0511, '97': -0.0511, '111': -0.0511, '100': -0.0511, '99': -0.0511, '103': -0.0511, '113': -0.0511}},
    {c: 'B', h: 0.683, w: 0.704, ic: 0.103},
    {c: 'C', h: 0.683, w: 0.716, ic: 0.145},
    {c: 'D', h: 0.683, w: 0.755, ic: 0.094, krn: {'88': -0.0256, '87': -0.0256, '65': -0.0256, '86': -0.0256, '89': -0.0256}},
    {c: 'E', h: 0.683, w: 0.678, ic: 0.12},
    {c: 'F', h: 0.683, w: 0.653, ic: 0.133, krn: {'111': -0.0767, '101': -0.0767, '117': -0.0767, '114': -0.0767, '97': -0.0767, '65': -0.102, '79': -0.0256, '67': -0.0256, '71': -0.0256, '81': -0.0256}},
    {c: 'G', h: 0.683, w: 0.774, ic: 0.0872},
    {c: 'H', h: 0.683, w: 0.743, ic: 0.164},
    {c: 'I', h: 0.683, w: 0.386, ic: 0.158},
    {c: 'J', h: 0.683, w: 0.525, ic: 0.14},
    {c: 'K', h: 0.683, w: 0.769, ic: 0.145, krn: {'79': -0.0256, '67': -0.0256, '71': -0.0256, '81': -0.0256}},
    {c: 'L', h: 0.683, w: 0.627, krn: {'84': -0.0767, '89': -0.0767, '86': -0.102, '87': -0.102, '101': -0.0511, '97': -0.0511, '111': -0.0511, '100': -0.0511, '99': -0.0511, '103': -0.0511, '113': -0.0511}},
    {c: 'M', h: 0.683, w: 0.897, ic: 0.164},
    {c: 'N', h: 0.683, w: 0.743, ic: 0.164},
    {c: 'O', h: 0.683, w: 0.767, ic: 0.094, krn: {'88': -0.0256, '87': -0.0256, '65': -0.0256, '86': -0.0256, '89': -0.0256}},
    // 50 - 5F
    {c: 'P', h: 0.683, w: 0.678, ic: 0.103, krn: {'65': -0.0767}},
    {c: 'Q', h: 0.683, d: 0.194, w: 0.767, ic: 0.094},
    {c: 'R', h: 0.683, w: 0.729, ic: 0.0387, krn: {'110': -0.0256, '108': -0.0256, '114': -0.0256, '117': -0.0256, '109': -0.0256, '116': -0.0256, '105': -0.0256, '67': -0.0256, '79': -0.0256, '71': -0.0256, '104': -0.0256, '98': -0.0256, '85': -0.0256, '107': -0.0256, '118': -0.0256, '119': -0.0256, '81': -0.0256, '84': -0.0767, '89': -0.0767, '86': -0.102, '87': -0.102, '101': -0.0511, '97': -0.0511, '111': -0.0511, '100': -0.0511, '99': -0.0511, '103': -0.0511, '113': -0.0511}},
    {c: 'S', h: 0.683, w: 0.562, ic: 0.12},
    {c: 'T', h: 0.683, w: 0.716, ic: 0.133, krn: {'121': -0.0767, '101': -0.0767, '111': -0.0767, '114': -0.0767, '97': -0.0767, '117': -0.0767, '65': -0.0767}},
    {c: 'U', h: 0.683, w: 0.743, ic: 0.164},
    {c: 'V', h: 0.683, w: 0.743, ic: 0.184, krn: {'111': -0.0767, '101': -0.0767, '117': -0.0767, '114': -0.0767, '97': -0.0767, '65': -0.102, '79': -0.0256, '67': -0.0256, '71': -0.0256, '81': -0.0256}},
    {c: 'W', h: 0.683, w: 0.999, ic: 0.184, krn: {'65': -0.0767}},
    {c: 'X', h: 0.683, w: 0.743, ic: 0.158, krn: {'79': -0.0256, '67': -0.0256, '71': -0.0256, '81': -0.0256}},
    {c: 'Y', h: 0.683, w: 0.743, ic: 0.194, krn: {'101': -0.0767, '111': -0.0767, '114': -0.0767, '97': -0.0767, '117': -0.0767, '65': -0.0767}},
    {c: 'Z', h: 0.683, w: 0.613, ic: 0.145},
    {c: '[', h: 0.75, d: 0.25, w: 0.307, ic: 0.188},
    {c: '\\', h: 0.694, w: 0.514, ic: 0.169},
    {c: ']', h: 0.75, d: 0.25, w: 0.307, ic: 0.105},
    {c: '^', h: 0.694, w: 0.511, ic: 0.0665},
    {c: '_', h: 0.668, w: 0.307, ic: 0.118},
    // 60 - 6F
    {c: '&#x60;', h: 0.694, w: 0.307, ic: 0.124, lig: {'96': 92}},
    {c: 'a', h: 0.431, w: 0.511, ic: 0.0767},
    {c: 'b', h: 0.694, w: 0.46, ic: 0.0631, krn: {'101': -0.0511, '97': -0.0511, '111': -0.0511, '100': -0.0511, '99': -0.0511, '103': -0.0511, '113': -0.0511}},
    {c: 'c', h: 0.431, w: 0.46, ic: 0.0565, krn: {'101': -0.0511, '97': -0.0511, '111': -0.0511, '100': -0.0511, '99': -0.0511, '103': -0.0511, '113': -0.0511}},
    {c: 'd', h: 0.694, w: 0.511, ic: 0.103, krn: {'108': 0.0511}},
    {c: 'e', h: 0.431, w: 0.46, ic: 0.0751, krn: {'101': -0.0511, '97': -0.0511, '111': -0.0511, '100': -0.0511, '99': -0.0511, '103': -0.0511, '113': -0.0511}},
    {c: 'f', h: 0.694, d: 0.194, w: 0.307, ic: 0.212, krn: {'39': 0.104, '63': 0.104, '33': 0.104, '41': 0.104, '93': 0.104}, lig: {'105': 12, '102': 11, '108': 13}},
    {c: 'g', h: 0.431, d: 0.194, w: 0.46, ic: 0.0885},
    {c: 'h', h: 0.694, w: 0.511, ic: 0.0767},
    {c: 'i', h: 0.655, w: 0.307, ic: 0.102},
    {c: 'j', h: 0.655, d: 0.194, w: 0.307, ic: 0.145},
    {c: 'k', h: 0.694, w: 0.46, ic: 0.108},
    {c: 'l', h: 0.694, w: 0.256, ic: 0.103, krn: {'108': 0.0511}},
    {c: 'm', h: 0.431, w: 0.818, ic: 0.0767},
    {c: 'n', h: 0.431, w: 0.562, ic: 0.0767, krn: {'39': -0.102}},
    {c: 'o', h: 0.431, w: 0.511, ic: 0.0631, krn: {'101': -0.0511, '97': -0.0511, '111': -0.0511, '100': -0.0511, '99': -0.0511, '103': -0.0511, '113': -0.0511}},
    // 70 - 7F
    {c: 'p', h: 0.431, d: 0.194, w: 0.511, ic: 0.0631, krn: {'101': -0.0511, '97': -0.0511, '111': -0.0511, '100': -0.0511, '99': -0.0511, '103': -0.0511, '113': -0.0511}},
    {c: 'q', h: 0.431, d: 0.194, w: 0.46, ic: 0.0885},
    {c: 'r', h: 0.431, w: 0.422, ic: 0.108, krn: {'101': -0.0511, '97': -0.0511, '111': -0.0511, '100': -0.0511, '99': -0.0511, '103': -0.0511, '113': -0.0511}},
    {c: 's', h: 0.431, w: 0.409, ic: 0.0821},
    {c: 't', h: 0.615, w: 0.332, ic: 0.0949},
    {c: 'u', h: 0.431, w: 0.537, ic: 0.0767},
    {c: 'v', h: 0.431, w: 0.46, ic: 0.108},
    {c: 'w', h: 0.431, w: 0.664, ic: 0.108, krn: {'108': 0.0511}},
    {c: 'x', h: 0.431, w: 0.464, ic: 0.12},
    {c: 'y', h: 0.431, d: 0.194, w: 0.486, ic: 0.0885},
    {c: 'z', h: 0.431, w: 0.409, ic: 0.123},
    {c: '&#x7B;', h: 0.431, w: 0.511, ic: 0.0921, lig: {'45': 124}},
    {c: '&#x7C;', h: 0.431, w: 1.02, ic: 0.0921},
    {c: '&#x7D;', h: 0.694, w: 0.511, ic: 0.122},
    {c: '&#x7E;', h: 0.668, w: 0.511, ic: 0.116},
    {c: '&#xC4;', h: 0.668, w: 0.511, ic: 0.105}
  ],
  
  cmbx10: [
    // 00 - 0F
    {c: '&#xA1;', h: 0.686, w: 0.692},
    {c: '&#xA2;', h: 0.686, w: 0.958},
    {c: '&#xA3;', h: 0.686, w: 0.894},
    {c: '&#xA4;', h: 0.686, w: 0.806},
    {c: '&#xA5;', h: 0.686, w: 0.767},
    {c: '&#xA6;', h: 0.686, w: 0.9},
    {c: '&#xA7;', h: 0.686, w: 0.831},
    {c: '&#xA8;', h: 0.686, w: 0.894},
    {c: '&#xA9;', h: 0.686, w: 0.831},
    {c: '&#xAA;', h: 0.686, w: 0.894},
    {c: '&#xAD;', h: 0.686, w: 0.831},
    {c: '&#xAE;', h: 0.694, w: 0.671, ic: 0.109, krn: {'39': 0.109, '63': 0.109, '33': 0.109, '41': 0.109, '93': 0.109}, lig: {'105': 14, '108': 15}},
    {c: '&#xAF;', h: 0.694, w: 0.639},
    {c: '&#xB0;', h: 0.694, w: 0.639},
    {c: '&#xB1;', h: 0.694, w: 0.958},
    {c: '&#xB2;', h: 0.694, w: 0.958},
    // 10 - 1F
    {c: '&#xB3;', h: 0.444, w: 0.319},
    {c: '&#xB4;', h: 0.444, d: 0.194, w: 0.351},
    {c: '&#xB5;', h: 0.694, w: 0.575},
    {c: '&#xB6;', h: 0.694, w: 0.575},
    {c: '&#x2219;', h: 0.632, w: 0.575},
    {c: '&#xB8;', h: 0.694, w: 0.575},
    {c: '&#xB9;', h: 0.596, w: 0.575},
    {c: '&#xBA;', h: 0.694, w: 0.869},
    {c: '&#xBB;', d: 0.17, w: 0.511},
    {c: '&#xBC;', h: 0.694, w: 0.597},
    {c: '&#xBD;', h: 0.444, w: 0.831},
    {c: '&#xBE;', h: 0.444, w: 0.894},
    {c: '&#xBF;', h: 0.542, d: 0.0972, w: 0.575},
    {c: '&#xC0;', h: 0.686, w: 1.04},
    {c: '&#xC1;', h: 0.686, w: 1.17},
    {c: '&#xC2;', h: 0.735, d: 0.0486, w: 0.894},
    // 20 - 2F
    {c: '&#xC3;', h: 0.444, w: 0.319, krn: {'108': -0.319, '76': -0.378}},
    {c: '!', h: 0.694, w: 0.35, lig: {'96': 60}},
    {c: '"', h: 0.694, w: 0.603},
    {c: '#', h: 0.694, d: 0.194, w: 0.958},
    {c: '$', h: 0.75, d: 0.0556, w: 0.575},
    {c: '%', h: 0.75, d: 0.0556, w: 0.958},
    {c: '&#x26;', h: 0.694, w: 0.894},
    {c: '\'', h: 0.694, w: 0.319, krn: {'63': 0.128, '33': 0.128}, lig: {'39': 34}},
    {c: '(', h: 0.75, d: 0.25, w: 0.447},
    {c: ')', h: 0.75, d: 0.25, w: 0.447},
    {c: '*', h: 0.75, w: 0.575},
    {c: '+', h: 0.633, d: 0.133, w: 0.894},
    {c: ',', h: 0.156, d: 0.194, w: 0.319},
    {c: '-', h: 0.444, w: 0.383, lig: {'45': 123}},
    {c: '.', h: 0.156, w: 0.319},
    {c: '/', h: 0.75, d: 0.25, w: 0.575},
    // 30 - 3F
    {c: '0', h: 0.644, w: 0.575},
    {c: '1', h: 0.644, w: 0.575},
    {c: '2', h: 0.644, w: 0.575},
    {c: '3', h: 0.644, w: 0.575},
    {c: '4', h: 0.644, w: 0.575},
    {c: '5', h: 0.644, w: 0.575},
    {c: '6', h: 0.644, w: 0.575},
    {c: '7', h: 0.644, w: 0.575},
    {c: '8', h: 0.644, w: 0.575},
    {c: '9', h: 0.644, w: 0.575},
    {c: ':', h: 0.444, w: 0.319},
    {c: ';', h: 0.444, d: 0.194, w: 0.319},
    {c: '&#x3C;', h: 0.5, d: 0.194, w: 0.35},
    {c: '=', h: 0.391, d: -0.109, w: 0.894},
    {c: '&#x3E;', h: 0.5, d: 0.194, w: 0.543},
    {c: '?', h: 0.694, w: 0.543, lig: {'96': 62}},
    // 40 - 4F
    {c: '@', h: 0.694, w: 0.894},
    {c: 'A', h: 0.686, w: 0.869, krn: {'116': -0.0319, '67': -0.0319, '79': -0.0319, '71': -0.0319, '85': -0.0319, '81': -0.0319, '84': -0.0958, '89': -0.0958, '86': -0.128, '87': -0.128}},
    {c: 'B', h: 0.686, w: 0.818},
    {c: 'C', h: 0.686, w: 0.831},
    {c: 'D', h: 0.686, w: 0.882, krn: {'88': -0.0319, '87': -0.0319, '65': -0.0319, '86': -0.0319, '89': -0.0319}},
    {c: 'E', h: 0.686, w: 0.756},
    {c: 'F', h: 0.686, w: 0.724, krn: {'111': -0.0958, '101': -0.0958, '117': -0.0958, '114': -0.0958, '97': -0.0958, '65': -0.128, '79': -0.0319, '67': -0.0319, '71': -0.0319, '81': -0.0319}},
    {c: 'G', h: 0.686, w: 0.904},
    {c: 'H', h: 0.686, w: 0.9},
    {c: 'I', h: 0.686, w: 0.436, krn: {'73': 0.0319}},
    {c: 'J', h: 0.686, w: 0.594},
    {c: 'K', h: 0.686, w: 0.901, krn: {'79': -0.0319, '67': -0.0319, '71': -0.0319, '81': -0.0319}},
    {c: 'L', h: 0.686, w: 0.692, krn: {'84': -0.0958, '89': -0.0958, '86': -0.128, '87': -0.128}},
    {c: 'M', h: 0.686, w: 1.09},
    {c: 'N', h: 0.686, w: 0.9},
    {c: 'O', h: 0.686, w: 0.864, krn: {'88': -0.0319, '87': -0.0319, '65': -0.0319, '86': -0.0319, '89': -0.0319}},
    // 50 - 5F
    {c: 'P', h: 0.686, w: 0.786, krn: {'65': -0.0958, '111': -0.0319, '101': -0.0319, '97': -0.0319, '46': -0.0958, '44': -0.0958}},
    {c: 'Q', h: 0.686, d: 0.194, w: 0.864},
    {c: 'R', h: 0.686, w: 0.862, krn: {'116': -0.0319, '67': -0.0319, '79': -0.0319, '71': -0.0319, '85': -0.0319, '81': -0.0319, '84': -0.0958, '89': -0.0958, '86': -0.128, '87': -0.128}},
    {c: 'S', h: 0.686, w: 0.639},
    {c: 'T', h: 0.686, w: 0.8, krn: {'121': -0.0319, '101': -0.0958, '111': -0.0958, '114': -0.0958, '97': -0.0958, '65': -0.0958, '117': -0.0958}},
    {c: 'U', h: 0.686, w: 0.885},
    {c: 'V', h: 0.686, w: 0.869, ic: 0.016, krn: {'111': -0.0958, '101': -0.0958, '117': -0.0958, '114': -0.0958, '97': -0.0958, '65': -0.128, '79': -0.0319, '67': -0.0319, '71': -0.0319, '81': -0.0319}},
    {c: 'W', h: 0.686, w: 1.19, ic: 0.016, krn: {'111': -0.0958, '101': -0.0958, '117': -0.0958, '114': -0.0958, '97': -0.0958, '65': -0.128, '79': -0.0319, '67': -0.0319, '71': -0.0319, '81': -0.0319}},
    {c: 'X', h: 0.686, w: 0.869, krn: {'79': -0.0319, '67': -0.0319, '71': -0.0319, '81': -0.0319}},
    {c: 'Y', h: 0.686, w: 0.869, ic: 0.0287, krn: {'101': -0.0958, '111': -0.0958, '114': -0.0958, '97': -0.0958, '65': -0.0958, '117': -0.0958}},
    {c: 'Z', h: 0.686, w: 0.703},
    {c: '[', h: 0.75, d: 0.25, w: 0.319},
    {c: '\\', h: 0.694, w: 0.603},
    {c: ']', h: 0.75, d: 0.25, w: 0.319},
    {c: '^', h: 0.694, w: 0.575},
    {c: '_', h: 0.694, w: 0.319},
    // 60 - 6F
    {c: '&#x60;', h: 0.694, w: 0.319, lig: {'96': 92}},
    {c: 'a', h: 0.444, w: 0.559, krn: {'118': -0.0319, '106': 0.0639, '121': -0.0319, '119': -0.0319}},
    {c: 'b', h: 0.694, w: 0.639, krn: {'101': 0.0319, '111': 0.0319, '120': -0.0319, '100': 0.0319, '99': 0.0319, '113': 0.0319, '118': -0.0319, '106': 0.0639, '121': -0.0319, '119': -0.0319}},
    {c: 'c', h: 0.444, w: 0.511, krn: {'104': -0.0319, '107': -0.0319}},
    {c: 'd', h: 0.694, w: 0.639},
    {c: 'e', h: 0.444, w: 0.527},
    {c: 'f', h: 0.694, w: 0.351, ic: 0.109, krn: {'39': 0.109, '63': 0.109, '33': 0.109, '41': 0.109, '93': 0.109}, lig: {'105': 12, '102': 11, '108': 13}},
    {c: 'g', h: 0.444, d: 0.194, w: 0.575, ic: 0.016, krn: {'106': 0.0319}},
    {c: 'h', h: 0.694, w: 0.639, krn: {'116': -0.0319, '117': -0.0319, '98': -0.0319, '121': -0.0319, '118': -0.0319, '119': -0.0319}},
    {c: 'i', h: 0.694, w: 0.319},
    {c: 'j', h: 0.694, d: 0.194, w: 0.351},
    {c: 'k', h: 0.694, w: 0.607, krn: {'97': -0.0639, '101': -0.0319, '97': -0.0319, '111': -0.0319, '99': -0.0319}},
    {c: 'l', h: 0.694, w: 0.319},
    {c: 'm', h: 0.444, w: 0.958, krn: {'116': -0.0319, '117': -0.0319, '98': -0.0319, '121': -0.0319, '118': -0.0319, '119': -0.0319}},
    {c: 'n', h: 0.444, w: 0.639, krn: {'116': -0.0319, '117': -0.0319, '98': -0.0319, '121': -0.0319, '118': -0.0319, '119': -0.0319}},
    {c: 'o', h: 0.444, w: 0.575, krn: {'101': 0.0319, '111': 0.0319, '120': -0.0319, '100': 0.0319, '99': 0.0319, '113': 0.0319, '118': -0.0319, '106': 0.0639, '121': -0.0319, '119': -0.0319}},
    // 70 - 7F
    {c: 'p', h: 0.444, d: 0.194, w: 0.639, krn: {'101': 0.0319, '111': 0.0319, '120': -0.0319, '100': 0.0319, '99': 0.0319, '113': 0.0319, '118': -0.0319, '106': 0.0639, '121': -0.0319, '119': -0.0319}},
    {c: 'q', h: 0.444, d: 0.194, w: 0.607},
    {c: 'r', h: 0.444, w: 0.474},
    {c: 's', h: 0.444, w: 0.454},
    {c: 't', h: 0.635, w: 0.447, krn: {'121': -0.0319, '119': -0.0319}},
    {c: 'u', h: 0.444, w: 0.639, krn: {'119': -0.0319}},
    {c: 'v', h: 0.444, w: 0.607, ic: 0.016, krn: {'97': -0.0639, '101': -0.0319, '97': -0.0319, '111': -0.0319, '99': -0.0319}},
    {c: 'w', h: 0.444, w: 0.831, ic: 0.016, krn: {'101': -0.0319, '97': -0.0319, '111': -0.0319, '99': -0.0319}},
    {c: 'x', h: 0.444, w: 0.607},
    {c: 'y', h: 0.444, d: 0.194, w: 0.607, ic: 0.016, krn: {'111': -0.0319, '101': -0.0319, '97': -0.0319, '46': -0.0958, '44': -0.0958}},
    {c: 'z', h: 0.444, w: 0.511},
    {c: '&#x7B;', h: 0.444, w: 0.575, ic: 0.0319, lig: {'45': 124}},
    {c: '&#x7C;', h: 0.444, w: 1.15, ic: 0.0319},
    {c: '&#x7D;', h: 0.694, w: 0.575},
    {c: '&#x7E;', h: 0.694, w: 0.575},
    {c: '&#xC4;', h: 0.694, w: 0.575}
  ]
});

/***************************************************************************/

/*
 *  jsMath.HTML handles creation of most of the HTML needed for
 *  presenting mathematics in HTML pages.
 */

jsMath.HTML = {
  
  /*
   *  produce a string version of a measurement in ems,
   *  showing only a limited number of digits, and 
   *  using 0 when the value is near zero.
   */
  Em: function (m) {
    var n = 5; if (m < 0) {n++}
    if (Math.abs(m) < .000001) {m = 0}
    var s = String(m); s = s.replace(/(\.\d\d\d).+/,'$1');
    return s+'em'
  },

  /*
   *  Create a horizontal space of width w
   */
  Spacer: function (w) {
    if (w == 0) {return ''};
    return '<SPAN STYLE="margin-left: '+this.Em(w)+'"></SPAN>';
  },

  /*
   *  Use an image to create a horizontal space of width w
   */
  SpacerImage: function (w) {
    if (w == 0) {return ''};
    return '<IMG SRC="'+jsMath.blank+'" STYLE="'
             + ' width: 0; margin-left: '+this.Em(w)+'">';
  },

  /*
   *  Create a colored frame (for debugging use)
   */
  Frame: function (x,y,w,h,c,pos) {

//    if (!c) {c = 'black'};
//    if (pos) {pos = 'absolute;'} else
//             {pos = 'relative; margin-right: '+this.Em(-w-.1)+'; '}
//    return '<IMG SRC="blank.gif" STYLE="position:' + pos
//             + 'vertical-align: '+this.Em(y)+'; left: '+this.Em(x)+'; '
//             + 'width:'+this.Em(w)+'; height: '+this.Em(h)+'; '
//             + 'border-color: '+c+'; border-style: solid; border-width: 1px;">';

    h = Math.round(h*jsMath.em)-2; // use pixels to compensate for border size
    w = Math.round(w*jsMath.em)-2;
    y = Math.round(y*jsMath.em)-1;
    if (!c) {c = 'black'};
    if (pos) {pos = 'absolute;'} else
             {pos = 'relative; margin-right: '+(-w-2)+'px; '}
    return '<IMG SRC="'+jsMath.blank+'" STYLE="position:' + pos
             + 'vertical-align: '+y+'px; left: '+this.Em(x)+'; '
             + 'width:'+w+'px; height: '+h+'px; '
             + 'border-color: '+c+'; border-style: solid; border-width: 1px;">';
  },

  /*
   *  Create a 1-pixel-high horizontal line at a particular
   *  position, width and color.
   */
  Line: function (x,y,w,c,pos) {
    if (!c) {c = 'black'};
    if (pos) {pos = 'absolute;'} else
             {pos = 'relative; margin-right: '+this.Em(-w)+'; '}
    return '<IMG SRC="'+jsMath.blank+'" STYLE="position:'+pos
             + 'top: '+this.Em(-y)+'; left:'+this.Em(x)+'; '
             + 'width:'+this.Em(w)+'; height:1px; background-color: '+c+';">';
  },

  /*
   *  Create a black rule line for fractions, etc.
   *  Height is converted to pixels (with a minimum of 1), so that
   *    the line will not disappear at small font sizes.  This means that
   *    the thickness will not change if you change the font size, or
   *    may not be correct within a header or other enlarged text.
   */
  Rule: function (w,h) {
    if (h == null) {h = jsMath.TeX.default_rule_thickness}
    if (w == 0 || h == 0) return;  // should make an invisible box?
    h *= jsMath.em; h = Math.round(h);
    if (h < 1) {h = 1}
    return '<IMG SRC="'+jsMath.black+'" HSPACE="0" VSPACE="0" '
              + 'STYLE="width:'+this.Em(w)+'; height: '+h+'px">';
  },

  /*
   *  Create a colored block of a specific size (won't always print
   *  correctly).
   */
  Block: function (w,h,c) {
    if (c == null) {c = 'black'}
    return '<IMG SRC="'+jsMath.blank+'" HSPACE="0" VSPACE="0" '
            +      'STYLE="width:'+this.Em(w)+'; height: '+this.Em(h)+'; '
            +      'background-color: '+c+'">';
  },

  /*
   *  Add a <SPAN> tag to activate a specific CSS class
   */
  Class: function (tclass,html) {
    return '<SPAN CLASS="'+tclass+'">'+html+'</SPAN>';
  },
  
  /*
   *  Use a <SPAN> to place some HTML at a specific position.
   *  (This can be replaced by the ones below to overcome
   *   some browser-specific bugs.)
   */
  Place: function (html,x,y) {
    if (Math.abs(x) < .0001) {x = 0}
    if (Math.abs(y) < .0001) {y = 0}
    if (x || y) {
      var span = '<SPAN STYLE="position: relative;';
      if (x) {span += ' margin-left:'+this.Em(x)+';'}
      if (y) {span += ' top:'+this.Em(-y)+';'}
      html = span + '">' + html + '</SPAN>';
    }
    return html;
  },
  
  /*
   *  For MSIE on Windows, backspacing must be done in a separate
   *  <SPAN>, otherwise the contents will be clipped.
   */
  PlaceSeparateNegative: function (html,x,y) {
    if (Math.abs(x) < .0001) {x = 0}
    if (Math.abs(y) < .0001) {y = 0}
    if (x > 0 || y) {
      var span = '<SPAN STYLE="position: relative;';
      if (x > 0) {span += ' margin-left:'+this.Em(x)+';'}
      if (y) {span += ' top:'+this.Em(-y)+';'}
      html = span + '">' + html + '</SPAN>';
    }
    if (x < 0) {html = '<SPAN STYLE="margin-left:'+this.Em(x)+';"></SPAN>' + html}
    return html;
  },

  /*
   *  Here the x and y positioning is done in separate <SPAN> tags
   */
  PlaceSeparateSkips: function (html,x,y) {
    if (Math.abs(x) < .0001) {x = 0}
    if (Math.abs(y) < .0001) {y = 0}
    if (y) {html = '<SPAN STYLE="position: relative; top:'+this.Em(-y)+';'
                       + '">' + html + '</SPAN>'}
    if (x) {html = '<SPAN STYLE="margin-left:'+this.Em(x)+';"></SPAN>' + html}
    return html;
  }

};


/***************************************************************************/

/*
 *  jsMath.Box handles TeX's math boxes and jsMath's equivalent of hboxes.
 */

jsMath.Box = function (format,text,w,h,d) {
  if (d == null) {d = jsMath.d}
  this.type = 'typeset';
  this.w = w; this.h = h; this.d = d; this.bh = h; this.bd = d;
  this.x = 0; this.y = 0;
  this.html = text; this.format = format;
};


jsMath.Add(jsMath.Box,{

  /*
   *  An empty box
   */
  Null: new jsMath.Box('null','',0,0,0),

  /*
   *  A box containing only text whose class and style haven't been added
   *  yet (so that we can combine ones with the same styles).  It gets
   *  the text dimensions, if needed.  (In general, this has been
   *  replaced by TeX() below.)
   */
  Text: function (text,tclass,style,a,d) {
    var html = jsMath.Typeset.AddClass(tclass,text);
        html = jsMath.Typeset.AddStyle(style,html);
    var BB = jsMath.EmBoxFor(html); var TeX = jsMath.Typeset.TeX(style);
    var bd = ((tclass == 'cmsy10' || tclass == 'cmex10')? BB.h-TeX.h: TeX.d*BB.h/TeX.hd);
    var box = new jsMath.Box('text',text,BB.w,BB.h-bd,bd);
    box.style = style; box.tclass = tclass;
    if (d != null) {if (d != 1) {box.d = d}} else {box.d = 0}
    if (a == null || a == 1) {box.h = .9*TeX.M_height}
      else {box.h = 1.1*TeX.x_height + a}
    return box;
  },

  /*
   *  Produce a box containing a given TeX character from a given font.
   *  The box is a text box (like the ones above), so that characters from
   *  the same font can be combined.
   */
  TeX: function (c,font,style) {
    c = jsMath.TeX[font][c];
    if (c.d == null) {c.d = 0}; if (c.h == null) {c.h = 0}
    var scale = jsMath.Typeset.TeX(style).quad;
    var h = c.h + jsMath.TeX[font].dh
    var box = new jsMath.Box('text',c.c,c.w*scale,h*scale,c.d*scale);
    box.style = style;
    if (c.tclass) {
      box.tclass = c.tclass;
      box.bh = scale*jsMath.h;
      box.bd = scale*jsMath.d;
    } else {
      box.tclass = font;
      box.bh = scale*jsMath.TeX[font].h;
      box.bd = scale*jsMath.TeX[font].d;
      if (jsMath.msieFontBug) {
        // hack to avoid Font changing back to the default
        // font when a unicode reference is not followed
        // by a letter or number
        box.html += '<SPAN STYLE="display: none">x</SPAN>'
      }
    }
    return box;
  },

  /*
   *  A box containing a spacer of a specific width
   */
  Space: function (w) {
    return new jsMath.Box('html',jsMath.HTML.Spacer(w),w,0,0);
  },

  /*
   *  A box containing a horizontal rule
   */
  Rule: function (w,h) {
    if (h == null) {h = jsMath.TeX.default_rule_thickness}
    html = jsMath.HTML.Rule(w,h);
    return new jsMath.Box('html',html,w,h,0);
  },

  /*
   *  A box containing a colored block
   */
  Block: function (w,h,c) {
    return new jsMath.Box('html',jsMath.HTML.Block(w,h,c),w,h,0);
  },
  
  /*
   *  Get a character from a TeX font, and make sure that it has
   *  its metrics specified.
   */
  GetChar: function (code,font) {
    var c = jsMath.TeX[font][code];
    if (c.tclass == null) {c.tclass = font}
    if (!c.computedW) {
      c.w = jsMath.EmBoxFor(jsMath.HTML.Class(c.tclass,c.c)).w;
      if (c.h == null) {c.h = jsMath.defaultH}; if (c.d == null) {c.d = 0}
      c.computedW = 1;
    }
    return c;
  },
  
  /*
   *  Locate the TeX delimiter character that matches a given height.
   *  Return the character, font, style and actual height used.
   */
  DelimBestFit: function (H,c,font,style) {
    if (c == 0 && font == 0) return;
    var C; var h; font = jsMath.TeX.fam[font];
    var isSS = (style.charAt(1) == 'S');
    var isS  = (style.charAt(0) == 'S');
    while (c != null) {
      C = jsMath.TeX[font][c];
      if (C.h == null) {C.h = jsMath.defaultH}; if (C.d == null) {C.d = 0}
      h = C.h+C.d;
      if (C.delim) {return [c,font,'',H]}
      if (isSS && .6*h >= H) {return [c,font,'SS',.6*h]}
      if (isS && .75*h >= H) {return [c,font,'S',.75*h]}
      if (h >= H || C.n == null) {return [c,font,'T',h]}
      c = C.n
    }
  },
  
  /*
   *  Create the HTML needed for a stretchable delimiter of a given height,
   *  either centered or not.  This version uses relative placement (i.e.,
   *  backspaces, not line-breaks).  This works with more browsers, but
   *  if the font size changes, the backspacing may not be right, so the
   *  delimiters may become jagged.
   */
  DelimExtendRelative: function (H,c,font,a,nocenter) {
    var C = jsMath.TeX[font][c];
    var top = this.GetChar(C.delim.top? C.delim.top: C.delim.rep,font);
    var rep = this.GetChar(C.delim.rep,font);
    var bot = this.GetChar(C.delim.bot? C.delim.bot: C.delim.rep,font);
    var ext = jsMath.HTML.Class(rep.tclass,rep.c);
    var w = rep.w; var h = rep.h+rep.d
    var y; var dx;
    if (C.delim.mid) {// braces
      var mid = this.GetChar(C.delim.mid,font);
      var n = Math.ceil((H-(top.h+top.d)-(mid.h+mid.d)-(bot.h+bot.d))/(2*(rep.h+rep.d)));
      H = 2*n*(rep.h+rep.d) + (top.h+top.d) + (mid.h+mid.d) + (bot.h+bot.d);
      if (nocenter) {y = 0} else {y = H/2+a}; var Y = y;
      var html = jsMath.HTML.Place(jsMath.HTML.Class(top.tclass,top.c),0,y-top.h)
               + jsMath.HTML.Place(jsMath.HTML.Class(bot.tclass,bot.c),-(top.w+bot.w)/2,y-(H-bot.d))
               + jsMath.HTML.Place(jsMath.HTML.Class(mid.tclass,mid.c),-(bot.w+mid.w)/2,y-(H+mid.h-mid.d)/2);
      dx = (w-mid.w)/2; if (Math.abs(dx) < .0001) {dx = 0}
      if (dx) {html += jsMath.HTML.Spacer(dx)}
      y -= top.h+top.d + rep.h;
      for (var i = 0; i < n; i++) {html += jsMath.HTML.Place(ext,-w,y-i*h)}
      y -= H/2 - rep.h/2;
      for (var i = 0; i < n; i++) {html += jsMath.HTML.Place(ext,-w,y-i*h)}
    } else {// everything else
      var n = Math.ceil((H - (top.h+top.d) - (bot.h+bot.d))/(rep.h+rep.d));
      // make sure two-headed arrows have an extender
      if (top.h+top.d < .9*(rep.h+rep.d)) {n = Math.max(1,n)}
      H = n*(rep.h+rep.d) + (top.h+top.d) + (bot.h+bot.d);
      if (nocenter) {y = 0} else {y = H/2+a}; var Y = y;
      var html = jsMath.HTML.Place(jsMath.HTML.Class(top.tclass,top.c),0,y-top.h)
      dx = (w-top.w)/2; if (Math.abs(dx) < .0001) {dx = 0}
      if (dx) {html += jsMath.HTML.Spacer(dx)}
      y -= top.h+top.d + rep.h;
      for (var i = 0; i < n; i++) {html += jsMath.HTML.Place(ext,-w,y-i*h)}
      html += jsMath.HTML.Place(jsMath.HTML.Class(bot.tclass,bot.c),-(w+bot.w)/2,Y-(H-bot.d));
    }
    if (nocenter) {h = top.h} else {h = H/2+a}
    var box = new jsMath.Box('html',html,rep.w,h,H-h);
    box.bh = jsMath.TeX[font].h; box.bd = jsMath.TeX[font].d;
    return box;
  },

  /*
   *  Create the HTML needed for a stretchable delimiter of a given height,
   *  either centered or not.  This version uses absolute placement (i.e.,
   *  line-breaks, not backspacing).  This gives more reliable results,
   *  but doesn't work with all browsers.
   */
  DelimExtendAbsolute: function (H,c,font,a,nocenter) {
    var Font = jsMath.TeX[font];
    var C = Font[c];
    var top = this.GetChar(C.delim.top? C.delim.top: C.delim.rep,font);
    var rep = this.GetChar(C.delim.rep,font);
    var bot = this.GetChar(C.delim.bot? C.delim.bot: C.delim.rep,font);
    rep.h = 0; // fix adjusted heights
    
    if (C.delim.mid) {// braces
      var mid = this.GetChar(C.delim.mid,font);
      var n = Math.ceil((H-(top.h+top.d)-(mid.h+mid.d)-(bot.h+bot.d))/(2*(rep.h+rep.d)));
      H = 2*n*(rep.h+rep.d-.05) + (top.h+top.d) + (mid.h+mid.d) + (bot.h+bot.d);
      
      html = jsMath.HTML.Place(jsMath.HTML.Class(top.tclass,top.c),0,-top.h);
      var h = rep.h+rep.d - Font.hd; var y = -(top.h+top.d + rep.h) + Font.hd;
      var ext = jsMath.HTML.Class(font,rep.c)
      for (var i = 0; i < n; i++) {html += '<BR>'+jsMath.HTML.Place(ext,0,y-i*h)}
      html += '<BR>' + jsMath.HTML.Place(jsMath.HTML.Class(mid.tclass,mid.c),0,y-i*h);
      y -= i*h+mid.h+mid.d - Font.hd;
      for (var i = 0; i < n; i++) {html += '<BR>'+jsMath.HTML.Place(ext,0,y-i*h)}
      html += '<BR>' + jsMath.HTML.Place(jsMath.HTML.Class(bot.tclass,bot.c),0,y-i*h);
    } else {// all others
      var n = Math.ceil((H - (top.h+top.d) - (bot.h+bot.d))/(rep.h+rep.d-.1));
      H = n*(rep.h+rep.d-.1) + (top.h+top.d) + (bot.h+bot.d);

      html = jsMath.HTML.Place(jsMath.HTML.Class(top.tclass,top.c),0,-top.h);
      var h = rep.h+rep.d-.1 - Font.hd; var y = -(top.h+top.d + rep.h) + Font.hd;
      var ext = jsMath.HTML.Class(rep.tclass,rep.c)
      for (var i = 0; i < n; i++) {html += '<BR>'+jsMath.HTML.Place(ext,0,y-i*h)}
      html += '<BR>' + jsMath.HTML.Place(jsMath.HTML.Class(bot.tclass,bot.c),0,y-i*h);
    }
    
    var w = top.w; h = Font.h; 
    if (nocenter) {y = top.h} else {y = (H/2 + a) - top.h}
    if (jsMath.isSafari) {y -= .175}
    html = '<SPAN STYLE="position: relative; '
           +   'width: '+jsMath.HTML.Em(w)+'; ' // for MSIE
           +   'height: '+jsMath.HTML.Em(top.h)+'; ' //for MSIE
           +   '">'
             + '<SPAN STYLE="position: absolute; '
               +   'top: '+jsMath.HTML.Em(-y)+'; '
               +   'left: 0;">'
               + html
             + '</SPAN>'
             + '<IMG SRC="'+jsMath.blank+'" STYLE="width: '+jsMath.HTML.Em(w)+'; '
                        + 'height: '+jsMath.HTML.Em(h)+';">'
         + '</SPAN>';

    if (nocenter) {h = top.h} else {h = H/2+a}
    return new jsMath.Box('html',html,rep.w,h,H-h);
  },
  
  /*
   *  Get the HTML for a given delimiter of a given height.
   *  It will return either a single character, if one exists, or the
   *  more complex HTML needed for a stretchable delimiter.
   */
  Delimiter: function (H,delim,style,nocenter) {
    var TeX = jsMath.Typeset.TeX(style);
    var CFSH = this.DelimBestFit(H,(delim&0xFF000)>>12,(delim&0xF00000)>>20,style);
    if (CFSH == null || CFSH[3] < H) 
      {CFSH = this.DelimBestFit(H,(delim&0xFF),(delim&0xF00)>>8,style)}
    if (CFSH == null) {return this.Space(TeX.nulldelimiterspace)}
    if (CFSH[2] == '')
      {return this.DelimExtend(H,CFSH[0],CFSH[1],TeX.axis_height,nocenter)}
    box = jsMath.Box.TeX(CFSH[0],CFSH[1],CFSH[2]).Styled();
    if (nocenter) {
      box.h -= jsMath.TeX[CFSH[1]].dh;
      box.d += jsMath.TeX[CFSH[1]].dh;
    } else {
      box.y = -((box.h+box.d)/2 - box.d - TeX.axis_height);
      if (Math.abs(box.y) < .0001) {box.y = 0}
      if (box.y) {box = jsMath.Box.SetList([box],CFSH[2])}
    }
    return box;
  },
  
  /*
   *  Get a character by its TeX charcode, and make sure its width
   *  is specified.
   */
  GetCharCode: function (code) {
    var font = jsMath.TeX.fam[(code&0xF00)>>8];
    var Font = jsMath.TeX[font];
    var c = Font[code & 0xFF];
    if (c.w == null) {c.w = jsMath.EmBoxFor(jsMath.HTML.Class(c.tclass,c.c)).w}
    if (c.tclass == null) {c.tclass = font}
    return c;
  },
  
  /*
   *  Create a horizontally stretchable "delimiter" (like over- and
   *  underbraces).
   */
  Leaders: function (W,leader) {
    var h; var d; var w; var html; var font;
    if (leader.lmid) {// braces
      font = jsMath.TeX.fam[(leader.left & 0xF00) >> 8];
      var left = this.GetCharCode(leader.left);
      var right = this.GetCharCode(leader.right);
      var lmid = this.GetCharCode(leader.lmid);
      var rmid = this.GetCharCode(leader.rmid);
      w = (W - left.w - right.w - lmid.w - rmid.w)/2 - .1; h = .4; d = .3;
      if (w > 0) {
        html = jsMath.HTML.Class(left.tclass,left.c) 
             + jsMath.HTML.Rule(w,left.h)
             + jsMath.HTML.Class(lmid.tclass,lmid.c+rmid.c)
             + jsMath.HTML.Rule(w,right.h)
             + jsMath.HTML.Class(right.tclass,right.c);
      } else {
        html = jsMath.HTML.Class(left.tclass,left.c + lmid.c + rmid.c + right.c);
      }
    } else { //arrows
      font = jsMath.TeX.fam[(leader.rep &0xF00) >> 8];
      var left = this.GetCharCode(leader.left? leader.left: leader.rep);
      var rep = this.GetCharCode(leader.rep);
      var right = this.GetCharCode(leader.right? leader.right: leader.rep);
      var n = Math.ceil((W - left.w - right.w + .4)/(rep.w - .3));
      w = (W - left.w - right.w + .4 - n*(rep.w - .3));
      if (leader.left) {h = left.h; d = left.d} else {h = right.h; d = right.d}
      if (d == null) {d = 0}; if (h == null) {h = 0}
      var html = jsMath.HTML.Class(left.tclass,left.c); var m = Math.floor(n/2);
      var ext = jsMath.HTML.Place(rep.c,-.3,0);
      var ehtml = ''; for (var i = 0; i < m; i++) {ehtml += ext};
      html += jsMath.HTML.Class(rep.tclass,ehtml) + jsMath.HTML.Spacer(w);
      ehtml = ''; for (var i = m; i < n; i++) {ehtml += ext};
      html += jsMath.HTML.Class(rep.tclass,ehtml);
      if (jsMath.msieFontBug) {html += '<SPAN STYLE="display: none">x</SPAN>'}
      html += jsMath.HTML.Place(jsMath.HTML.Class(right.tclass,right.c),-.4,0);
    }
    w = jsMath.EmBoxFor(html).w;
    if (w != W) {
      w = jsMath.HTML.Spacer((W-w)/2);
      html = w + html + w;
    }
    var box = new jsMath.Box('html',html,W,h,d);
    box.bh = jsMath.TeX[font].h; box.bd = jsMath.TeX[font].d;
    return box;
  },
  
  /*
   *  Create the HTML for an alignment (e.g., array or matrix)
   *  Since the widths are not really accurate (they are based on pixel
   *  widths not the sub-pixel widths of the actual characters), there
   *  is some drift involved.  We lay out the table column by column
   *  to help reduce the problem.
   *  
   *  ###  still need to allow users to specify row and column attributes,
   *       and do things like \span and \multispan  ###
   */
  Layout: function (table,align) {
    if (align == null) {align = []}
    
    // get row and column maximum dimensions
    var W = []; var H = []; var D = [];
    var unset = -1000; var bh = unset; var bd = unset;
    var i; var j; var row;
    for (i = 0; i < table.length; i++) {
      row = table[i]; H[i] = jsMath.h; D[i] = jsMath.d;
      for (j = 0; j < row.length; j++) {
        if (row[j].h > H[i]) {H[i] = row[j].h}
        if (row[j].d > D[i]) {D[i] = row[j].d}
        if (j >= W.length) {W[j] = row[j].w}
        else if (row[j].w > W[j]) {W[j] = row[j].w}
        if (row[j].bh > bh) {bh = row[j].bh}
        if (row[j].bd > bd) {bd = row[j].bd}
      }
    }
    if (bh == unset) {bh = 0}; if (bd == unset) {bd = 0}

    // lay out the columns
    var html = ''; var pW = 0; var cW = 0;
    var w; var h; var y;
    var box; var mlist; var entry;
    for (j = 0; j < W.length; j++) {
      mlist = []; y = -H[0]; pW = 0;
      for (i = 0; i < table.length; i++) {
        entry = table[i][j];
        if (entry && entry.format != 'null') {
          if (align[j] == 'l') {w = 0} else
          if (align[j] == 'r') {w = W[j] - entry.w} else
            {w = (W[j] - entry.w)/2}
          entry.x = w - pW; pW = entry.w + w; entry.y = y;
          mlist[mlist.length] = entry;
        }
        if (i == table.length-1) {y -= D[i]}
        else {y -= Math.max(jsMath.hd-.1,D[i]+H[i+1]) + .1}
      }
      if (mlist.length > 0) {
        box = jsMath.Box.SetList(mlist,'T');
        html += jsMath.HTML.Place(box.html,cW,0);
        cW = W[j] - box.w + 1;
      } else {cW += 1}
    }
    
    // get the full width and height
    w = -1; for (i = 0; i < W.length; i++) {w += W[i] + 1}
    h = jsMath.TeX.axis_height-y/2;
    
    // adjust the final row width, and vcenter the table
    //   (add 1/6em at each side for the \,)
    html += jsMath.HTML.Spacer(cW-1 + 1/6);
    html = jsMath.HTML.Place(html,1/6,h);
    box = new jsMath.Box('html',html,w+1/3,h,-y-h);
    box.bh = bh; box.bd = bd;
    return box;
  },

  /*
   *  Look for math within \hbox and other non-math text
   */
  InternalMath: function (text) {
    if (!text.match(/\$|\\\(/)) {return this.Text(text,'nonmath','T').Styled()}
    
    var i = 0; var k = 0; var c; var match = '';
    var mlist = []; var parse; var html; var box;
    while (i < text.length) {
      c = text.charAt(i++);
      if (c == '$') {
        if (match == '$') {
          parse = jsMath.Parse(text.slice(k,i-1));
          if (parse.error) {
            mlist[mlist.length] = this.Text(parse.error,'error','T',1,1);
          } else {
            parse.Atomize('T');
            mlist[mlist.length] = parse.mlist.Typeset('T').Styled();
          }
          match = ''; k = i;
        } else {
          mlist[mlist.length] = this.Text(text.slice(k,i-1),'nonmath','T',1,1);
          match = '$'; k = i;
        }
      } else if (c == '\\') {
        c = text.charAt(i++);
        if (c == '(' && match == '') {
          mlist[mlist.length] = this.Text(text.slice(k,i-2),'nonmath','T',1,1);
          match = ')'; k = i;
        } else if (c == ')' && match == ')') {
          parse = jsMath.Parse(text.slice(k,i-2));
          if (parse.error) {
            mlist[mlist.length] = this.Text(parse.error,'error','T',1,1);
          } else {
            parse.Atomize('T');
            mlist[mlist.length] = parse.mlist.Typeset('T').Styled();
          }
          match = ''; k = i;
        }
      }
    }
    mlist[mlist.length] = this.Text(text.slice(k),'nonmath','T',1,1);
    return this.SetList(mlist,'T');
  },
  
  /*
   *  Convert an abitrary box to a typeset box.  I.e., make an
   *  HTML version of the contents of the box, at its desired (x,y)
   *  position.
   */
  Set: function (box,style,addstyle) {
    if (box) {
      if (box.type == 'typeset') {return box}
      if (box.type == 'mlist') {
        box.mlist.Atomize(style);
        return box.mlist.Typeset(style);
      }
      if (box.type == 'text') {
        box = this.Text(box.text,box.tclass,style,box.ascend,box.descend);
        if (addstyle != 0) {box.Styled()}
        return box;
      }
      box = this.TeX(box.c,box.font,style);
      if (addstyle != 0) {box.Styled()}
      return box;
    }
    return jsMath.Box.Null;
  },

  /*
   *  Convert a list of boxes to a single typeset box.  I.e., finalize
   *  the HTML for the list of boxes, properly spaced and positioned.
   */
  SetList: function (boxes,style) {
    var mlist = []; var box;
    for (var i = 0; i < boxes.length; i++) {
      box = boxes[i];
      if (box.type == 'typeset') {box = new jsMath.mItem.Typeset(box)}
      mlist[mlist.length] = box;
    }
    var typeset = new jsMath.Typeset(mlist);
    return typeset.Typeset(style);
  }

});


jsMath.Package(jsMath.Box,{

  /*
   *  Add the class and style to a text box (i.e., finalize the
   *  unpositioned HTML for the box).
   */
  Styled: function () {
    if (this.format == 'text') {
      this.html = jsMath.Typeset.AddClass(this.tclass,this.html);
      this.html = jsMath.Typeset.AddStyle(this.style,this.html);
//      var BB = jsMath.EmBoxFor(this.html);
//      this.w = BB.w;
      delete this.tclass; delete this.style;
      this.format = 'html';
    }
    return this;
  }

});


/***************************************************************************/

/*
 *  mItems are the buiulding blocks of mLists (math lists) used to
 *  store the information about a mathematical expression.  These are
 *  basically the items listed in the TeXbook in Appendix G (plus some
 *  minor extensions).
 */
jsMath.mItem = function (type,def) {
  this.type = type;
  jsMath.Add(this,def);
}

jsMath.Add(jsMath.mItem,{

  /*
   *  a general atom (given a nucleus for the atom)
   */
  Atom: function (type,nucleus) {
    return new jsMath.mItem(type,{atom: 1, nuc: nucleus});
  },

  /*
   *  An atom whose nucleus is a piece of text, in a given
   *  class, with a given additional height and depth
   */
  TextAtom: function (type,text,tclass,a,d) {
    var atom = new jsMath.mItem(type,{
      atom: 1,
      nuc: {
        type: 'text',
        text: text,
        tclass: tclass
      }
    });
    if (a != null)   {atom.nuc.ascend = a}
    if (d != null)   {atom.nuc.descend = d}
    return atom;
  },
  
  /*
   *  An atom whose nucleus is a TeX character in a specific font
   */
  TeXAtom: function (type,c,font) {
    return new jsMath.mItem(type,{
      atom: 1,
      nuc: {
        type: 'TeX',
        c: c,
        font: font
      }
    });
  },

  /*
   *  A generalized fraction atom, with given delimiters, rule
   *  thickness, and a numerator and denominator.
   */
  Fraction: function (name,num,den,thickness,left,right) {
    return new jsMath.mItem('fraction',{
      from: name, num: num, den: den,
      thickness: thickness, left: left, right: right
    });
  },

  /*
   *  An atom that inserts some glue
   */
  Space: function (w) {return new jsMath.mItem('space',{w: w})},

  /*
   *  An atom that contains a typeset box (like an hbox or vbox)
   */
  Typeset: function (box) {return new jsMath.mItem('box',{nuc: box})},
  
  /*
   *  An atom that contains some finished HTML (acts like a typeset box)
   */
  HTML: function (html) {return new jsMath.mItem('html',{html: html})}

});

/***************************************************************************/

/*
 *  mLists are lists of mItems, and encode the contents of
 *  mathematical expressions and sub-expressions.  They act as
 *  the expression "stack" as the mathematics is parsed, and
 *  contain some state information, like the position of the
 *  most recent open paren and \over command, and the current font.
 */
jsMath.mList = function (list) {
  if (list) {this.mlist = list} else {this.mlist = []}
  this.openI = this.overI = this.overF = null;
  this.font = null;
}

jsMath.Package(jsMath.mList,{

  /*
   *  Add an mItem to the list
   */
  Add: function (box) {return (this.mlist[this.mlist.length] = box)},
  
  /*
   *  Get the i-th mItem from the list
   */
  Get: function (i) {return this.mlist[i]},
  
  /*
   *  Get the length of the list
   */
  Length: function() {return this.mlist.length},

  /*
   *  Get the tail mItem of the list
   */
  Last: function () {
    if (this.mlist.length == 0) {return null}
    return this.mlist[this.mlist.length-1]
  },

  /*
   *  Get a sublist of an mList
   */
  Range: function (i,j) {
    if (j == null) {j = this.mlist.length}
    return new jsMath.mList(this.mlist.slice(i,j+1));
  },

  /*
   *  Remove a range of mItems from the list.
   */
  Delete: function (i,j) {
    if (j == null) {j = i}
    if (this.mlist.splice) {this.mlist.splice(i,j-i+1)} else {
      var mlist = [];
      for (var k = 0; k < this.mlist.length; k++)
        {if (k < i || k > j) {mlist[mlist.length] = this.mlist[k]}}
      this.mlist = mlist;
    }
  },

  /*
   *  Add an open brace and maintain the stack information
   *  about the previous open brace so we can recover it
   *  when this one os closed.
   */
  Open: function (left) {
    var box = this.Add(new jsMath.mItem('boundary',
      {overI: this.overI, overF: this.overF,
       openI: this.openI, font: this.font}
    ));
    delete this.overI; delete this.overF;
    this.openI = this.mlist.length-1;
    if (left != null) {box.left = left}
    return box;
  },

  /*
   *  Attempt to close a brace.  Recover the stack information
   *  about previous open braces and \over commands.  If there was an
   *  \over (or \above, etc) in this set of braces, create a fraction
   *  atom from the two halves, otherwise create an inner or ord
   *  from the contents of the braces.
   *  Remove the braced material from the list and add the newly
   *  created atom (the fraction, inner or ord).
   */
  Close: function (right) {
    if (right != null) {right = new jsMath.mItem('boundary',{right: right})}
    var atom; var open = this.openI;
    var over = this.overI; var from = this.overF;
    this.openI = this.mlist[open].openI;
    this.overI = this.mlist[open].overI;
    this.overF = this.mlist[open].overF;
    this.font  = this.mlist[open].font;
    if (over) {
      atom = jsMath.mItem.Fraction(from.name,
        {type: 'mlist', mlist: this.Range(open+1,over-1)},
        {type: 'mlist', mlist: this.Range(over)},
        from.thickness,from.left,from.right);
      if (right) {
        var mlist = new jsMath.mList([this.mlist[open],atom,right]);
        atom = jsMath.mItem.Atom('inner',{type: 'mlist', mlist: mlist});
      }
    } else {
      var openI = open+1; if (right) {this.Add(right); openI--}
      atom = jsMath.mItem.Atom((right)?'inner':'ord',
                  {type: 'mlist', mlist: this.Range(openI)});
    }
    this.Delete(open,this.Length());
    return this.Add(atom);
  },

  /*
   *  Create a generalized fraction from an mlist that
   *  contains an \over (or \above, etc).
   */
  Over: function () {
    var over = this.overI; var from = this.overF
    var atom = jsMath.mItem.Fraction(from.name,
      {type: 'mlist', mlist: this.Range(open+1,over-1)},
      {type: 'mlist', mlist: this.Range(over)},
      from.thickness,from.left,from.right);
    this.mlist = [atom];
  },

  /*
   *  Take a raw mList (that has been produced by parsing some TeX
   *  expression), and perform the modifications outlined in
   *  Appendix G of the TeXbook.  
   */
  Atomize: function (style) {
    var mitem; var prev = '';
    this.style = style;
    for (var i = 0; i < this.mlist.length; i++) {
      mitem = this.mlist[i]; mitem.delta = 0;
      if (mitem.type == 'style') {this.style = mitem.style}
      else if (mitem.type == 'choice') 
        {this.mlist = this.Atomize.choice(this.style,mitem,i,this.mlist); i--}
      else if (this.Atomize[mitem.type]) {
        var f = this.Atomize[mitem.type];
        f(this.style,mitem,prev,this,i);
      }
      prev = mitem;
    }
    if (mitem && mitem.type == 'bin') {mitem.type = 'ord'}
    if (this.mlist.length >= 2 && mitem.type == 'boundary' &&
        this.mlist[0].type == 'boundary') {this.AddDelimiters(style)}
  },

  /*
   *  For a list that has boundary delimiters as its first and last
   *  entries, we replace the boundary atoms by open and close
   *  atoms whose nuclei are the specified delimiters perperly sized
   *  for the contents of the list.  (Rule 19)
   */
  AddDelimiters: function(style) {
    var unset = -10000; var h = unset; var d = unset;
    for (var i = 0; i < this.mlist.length; i++) {
      mitem = this.mlist[i];
      if (mitem.atom || mitem.type == 'box') {
        h = Math.max(h,mitem.nuc.h+mitem.nuc.y);
        d = Math.max(d,mitem.nuc.d-mitem.nuc.y);
      }
    }
    var TeX = jsMath.TeX; var a = jsMath.Typeset.TeX(style).axis_height;
    var delta = Math.max(h-a,d+a);
    var H =  Math.max(Math.floor(TeX.integer*delta/500)*TeX.delimiterfactor,
                      TeX.integer*(2*delta-TeX.delimitershortfall))/TeX.integer;
    var left = this.mlist[0]; var right = this.mlist[this.mlist.length-1];
    left.nuc = jsMath.Box.Delimiter(H,left.left,style);
    right.nuc = jsMath.Box.Delimiter(H,right.right,style);
    left.type = 'open'; left.atom = 1; delete left.left;
    right.type = 'close'; right.atom = 1; delete right.right;
  },

  /*
   *  Typeset a math list to produce final HTML for the list.
   */
  Typeset: function (style) {
    var typeset = new jsMath.Typeset(this.mlist);
    return typeset.Typeset(style);
  }

});


/*
 *  These routines implement the main rules given in Appendix G of the
 *  TeXbook
 */

jsMath.Add(jsMath.mList.prototype.Atomize,{

  /*
   *  Handle a 4-way choice atom.  (Rule 4)
   */
  choice: function (style,mitem,i,mlist) {
    if (style.charAt(style.length-1) == "'") {style = style.slice(0,style.length-1)}
    var nlist = []; var M = mitem[style]; if (!M) {M = {type: 'mlist', mlist: []}}
    if (M.type == 'mlist') {
      M = M.mlist.mlist;
      for (var k = 0; k < i; k++) {nlist[k] = mlist[k]}
      for (k = 0; k < M.length; k++) {nlist[i+k] = M[k]}
      for (k = i+1; k < mlist.length; k++) {nlist[nlist.length] = mlist[k]}
      return nlist;
    } else {
      mlist[i] = jsMath.mItem.Atom('ord',M);
      return mlist;
    }
  },
  
  /*
   *  Create empty boxes of the proper sizes for the various
   *  phantom-type commands
   */
  phantom: function (style,mitem) {
    var box = mitem.nuc = jsMath.Box.Set(mitem.phantom,style);
    if (mitem.h) {box.html = jsMath.HTML.Spacer(box.w)}
      else {box.html = '', box.w = 0}
    if (!mitem.v) {box.h = box.d = 0}
    box.bd = box.bh = 0;
    delete mitem.phantom;
    mitem.type = 'box';
  },
  
  /*
   *  Create a box of zero height and depth containing the
   *  contents of the atom
   */
  smash: function (style,mitem) {
    var box = mitem.nuc = jsMath.Box.Set(mitem.smash,style);
    box.h = box.d = box.bd = box.bh = 0;
    delete mitem.smash;
    mitem.type = 'box';
  },

  /*
   *  Move a box up or down vertically
   */
  raise: function (style,mitem) {
    mitem.nuc = jsMath.Box.Set(mitem.nuc,style);
    var y = mitem.raise;
    mitem.nuc.html = jsMath.HTML.Place(mitem.nuc.html,0,y);
    mitem.nuc.h += y; mitem.nuc.d -= y;
    mitem.type = 'ord'; mitem.atom = 1;
  },

  /*
   *  Hide the size of a box so that it laps to the left or right, or
   *  up or down.
   */
  lap: function (style,mitem) {
    var box = jsMath.Box.Set(mitem.nuc,style);
    var mlist = [box];
    if (mitem.lap == 'llap') {box.x = -box.w} else
    if (mitem.lap == 'rlap') {mlist[1] = jsMath.mItem.Space(-box.w)} else
    if (mitem.lap == 'ulap') {box.y = box.d; box.h = box.d = 0} else
    if (mitem.lap == 'dlap') {box.y = -box.h; box.h = box.d = 0}
    mitem.nuc = jsMath.Box.SetList(mlist);
    if (mitem.lap == 'ulap' || mitem.lap == 'dlap') {mitem.nuc.h = mitem.nuc.d = 0}
    mitem.type = 'box'; delete mitem.atom;
  },

  /*
   *  Handle a Bin atom. (Rule 5)
   */
  bin: function (style,mitem,prev) {
    if (prev) {
      var type  = prev.type;
      if (type == 'bin' || type == 'op' || type == 'rel' ||
          type == 'open' || type == 'punct' || type == '' ||
          (type == 'boundary' && prev.left != '')) {mitem.type = 'ord'}
    } else {mitem.type = 'ord'}
    jsMath.mList.prototype.Atomize.SupSub(style,mitem);
  },

  /*
   *  Handle a Rel atom.  (Rule 6)
   */
  rel: function (style,mitem,prev) {
    if (prev.type == 'bin') {prev.type = 'ord'}
    jsMath.mList.prototype.Atomize.SupSub(style,mitem);
  },

  /*
   *  Handle a Close atom.  (Rule 6)
   */
  close: function (style,mitem,prev) {
    if (prev.type == 'bin') {prev.type = 'ord'}
    jsMath.mList.prototype.Atomize.SupSub(style,mitem);
  },

  /*
   *  Handle a Punct atom.  (Rule 6)
   */
  punct: function (style,mitem,prev) {
    if (prev.type == 'bin') {prev.type = 'ord'}
    jsMath.mList.prototype.Atomize.SupSub(style,mitem);
  },

  /*
   *  Handle an Open atom.  (Rule 7)
   */
  open: function (style,mitem) {
    jsMath.mList.prototype.Atomize.SupSub(style,mitem);
  },

  /*
   *  Handle an Inner atom.  (Rule 7)
   */
  inner: function (style,mitem) {
    jsMath.mList.prototype.Atomize.SupSub(style,mitem);
  },

  /*
   *  Handle a Vcent atom.  (Rule 8)
   */
  vcenter: function (style,mitem) {
    var box = jsMath.Box.Set(mitem.nuc,style);
    var TeX = jsMath.Typeset.TeX(style);
    box.y = TeX.axis_height - (box.h-box.d)/2;
    mitem.nuc = box; mitem.type = 'ord';
    jsMath.mList.prototype.Atomize.SupSub(style,mitem);
  },

  /*
   *  Handle an Over atom.  (Rule 9)
   */
  overline: function (style,mitem) {
    var TeX = jsMath.Typeset.TeX(style);
    var box = jsMath.Box.Set(mitem.nuc,jsMath.Typeset.PrimeStyle(style));
    var t = TeX.default_rule_thickness;
    var rule = jsMath.Box.Rule(box.w,t);
    rule.x = -rule.w; rule.y = box.h + 3*t;
    mitem.nuc = jsMath.Box.SetList([box,rule]);
    mitem.nuc.h += t;
    mitem.type = 'ord';
    jsMath.mList.prototype.Atomize.SupSub(style,mitem);
  },

  /*
   *  Handle an Under atom.  (Rule 10)
   */
  underline: function (style,mitem) {
    var TeX = jsMath.Typeset.TeX(style);
    var box = jsMath.Box.Set(mitem.nuc,jsMath.Typeset.PrimeStyle(style));
    var t = TeX.default_rule_thickness;
    var rule = jsMath.Box.Rule(box.w,t);
    rule.x = -rule.w; rule.y = -box.d - 3*t - t;
    mitem.nuc = jsMath.Box.SetList([box,rule]);
    mitem.nuc.d += t;
    mitem.type = 'ord';
    jsMath.mList.prototype.Atomize.SupSub(style,mitem);
  },

  /*
   *  Handle a Rad atom.  (Rule 11 plus stuff for \root..\of)
   */
  radical: function (style,mitem) {
    var TeX = jsMath.Typeset.TeX(style);
    var Cp = jsMath.Typeset.PrimeStyle(style);
    var box = jsMath.Box.Set(mitem.nuc,Cp);
    var t = TeX.default_rule_thickness;
    var p = t; if (style == 'D' || style == "D'") {p = TeX.x_height}
    var r = t + p/4; 
    var surd = jsMath.Box.Delimiter(box.h+box.d+r+t,0x270370,style,1);
    t = surd.h; // thickness of rule is height of surd character
    if (surd.d > box.h+box.d+r) {r = (r+surd.d-box.h-box.d)/2}
    surd.y = box.h+r;
    var rule = jsMath.Box.Rule(box.w,t); rule.y = box.h+r; box.x = -box.w;
    var Cr = jsMath.Typeset.UpStyle(jsMath.Typeset.UpStyle(style));
    var root = jsMath.Box.Set(mitem.root,Cr);
    if (mitem.root) {root.y = .6*(box.h-box.d+3*t+r); surd.x = -(2/3)*surd.w}
    mitem.nuc = jsMath.Box.SetList([root,surd,rule,box],style);
    mitem.type = 'ord';
    jsMath.mList.prototype.Atomize.SupSub(style,mitem);
  },

  /*
   *  Handle an Acc atom.  (Rule 12)
   */
  accent: function (style,mitem) {
    var TeX = jsMath.Typeset.TeX(style);
    var Cp = jsMath.Typeset.PrimeStyle(style);
    var box = jsMath.Box.Set(mitem.nuc,Cp);
    var u = box.w; var s; var Font;
    if (mitem.nuc.type == 'TeX') {
      Font = jsMath.TeX[mitem.nuc.font];
      if (Font[mitem.nuc.c].krn && Font.skewchar)
        {s = Font[mitem.nuc.c].krn[Font.skewchar]}
    }
    if (s == null) {s = 0}
    
    var c = mitem.accent & 0xFF;
    var font = jsMath.TeX.fam[(mitem.accent&0xF00)>>8]; Font = jsMath.TeX[font];
    while (Font[c].n && Font[Font[c].n].w <= u) {c = Font[c].n}
    
    var delta = Math.min(box.h,TeX.x_height);
    if (mitem.nuc.type == 'TeX') {
      var nitem = jsMath.mItem.Atom('ord',mitem.nuc);
      nitem.sup = mitem.sup; nitem.sub = mitem.sub; nitem.delta = 0;
      jsMath.mList.prototype.Atomize.SupSub(style,nitem);
      delta += (nitem.nuc.h - box.h);
      box = mitem.nuc = nitem.nuc;
      delete mitem.sup; delete mitem.sub;
    }
    var acc = jsMath.Box.TeX(c,font,style);
    acc.y = box.h - delta; acc.x = -box.w + s + (u-acc.w)/2;
    if (Font[c].ic) {acc.x -= Font[c].ic}

    mitem.nuc = jsMath.Box.SetList([box,acc],style);
    if (mitem.nuc.w != box.w) 
      {mitem.nuc = jsMath.Box.SetList([mitem.nuc,jsMath.mItem.Space(box.w-mitem.nuc.w)])}
    mitem.type = 'ord';
    jsMath.mList.prototype.Atomize.SupSub(style,mitem);
  },

  /*
   *  Handle an Op atom.  (Rules 13 and 13a)
   */
  op: function (style,mitem) {
    var TeX = jsMath.Typeset.TeX(style); var box;
    mitem.delta = 0; var isD = (style.charAt(0) == 'D');
    if (mitem.limits == null && isD) {mitem.limits = 1}

    if (mitem.nuc.type == 'TeX') {
      var C = jsMath.TeX[mitem.nuc.font][mitem.nuc.c];
      if (isD && C.n) {mitem.nuc.c = C.n; C = jsMath.TeX[mitem.nuc.font][C.n]}
      box = jsMath.Box.Set(mitem.nuc,style);
      if (C.ic) {
        mitem.delta = C.ic;
        if (mitem.limits || !mitem.sub || jsMath.msieIntegralBug) 
          {box = jsMath.Box.SetList([box,jsMath.mItem.Space(C.ic)],style)}
      }
      box.y = -((box.h+box.d)/2 - box.d - TeX.axis_height);
      if (Math.abs(box.y) < .0001) (box.y = 0)
    }

    if (!box) {box = jsMath.Box.Set(mitem.nuc,style)}
    if (mitem.limits) {
      var W = box.w; var x = box.w;
      var mlist = [box]; var dh = 0; var dd = 0;
      if (mitem.sup) {
        var sup = jsMath.Box.Set(mitem.sup,jsMath.Typeset.UpStyle(style));
        sup.x = ((box.w-sup.w)/2 + mitem.delta/2) - x; dh = TeX.big_op_spacing5;
        W = Math.max(W,sup.w); x += sup.x + sup.w;
        sup.y = box.h+sup.d + box.y +
                    Math.max(TeX.big_op_spacing1,TeX.big_op_spacing3-sup.d);
        mlist[mlist.length] = sup; delete mitem.sup;
      }
      if (mitem.sub) {
        var sub = jsMath.Box.Set(mitem.sub,jsMath.Typeset.DownStyle(style));
        sub.x = ((box.w-sub.w)/2 - mitem.delta/2) - x; dd = TeX.big_op_spacing5;
        W = Math.max(W,sub.w); x += sub.x + sub.w;
        sub.y = -box.d-sub.h + box.y -
                   Math.max(TeX.big_op_spacing2,TeX.big_op_spacing4-sub.h);
        mlist[mlist.length] = sub; delete mitem.sub;
      }
      if (W > box.w) {box.x = (W-box.w)/2; x += box.x}
      if (x < W) {mlist[mlist.length] = jsMath.mItem.Space(W-x)}
      mitem.nuc = jsMath.Box.SetList(mlist);
      mitem.nuc.h += dh; mitem.nuc.d += dd;
    } else {
      if (jsMath.msieIntegralBug && mitem.sub && C && C.ic) 
        {mitem.nuc = jsMath.Box.SetList([box,jsMath.Box.Space(-C.ic)],style)}
      else if (box.y) {mitem.nuc = jsMath.Box.SetList([box],style)}
      jsMath.mList.prototype.Atomize.SupSub(style,mitem);
    }
  },

  /*
   *  Handle an Ord atom.  (Rule 14)
   */
  ord: function (style,mitem,prev,mList,i) {
    if (mitem.nuc.type == 'TeX' && !mitem.sup && !mitem.sub) {
      var nitem = mList.mlist[i+1];
      if (nitem && nitem.atom && nitem.type &&
          (nitem.type == 'ord' || nitem.type == 'op' || nitem.type == 'bin' ||
           nitem.type == 'rel' || nitem.type == 'open' ||
           nitem.type == 'close' || nitem.type == 'punct')) {
        if (nitem.nuc.type == 'TeX' && nitem.nuc.font == mitem.nuc.font) {
          mitem.textsymbol = 1;
          var krn = jsMath.TeX[mitem.nuc.font][mitem.nuc.c].krn;
          if (krn && krn[nitem.nuc.c]) {
            for (var k = mList.mlist.length-1; k > i; k--)
              {mList.mlist[k+1] = mList.mlist[k]}
            mList.mlist[i+1] = jsMath.mItem.Space(krn[nitem.nuc.c]);
          }
        }
      }
    }
    jsMath.mList.prototype.Atomize.SupSub(style,mitem);
  },

  /*
   *  Handle a generalized fraction.  (Rules 15 to 15e)
   */
  fraction: function (style,mitem) {
    var TeX = jsMath.Typeset.TeX(style); var t = 0;
    if (mitem.thickness != null) {t = mitem.thickness}
    else if (mitem.from.match(/over/)) {t = TeX.default_rule_thickness}
    var isD = (style.charAt(0) == 'D');
    var Cn = (style == 'D')? 'T': (style == "D'")? "T'": jsMath.Typeset.UpStyle(style);
    var Cd = (isD)? "T'": jsMath.Typeset.DownStyle(style);
    var num = jsMath.Box.Set(mitem.num,Cn);
    var den = jsMath.Box.Set(mitem.den,Cd);

    var u; var v; var w;
    var H = (isD)? TeX.delim1 : TeX.delim2;
    var mlist = [jsMath.Box.Delimiter(H,mitem.left,style)]
    var right = jsMath.Box.Delimiter(H,mitem.right,style);

    if (num.w < den.w) {
      num.x = (den.w-num.w)/2;
      den.x = -(num.w+den.w)/2;
      w = den.w; mlist[1] = num; mlist[2] = den;
    } else {
      den.x = (num.w-den.w)/2;
      num.x = -(num.w+den.w)/2;
      w = num.w; mlist[1] = den; mlist[2] = num;
    }
    if (isD) {u = TeX.num1; v = TeX.denom1} else {
      u = (t != 0)? TeX.num2: TeX.num3;
      v = TeX.denom2;
    }
    if (t == 0) {// atop
      var p = (isD)? 7*TeX.default_rule_thickness: 3*TeX.default_rule_thickness;
      var r = (u - num.d) - (den.h - v);
      if (r < p) {u += (p-r)/2; v += (p-r)/2}
    } else {// over
      var p = (isD)? 3*t: t; var a = TeX.axis_height;
      var r = (u-num.d)-(a+t/2); if (r < p) {u += p-r}
          r = (a-t/2)-(den.h-v); if (r < p) {v += p-r}
      var rule = jsMath.Box.Rule(w,t); rule.x = -w; rule.y = a - t/2;
      mlist[mlist.length] = rule;
    }
    num.y = u; den.y = -v;

    mlist[mlist.length] = right;
    mitem.nuc = jsMath.Box.SetList(mlist,style);
    mitem.type = 'ord'; mitem.atom = 1;
    delete mitem.num; delete mitem.den;
    jsMath.mList.prototype.Atomize.SupSub(style,mitem);
  },

  /*
   *  Add subscripts and superscripts.  (Rules 17-18f)
   */
  SupSub: function (style,mitem) {
    var TeX = jsMath.Typeset.TeX(style);
    var nuc = mitem.nuc;
    var box = mitem.nuc = jsMath.Box.Set(mitem.nuc,style,0);
    if (box.format == 'null') 
      {box = mitem.nuc = jsMath.Box.Text('','normal',style)}

    if (nuc.type == 'TeX') {
      if (!mitem.textsymbol) {
        var C = jsMath.TeX[nuc.font][nuc.c];
        if (C.ic) {
          mitem.delta = C.ic;
          if (!mitem.sub) {
            box = mitem.nuc = jsMath.Box.SetList([box,jsMath.Box.Space(C.ic)],style);
            mitem.delta = 0;
          } else {mitem.delta = C.ic}
        }
      } else {mitem.delta = 0}
    }

    if (!mitem.sup && !mitem.sub) return;
    mitem.nuc.Styled();
    
    var Cd = jsMath.Typeset.DownStyle(style);
    var Cu = jsMath.Typeset.UpStyle(style);
    var q = jsMath.Typeset.TeX(Cu).sup_drop;
    var r = jsMath.Typeset.TeX(Cd).sub_drop;
    var u = 0; var v = 0; var p;
    if (nuc.type != 'text' && nuc.type != 'TeX' && nuc.type != 'null')
      {u = box.h - q; v = box.d + r}

    if (mitem.sub) {
      var sub = jsMath.Box.Set(mitem.sub,Cd);
      sub = jsMath.Box.SetList([sub,jsMath.mItem.Space(TeX.scriptspace)],style);
    }

    if (!mitem.sup) {
      sub.y = -Math.max(v,TeX.sub1,sub.h-(4/5)*TeX.x_height);
      mitem.nuc = jsMath.Box.SetList([box,sub],style).Styled(); delete mitem.sub;
      return;
    }

    var sup = jsMath.Box.Set(mitem.sup,Cu);
    sup = jsMath.Box.SetList([sup,jsMath.mItem.Space(TeX.scriptspace)],style);
    if (style == 'D') {p = TeX.sup1}
    else if (style.charAt(style.length-1) == "'") {p = TeX.sup3}
    else {p = TeX.sup2}
    u = Math.max(u,p,sup.d+TeX.x_height/4);

    if (!mitem.sub) {
      sup.y = u;
      mitem.nuc = jsMath.Box.SetList([box,sup],style); delete mitem.sup;
      return;
    }

    v = Math.max(v,TeX.sub2);
    var t = TeX.default_rule_thickness;
    if ((u-sup.d) - (sub.h -v) < 4*t) {
      v = 4*t + sub.h - (u-sup.d);
      p = (4/5)*TeX.x_height - (u-sup.d);
      if (p > 0) {u += p; v -= p}
    }
    sup.y = u; sub.y = -v; sup.x = mitem.delta;
    if (sup.w+sup.x > sub.w)
      {sup.x -= sub.w; mitem.nuc = jsMath.Box.SetList([box,sub,sup],style)} else
      {sub.x -= (sup.w+sup.x); mitem.nuc = jsMath.Box.SetList([box,sup,sub],style)}

    delete mitem.sup; delete mitem.sub;
  }

});


/***************************************************************************/

/*
 *  The Typeset object handles most of the TeX-specific processing
 */

jsMath.Typeset = function (mlist) {
  this.type = 'typeset';
  this.mlist = mlist;
}

jsMath.Add(jsMath.Typeset,{

  /*
   *  The "C-uparrow" style table (TeXbook, p. 441)
   */
  upStyle: {
    D: "S", T: "S",  "D'": "S'", "T'": "S'",
    S: "SS",  SS: "SS",  "S'": "SS'", "SS'": "SS'"
  },

  /*
   *  The "C-downarrow" style table (TeXbook, p. 441)
   */
  downStyle: {
    D: "S'", T: "S'",  "D'": "S'", "T'": "S'",
    S: "SS'",  SS: "SS'",  "S'": "SS'", "SS'": "SS'"
  },

  /*
   *  Get the various styles given the current style
   *  (see TeXbook, p. 441)
   */
  UpStyle: function (style) {return this.upStyle[style]},
  DownStyle: function (style) {return this.downStyle[style]},
  PrimeStyle: function (style) {
    if (style.charAt(style.length-1) == "'") {return style}
    return style + "'"
  },

  /*
   *  A value scaled to the appropriate size for scripts
   */
  StyleValue: function (style,v) {
    if (style == "S" || style == "S'") {return .75*v}
    if (style == "SS" || style == "SS'") {return .6*v}
    return v;
  },

  /*
   *  Return the font parameter table for the given style
   */
  TeX: function (style) {
    if (style.charAt(0) == 'D' || style.charAt(0) == 'T') {return jsMath.TeX}
    if (style == "S" || style == "S'") {return jsMath.TeXscript}
    return jsMath.TeXscriptscript;
  },


  /*
   *  Add the CSS class for the given TeX style
   */
  AddStyle: function (style,html) {
    if (style == "S" || style == "S'") 
      {html = '<SPAN CLASS="script">'+html+'</SPAN>'}
    else if (style == "SS" || style == "SS'") 
      {html = '<SPAN CLASS="scriptscript">'+html+'</SPAN>'}
    return html;
  },

  /*
   *  Add the font class, if needed
   */
  AddClass: function (tclass,html) {
    if (tclass != '' && tclass != 'normal') 
      {html = '<SPAN CLASS="'+tclass+'">'+html+'</SPAN>'}
    return html;
  }

});


jsMath.Package(jsMath.Typeset,{
  
  /*
   *  The spacing tables for inter-atom spacing
   *  (See rule 20, and Chapter 18, p 170)
   */
  DTsep: {
    ord: {op: 1, bin: 2, rel: 3, inner: 1},
    op:  {ord: 1, op: 1, rel: 3, inner: 1},
    bin: {ord: 2, op: 2, open: 2, inner: 2},
    rel: {ord: 3, op: 3, open: 3, inner: 3},
    open: {},
    close: {op: 1, bin:2, rel: 3, inner: 1},
    punct: {ord: 1, op: 1, rel: 1, open: 1, close: 1, punct: 1, inner: 1},
    inner: {ord: 1, op: 1, bin: 2, rel: 3, open: 1, punct: 1, inner: 1}
  },

  SSsep: {
    ord: {op: 1},
    op:  {ord: 1, op: 1},
    bin: {},
    rel: {},
    open: {},
    close: {op: 1},
    punct: {},
    inner: {op: 1}
  },

  /*
   *  The sizes used in the tables above
   */
  sepW: ['','thinmuskip','medmuskip','thickmuskip'],
  
  
  /*
   *  Find the amount of separation to use between two adjacent
   *  atoms in the given style
   */
  GetSeparation: function (l,r,style) {
    if (l && l.atom && r.atom) {
      var table = this.DTsep; if (style.charAt(0) == "S") {table = this.SSsep}
      var row = table[l.type];
      if (row && row[r.type] != null) {return jsMath.TeX[this.sepW[row[r.type]]]}
    }
    return 0;
  },

  /*
   *  Typeset an mlist (i.e., turn it into HTML).
   *  Here, text items of the same class and style are combined
   *  to reduce the number of <SPAN> tags used (though it is still
   *  huge).  Spaces are combined, when possible.
   *  ###  More needs to be done with that.  ###
   *  The width of the final box is recomputed at the end, since
   *  the final width is not necessarily the sum of the widths of
   *  the individual parts (widths are in pixels, but the browsers
   *  puts pieces together using sub-pixel accuracy).
   */
  Typeset: function (style) {
    this.style = style; var unset = -10000
    this.w = 0; this.h = unset; this.d = unset;
    this.bh = this.h; this.bd = this.d;
    this.tbuf = ''; this.tx = 0; this.tclass = '';
    this.cbuf = ''; this.hbuf = ''; this.hx = 0;
    var mitem = null; var prev; this.x = 0; this.dx = 0;

    for (var i = 0; i < this.mlist.length; i++) {
      prev = mitem; mitem = this.mlist[i];
      switch (mitem.type) {

        case 'style':
          this.FlushClassed();
          if (this.style.charAt(this.style.length-1) == "'")
            {this.style = mitem.style + "'"} else {this.style = mitem.style}
          break;

        case 'space':
          if (typeof(mitem.w) == 'object') {
            if (this.style.charAt(1) == 'S') {mitem.w = .6*mitem.w[0]/18}
            else if (this.style.charAt(0) == 'S') {mitem.w = .75*mitem.w[0]/18}
            else {mitem.w = mitem.w[0]/18}
          }
          this.dx += mitem.w-0; // mitem.w is sometimes a string?
          break;
          
        case 'html':
          this.FlushClassed();
          if (this.hbuf == '') {this.hx = this.x}
          this.hbuf += mitem.html;
          mitem = prev; // hide this from TeX
          break;
          
        default:   // atom
          if (!mitem.atom && mitem.type != 'box') break;
          mitem.nuc.x += this.dx + this.GetSeparation(prev,mitem,this.style);
          if (mitem.nuc.y || mitem.nuc.x) mitem.nuc.Styled();
          this.dx = 0; this.x = this.x + this.w;
          this.w += mitem.nuc.w + mitem.nuc.x;
          if (mitem.nuc.format == 'text') {
            if (this.tclass != mitem.nuc.tclass && this.tclass != '') this.FlushText();
            if (this.tbuf == '' && this.cbuf == '') {this.tx = this.x}
            this.tbuf += mitem.nuc.html; this.tclass = mitem.nuc.tclass;
          } else  {
            this.FlushClassed();
            if (mitem.nuc.x || mitem.nuc.y) this.Place(mitem.nuc);
            if (this.hbuf == '') {this.hx = this.x}
            this.hbuf += mitem.nuc.html;
          }
          this.h = Math.max(this.h,mitem.nuc.h); this.bh = Math.max(this.bh,mitem.nuc.bh);
          this.d = Math.max(this.d,mitem.nuc.d); this.bd = Math.max(this.bd,mitem.nuc.bd);
          break;
      }
    }
    
    this.FlushClassed(); // make sure scaling is included
    if (this.dx) {this.hbuf += jsMath.HTML.Spacer(this.dx)}
    if (this.hbuf == '') {return jsMath.Box.Null}
    if (this.w >= 0 && (!jsMath.spanHeightVaries || !this.hbuf.match(/position: ?absolute/)))
       {this.w = jsMath.EmBoxFor(this.hbuf).w}
    if (this.h == unset) {this.h = 0}
    if (this.d == unset) {this.d = 0}
    var box = new jsMath.Box('html',this.hbuf,this.w,this.h,this.d);
    box.bh = this.bh; box.bd = this.bd;
    return box;
  },

  /*
   *  Add the font to the buffered text and move it to the
   *  classed-text buffer.
   */
  FlushText: function () {
    if (this.tbuf == '') return;
    this.cbuf += jsMath.Typeset.AddClass(this.tclass,this.tbuf);
    this.tbuf = ''; this.tclass = '';
  },

  /*
   *  Add the script or scriptscript style to the text and
   *  move it to the HTML buffer
   */
  FlushClassed: function () {
    this.FlushText();
    if (this.cbuf == '') return;
    if (this.hbuf == '') {this.hx = this.tx}
    this.hbuf += jsMath.Typeset.AddStyle(this.style,this.cbuf);
    this.cbuf = '';
  },

  /*
   *  Add a <SPAN> to position an item's HTML, and
   *  adjust the items height and depth.
   *  (This may be replaced buy one of the following browser-specific
   *   versions by InitBrowser().)
   */
  Place: function (item) {
    var html = '<SPAN STYLE="position: relative;';
    if (item.x) {html += ' margin-left:'+jsMath.HTML.Em(item.x)+';'}
    if (item.y) {html += ' top:'+jsMath.HTML.Em(-item.y)+';'}
    item.html = html + '">' + item.html + '</SPAN>';
    item.h += item.y; item.d -= item.y;
    item.x = 0; item.y = 0;
  },
  
  /*
   *  A replacement for Place() above that fixes a bug in MSIE.
   *  (A separate <SPAN> is used to backspace, otherwise the
   *   contents are clipped incorrectly.)
   */
  PlaceSeparateNegative: function (item) {
    var html = '<SPAN STYLE="position: relative;';
    // MSIE needs backspacing as separate SPAN
    if (item.x < 0) 
      {html = '<SPAN STYLE="margin-left:'+jsMath.HTML.Em(item.x)+';"></SPAN>'+html}
    if (item.x > 0) {html += ' margin-left:'+jsMath.HTML.Em(item.x)+';'}
    if (item.y) {html += ' top:'+jsMath.HTML.Em(-item.y)+';'}
    item.html = html + '">' + item.html + '</SPAN>';
    item.h += item.y; item.d -= item.y;
    item.x = 0; item.y = 0;
  },

  /*
   *  Here, the horizontal spacing is always done separately.
   */
  PlaceSeparateSkips: function (item) {
    if (item.y) 
      {item.html = '<SPAN STYLE="position: relative; top:'+jsMath.HTML.Em(-item.y)+';'
                       + '">' + item.html + '</SPAN>'}
    if (item.x) 
      {item.html = '<SPAN STYLE="margin-left:'+jsMath.HTML.Em(item.x)+';'
                       + '"></SPAN>' + item.html}
    item.h += item.y; item.d -= item.y;
    item.x = 0; item.y = 0;
  }
  
});



/***************************************************************************/

/*
 *  The Parse object handles the parsing of the TeX input string, and creates
 *  the mList to be typeset by the Typeset object above.
 */

jsMath.Parse = function (s,font) {
  var parse = new jsMath.Parser(s,font);
  parse.Parse();
  return parse;
}

jsMath.Parser = function (s,font) {
  this.string = s; this.i = 0;
  this.mlist = new jsMath.mList();
  if (font != null) {this.mlist.font = font}
}

jsMath.Package(jsMath.Parser,{
  
  // special characters
  cmd:   '\\',
  open:  '{',
  close: '}',

  // patterns for letters and numbers
  letter:  /[a-z]/i,
  number:  /[0-9]/,
  
  //  the \mathchar definitions (see Appendix B of the TeXbook).
  mathchar: {
    '!': 0x5021,
    '(': 0x4028,
    ')': 0x5029,
    '*': 0x2203, // \ast
    '+': 0x202B,
    ',': 0x613B,
    '-': 0x2200,
    '.': 0x013A,
    '/': 0x013D,
    ':': 0x303A,
    ';': 0x603B,
    '<': 0x313C,
    '=': 0x303D,
    '>': 0x313E,
    '?': 0x503F,
    '[': 0x405B,
    ']': 0x505D,
//  '{': 0x4266,
//  '}': 0x5267,
    '|': 0x026A
  },

  //  handle special \catcode characters
  special: {
    '^':   'HandleSuperscript',
    '_':   'HandleSubscript',
    ' ':   'Space',
    "\t":  'Space',
    "\r":  'Space',
    "\n":  'Space',
    "'":   'Prime',
    '%':   'HandleComment',
    '&':   'HandleEntry'
  },

  // the \mathchardef table (see Appendix B of the TeXbook).
  mathchardef: {
  // brace parts
    braceld:      0x37A,
    bracerd:      0x37B,
    bracelu:      0x37C,
    braceru:      0x37D,

  // Greek letters
    alpha:        0x010B,
    beta:         0x010C,
    gamma:        0x010D,
    delta:        0x010E,
    epsilon:      0x010F,
    zeta:         0x0110,
    eta:          0x0111,
    theta:        0x0112,
    iota:         0x0113,
    kappa:        0x0114,
    lambda:       0x0115,
    mu:           0x0116,
    nu:           0x0117,
    xi:           0x0118,
    pi:           0x0119,
    rho:          0x011A,
    sigma:        0x011B,
    tau:          0x011C,
    upsilon:      0x011D,
    phi:          0x011E,
    chi:          0x011F,
    psi:          0x0120,
    omega:        0x0121,
    varepsilon:   0x0122,
    vartheta:     0x0123,
    varpi:        0x0124,
    varrho:       0x0125,
    varsigma:     0x0126,
    varphi:       0x0127,
    
    Gamma:        0x7000,
    Delta:        0x7001,
    Theta:        0x7002,
    Lambda:       0x7003,
    Xi:           0x7004,
    Pi:           0x7005,
    Sigma:        0x7006,
    Upsilon:      0x7007,
    Phi:          0x7008,
    Psi:          0x7009,
    Omega:        0x700A,

  // Ord symbols
    aleph:        0x0240,
    imath:        0x017B,
    jmath:        0x017C,
    ell:          0x0160,
    wp:           0x017D,
    Re:           0x023C,
    Im:           0x023D,
    partial:      0x0140,
    infty:        0x0231,
    prime:        0x0230,
    emptyset:     0x023B,
    nabla:        0x0272,
    surd:         0x1270,
    top:          0x023E,
    bot:          0x023F,
    triangle:     0x0234,
    forall:       0x0238,
    exists:       0x0239,
    neg:          0x023A,
    lnot:         0x023A,
    flat:         0x015B,
    natural:      0x015C,
    sharp:        0x015D,
    clubsuit:     0x027C,
    diamondsuit:  0x027D,
    heartsuit:    0x027E,
    spadesuit:    0x027F,

  // big ops
    coprod:      0x1360,
    bigvee:      0x1357,
    bigwedge:    0x1356,
    biguplus:    0x1355,
    bigcap:      0x1354,
    bigcup:      0x1353,
    intop:       0x1352, 
    prod:        0x1351,
    sum:         0x1350,
    bigotimes:   0x134E,
    bigoplus:    0x134C,
    bigodot:     0x134A,
    ointop:      0x1348,
    bigsqcup:    0x1346,
    smallint:    0x1273,

  // binary operations
    triangleleft:      0x212F,
    triangleright:     0x212E,
    bigtriangleup:     0x2234,
    bigtriangledown:   0x2235,
    wedge:       0x225E,
    land:        0x225E,
    vee:         0x225F,
    lor:         0x225F,
    cap:         0x225C,
    cup:         0x225B,
    ddagger:     0x227A,
    dagger:      0x2279,
    sqcap:       0x2275,
    sqcup:       0x2274,
    uplus:       0x225D,
    amalg:       0x2271,
    diamond:     0x2205,
    bullet:      0x220F,
    wr:          0x226F,
    div:         0x2204,
    odot:        0x220C,
    oslash:      0x220B,
    otimes:      0x220A,
    ominus:      0x2209,
    oplus:       0x2208,
    mp:          0x2207,
    pm:          0x2206,
    circ:        0x220E,
    bigcirc:     0x220D,
    setminus:    0x226E, // for set difference A\setminus B
    cdot:        0x2201,
    ast:         0x2203,
    times:       0x2202,
    star:        0x213F,

  // Relations
    propto:      0x322F,
    sqsubseteq:  0x3276,
    sqsupseteq:  0x3277,
    parallel:    0x326B,
    mid:         0x326A,
    dashv:       0x3261,
    vdash:       0x3260,
    leq:         0x3214,
    le:          0x3214,
    geq:         0x3215,
    ge:          0x3215,
    succ:        0x321F,
    prec:        0x321E,
    approx:      0x3219,
    succeq:      0x3217,
    preceq:      0x3216,
    supset:      0x321B,
    subset:      0x321A,
    supseteq:    0x3213,
    subseteq:    0x3212,
    'in':        0x3232,
    ni:          0x3233,
    owns:        0x3233,
    gg:          0x321D,
    ll:          0x321C,
    not:         0x3236,
    sim:         0x3218,
    simeq:       0x3227,
    perp:        0x323F,
    equiv:       0x3211,
    asymp:       0x3210,
    smile:       0x315E,
    frown:       0x315F,

  // Arrows
    Leftrightarrow:   0x322C,
    Leftarrow:        0x3228,
    Rightarrow:       0x3229,
    leftrightarrow:   0x3224,
    leftarrow:        0x3220,
    gets:             0x3220,
    rightarrow:       0x3221,
    to:               0x3221,
    mapstochar:       0x3237,
    leftharpoonup:    0x3128,
    leftharpoondown:  0x3129,
    rightharpoonup:   0x312A,
    rightharpoondown: 0x312B,
    nearrow:          0x3225,
    searrow:          0x3226,
    nwarrow:          0x322D,
    swarrow:          0x322E,

    hbarchar:   0x0016, // for \hbar
    lhook:      0x312C,
    rhook:      0x312D,

    ldotp:      0x613A, // ldot as a punctuation mark
    cdotp:      0x6201, // cdot as a punctuation mark
    colon:      0x603A, // colon as a punctuation mark

    '#':        0x7023,
    '$':        0x7024,
    '%':        0x7025,
    '&':        0x7026
  },
  
  // The delimiter table (see Appendix B of the TeXbook)
  delimiter: {
    '(':                0x0028300,
    ')':                0x0029301,
    '[':                0x005B302,
    ']':                0x005D303,
    '<':                0x026830A,
    '>':                0x026930B,
    '/':                0x002F30E,
    '|':                0x026A30C,
    '.':                0x0000000,
    '\\':               0x026E30F,
    '\\lmoustache':     0x437A340,  // top from (, bottom from )
    '\\rmoustache':     0x537B341,  // top from ), bottom from (
    '\\lgroup':         0x462833A,  // extensible ( with sharper tips
    '\\rgroup':         0x562933B,  // extensible ) with sharper tips
    '\\arrowvert':      0x026A33C,  // arrow without arrowheads
    '\\Arrowvert':      0x026B33D,  // double arrow without arrowheads
//  '\\bracevert':      0x077C33E,  // the vertical bar that extends braces
    '\\bracevert':      0x026A33E,  // we don't load tt, so use | instead
    '\\Vert':           0x026B30D,
    '\\|':              0x026B30D,
    '\\vert':           0x026A30C,
    '\\uparrow':        0x3222378,
    '\\downarrow':      0x3223379,
    '\\updownarrow':    0x326C33F,
    '\\Uparrow':        0x322A37E,
    '\\Downarrow':      0x322B37F,
    '\\Updownarrow':    0x326D377,
    '\\backslash':      0x026E30F,  // for double coset G\backslash H
    '\\rangle':         0x526930B,
    '\\langle':         0x426830A,
    '\\rbrace':         0x5267309,
    '\\lbrace':         0x4266308,
    '\\}':              0x5267309,
    '\\{':              0x4266308,
    '\\rceil':          0x5265307,
    '\\lceil':          0x4264306,
    '\\rfloor':         0x5263305,
    '\\lfloor':         0x4262304
  },

  /*
   *  The basic macros for plain TeX.
   *
   *  When the control sequence on the left is called, the JavaScript
   *  funtion on the right is called, with the name of the control sequence
   *  as its first parameter (this way, the same function can be called by
   *  several different control sequences to do similar actions, and the
   *  function can still tell which TeX command was issued).  If the right
   *  is an array, the first entry is the routine to call, and the
   *  remaining entries in the array are parameters to pass to the function
   *  as the second parameter (they are in an array reference).
   *  
   *  Note:  TeX macros as defined by the user are discussed below.
   */
  macros: {
    displaystyle:      ['HandleStyle','D'],
    textstyle:         ['HandleStyle','T'],
    scriptstyle:       ['HandleStyle','S'],
    scriptscriptstyle: ['HandleStyle','SS'],
    
    rm:                ['HandleFont',0],
    mit:               ['HandleFont',1],
    oldstyle:          ['HandleFont',1],
    cal:               ['HandleFont',2],
    it:                ['HandleFont',4],
    bf:                ['HandleFont',6],
    
    left:              'HandleLeft',
    right:             'HandleRight',

    arcsin:       ['NamedOp',0],
    arccos:       ['NamedOp',0],
    arctan:       ['NamedOp',0],
    arg:          ['NamedOp',0],
    cos:          ['NamedOp',0],
    cosh:         ['NamedOp',0],
    cot:          ['NamedOp',0],
    coth:         ['NamedOp',0],
    csc:          ['NamedOp',0],
    deg:          ['NamedOp',0],
    det:           'NamedOp',
    dim:          ['NamedOp',0],
    exp:          ['NamedOp',0],
    gcd:           'NamedOp',
    hom:          ['NamedOp',0],
    inf:           'NamedOp',
    ker:          ['NamedOp',0],
    lg:           ['NamedOp',0],
    lim:           'NamedOp',
    liminf:       ['NamedOp',null,'lim<SPAN STYLE="margin-left: '+1/6+'em"></SPAN>inf'],
    limsup:       ['NamedOp',null,'lim<SPAN STYLE="margin-left: '+1/6+'em"></SPAN>sup'],
    ln:           ['NamedOp',0],
    log:          ['NamedOp',0],
    max:           'NamedOp',
    min:           'NamedOp',
    Pr:            'NamedOp',
    sec:          ['NamedOp',0],
    sin:          ['NamedOp',0],
    sinh:         ['NamedOp',0],
    sup:           'NamedOp',
    tan:          ['NamedOp',0],
    tanh:         ['NamedOp',0],

    vcenter:        ['HandleAtom','vcenter'],
    overline:       ['HandleAtom','overline'],
    underline:      ['HandleAtom','underline'],
    over:            'HandleOver',
    overwithdelims:  'HandleOver',
    atop:            'HandleOver',
    atopwithdelims:  'HandleOver',
    above:           'HandleOver',
    abovewithdelims: 'HandleOver',
    brace:           ['HandleOver','\\{','\\}'],
    brack:           ['HandleOver','[',']'],
    choose:          ['HandleOver','(',')'],
    
    overbrace:       ['HandleLeaders','downbrace',1],
    underbrace:      ['HandleLeaders','upbrace',1,1],
    overrightarrow:  ['HandleLeaders','rightarrow'],
    overleftarrow:   ['HandleLeaders','leftarrow'],

    llap:            'HandleLap',
    rlap:            'HandleLap',
    ulap:            'HandleLap',
    dlap:            'HandleLap',
    raise:           'RaiseLower',
    lower:           'RaiseLower',
    moveleft:        'MoveLeftRight',
    moveright:       'MoveLeftRight',

    frac:            'Frac',
    root:            'Root',
    sqrt:            'Sqrt',

    //  TeX substitution macros
    hbar:               ['Macro','\\hbarchar\\kern-.5em h'],
    ne:                 ['Macro','\\not='],
    neq:                ['Macro','\\not='],
    notin:              ['Macro','\\mathrel{\\rlap{\\kern2mu/}}\\in'],
    cong:               ['Macro','\\mathrel{\\lower2mu{\\mathrel{{\\rlap{=}\\raise6mu\\sim}}}}'],
    bmod:               ['Macro','\\mathbin{\\rm mod}'],
    pmod:               ['Macro','\\kern 18mu ({\\rm mod}\\,\\,#1)',1],
    'int':              ['Macro','\\intop\\nolimits'],
    oint:               ['Macro','\\ointop\\nolimits'],
    doteq:              ['Macro','\\buildrel\\textstyle.\\over='],
    ldots:              ['Macro','\\mathinner{\\ldotp\\ldotp\\ldotp}'],
    cdots:              ['Macro','\\mathinner{\\cdotp\\cdotp\\cdotp}'],
    vdots:              ['Macro','\\mathinner{\\rlap{\\raise8pt{\\rule 0pt 6pt 0pt .}}\\rlap{\\raise4pt{.}}.}'],
    ddots:              ['Macro','\\mathinner{\\kern1mu\\raise7pt{\\rule 0pt 7pt 0pt .}\\kern2mu\\raise4pt{.}\\kern2mu\\raise1pt{.}\\kern1mu}'],
    joinrel:            ['Macro','\\mathrel{\\kern-4mu}'],
    relbar:             ['Macro','\\mathrel{\\smash-}'], // \smash, because - has the same height as +
    Relbar:             ['Macro','\\mathrel='],
    bowtie:             ['Macro','\\mathrel\\triangleright\\joinrel\\mathrel\\triangleleft'],
    models:             ['Macro','\\mathrel|\\joinrel='],
    mapsto:             ['Macro','\\mapstochar\\rightarrow'],
    rightleftharpoons:  ['Macro','\\vcenter{\\mathrel{\\rlap{\\raise3mu{\\rightharpoonup}}}\\leftharpoondown}'],
    hookrightarrow:     ['Macro','\\lhook\\joinrel\\rightarrow'],
    hookleftarrow:      ['Macro','\\leftarrow\\joinrel\\rhook'],
    Longrightarrow:     ['Macro','\\Relbar\\joinrel\\Rightarrow'],
    longrightarrow:     ['Macro','\\relbar\\joinrel\\rightarrow'],
    longleftarrow:      ['Macro','\\leftarrow\\joinrel\\relbar'],
    Longleftarrow:      ['Macro','\\Leftarrow\\joinrel\\Relbar'],
    longmapsto:         ['Macro','\\mapstochar\\char{cmsy10}{0}\\joinrel\\rightarrow'],
    longleftrightarrow: ['Macro','\\leftarrow\\joinrel\\rightarrow'],
    Longleftrightarrow: ['Macro','\\Leftarrow\\joinrel\\Rightarrow'],
    iff:                ['Macro','\\;\\Longleftrightarrow\\;'],
    mathrm:             ['Macro','{\\rm #1}',1],
    mathbf:             ['Macro','{\\bf #1}',1],
    mathit:             ['Macro','{\\it #1}',1],
    mathbb:             ['Macro','{\\bf #1}',1],

    // for WeBWorK
    lt:			['Macro','<'],
    gt:			['Macro','>'],
    setlength:          ['Macro','',2],

    limits:       ['Limits',1],
    nolimits:     ['Limits',0],

    ',':          ['Spacer',1/6],
    ':':          ['Spacer',1/6],
    '>':          ['Spacer',2/9],
    ';':          ['Spacer',5/18],
    '!':          ['Spacer',-1/6],
    enspace:      ['Spacer',1/2],
    quad:         ['Spacer',1],
    qquad:        ['Spacer',2],
    thinspace:    ['Spacer',1/6],
    negthinspace: ['Spacer',-1/6],
    
    hskip:         'Hskip',
    kern:          'Hskip',
    rule:          ['Rule','black'],
    space:         ['Rule','blank'],
    
    big:        ['MakeBig','ord',0.85],
    Big:        ['MakeBig','ord',1.15],
    bigg:       ['MakeBig','ord',1.45],
    Bigg:       ['MakeBig','ord',1.75],
    bigl:       ['MakeBig','open',0.85],
    Bigl:       ['MakeBig','open',1.15],
    biggl:      ['MakeBig','open',1.45],
    Biggl:      ['MakeBig','open',1.75],
    bigr:       ['MakeBig','close',0.85],
    Bigr:       ['MakeBig','close',1.15],
    biggr:      ['MakeBig','close',1.45],
    Biggr:      ['MakeBig','close',1.75],
    bigm:       ['MakeBig','rel',0.85],
    Bigm:       ['MakeBig','rel',1.15],
    biggm:      ['MakeBig','rel',1.45],
    Biggm:      ['MakeBig','rel',1.75],
    
    mathord:    ['HandleAtom','ord'],
    mathop:     ['HandleAtom','op'],
    mathopen:   ['HandleAtom','open'],
    mathclose:  ['HandleAtom','close'],
    mathbin:    ['HandleAtom','bin'],
    mathrel:    ['HandleAtom','rel'],
    mathpunct:  ['HandleAtom','punct'],
    mathinner:  ['HandleAtom','inner'],
    
    mathchoice: 'MathChoice',
    buildrel:   'BuildRel',
    
    hbox:       'HBox',
    text:       'HBox',
    mbox:       'HBox',

    strut:      'Strut',
    mathstrut:  ['Macro','\\vphantom{(}'],
    phantom:    ['Phantom',1,1],
    vphantom:   ['Phantom',1,0],
    hphantom:   ['Phantom',0,1],
    smash:      'Smash',
    
    acute:      ['MathAccent', 0x7013],
    grave:      ['MathAccent', 0x7012],
    ddot:       ['MathAccent', 0x707F],
    tilde:      ['MathAccent', 0x707E],
    bar:        ['MathAccent', 0x7016],
    breve:      ['MathAccent', 0x7015],
    check:      ['MathAccent', 0x7014],
    hat:        ['MathAccent', 0x705E],
    vec:        ['MathAccent', 0x017E],
    dot:        ['MathAccent', 0x705F],
    widetilde:  ['MathAccent', 0x0365],
    widehat:    ['MathAccent', 0x0362],

    '_':        ['Replace','ord','_','normal',-.4,.1],
    ' ':        ['Replace','ord','&nbsp;','normal'],
    angle:      ['Replace','ord','&#x2220;','normal'],
        
    matrix:     'Matrix',
    array:      'Matrix',  // ### still need to do alignment options ###
    pmatrix:    ['Matrix','(',')'],
    cases:      ['Matrix','\\{','.',['l','l']],
    cr:         'HandleRow',
    '\\':       'HandleRow',
    
    //  LaTeX
    begin:      'Begin',
    end:        'End',

    //  Extensions to TeX
    color:      'Color',
    href:       'Href',
    'class':    'Class',
    style:      'Style',
    unicode:    'Unicode',

    //  debugging and test routines
    'char':     'Char',
    test:       'Test'
  },
  
  /*
   *  LaTeX environments
   */
  environments: {
    array:      'Array',
    cases:      ['Array','\\{','.','ll']
  },

  /*
   *  The horizontally stretchable delimiters
   */
  leaders: {
    downbrace:  {left: 0x37A, lmid: 0x37D, rmid: 0x37C, right: 0x37B},
    upbrace:    {left: 0x37C, lmid: 0x37B, rmid: 0x37A, right: 0x37D},
    leftarrow:  {left: 0x220, rep: 0x200},
    rightarrow: {rep: 0x200, right: 0x221}
  },


  /***************************************************************************/

  /*
   *  Add special characters to list above.  (This makes it possible
   *  to define them in a variable that the user can change.)
   */
  AddSpecial: function (obj) {
    for (var id in obj) {
      jsMath.Parser.prototype.special[jsMath.Parser.prototype[id]] = obj[id];
    }
  },

  /*
   *  Throw an error
   */
  Error: function (s) {
   this.i = this.string.length;
    if (s.error) {this.error = s.error} else {
      if (!this.error) {this.error = s}
    }
  },

  /***************************************************************************/

  /*
   *  Parse a substring to get its mList, and return it.
   *  Check that no errors occured
   */
  Process: function (arg) {
    arg = jsMath.Parse(arg,this.mlist.font); if (arg.error) {this.Error(arg); return}
    if (arg.mlist.Length() == 0) {return null}
    if (arg.mlist.Length() == 1) {
      var atom = arg.mlist.Last();
      if (atom.atom && atom.type == 'ord' && atom.nuc &&
         !atom.sub && !atom.sup && (atom.nuc.type == 'text' || atom.nuc.type == 'TeX'))
             {return atom.nuc}
    }
    return {type: 'mlist', mlist: arg.mlist};
  },

  /*
   *  Get and return a control-sequence name from the TeX string
   */
  GetCommand: function () {
    var letter = /^([a-z]+|.) ?/i;
    var cmd = letter.exec(this.string.slice(this.i));
    if (cmd) {this.i += cmd[1].length; return cmd[1]}
    this.Error("Missing control sequnece name at end of string or argument"); return
  },

  /*
   *  Get and return a TeX argument (either a single character or control sequence,
   *  or the contents of the next set of braces).
   */
  GetArgument: function (name,noneOK) {
    while (this.string.charAt(this.i) == " ") {this.i++}
    if (this.i >= this.string.length) {if (!noneOK) this.Error("Missing argument for "+name); return}
    if (this.string.charAt(this.i) == this.close) {if (!noneOK) this.Error("Extra close brace"); return}
    if (this.string.charAt(this.i) == this.cmd) {this.i++; return this.cmd+this.GetCommand()}
    if (this.string.charAt(this.i) != this.open) {return this.string.charAt(this.i++)}
    var j = ++this.i; var pcount = 1; var c = '';
    while (this.i < this.string.length) {
      c = this.string.charAt(this.i++);
      if (c == this.cmd) {this.i++}
      else if (c == this.open) {pcount++}
      else if (c == this.close) {
        if (pcount == 0) {this.Error("Extra close brace"); return}
        if (--pcount == 0) {return this.string.slice(j,this.i-1)}
      }
    }
    this.Error("Missing close brace");
  },

  /*
   *  Get an argument and process it into an mList
   */
  ProcessArg: function (name) {
    var arg = this.GetArgument(name); if (this.error) return;
    return this.Process(arg);
  },

  /*
   *  Get the name of a delimiter (check it in the delimiter list).
   */
  GetDelimiter: function (name) {
    while (this.string.charAt(this.i) == " ") {this.i++}
    var c = this.string.charAt(this.i);
    if (this.i < this.string.length) {
      this.i++;
      if (c == this.cmd) {c = '\\'+this.GetCommand(name); if (this.error) return}
      if (this.delimiter[c] != null) {return this.delimiter[c]}
    }
    this.Error("Missing or unrecognized delimiter for "+name);
  },
  
  /*
   *  Get a dimension (including its units).
   *  Convert the dimen to em's, except for mu's, which must be
   *  converted when typeset.
   */
  GetDimen: function (name,nomu) {
    var rest = this.string.slice(this.i);
    var match = rest.match(/^\s*([-+]?(\.\d+|\d+(\.\d*)?))(pt|em|ex|mu|px)/);
    if (!match) {this.Error("Missing dimension or its units for "+name); return}
    this.i += match[0].length;
    if (this.string.charAt(this.i) == ' ') {this.i++}
    var d = match[1]-0;
    if (match[4] == 'px') {d /= jsMath.em}
    else if (match[4] == 'pt') {d /= 10}
    else if (match[4] == 'ex') {d *= jsMath.TeX.x_height}
    else if (match[4] == 'mu') {if (nomu) {d = d/18} else {d = [d,'mu']}}
    return d;
  },

  /*
   *  Get the next non-space character
   */
  GetNext: function () {
    while (this.string.charAt(this.i) == " ") {this.i++}
    return this.string.charAt(this.i);
  },
  
  /*
   *  Get an optional LaTeX argument in brackets
   */
  GetBrackets: function (name) {
    var c = this.GetNext(); if (c != '[') return '';
    var start = ++this.i; var pcount = 0;
    while (this.i < this.string.length) {
      var c = this.string.charAt(this.i++);
      if (c == '{') {pcount++}
      else if (c == '}') {
        if (pcount == 0)
          {this.Error("Extra close brace while looking for ']'"); return}
        pcount --;
      } else if (c == this.cmd) {
        this.i++;
      } else if (c == ']') {
        if (pcount == 0) {return this.string.slice(start,this.i-1)}
      }
    }
    this.Error("Couldn't find closing ']' for argument to "+this.cmd+name);
  },
  
  /*
   *  Get everything up to the given control sequence name (token)
   */
  GetUpto: function (name,token) {
    while (this.string.charAt(this.i) == " ") {this.i++}
    var start = this.i; var pcount = 0;
    while (this.i < this.string.length) {
      var c = this.string.charAt(this.i++);
      if (c == '{') {pcount++}
      else if (c == '}') {
        if (pcount == 0)
          {this.Error("Extra close brace while looking for "+this.cmd+token); return}
        pcount --;
      } else if (c == this.cmd) {
        if (pcount == 0)  {
          if (this.string.slice(this.i,this.i+token.length) == token) {
            c = this.string.charAt(this.i+token.length);
            if (c.match(/[^a-z]/i) || !token.match(/[a-z]/i)) {
              var arg = this.string.slice(start,this.i-1);
              this.i += token.length;
              return arg;
            }
          }
        }
        this.i++;
      }
    }
    this.Error("Couldn't find "+this.cmd+token+" for "+name);
  },

  /*
   *  Get a parameter delimited by a control sequence, and
   *  process it to get its mlist
   */
  ProcessUpto: function (name,token) {
    var arg = this.GetUpto(name,token); if (this.error) return;
    return this.Process(arg);
  },

  /*
   *  Get everything up to \end{env}
   */
  GetEnd: function (env) {
    var body = ''; var name = '';
    while (name != env) {
      body += this.GetUpto('begin{'+env+'}','end'); if (this.error) return;
      name = this.GetArgument(this.cmd+'end'); if (this.error) return;
    }
    return body;
  },
  

  /***************************************************************************/


  /*
   *  Ignore spaces
   */
  Space: function () {},

  /*
   *  Collect together any primes and convert them to a superscript
   */
  Prime: function (c) {
    var base = this.mlist.Last();
    if (base == null || (!base.atom && base.type != 'box' && base.type != 'frac'))
       {base = this.mlist.Add(jsMath.mItem.Atom('ord',null))}
    if (base.sup) {this.Error("Prime causes double exponent: use braces to clarify"); return}
    var sup = '';
    while (c == "'") {sup += '\\prime'; c = this.GetNext(); if (c == "'") {this.i++}}
    base.sup = this.Process(sup);
  },

  /*
   *  Raise or lower its parameter by a given amount
   *  @@@ Note that this is different from TeX, which requires an \hbox @@@
   *  ### make this work with mu's ###
   */
  RaiseLower: function (name) {
    var h = this.GetDimen(this.cmd+name,1); if (this.error) return;
    var box = this.ProcessArg(this.cmd+name); if (this.error) return;
    if (name == 'lower') {h = -h}
    this.mlist.Add(new jsMath.mItem('raise',{nuc: box, raise: h}));
  },
  
  /*
   *  Shift an expression to the right or left
   *  @@@ Note that this is different from TeX, which requires a \vbox @@@
   *  ### make this work with mu's ###
   */
  MoveLeftRight: function (name) {
    var x = this.GetDimen(this.cmd+name,1); if (this.error) return;
    var box = this.ProcessArg(this.cmd+name); if (this.error) return;
    if (name == 'moveleft') {x = -x}
    this.mlist.Add(jsMath.mItem.Space(x));
    this.mlist.Add(jsMath.mItem.Atom('ord',box));
    this.mlist.Add(jsMath.mItem.Space(-x));
  },

  /*
   *  Show the argument in a particular color
   *  ### doesn't affect horizontal rules; can we fix that? ###
   */
  Color: function (name) {
    var color = this.GetArgument(this.cmd+name); if (this.error) return;
    // check that it looks like a color?
    this.AddHTML(name,['<SPAN STYLE="color: '+color+'">','</SPAN>']);
  },
  
  /*
   *  Make the argument be a link
   */
  Href: function (name) {
    var href = this.GetArgument(this.cmd+name); if (this.error) return;
    this.AddHTML(name,['<A CLASS="mathlink" HREF="'+href+'">','</A>']);
  },
  
  /*
   *  Apply a CSS class to the argument
   */
  Class: function (name) {
    var clss = this.GetArgument(this.cmd+name); if (this.error) return;
    this.AddHTML(name,['<SPAN CLASS="'+clss+'">','</SPAN>']);
  },
  
  /*
   *  Apply a CSS style to the argument
   */
  Style: function (name) {
    var style = this.GetArgument(this.cmd+name); if (this.error) return;
    this.AddHTML(name,['<SPAN STYLE="'+style+'">','</SPAN>']);
  },
  
  /*
   *  Insert some raw HTML around the argument (this will not affect
   *  the spacing or other TeX features)
   */
  AddHTML: function (name,data) {
    var arg = this.GetArgument(this.cmd+name); if (this.error) return;
    arg = jsMath.Parse(arg,this.mlist.font); if (arg.error) {this.Error(arg); return}
    this.mlist.Add(jsMath.mItem.HTML(data[0]));
    for (var i = 0; i < arg.mlist.Length(); i++) {this.mlist.Add(arg.mlist.Get(i))}
    this.mlist.Add(jsMath.mItem.HTML(data[1]));
  },
  
  /*
   *  Insert a unicode reference as an Ord atom.  Its argument should
   *  be the unicode code point, e.g. \unicode{8211}, or \unicode{x203F}.
   *  You can also specify the height and depth in ems, e.g.,
   *  \unicode{8211,.6,-.3}
   */
  Unicode: function (name) {
    var arg = this.GetArgument(this.cmd+name); if (this.error) return;
    arg = arg.split(','); arg[0] = '&#'+arg[0]+';';
    if (!arg[1]) {arg[1] = 'normal'}
    this.mlist.Add(jsMath.mItem.TextAtom('ord',arg[0],arg[1],arg[2]));
  },


  /*
   *  Implements \frac{num}{den}
   */
  Frac: function (name) {
    var num = this.ProcessArg(this.cmd+name); if (this.error) return;
    var den = this.ProcessArg(this.cmd+name); if (this.error) return;
    this.mlist.Add(jsMath.mItem.Fraction('over',num,den));
  },
  
  /*
   *  Implements \sqrt[n]{...}
   */
  Sqrt: function (name) {
    var n = this.GetBrackets(this.cmd+name); if (this.error) return;
    var arg = this.ProcessArg(this.cmd+name); if (this.error) return;
    box = jsMath.mItem.Atom('radical',arg);
    if (this.n != '') {box.root = this.Process(n); if (this.error) return}
    this.mlist.Add(box);
  },

  /*
   *  Implements \root...\of{...}
   */
  Root: function (name) {
    var n = this.ProcessUpto(this.cmd+name,'of'); if (this.error) return;
    var arg = this.ProcessArg(this.cmd+name); if (this.error) return;
    box = jsMath.mItem.Atom('radical',arg);
    box.root = n; this.mlist.Add(box);
  },
  

  /*
   *  Implements \mathchoice{}{}{}{}
   */
  MathChoice: function (name) {
    var D  = this.ProcessArg(this.cmd+name); if (this.error) return;
    var T  = this.ProcessArg(this.cmd+name); if (this.error) return;
    var S  = this.ProcessArg(this.cmd+name); if (this.error) return;
    var SS = this.ProcessArg(this.cmd+name); if (this.error) return;
    var box = new jsMath.mItem('choice',{D: D, T: T, S: S, SS: SS});
    this.mlist.Add(new jsMath.mItem('choice',{D: D, T: T, S: S, SS: SS}));
  },
  
  /*
   *  Implements \buildrel...\over{...}
   */
  BuildRel: function (name) {
    var top = this.ProcessUpto(this.cmd+name,'over'); if (this.error) return;
    var bot = this.ProcessArg(this.cmd+name); if (this.error) return;
    var op = jsMath.mItem.Atom('op',bot);
    op.limits = 1; op.sup = top;
    this.mlist.Add(op);
  },

  /*
   *  Create a delimiter of the type and size specified in the parameters
   */
  MakeBig: function (name,data) {
    var type = data[0]; var h = data[1] * jsMath.p_height;
    var delim = this.GetDelimiter(this.cmd+name); if (this.error) return;
    this.mlist.Add(jsMath.mItem.Atom(type,jsMath.Box.Delimiter(h,delim,'T')));
  },
  
  /*
   *  Insert the specified character in the given font.
   */
  Char: function (name) {
    var font = this.GetArgument(this.cmd+name); if (this.error) return;
    var n = this.GetArgument(this.cmd+name); if (this.error) return;
    this.mlist.Add(jsMath.mItem.Typeset(jsMath.Box.TeX(n-0,font,'T')));
    return;
  },
  
  /*
   *  Create an array or matrix.
   */
  Matrix: function (name,data) {
    var arg = this.GetArgument(this.cmd+name); if (this.error) return;
    var parse = new jsMath.Parser(arg);
    parse.matrix = name; parse.row = []; parse.table = [];
    parse.Parse(); if (parse.error) {this.Error(parse); return}
    parse.HandleRow(name,1);  // be sure the last row is recorded
    var box = jsMath.Box.Layout(parse.table,data[2]);
    // Add parentheses, if needed
    if (data[0] && data[1]) {
      var left  = jsMath.Box.Delimiter(box.h+box.d,this.delimiter[data[0]],'T');
      var right = jsMath.Box.Delimiter(box.h+box.d,this.delimiter[data[1]],'T');
      box = jsMath.Box.SetList([left,box,right]);
    }
    this.mlist.Add(jsMath.mItem.Atom((data[0]? 'inner': 'ord'),box));
  },
  
  /*
   *  When we see an '&', try to add a matrix entry to the row data.
   *  (Use all the data in the current mList, and then clear it)
   */
  HandleEntry: function (name) {
    if (!this.matrix) 
      {this.Error(name+" can only appear in a matrix or array"); return}
    if (this.mlist.openI != null) {
      var open = this.mlist.Get(this.mlist.openI);
      if (open.left) {this.Error("Missing "+this.cmd+"right")}
        else {this.Error("Missing close brace")}
    }
    if (this.mlist.overI != null) {this.mlist.Over()}
    this.mlist.Atomize('T'); var box = this.mlist.Typeset('T');
    this.row[this.row.length] = box;
    this.mlist = new jsMath.mList(); 
  },
  
  /*
   *  When we see a \cr or \\, try to add a row to the table
   */
  HandleRow: function (name,last) {
    if (!this.matrix)
      {this.Error(this.cmd+name+" can only appear in a matrix or array"); return}
    this.HandleEntry(name);
    if (!last || this.row.length > 1 || this.row[0].format != 'null')
      {this.table[this.table.length] = this.row}
    this.row = [];
  },
  
  /*
   *  LaTeX array environment
   */
  Array: function (name,data) {
    var columns = data[2];
    if (!columns) {
      columns = this.GetArgument(this.cmd+'begin{'+name+'}');
      if (this.error) return;
    }
    columns = columns.replace(/[^clr]/g,'');
    columns = columns.split('');
    var arg = this.GetEnd(name); if (this.error) return;
    var parse = new jsMath.Parser(arg);
    parse.matrix = name; parse.row = []; parse.table = [];
    parse.Parse(); if (parse.error) {this.Error(parse); return}
    parse.HandleRow(name,1);  // be sure the last row is recorded
    var box = jsMath.Box.Layout(parse.table,columns);
    // Add parentheses, if needed
    if (data[0] && data[1]) {
      var left  = jsMath.Box.Delimiter(box.h+box.d,this.delimiter[data[0]],'T');
      var right = jsMath.Box.Delimiter(box.h+box.d,this.delimiter[data[1]],'T');
      box = jsMath.Box.SetList([left,box,right]);
    }
    this.mlist.Add(jsMath.mItem.Atom((data[0]? 'inner': 'ord'),box));
    
  },
  
  /*
   *  LaTeX \begin{env}
   */
  Begin: function (name) {
    var env = this.GetArgument(this.cmd+name); if (this.error) return;
    if (env.match(/[^a-z*]/i)) {this.Error('Invalid environment name "'+env+'"'); return}
    if (!this.environments[env]) {this.Error('Unknown environment "'+env+'"'); return}
    var cmd = this.environments[env];
    if (typeof(cmd) == "string") {cmd = [cmd]}
    this[cmd[0]](env,cmd.slice(1));
  },
  
  /*
   *  LaTeX \end{env}
   */
  End: function (name) {
    var env = this.GetArgument(this.cmd+name); if (this.error) return;
    this.Error(this.cmd+name+'{'+env+'} without matching '+this.cmd+'begin');
  },

  /*
   *  Debugging routine to test stretchable delimiters
   */
  Test: function () {
    var delim = this.GetDelimiter(this.cmd+'test'); if (this.error) return;
    var H = this.GetArgument(this.cmd+'test'); if (this.error) return;
    this.mlist.Add(jsMath.mItem.Typeset(jsMath.Box.Delimiter(H,delim,'T')));
    return;

    var leader = this.GetArgument(this.cmd+'test'); if (this.error) return;
    var W = this.GetArgument(this.cmd+'test'); if (this.error) return;
    if (this.leaders[leader] == null) 
      {this.Error('Unknown leaders "'+leader+'"'); return}
    this.mlist.Add(jsMath.mItem.Typeset(jsMath.Box.Leaders(W,this.leaders[leader])));
    return;
  },
  
  /*
   *  Add a fixed amount of horizontal space
   */
  Spacer: function (name,w) {
    this.mlist.Add(jsMath.mItem.Space(w-0));
  },
  
  /*
   *  Add horizontal space given by the argument
   */
  Hskip: function (name) {
    var w = this.GetDimen(this.cmd+name); if (this.error) return;
    this.mlist.Add(jsMath.mItem.Space(w));
  },

  /*
   *  Typeset the argument as plain text rather than math.
   */
  HBox: function (name) {
    var text = this.GetArgument(this.cmd+name); if (this.error) return;
    var box = jsMath.Box.InternalMath(text);
    this.mlist.Add(jsMath.mItem.Typeset(box));
  },
  
  /*
   *  Insert a rule of a particular width, height and depth
   *  This replaces \hrule and \vrule
   *  @@@ not a standard TeX command, and all three parameters must be given @@@
   */
  Rule: function (name,gif) {
    var w = this.GetDimen(this.cmd+name,1); if (this.error) return;
    var h = this.GetDimen(this.cmd+name,1); if (this.error) return;
    var d = this.GetDimen(this.cmd+name,1); if (this.error) return;
    h += d; 
    if (h != 0) {h = Math.max(1.05/jsMath.em,h)}
    if (h == 0 || w == 0) {gif = "blank"}
    var html = '<IMG SRC="'+jsMath[gif]+'" STYLE="height: '+jsMath.HTML.Em(h)+'; '
                + 'width: '+jsMath.HTML.Em(w)+'">';
    if (d) {html = jsMath.HTML.Place(html,0,-d)}
    this.mlist.Add(jsMath.mItem.Typeset(new jsMath.Box('html',html,w,h-d,d)));
  },
  
  /*
   *  Inserts an empty box of a specific height and depth
   */
  Strut: function () {
    var box = jsMath.Box.Text('','normal','T').Styled();
    box.bh = box.dh = 0; box.h = .8; box.d = .3; box.w = 0;
    this.mlist.Add(jsMath.mItem.Typeset(box));
  },
  
  /*
   *  Handles \phantom, \vphantom and \hphantom
   */
  Phantom: function (name,data) {
    var arg = this.ProcessArg(this.cmd+name); if (this.error) return;
    this.mlist.Add(new jsMath.mItem('phantom',{phantom: arg, v: data[0], h: data[1]}));
  },
  
  /*
   *  Implements \smash
   */
  Smash: function (name,data) {
    var arg = this.ProcessArg(this.cmd+name); if (this.error) return;
    this.mlist.Add(new jsMath.mItem('smash',{smash: arg}));
  },
  
  /*
   *  Puts an accent on the following argument
   */
  MathAccent: function (name,accent) {
    var c = this.ProcessArg(this.cmd+name); if (this.error) return;
    var atom = jsMath.mItem.Atom('accent',c); atom.accent = accent[0];
    this.mlist.Add(atom);
  },

  /*
   *  Handles functions and operators like sin, cos, sum, etc.
   */
  NamedOp: function (name,data) {
    var a = (name.match(/[^acegm-su-z]/)) ? 1: 0;
    var d = (name.match(/[gjpqy]/)) ? 1: 0;
    if (data[1]) {name = data[1]}
    var box = jsMath.mItem.TextAtom('op',name,'cmr10',a,d);
    if (data[0] != null) {box.limits = data[0]}
    this.mlist.Add(box);
  },

  /*
   *  Implements \limits
   */
  Limits: function (name,data) {
    var atom = this.mlist.Last();
    if (!atom || atom.type != 'op') 
      {this.Error(this.cmd+name+" is allowed only on operators"); return}
    atom.limits = data[0];
  },

  /*
   *  Implements macros like those created by \def.  The named control
   *  sequence is replaced by the string given as the first data value.
   *  If there is a second data value, this specifies how many arguments
   *  the macro uses, and in this case, those arguments are substituted
   *  for #1, #2, etc. within the replacement string.
   *  
   *  See the jsMath.Macro() command below for more details.
   */
  Macro: function (name,data) {
    var text = data[0]
    if (data[1]) {
      var args = [];
      for (var i = 0; i < data[1]; i++) 
        {args[args.length] = this.GetArgument(this.cmd+name); if (this.error) return}
      text = ''; var c; var i = 0;
      while (i < data[0].length) {
        c = data[0].charAt(i++);
        if (c == '\\') {text += c + data[0].charAt(i++)}
        else if (c == '#') {
          c = data[0].charAt(i++);
          if (!c.match(/[0-9]/) || c > args.length)
            {this.Error("Illegal macro argument reference"); return}
          text += args[c-1];
        } else {text += c}
      }
    }
    this.string = text + this.string.slice(this.i);
    this.i = 0;
  },
  
  /*
   *  Replace the control sequence with the given text
   */
  Replace: function (name,data) {
    this.mlist.Add(jsMath.mItem.TextAtom(data[0],data[1],data[2],data[3]));
  },

  /*
   *  Implements \overbrace, \underbrace, etc.
   */
  HandleLeaders: function (name,data) {
    var box = this.ProcessArg(this.cmd+name); if (this.error) return;
    box = jsMath.Box.Set(box,'D');
    var leader = jsMath.Box.Leaders(box.w,this.leaders[data[0]]);
    if (data[2]) {leader.y = -leader.h - box.d} else {leader.y = box.h + leader.d}
    leader.x = -(leader.w + box.w)/2;
    box = jsMath.mItem.Atom(data[1]? 'op': 'inner',jsMath.Box.SetList([box,leader],'T'));
    box.limits = (data[1]? 1: 0);
    this.mlist.Add(box);
  },
  
  /*
   *  Implements \llap, \rlap, etc.
   */
  HandleLap: function (name) {
    var box = this.ProcessArg(); if (this.error) return;
    box = this.mlist.Add(new jsMath.mItem('lap',{nuc: box, lap: name}));
  },

  /*
   *  Adds the argument as a specific type of atom (for commands like
   *  \overline, etc.)
   */
  HandleAtom: function (name,data) {
    var arg = this.ProcessArg(this.cmd+name); if (this.error) return;
    this.mlist.Add(jsMath.mItem.Atom(data,arg));
  },


  /*
   *  Process the character associated with a specific \mathcharcode
   */
  HandleMathCode: function (name,code) {
    var type = (code & 0xF000) >> 12;
    var font = (code & 0x0F00) >> 8;
    var code = code & 0x00FF;
    this.HandleTeXchar(type,font,code);
  },
  
  /*
   *  Add a specific character from a TeX font (use the current
   *  font if the type is 7 (variable) or the font is not specified)
   */
  HandleTeXchar: function (type,font,code) {
    if (type == 7 && this.mlist.font != null) {font = this.mlist.font}
    font = jsMath.TeX.fam[font];
    this.mlist.Add(jsMath.mItem.TeXAtom(jsMath.TeX.atom[type],code,font));
  },

  /*
   *  Add a TeX variable character or number
   */
  HandleVariable: function (c) {this.HandleTeXchar(7,1,c.charCodeAt(0))},
  HandleNumber: function (c) {this.HandleTeXchar(7,0,c.charCodeAt(0))},

  /*
   *  For unmapped characters, just add them in as normal
   *  (non-TeX) characters
   */
  HandleOther: function (c) {
    this.mlist.Add(jsMath.mItem.TextAtom('ord',c,'normal'));
  },
  
  /*
   *  Ignore comments in TeX data
   *  ### Some browsers remove the newlines, so this might cause
   *      extra stuff to be ignored; look into this ###
   */
  HandleComment: function () {
    var c;
    while (this.i < this.string.length) {
      c = this.string.charAt(this.i++);
      if (c == "\r" || c == "\n") return;
    }
  },

  /*
   *  Add a style change (e.g., \displaystyle, etc)
   */
  HandleStyle: function (name,style) {
    this.mlist.Add(new jsMath.mItem('style',{style: style[0]}));
  },
  
  /*
   *  Set the current font (e.g., \rm, etc)
   */
  HandleFont: function (name,font) {
    this.mlist.font = font[0];
  },

  /*
   *  Look for and process a control sequence
   */
  HandleCS: function () {
    var cmd = this.GetCommand(); if (this.error) return;
    if (this.macros[cmd]) {
      var macro = this.macros[cmd];
      if (typeof(macro) == "string") {macro = [macro]}
//    var args = macro.slice(1); if (args.length == 1) {args = args[0]}
      this[macro[0]](cmd,macro.slice(1)); return;
    }
    if (this.mathchardef[cmd]) {
      this.HandleMathCode(cmd,this.mathchardef[cmd]);
      return;
    }
    if (this.delimiter[this.cmd+cmd]) {
      this.HandleMathCode(cmd,this.delimiter[this.cmd+cmd]>>12)
      return;
    }
    this.Error("Unknown control sequence '"+this.cmd+cmd+"'");
  },

  /*
   *  Process open and close braces
   */
  HandleOpen: function () {this.mlist.Open()},
  HandleClose: function () {
    if (this.mlist.openI == null) {this.Error("Extra close brace"); return}
    var open = this.mlist.Get(this.mlist.openI);
    if (!open || open.left == null) {this.mlist.Close()}
      else {this.Error("Extra close brace or missing "+this.cmd+"right"); return}
  },

  /*
   *  Implements \left
   */
  HandleLeft: function (name) {
    var left = this.GetDelimiter(this.cmd+name); if (this.error) return;
    this.mlist.Open(left);
  },

  /*
   *  Implements \right
   */
  HandleRight: function (name) {
    var right = this.GetDelimiter(this.cmd+name); if (this.error) return;
    var open = this.mlist.Get(this.mlist.openI);
    if (open && open.left != null) {this.mlist.Close(right)}
      else {this.Error("Extra open brace or missing "+this.cmd+"left");}
  },

  /*
   *  Implements generalized fractions (\over, \above, etc.)
   */
  HandleOver: function (name,data) {
    if (this.mlist.overI != null) 
      {this.Error('Ambiguous use of '+this.cmd+name); return}
    this.mlist.overI = this.mlist.Length();
    this.mlist.overF = {name: name};
    if (data.length > 0) {
      this.mlist.overF.left  = this.delimiter[data[0]];
      this.mlist.overF.right = this.delimiter[data[1]];
    } else if (name.match(/withdelims$/)) {
      this.mlist.overF.left  = this.GetDelimiter(this.cmd+name); if (this.error) return;
      this.mlist.overF.right = this.GetDelimiter(this.cmd+name); if (this.error) return;
    }
    if (name.match(/^above/))
    {
      this.mlist.overF.thickness = this.GetDimen(this.cmd.name,1);
      if (this.error) return;
    }
  },

  /*
   *  Add a superscript to the preceeding atom
   */
  HandleSuperscript: function () {
    var base = this.mlist.Last();
    if (base == null || (!base.atom && base.type != 'box' && base.type != 'frac'))
       {base = this.mlist.Add(jsMath.mItem.Atom('ord',null))}
    if (base.sup) {this.Error("Double exponent: use braces to clarify"); return}
    base.sup = this.ProcessArg('superscript'); if (this.error) return;
  },

  /*
   *  Adda subscript to the preceeding atom
   */
  HandleSubscript: function () {
    var base = this.mlist.Last();
    if (base == null || (!base.atom && base.type != 'box' && base.type != 'frac'))
       {base = this.mlist.Add(jsMath.mItem.Atom('ord',null))}
    if (base.sub) {this.Error("Double subscripts: use braces to clarify"); return}
    base.sub = this.ProcessArg('subscript'); if (this.error) return;
  },

  /*
   *  Parse a TeX math string, handling macros, etc.
   */
  Parse: function () {
    var c;
    while (this.i < this.string.length) {
      c = this.string.charAt(this.i++);
      if (this.mathchar[c]) {this.HandleMathCode(c,this.mathchar[c])}
      else if (this.special[c]) {this[this.special[c]](c)}
      else if (this.letter.test(c)) {this.HandleVariable(c)}
      else if (this.number.test(c)) {this.HandleNumber(c)}
      else {this.HandleOther(c)}
    }
    if (this.mlist.openI != null) {
      var open = this.mlist.Get(this.mlist.openI);
      if (open.left) {this.Error("Missing "+this.cmd+"right")}
        else {this.Error("Missing close brace")}
    }
    if (this.mlist.overI != null) {this.mlist.Over()}
  },

  /*
   *  Perform the processing of Appendix G
   */
  Atomize: function (style) {if (!this.error) this.mlist.Atomize(style)},

  /*
   *  Produce the final HTML.
   *  
   *  We have to wrap the HTML it appropriate <SPAN> tags to hide its
   *  actual dimensions when these don't match the TeX dimensions of the
   *  results.  We also include an image to force the results to take up
   *  the right amount of space.  The results may need to be vertically
   *  adjusted to make the baseline appear in the correct place.
   *  
   *  This is where the touchiest browser-dependent code appears.
   */
  Typeset: function (style) {
    var box = this.typeset = this.mlist.Typeset(style);
    if (this.error) {return '<SPAN CLASS="error">'+this.error+'</SPAN>'}
    if (box.format == 'null') {return ''};
    var rules = ''; var html

    var w = box.w; var h = box.bh; var d = box.bd;
    box.Styled(); var isSmall = 0; var isBig = 0;
    if (box.bh > box.h && box.bh > jsMath.h+.001) {isSmall = 1; h = box.h;}
    if (box.bd > box.d && box.bd > jsMath.d+.001) {isSmall = 1; d = box.d;}
    if (box.h > jsMath.h) {isBig = 1; h = Math.max(h,box.h);}
    if (box.d > jsMath.d) {isBig = 1; d = Math.max(d,box.d);}

    if (jsMath.show.BBox) {rules += jsMath.HTML.Frame(0,-box.d,w,box.h+box.d,'green')}
    if (jsMath.show.Top) {rules += jsMath.HTML.Line(0,box.h,w,'red')}
    if (jsMath.show.Baseline) {rules += jsMath.HTML.Line(0,0,w,'blue')}

    html = box.html; var y = jsMath.absoluteOffsetY;
    if (jsMath.absoluteHeightVaries) {y += (jsMath.h - box.bh)}
    if (jsMath.spanHeightVaries) {y = 1-box.bh} // for MSIE
    if (isSmall) {// hide the extra size
      if (jsMath.allowAbsolute) {
        html = '<SPAN STYLE="position: relative;'
               +   ' width: '+jsMath.HTML.Em(w)+';'          // for MSIE
               +   ' height: '+jsMath.HTML.Em(jsMath.lineH)+';'  // for MSIE
               +   '">'
               + '<SPAN STYLE="position: relative;">'        // for MSIE (Mac)
                 + '<SPAN STYLE="position: absolute; '
                   + 'top:'+jsMath.HTML.Em(y)+'; left:0;">'
                   + html + '&nbsp;' // space normalizes line height in script styles
                 + '</SPAN>'
                 + '<IMG SRC="'+jsMath.blank+'" STYLE="width: '+jsMath.HTML.Em(w)+'; '
                            + 'height: '+jsMath.HTML.Em(jsMath.h)+';">'
               + '</SPAN>'                                   // for MSIE (Mac)
             + '</SPAN>';
        isBig = 1;
      } else {// remove line height and try to hide the depth
        var dy = jsMath.HTML.Em(Math.max(0,box.bd-jsMath.hd)/3);
        html = '<SPAN STYLE="line-height: 0;'
               + ' position: relative; top: '+dy+'; vertical-align: '+dy
               + '">'
               + html
               + '</SPAN>';
      }
    }
    html = '<NOBR>' + rules + html;
    if (isBig) {// add height and depth to the line
      html += '<IMG SRC="'+jsMath.blank+'" CLASS="mathHD" '
               +   'STYLE="height: '+jsMath.HTML.Em(h+d)+'; '
               +   'vertical-align: '+jsMath.HTML.Em(-d)+';">'
    }
    html += '<NOBR>'
    return html;
  }

});

/*
 *  Make these characters special (and call the given routines)
 */
jsMath.Parser.prototype.AddSpecial({
  cmd:   'HandleCS',
  open:  'HandleOpen',
  close: 'HandleClose'
});


/*
 *  The web-page author can call jsMath.Macro to create additional
 *  TeX macros for use within his or her mathematics.  jsMath.Macro
 *  has two required and one optional parameter.  The first parameter
 *  is the control sequence name that will trigger the macro, and the
 *  second is the replacement string for that control sequence.
 *  NOTE:  since the backslash (\) has special meaning in JavaScript,
 *  you must double the backslash in order to include control sequences
 *  within your replacement string.  E.g., 
 *  
 *      <SCRIPT> jsMath.Macro('R','{\\rm R}') </SCRIPT>
 * 
 *  would make \R produce a bold-faced R.
 *  
 *  The optional parameter tells how many arguments the macro
 *  requires.  These are substituted for #1, #2, etc. within the 
 *  replacement string of the macro.  For example
 *  
 *      <SCRIPT> jsMath.Macro('x','{\vec x}_{#1}') </SCRIPT>
 *  
 *  would make \x1 produce {\vec x}_{1} and \x{i+1} produce {\vec x}_{i+1}.
 *
 *  You can put several jsMath.Macro calls together into one .js file, and
 *  then include that into your web page using a command of the form
 *  
 *      <SCRIPT SRC="..."></SCRIPT>
 *  
 *  in your main HTML page.  This way you can include the same macros
 *  into several web pages, for example.
 */

jsMath.Add(jsMath,{
  Macro: function (name) {
    var macro = jsMath.Parser.prototype.macros;
    macro[name] = ['Macro'];
    for (var i = 1; i < arguments.length; i++) 
      {macro[name][macro[name].length] = arguments[i]}
  }
});


/***************************************************************************/

/*
 *  These routines look through the web page for math elements to process.
 *  There are two main entry points you can call:
 *  
 *      <SCRIPT> jsMath.Process() </SCRIPT>
 *  or
 *      <SCRIPT> jsMath.ProcessBeforeShowing() </SCRIPT>
 *
 *  The first will process the page asynchronously (so the user can start
 *  reading the top of the file while jsMath is still processing the bottom)
 *  while the second does not update until all the mathematics is typeset.
 */

jsMath.Add(jsMath,{

  /*
   *  Typeset a string in \textstyle and return the HTML for it
   */
  TextMode: function (s) {
    var parse = jsMath.Parse(s);
    parse.Atomize('T');
    var html = parse.Typeset('T');
    return html;
  },

  /*
   *  Typeset a string in \displaystyle and return the HTML for it
   *  ### need to give more control over whether to center, etc. ###
   */
  DisplayMode: function (s) {
    var parse = jsMath.Parse(s);
    parse.Atomize('D');
    var html = parse.Typeset('D');
    html = '<p align="CENTER">' + html + '</p>'
    return html;
  },
  
  /*
   *  Return the text of a given DOM element
   */
  GetElementText: function (element) {
    var text = element.innerText;
    if (text == null) {
      text = element.textContent;
      if (text == null) {
        text = element.innerHTML;
      }
    }
    if (text.search('&')) {
      text = text.replace(/&lt;/g,'<');
      text = text.replace(/&gt;/g,'>');
      text = text.replace(/&quot;/g,'"');
      text = text.replace(/&amp;/g,'&');
    }
    return text;
  },
  
  /*
   *  Typeset the contents of an element in \textstyle
   */
  ConvertText: function (element) {
    var text = this.GetElementText(element);
    element.innerHTML = this.TextMode(text);
    element.className = 'typeset';
  },
  
  /*
   *  Typeset the contents of an element in \displaystyle
   */
  ConvertDisplay: function (element) {
    var text = this.GetElementText(element);
    element.innerHTML = this.DisplayMode(text);
    element.className = 'typeset';
  },
  
  /*
   *  Call this at the bottom of your HTML page to have the
   *  mathematics typeset before the page is displayed.
   *  This can take a long time, so the user could cancel the
   *  page before it is complete; use it with caution, and only
   *  when there is a relatively small amount of math on the page.
   */
  ProcessBeforeShowing: function () {
    if (!jsMath.initialized) {jsMath.Init()}
    var element = jsMath.GetMathElements();
    for (var i = 0; i < element.length; i++)
      {jsMath.ProcessElement(element[i])}
    jsMath.ProcessComplete();
  },
  
  /*
   *  Process a math element
   */
  ProcessElement: function (element) {
    window.status = 'Processing Math...';
    if (element.tagName == 'DIV') {
      this.ConvertDisplay(element);
    } else if (element.tagName == 'SPAN') {
      this.ConvertText(element);
    }
  },

  /*
   *  Asynchronously process all the math elements starting with
   *  the k-th one
   */
  ProcessElements: function (k) {
    if (k >= this.element.length) {
      this.ProcessComplete();
    } else {
      this.ProcessElement(this.element[k])
      setTimeout('jsMath.ProcessElements('+(k+1)+')',jsMath.delay);
    }
  },

  /*
   *  Call this at the bottom of your HTML page to have the
   *  mathematics typeset asynchronously.  This lets the user
   *  start reading the mathematics while the rest of the page
   *  is being processed.
   */
  Process: function () {
    if (!jsMath.initialized) {jsMath.Init()}
    this.element = this.GetMathElements();
    window.status = 'Processing Math...';
    setTimeout('jsMath.ProcessElements(0)',jsMath.delay);
  },
  
  element: [],  // the list of math elements on the page

  /*
   *  Look up all the math elements on the page and
   *  put them in a list sorted from top to bottom of the page
   */
  GetMathElements: function () {
    var element = [];
    var math = document.getElementsByTagName('DIV');
    for (var k = 0; k < math.length; k++) {
      if (math[k].className == 'math') {
        if (jsMath.renameOK) {math[k].setAttribute('NAME','_jsMath_')}
          else {element[element.length] = math[k]}
      }
    }
    math = document.getElementsByTagName('SPAN');
    for (var k = 0; k < math.length; k++) {
      if (math[k].className == 'math') {
        if (jsMath.renameOK) {math[k].setAttribute('NAME','_jsMath_')}
          else {element[element.length] = math[k]}
      }
    }
    // this gets the SPAN and DIV elements interleaved in order
    if (jsMath.renameOK) {
      element = document.getElementsByName('_jsMath_')
    } else if (jsMath.hidden.sourceIndex) {
      element.sort(function (a,b) {return a.sourceIndex - b.sourceIndex});
    }
    return element;
  },

  /*
   *  Remove the window message about processing math
   *  and clean up any marked <SPAN> or <DIV> tags
   */
  ProcessComplete: function () {
    if (jsMath.renameOK) {
      var element = document.getElementsByName('_jsMath_');
      for (var i = element.length-1; i >= 0; i--) {
        element[i].removeAttribute('NAME');
      }
    }
    jsMath.element = [];
    window.status = 'Done';
  }

});

/***************************************************************************/

/*
 *  We use a hidden <DIV> for measuring the BBoxes of things
 */
jsMath.hidden = '<DIV CLASS="normal" ID="jsMath.Hidden" ' + 
      'STYLE="position:absolute; top:0 left:0;"></DIV>';
if (document.body.insertAdjacentHTML) {
   document.body.insertAdjacentHTML('AfterBegin',jsMath.hidden);
} else {
   document.write(jsMath.hidden);
}
jsMath.hidden = document.getElementById("jsMath.Hidden");

/*
 *  Initialize everything
 */
jsMath.InitSource();
jsMath.InitBrowser();
jsMath.InitStyles();

//make sure browser-specific loads are done before this
document.write('<SCRIPT>jsMath.CheckFonts()</SCRIPT>');

}

}
