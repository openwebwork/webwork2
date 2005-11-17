/*****************************************************************************
 * 
 *  jsMath: Mathematics on the Web
 *  
 *  This jsMath package makes it possible to display mathematics in HTML pages
 *  that are viewable by a wide range of browsers on both the Mac and the IBM PC,
 *  including browsers that don't process MathML.  See
 *  
 *            http://www.math.union.edu/locate/jsMath
 *
 *  for the latest version, and for documentation on how to use jsMath.
 * 
 *  Copyright (c) 2004-2005 by Davide P. Cervone.
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
if (!jsMath || !jsMath.loaded) {
var jsMath_old = jsMath;  // save user customizations

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
  
  version: "2.4a",  // change this if you edit the file
  
  //
  //  Name of image files
  //
  blank: "blank.gif",
  
  defaultH: 0, // default height for characters with none specified

  // Font sizes for \tiny, \small, etc. (must match styles below)
  sizes: [50, 60, 70, 85, 100, 120, 144, 173, 207, 249],

  //
  //  The styles needed for the TeX fonts
  //
  styles: {
    '.size0':          'font-size: 50%',  // tiny (\scriptscriptsize)
    '.size1':          'font-size: 60%',  //       (50% of \large for consistency)
    '.size2':          'font-size: 70%',  // scriptsize
    '.size3':          'font-size: 85%',  // small (70% of \large for consistency)
    '.size4':          'font-size: 100%', // normalsize
    '.size5':          'font-size: 120%', // large
    '.size6':          'font-size: 144%', // Large
    '.size7':          'font-size: 173%', // LARGE
    '.size8':          'font-size: 207%', // huge
    '.size9':          'font-size: 249%', // Huge
  
    '.cmr10':          'font-family: cmr10, serif',
    '.cmbx10':         'font-family: cmbx10, cmr10',
    '.cmti10':         'font-family: cmti10, cmr10',
    '.cmmi10':         'font-family: cmmi10',
    '.cmsy10':         'font-family: cmsy10',
    '.cmex10':         'font-family: cmex10',
    
    '.math':           'font-family: serif; font-style: normal; font-weight: normal',
    '.typeset':        'font-family: serif; font-style: normal; font-weight: normal',
    '.normal':         'font-family: serif; font-style: normal; font-weight: normal; '
                          + 'padding:0px; border:0px; margin:0px;',
    'span.typeset':    '',
    'div.typeset':     'text-align: center; margin: 1em 0px;',
    '.mathlink':       'text-decoration: none',
    '.mathHD':         'border-width:0px; width: 1px; margin-right: -1px',
  
    '.error':          'font-size: 10pt; font-style: italic; '
                         + 'background-color: #FFFFCC; padding: 1px; '
                         + 'border: 1px solid #CC0000',

    '.jsM_panel':      'position:fixed; bottom:1.5em; right:1.5em; padding: 10px 20px; '
                         + 'background-color:#DDDDDD; border: outset 2px; '
                         + 'z-index:103; width:auto;',
    '.jsM_button':     'position:fixed; bottom:1px; right:2px; background-color:white; '
                         + 'border: solid 1px #959595; margin:0px; padding: 0px 3px 1px 3px; '
                         + 'z-index:102; color:black; text-decoration:none; font-size:x-small; width:auto;',
    '.jsM_float':      'position:absolute; top:0px; left:0px; max-width:80%; '
                         + 'z-index:101; width:auto; height:auto;',
    '.jsM_drag':       'background-color:#DDDDDD; border: outset 1px; height:12px; font-size: 1px;',
    '.jsM_close':      'background-color:#E6E6E6; border: inset 1px; width:8px; height:8px; margin: 1px 2px;',
    '.jsM_source':     'background-color:#E2E2E2; border: outset 1px; '
                         + 'width:auto; height:auto; padding: 8px 15px; '
                         + 'font-family: courier, fixed; font-size: 90%',
    '.jsM_noFont':     'text-align: center; padding: 10px 20px; border: 3px solid #DD0000; '
                         + ' background-color: #FFF8F8; color: #AA0000; font-size:small; width:auto;',
    '.jsM_fontLink':   'padding: 0px 5px 2px 5px; text-decoration:none; color:black;'
                         + ' border: 2px outset; background-color:#E8E8E8; font-size:80%; width:auto;'
  },
  

  /***************************************************************************/

  /*
   *  Get the width and height (in pixels) of an HTML string
   */
  BBoxFor: function (s) {
    this.hidden.innerHTML = '<NOBR><SPAN CLASS="jsM_scale">'+s+'</SPAN></NOBR>';
    var bbox = {w: this.hidden.offsetWidth, h: this.hidden.offsetHeight};
    this.hidden.innerHTML = '';
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
   *  For browsers that don't handle sizes of italics properly (MSIE)
   */
  EmBoxForItalics: function (s) {
    var bbox = this.BBoxFor(s);
    if (s.match(/<I>|CLASS="icm/i)) {
      bbox.w = this.BBoxFor(s+jsMath.Browser.italicString).w
                - jsMath.Browser.italicCorrection;
    }
    return {w: bbox.w/this.em, h: bbox.h/this.em};
  },

  /*
   *  Initialize jsMath.  This determines the em size, and a variety
   *  of other parameters used throughout jsMath.
   */
  Init: function () {
    if (jsMath.Setup.inited != 1) {
      if (jsMath.Setup.inited) {
        alert("It looks like jsMath failed to set up properly.");
      } else {
        alert("You must call jsMath.Setup.Body() explicitly when jsMath is" +
              "loaded as part of the <HEAD> section");
      }
      jsMath.Setup.Init(); // may fail to load fallback files properly
    }
    this.em = this.BBoxFor('<IMG SRC="'+jsMath.blank+'" STYLE="width:10em; height:1em">').w/10;
    if (jsMath.Browser.italicString) 
      jsMath.Browser.italicCorrection = jsMath.BBoxFor(jsMath.Browser.italicString).w;
    if (jsMath.Browser.hiddenSpace != '') {
      jsMath.Browser.spaceWidth =
        this.EmBoxFor(jsMath.Browser.hiddenSpace +
                      jsMath.Browser.hiddenSpace +
                      jsMath.Browser.hiddenSpace +
                      jsMath.Browser.hiddenSpace +
                      jsMath.Browser.hiddenSpace).w/5;
    }
    var bb = this.BBoxFor('x'); var h = bb.h;
    var d = this.BBoxFor('x<IMG SRC="'+jsMath.blank+'" HEIGHT="'+(h*jsMath.Browser.imgScale)+'" WIDTH="1">').h - h;
    this.h = (h-d)/this.em; this.d = d/this.em;
    this.hd = this.h + this.d;
    this.xWidth = bb.w;  // used to tell if scale has changed
    
    this.Setup.TeXfonts();
    
    var x_height = this.EmBoxFor('<SPAN CLASS="cmr10">M</SPAN>').w/2;
    this.TeX.M_height = x_height*(26/14);
    this.TeX.h = this.h; this.TeX.d = this.d; this.TeX.hd = this.hd;
    
    this.Img.Scale();
    if (!this.initialized) {
      this.Setup.Sizes();
      this.Img.UpdateFonts();
    }

    // factor for \big and its brethren
    this.p_height = (this.TeX.cmex10[0].h + this.TeX.cmex10[0].d) / .85;

    this.initialized = 1;
  },
  
  /*
   *  Get the xWidth size and if it has changed, reinitialize the sizes
   */
  ReInit: function () {
    var w = this.BBoxFor('x').w;
    if (w != this.xWidth) {this.Init()}
  },
  
  /*
   *  Mark jsMath as loaded and copy any user-provided overrides
   */
  Loaded: function () {
    this.Insert(jsMath,jsMath_old);
    jsMath_old = null;
    jsMath.loaded = 1;
  },
  
  /*
   *  Manage JavaScript objects:
   *  
   *      Add:        add/replace items in an object
   *      Insert:     add items to an object
   *      Package:    add items to an object prototype
   */
  Add: function (dst,src) {for (var id in src) {dst[id] = src[id]}},
  Insert: function (dst,src) {
    for (var id in src) {
      if (dst[id] && typeof(src[id]) == 'object'
                  && (typeof(dst[id]) == 'object'
                  ||  typeof(dst[id]) == 'function')) {
        this.Insert(dst[id],src[id]);
      } else {
        dst[id] = src[id];
      }
    }
  },
  Package: function (obj,def) {this.Insert(obj.prototype,def)}

}

/***************************************************************************/

/*
 *  Miscellaneous setup and initialization
 */
jsMath.Setup = {
  
  /*
   *  Insert a DIV at the top of the page with given ID,
   *  attributes, and style settings
   */
  TopHTML: function (id,attributes,styles) {
    try {
      var div = document.createElement('div');
      div.setAttribute("id",'jsMath.'+id);
      for (var i in attributes) {
        div.setAttribute(i,attributes[i]);
        if (i == "class") {div.setAttribute('className',attributes[i])} // MSIE
      }
      for (var i in styles) {div.style[i]= styles[i]}
      if (!document.body.hasChildNodes) {document.body.appendChild(div)}
        else {document.body.insertBefore(div,document.body.firstChild)}
    } catch (err) {
      var html = '<DIV ID="jsMath.'+id+'"';
      for (var id in attributes) {html += ' '+id+'="'+attributes[id]+'"'}
      if (styles) {
        html += ' STYLE="';
        for (var id in styles) {html += ' '+id+':'+styles[id]+';'}
        html += '"';
      }
      html += '</DIV>';
      if (!document.body.insertAdjacentHTML) {document.write(html)}
        else {document.body.insertAdjacentHTML('AfterBegin',html)}
      div = jsMath.Element(id);
    }
    return div;
  },
  
  /*
   *  Source a jsMath JavaScript file
   */
  Script: function (file) {
    if (!file.match('^([a-zA-Z]+:/)?/')) {file = jsMath.root + file}
    document.write('<SCRIPT SRC="'+file+'"></SCRIPT>');
  },
  
  /*
   *  Use a hidden <DIV> for measuring the BBoxes of things
   */
  HTML: function () {
    jsMath.hidden = this.TopHTML("Hidden",{'class':"normal"},{
      position:"absolute", top:0, left:0, border:0, padding:0, margin:0
    });
    jsMath.hiddenTop = jsMath.hidden;
    return;
  },

  /*
   *  Find the root URL for the jsMath files (so we can load
   *  the other .js and .gif files)
   */
  Source: function () {
    var script = document.getElementsByTagName('SCRIPT');
    if (script) {
      for (var i = 0; i < script.length; i++) {
        var src = script[i].src;
        if (src && src.match('(^|/)jsMath.js$')) {
          jsMath.root = src.replace(/jsMath.js$/,'');
          jsMath.Img.root = jsMath.root + "fonts/";
          jsMath.blank = jsMath.root + jsMath.blank;
          this.Domain();
          return;
        }
      }
    }
    jsMath.root = ''; jsMath.Img.root = "fonts/";
  },
  
  /*
   *  Find the most restricted common domain for the main
   *  page and jsMath.  Report an error if jsMath is outside
   *  the domain of the calling page.
   */
  Domain: function () {
    var jsDomain = ''; var pageDomain = document.domain;
    if (jsMath.root.match('://([^/]*)/')) {jsDomain = RegExp.$1}
    jsDomain = jsDomain.replace(/:\d+$/,'');
    if (jsDomain == "" || jsDomain == pageDomain) return;
    //
    // MSIE on the Mac can't change document.domain and 'try' won't
    //   catch the error (Grrr!), so exit for them
    //
    if (navigator.appName == 'Microsoft Internet Explorer' &&
        navigator.platform == 'MacPPC' && navigator.onLine &&
        navigator.userProfile && document.all) return;
    jsDomain = jsDomain.split(/\./); pageDomain = pageDomain.split(/\./);
    if (jsDomain.length < 2 || pageDomain.length < 2 ||
        jsDomain[jsDomain.length-1] != pageDomain[pageDomain.length-1] ||
        jsDomain[jsDomain.length-2] != pageDomain[pageDomain.length-2]) {
      this.DomainWarning();
      return;
    }
    var domain = jsDomain[jsDomain.length-2] + '.' + jsDomain[jsDomain.length-1];
    for (var i = 3; i <= jsDomain.length && i <= pageDomain.length; i++) {
      if (jsDomain[jsDomain.length-i] != pageDomain[pageDomain.length-i]) break;
      domain = jsDomain[jsDomain.length-i] + '.' + domain;
    }
    document.domain = domain;
  },

  DomainWarning: function () {
    alert("In order for jsMath to be able to load the additional "
        + "components that it may need, the jsMath.js file must be "
        + "loaded from a server in the same domain as the page that "
        + "contains it.  Because that is not the case for this page, "
        + "the mathematics displayed here may not appear correctly.");
  },
  
  /*
   *  Look up the default height and depth for a TeX font
   *  and set the skewchar
   */
  TeXfont: function (name) {
    var font = jsMath.TeX[name];
    var WH = jsMath.EmBoxFor('<SPAN CLASS="'+name+'">'+font[65].c+'</SPAN>');
    font.hd = WH.h;
    font.d = jsMath.EmBoxFor('<SPAN CLASS="'+name+'">'+ font[65].c +
      '<IMG SRC="'+jsMath.blank+'" STYLE="height:'+(font.hd*jsMath.Browser.imgScale)+'em; width:1px;"></SPAN>').h
      - font.hd;
    font.h = font.hd - font.d;
    font.dh = .05; if (jsMath.browser == 'Safari') {font.hd *= 2};
    if (name == 'cmmi10') {font.skewchar = 0177} 
    else if (name == 'cmsy10') {font.skewchar = 060}
  },

  /*
   *  Init all the TeX fonts
   */
  TeXfonts: function () {
    for (var i = 0; i < jsMath.TeX.fam.length; i++) 
      {if (jsMath.TeX.fam[i]) {this.TeXfont(jsMath.TeX.fam[i])}}
  },

  /*
   *  Compute font parameters for various sizes
   */
  Sizes: function () {
    jsMath.TeXparams = [];
    for (var j=0; j < jsMath.sizes.length; j++) {jsMath.TeXparams[j] = {}}
    for (var i in jsMath.TeX) {
      if (typeof(jsMath.TeX[i]) != 'object') {
        for (var j=0; j < jsMath.sizes.length; j++) {
          jsMath.TeXparams[j][i] = jsMath.sizes[j]*jsMath.TeX[i]/100;
        }
      }
    }
  },

  
  /*
   *  Send the style definitions to the browser (these may be adjusted
   *  by the browser-specific code)
   */
  Styles: function (styles) {
    if (!styles) {
      styles = jsMath.styles;
      styles['.jsM_scale'] = 'font-size:'+jsMath.Controls.cookie.scale+'%';
    }
    document.writeln('<STYLE TYPE="text/css" ID="jsMath.styles">');
    for (var id in styles) {document.writeln('  '+id+'  {'+styles[id]+'}')}
    document.writeln('</STYLE>');
  },
  
  /*
   *  Do the initialization that requires the BODY to be in place.
   *  (called automatically if the jsMath.js file is loaded in the
   *  BODY, but must be called explicitly if it is in the HEAD).
   */
  Body: function () {
    if (this.inited) return;

    this.inited = -1;

    jsMath.Setup.HTML();
    jsMath.Setup.Source();
    jsMath.Browser.Init();
    jsMath.Controls.Init();
    jsMath.Click.Init();
    jsMath.Setup.Styles();
    
    jsMath.Setup.User();  //  do user-specific initialization

    //make sure browser-specific loads are done before this
    document.write('<SCRIPT>jsMath.Font.Check()</SCRIPT>');
    
    this.inited = 1;
  },
  
  /*
   *  Web page author can override this to do initialization
   *  that must be done before the font check is performed
   */
  User: function () {}
  
};

jsMath.Update = {

  /*
   *  Update specific parameters for a limited number of font entries
   */
  TeXfonts: function (change) {
    for (var font in change) {
      for (var code in change[font]) {
        for (var id in change[font][code]) {
          jsMath.TeX[font][code][id] = change[font][code][id];
        }
      }
    }
  },
  
  /*
   *  Update the character code for every character in a list
   *  of fonts
   */
  TeXfontCodes: function (change) {
    for (var font in change) {
      for (var i = 0; i < change[font].length; i++) {
        jsMath.TeX[font][i].c = change[font][i];
      }
    }
  },

  /*
   *  Add a collection of styles to the style list
   */
  Styles: function (styles) {
    for (var i in styles) {jsMath.styles[i] = styles[i]}
  }
  
};

/***************************************************************************/

/*
 *  Implement browser-specific checks
 */

jsMath.Browser = {

  allowAbsolute: 1,           // tells if browser can nest absolutely positioned
                              //   SPANs inside relative SPANs
  allowAbsoluteDelim: 0,      // OK to use absolute placement for building delims?
  separateSkips: 0,           // MSIE doesn't do negative left margins, and
                              //   Netscape doesn't combine skips well

  msieSpaceFix: '',           // for MSIE spacing bug fix
  msieCenterBugFix: '',       // for MSIE centering bug with image fonts
  msieInlineBlockFix: '',     // for MSIE alignment bug in non-quirks mode
  imgScale: 1,                // MSI scales images for 120dpi screens, so compensate

  renameOK: 1,                // tells if brower will find a tag whose name
                              //   has been set via setAttributes

  delay: 1,                   // delay for asynchronous math processing
  
  spaceWidth: 0,              // Konqueror space fix
  hiddenSpace: "",            // ditto
  valignBug: 0,               // Konqueror doesn't nest vertical-align

  operaHiddenFix: '',         // for Opera to fix bug with math in tables

  /*
   *  Determine if the "top" of a <SPAN> is always at the same height
   *  or varies with the height of the rest of the line (MSIE).
   */
  TestSpanHeight: function () {
    jsMath.hidden.innerHTML = '<SPAN><IMG SRC="'+jsMath.blank+'" STYLE="height: 2em"></SPAN>';
    var span = jsMath.hidden.getElementsByTagName('SPAN')[0];
    var img  = jsMath.hidden.getElementsByTagName('IMG')[0];
    this.spanHeightVaries = (span.offsetHeight == img.offsetHeight);
    jsMath.hidden.innerHTML = '';
  },
  
  /*
   *  Determine if the NAME attribute of a tag can be changed
   *  using the setAttribute function, and then be properly
   *  returned by getElementByName.
   */
  TestRenameOK: function () {
    jsMath.hidden.innerHTML = '<SPAN ID="jsMath.test"></SPAN>';
    var test = document.getElementById('jsMath.test');
    test.setAttribute('NAME','jsMath_test');
    this.renameOK = (document.getElementsByName('jsMath_test').length > 0);
    jsMath.hidden.innerHTML = '';
  },

  /*
   *  Test for browser characteristics, and adjust things
   *  to overcome specific browser bugs
   */
  Init: function () {
    jsMath.browser = 'unknown';
    this.TestSpanHeight();
    this.TestRenameOK();

    this.MSIE();
    this.Mozilla();
    this.Opera();
    this.OmniWeb();
    this.Safari();
    this.Konqueror();
    
    //
    // Change some routines depending on the browser
    // 
    if (this.allowAbsoluteDelim) {
      jsMath.Box.DelimExtend = jsMath.Box.DelimExtendAbsolute;
      jsMath.Box.Layout = jsMath.Box.LayoutAbsolute;
    } else {
      jsMath.Box.DelimExtend = jsMath.Box.DelimExtendRelative;
      jsMath.Box.Layout = jsMath.Box.LayoutRelative;
    }
    
    if (this.separateSkips) {
      jsMath.HTML.Place = jsMath.HTML.PlaceSeparateSkips;
      jsMath.Typeset.prototype.Place = jsMath.Typeset.prototype.PlaceSeparateSkips;
    }
  },
  
  //
  //  Handle bug-filled Internet Explorer
  //
  MSIE: function () {
    if (this.spanHeightVaries) {
      jsMath.browser = 'MSIE';
      if (navigator.platform == 'Win32') {
        jsMath.Update.TeXfonts({
          cmr10:  {'10': {c: '&Omega;', tclass: 'normal'}},
          cmmi10: {
             '10':  {c: '<I>&Omega;</I>', tclass: 'normal'},
             '126': {c: '&#x7E;<SPAN STYLE="margin-left:.1em"></SPAN>'}
          },
          cmsy10: {
            '10': {c: '&#x2297;', tclass: 'arial'},
            '55': {c: '<SPAN STYLE="margin-right:-.54em">7</SPAN>'}
          },
          cmex10: {'10': {c: '<SPAN STYLE="font-size: 67%">D</SPAN>'}},
          cmti10: {'10': {c: '<I>&Omega;</I>', tclass: 'normal'}},
          cmbx10: {'10': {c: '<B>&Omega;</B>', tclass: 'normal'}}
        });
        this.allowAbsoluteDelim = 1;
        this.separateSkips = 1;
        this.buttonCheck = 1;
        this.msieDivWidthBug = 1;
        this.msieFontBug = 1; this.msieIntegralBug = 1;
        this.msieAlphaBug = 1; this.alphaPrintBug = 1;
        this.msieCenterBugFix = 'position:relative; ';
        this.msieSpaceFix = '<IMG SRC="'+jsMath.blank+'" CLASS="mathHD">';
        this.msieInlineBlockFix = ' display: inline-block;';
        jsMath.Macro('joinrel','\\mathrel{\\kern-5mu}'),
        jsMath.styles['.arial'] = "font-family: 'Arial unicode MS'";
        // MSIE doesn't implement fixed positioning, so use absolute
        jsMath.styles['.jsM_panel'] =
              jsMath.styles['.jsM_panel'].replace(/position:fixed/,"position:absolute").replace(/width:auto/,"");
        jsMath.styles['.jsM_button'] = 'width:1px; '
            + jsMath.styles['.jsM_button'].replace(/position:fixed/,"position:absolute").replace(/width:auto/,"");
        window.onscroll = jsMath.Controls.MoveButton;
        // MSIE will rescale images if the DPIs differ
        if (screen.deviceXDPI && screen.logicalXDPI 
             && screen.deviceXDPI != screen.logicalXDPI) {
          this.imgScale *= screen.logicalXDPI/screen.deviceXDPI;
          jsMath.Controls.cookie.alpha = 0;
        }
        // Handle bug with getting width of italic text
        this.italicString = '<I>x</I>';
        jsMath.EmBoxFor = jsMath.EmBoxForItalics;
      } else if (navigator.platform == 'MacPPC') {
        this.msieAbsoluteBug = 1; this.msieButtonBug = 1;
        this.msieDivWidthBug = 1;
        jsMath.Setup.Script('jsMath-msie-mac.js');
        jsMath.Parser.prototype.macros.angle = ['Replace','ord','<FONT FACE="Symbol">&#x8B;</FONT>','normal'];
        jsMath.styles['.jsM_panel'] = 'width:25em; ' + jsMath.styles['.jsM_panel'].replace(/width:auto/,"");
        jsMath.styles['.jsM_button'] = 'width:1px; ' + jsMath.styles['.jsM_button'].replace(/width:auto/,"");
      }
      jsMath.Macro('not','\\mathrel{\\rlap{\\kern3mu/}}');
    }
  },

  //
  //  Handle Netscape/Mozilla (any flavor)
  //
  Mozilla: function () {
    if (jsMath.hidden.ATTRIBUTE_NODE) {
      jsMath.browser = 'Mozilla';
      if (navigator.platform == 'MacPPC') {
        jsMath.Update.TeXfonts({
          cmr10:  {'10': {c: '&Omega;', tclass: 'normal'}},
          cmmi10: {'10': {c: '<I>&Omega;</I>', tclass: 'normal'}},
          cmsy10: {'10': {c: '&otimes;', tclass: 'normal'}},
          cmex10: {'10': {c: '<SPAN STYLE="font-size: 67%">D</SPAN>'}},
          cmti10: {'10': {c: '<I>&Omega;</I>', tclass: 'normal'}},
          cmbx10: {'10': {c: '<B>&Omega;</B>', tclass: 'normal'}}
        });
      } else {
        jsMath.Setup.Script('jsMath-mozilla.js');
        this.alphaPrintBug = 1;
      }
      for (var i = 0; i < jsMath.TeX.fam.length; i++) {
        if (jsMath.TeX.fam[i]) 
          {jsMath.styles['.'+jsMath.TeX.fam[i]] += '; position: relative'}
      }
      this.allowAbsoluteDelim = 1;
      this.separateSkips = 1;
      jsMath.Macro('not','\\mathrel{\\rlap{\\kern3mu/}}');
    }
  },
  
  //
  //  Handle OmniWeb
  //
  OmniWeb: function () {
    if (navigator.accentColorName) {
      jsMath.browser = 'OmniWeb';
      this.allowAbsolute = !navigator.userAgent.match("OmniWeb/v4");
      this.allowAbsoluteDelim = this.allowAbsolute;
      this.buttonCheck = 1;
    }
  },
    
  //
  //  Handle Opera
  //
  Opera: function () {
    if (navigator.appName == 'Opera' || navigator.userAgent.match(" Opera ")) {
      jsMath.browser = 'Opera';
      jsMath.Update.TeXfonts({
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
      this.allowAbsolute = 0;
      this.delay = 10;
      this.operaHiddenFix = '[Processing Math]';
    }
  },

  //
  //  Handle Safari
  //
  Safari: function () {
    if (navigator.appVersion.match(/Safari\//)) {
      jsMath.browser = 'Safari';
      var version = navigator.userAgent.match("Safari/([0-9]+)");
      version = (version)? version[1] : 200;  // FIXME: hack until I get Tiger
      for (var i = 0; i < jsMath.TeX.fam.length; i++)
        {if (jsMath.TeX.fam[i]) {jsMath.TeX[jsMath.TeX.fam[i]].dh = .1}}
      jsMath.TeX.axis_height += .05;
      this.allowAbsoluteDelim = version >= 125;
      this.safariIFRAMEbug = version >= 312;  // FIXME: find out if they fixed it
      this.safariImgBug = 1;
      this.buttonCheck = 1;
    }
  },
  
  //
  //  Handle Konqueror
  //
  Konqueror: function () {
    if (navigator.product && navigator.product.match("Konqueror")) {
      jsMath.browser = 'Konqueror';
      jsMath.Update.TeXfonts({
        cmr10:  {'20': {c: '&#x2C7;', tclass: 'normal'}},
        cmmi10: {'20': {c: '&kappa;', tclass: 'normal'}},
        cmsy10: {'20': {c: '&#x2264;', tclass: 'normal'}},
        cmex10: {'20': {c: '<SPAN STYLE="font-size: 84%">"</SPAN>'}},
        cmti10: {'20': {c: '<I>&#x2C7;</I>', tclass: 'normal'}},
        cmbx10: {'20': {c: '<B>&#x2C7;</B>', tclass: 'normal'}}
      });
      this.allowAbsolute = 0;
      this.allowAbsoluteDelim = 0;
      if (navigator.userAgent.match(/Konqueror\/(\d+)\.(\d+)/)) {
        if (RegExp.$1 < 3 || (RegExp.$1 == 3 && RegExp.$2 < 3)) {
          this.separateSkips = 1;
          this.valignBug = 1;
          this.hiddenSpace = '&nbsp;';
          jsMath.Box.prototype.Remeasured = function () {return this};
        }
      }
    }
  }

};

/***************************************************************************/

/*
 *  Implement font check and messages
 */
jsMath.Font = {
  
  fallback: "symbol", // the default fallback method

  // the HTML for the missing font message
  message:    
    '<B>No TeX fonts found</B> -- using image fonts instead.<BR>\n'
      + 'These may be slow and might not print well.<BR>\n'
      + 'Use the jsMath control panel to get additional information.',
      
  extra_message:
    'Extra TeX fonts not found: <B><SPAN ID="jsMath.ExtraFonts"></SPAN></B><BR>'
      + 'Using image fonts instead.  This may be slow and might not print well.<BR>\n'
      + 'Use the jsMath control panel to get additional information.',
  
  /*
   *  Look to see if a font is found.  HACK!
   *  Check the character in a given position, and see if it is
   *  wider than the usual one in that position.
   */
  Test1: function (name,n,factor) {
    if (n == null) {n = 124}; if (factor == null) {factor = 2}
    var wh1 = jsMath.BBoxFor('<SPAN STYLE="font-family: '+name+', serif">'+jsMath.TeX[name][n].c+'</SPAN>');
    var wh2 = jsMath.BBoxFor('<SPAN STYLE="font-family: serif">'+jsMath.TeX[name][n].c+'</SPAN>');
    //alert([wh1.w,wh2.w,wh1.h,factor*wh2.w]);
    return (wh1.w > factor*wh2.w && wh1.h != 0);
  },

  Test2: function (name,n,factor) {
    if (n == null) {n = 124}; if (factor == null) {factor = 2}
    var wh1 = jsMath.BBoxFor('<SPAN STYLE="font-family: '+name+', serif">'+jsMath.TeX[name][n].c+'</SPAN>');
    var wh2 = jsMath.BBoxFor('<SPAN STYLE="font-family: serif">'+jsMath.TeX[name][n].c+'</SPAN>');
    //alert([wh2.w,wh1.w,wh1.h,factor*wh1.w]);
    return (wh2.w > factor*wh1.w && wh1.h != 0);
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
   */
  Check: function () {
    var cookie = jsMath.Controls.cookie;
    var wh = jsMath.BBoxFor('<SPAN STYLE="font-family: cmex10">'+jsMath.TeX.cmex10[1].c+'</SPAN>');
    jsMath.nofonts = ((wh.w*3 > wh.h || wh.h == 0) && !this.Test1('cmr10'));
    if (jsMath.nofonts) {
      if (cookie.autofont || cookie.font == 'tex') {
        cookie.font = this.fallback;
        if (cookie.warn) {
          jsMath.nofontMessage = 1;
          cookie.warn = 0; jsMath.Controls.SetCookie(0);
          if (window.NoFontMessage) {window.NoFontMessage()}
                               else {this.Message(this.message)}
        }
      }
    } else {
      if (cookie.autofont) {cookie.font = 'tex'}
      if (cookie.font == 'tex') return;
    }
    if (jsMath.noImgFonts) {cookie.font = 'unicode'}
    if (cookie.font == 'unicode') {
      var platform = ({Win32: 'pc', MacPPC: 'mac'})[navigator.platform] || 'unix';
      jsMath.Setup.Script('jsMath-fallback-'+platform+'.js');
      return;
    }
    if (cookie.font == 'symbol') {
      jsMath.Setup.Script('jsMath-fallback-symbols.js');
      return;
    }
    jsMath.Img.SetFont({
      cmr10:  ['all'], cmmi10: ['all'], cmsy10: ['all'],
      cmex10: ['all'], cmbx10: ['all'], cmti10: ['all']
    });
    jsMath.Img.LoadFont('cm-fonts');
  },

  /*
   *  The message for when no TeX fonts.  You can eliminate this message
   *  by including
   *  
   *      <SCRIPT>jsMath = {Font: {Message: function () {}}}</SCRIPT>
   *
   *  in your HTML file, before loading jsMath.js, if you want.  But this
   *  means the user may not know that he or she can get a better version
   *  of your page.
   */
  Message: function (message) {
    if(jsMath.Element("Warning")) return;
    var div = jsMath.Setup.TopHTML("Warning",{'class':'jsM_Warning'},{});
    div.innerHTML = 
      '<CENTER><TABLE><TR><TD>'
      + '<DIV CLASS="jsM_noFont">' + message
      + '<DIV STYLE="text-align:left"><SPAN STYLE="float:left; margin: 8px 0px 0px 20px">'
      + '<A HREF="javascript:jsMath.Controls.Panel()" CLASS="jsM_fontLink">jsMath Control Panel</A>'
      + '</SPAN><SPAN STYLE="margin: 8px 20px 0px 0px; float:right">'
      + '<A HREF="javascript:jsMath.Font.HideMessage()" CLASS="jsM_fontLink">Hide this Message</A>'
      + '</SPAN></DIV><BR CLEAR="ALL"></DIV>'
      + '<DIV STYLE="width:22em; height:1px"></DIV>'
      + '</TD></TR></TABLE></CENTER><HR>';
  },
  
  HideMessage: function () {
    var message = jsMath.Element("Warning");
    if (message) {message.style.display = "none"}
  },
  
  /*
   *  Register an extra font so jsMath knows about it
   */
  Register: function (data) {
    if (typeof(data) == 'string') {data = {name: data}}
    var fontname = data.name; var name = fontname.replace(/10$/,'');
    var fontfam = jsMath.TeX.fam.length;
    if (!data.style) {data.style = "font-family: "+fontname+", serif"}
    if (!data.styles) {data.styles = {}}
    if (!data.macros) {data.macros = {}}
    /*
     *  Register font family
     */
    jsMath.TeX.fam[fontfam] = fontname;
    data.macros[name] = ['HandleFont',fontfam];
    jsMath.Add(jsMath.Parser.prototype.macros,data.macros);
    /*
     *  Set up styles
     */
    data.styles['.'+fontname] = data.style;
    jsMath.Setup.Styles(data.styles);
    jsMath.Setup.TeXfont(fontname);
    /*
     *  Check for font and give message if missing
     */
    var hasTeXfont = !jsMath.nofonts &&
                      data.test(fontname,data.testChar,data.testFactor);
    if (hasTeXfont && jsMath.Controls.cookie.font == 'tex') {
      if (data.tex) {data.tex(fontname,fontfam)}
      return;
    }
    if (!hasTeXfont && jsMath.Controls.cookie.warn &&
        jsMath.Controls.cookie.font == 'tex' && !jsMath.nofonts) {
      if (!jsMath.Element("Warning")) this.Message(this.extra_message);
      var extra = jsMath.Element("ExtraFonts");
      if (extra) {
        if (extra.innerHTML != "") {extra.innerHTML += ','}
        extra.innerHTML += " " + fontname;
      }
    }
    if (jsMath.Controls.cookie.font == 'unicode') {
      if (data.fallback) {data.fallback(fontname,fontfam)}
      return;
    }
    //  Image fonts
    var font = {}; font[fontname] = ['all'];
    jsMath.Img.SetFont(font);
    jsMath.Img.LoadFont(fontname);
  },

  /*
   *  Load a font
   */
  Load: function (name) {jsMath.Setup.Script("fonts/"+name+"/def.js")}
  
};

/***************************************************************************/

/*
 *  Implements the jsMath control panel.
 *  Much of the code is in jsMath-controls.html, which is
 *  loaded into a hidden IFRAME on demand
 */
jsMath.Controls = {

  //  Data stored in the jsMath cookie
  cookie: {
    scale: 100,
    font: 'tex', autofont: 1, scaleImg: 0, alpha: 1,
    warn: 1, button: 1,
    print: 0, keep: '0D'
  },
  
  cookiePath: '/',  // can also set cookieDomain
  
  
  /*
   *  Load the control panel
   */
  Panel: function () {
    if (!this.panel) {this.panel = jsMath.Element("Controls")}
    if (this.loaded) {this.Main()} else {
      this.openMain = 1;
      if (!this.iframe) {this.iframe = jsMath.Element("Frame")}
      this.iframe.src = jsMath.root+"jsMath-controls.html";
    }
  },
  
  /*
   *  Create the control panel button
   */
  Button: function () {
    var button = jsMath.Setup.TopHTML("jsMath",{'class':'jsM_button'},{});
    button.innerHTML = 
      '<A HREF="javascript:jsMath.Controls.Panel()" '+
         'STYLE="text-decoration:inherit; color:inherit">' +
      '<SPAN TITLE="Open jsMath Control Panel">jsMath</SPAN></A>'
    if (!this.cookie.button) {button.style.display = "none"}
  },
  
 /*
  *  MSIE doesn't implement position:fixed, so redraw the button on scrolls.
  */
  MoveButton: function () {
    if (!this.button) {this.button = jsMath.Element("jsMath")}
    this.button.style.visibility = "hidden";
    this.button.style.visibility = "visible";
  },

  /*
   *  Create the HTML needed for control panel
   */
  Init: function () {
    this.document = document;
    this.panel = jsMath.Setup.TopHTML("Controls", {'class':"jsM_panel"},{display:'none'});
    if (!jsMath.Browser.msieButtonBug) {this.Button()}
      else {setTimeout("jsMath.Controls.Button()",500)}
    if (jsMath.Browser.safariIFRAMEbug) {
      document.write(
         '<IFRAME SRC="'+jsMath.root+'/jsMath-controls.html" '
         + 'ID="jsMath.Frame" SCROLLING="no" '
         + 'STYLE="visibility:hidden; position:absolute; width:1em; height:1em;">'
         + '</IFRAME>\n');
      return;
    }
    try {
      var frame = document.createElement('iframe');
      frame.setAttribute('scrolling','no');
      frame.style.border = '0px';
      frame.style.width  = '0px';
      frame.style.height = '0px';
      document.body.insertBefore(frame,this.panel);
      this.iframe = frame;
    } catch (err) {
      document.write('<IFRAME SRC="" ID="jsMath.Frame" SCROLLING="no" '
         + 'STYLE="visibility:hidden; position:absolute; width:1em; height:1em;">'
         + '</IFRAME>\n');
    }
  },

  /*
   *  Get the cookie data from the browser
   *  (for file: references, use url '?' syntax)
   */
  GetCookie: function () {
    var cookies = document.cookie;
    if (window.location.protocol == 'file:') 
      {cookies = unescape(window.location.search.substr(1))}
    if (cookies.match(/jsMath=([^;]*)/)) {
      var data = RegExp.$1.split(/,/);
      for (var i = 0; i < data.length; i++) {
        var x = data[i].match(/(.*):(.*)/);
        if (x[2].match(/^\d+$/)) {x[2] = 1*x[2]} // convert from string
        this.cookie[x[1]] = x[2];
      }
    }
  },
  
  /*
   *  Save the cookie data in the browser
   *  (for file: urls, append data like CGI reference)
   */
  SetCookie: function (warn) {
    var cookie = [];
    for (var id in this.cookie) {cookie[cookie.length] = id + ':' + this.cookie[id]}
    cookie = cookie.join(',');
    if (window.location.protocol == 'file:') {
      if (!warn) return;
      this.loaded = 0;
      var href = window.location.href;
      href = href.replace(/\?.*/,"") + '?jsMath=' + escape(cookie);
      if (href != window.location.href) {window.location.replace(href)}
    } else {
      if (this.cookiePath) {cookie += '; path='+this.cookiePath}
      if (this.cookieDomain) {cookie += '; domain='+this.cookieDomain}
      if (this.cookie.keep != '0D') {
        var ms = {
          D: 1000*60*60*24,
          W: 1000*60*60*24*7,
          M: 1000*60*60*24*30,
          Y: 1000*60*60*24*365
        };
        var exp = new Date;
        exp.setTime(exp.getTime() +
            this.cookie.keep.substr(0,1) * ms[this.cookie.keep.substr(1,1)]);
        cookie += '; expires=' + exp.toGMTString();
      }
      document.cookie = 'jsMath='+cookie;
      var cookies = document.cookie;
      if (warn && !cookies.match(/jsMath=/))
        {alert("Cookies must be enabled in order to save jsMath options")}
    }
  }

};

/***************************************************************************/

/*
 *  Implements the actions for clicking and double-clicking
 *  on math formulas
 */
jsMath.Click = {
  
  dragging: 0,
  
  /*
   *  Create the hidden DIV used for the tex source window
   */
  Init: function () {
    this.source = jsMath.Setup.TopHTML("Source",{'class':'jsM_float'},{display:'none'});
    this.source.innerHTML =
      '<DIV CLASS="jsM_drag"><DIV CLASS="jsM_close"></DIV></DIV>'
      + '<DIV CLASS="jsM_source"><SPAN></SPAN></DIV>';
    this.drag = this.source.firstChild;
    this.tex  = this.drag.nextSibling.firstChild;
    this.drag.firstChild.onclick = jsMath.Click.CloseSource;
    this.drag.onmousedown = jsMath.Click.StartDragging;
    this.drag.ondragstart = jsMath.Click.False;
    this.drag.onselectstart = jsMath.Click.False;
    this.source.onclick = jsMath.Click.CheckClose;
  },
  False: function () {return false},

  /*
   *  Handle clicking on math to get control panel
   */
  CheckClick: function (event) {
    if (!event) {event = window.event}
    if (event.altKey) jsMath.Controls.Panel();
  },
  
  /*
   *  Handle double-click for seeing TeX code
   */
  CheckDblClick: function (event) {
    if (!event) {event = window.event}
    var event = jsMath.Click.Event(event);

    var source = jsMath.Click.source
    var tex = jsMath.Click.tex;

    source.style.visibility = 'hidden';
    source.style.display = ''; source.style.width = '';
    source.style.left = ''; source.style.top = '';
    tex.innerHTML = '';

    var TeX = this.alt;
    TeX = TeX.replace(/^\s+|\s+$/g,'');
    TeX = TeX.replace(/&/g,'&amp;');
    TeX = TeX.replace(/</g,'&lt;');
    TeX = TeX.replace(/>/g,'&gt;');
    TeX = TeX.replace(/\n/g,'<BR>');
    tex.innerHTML = TeX;

    var h = source.offsetHeight; var w;
    if (jsMath.Browser.msieDivWidthBug) {
      tex.className = 'jsM_source';      // Work around MSIE bug where
      w = tex.offsetWidth + 5;           // DIV's don't collapse to
      tex.className = '';                // their natural widths
    } else {
      w = source.offsetWidth;
    }
    w = Math.max(50,Math.min(w,.8*event.W,event.W-40));
    var x = Math.floor(event.x-w/2); var y = Math.floor(event.y-h/2);
    x = event.X + Math.max(Math.min(x,event.W-w-20),20);
    y = event.Y + Math.max(Math.min(y,event.H-h-5),5);

    source.style.left = x+'px'; source.style.top = y+'px';
    source.style.width = w+'px';
    source.style.visibility = '';
    jsMath.Click.left = x + event.X; jsMath.Click.top = y + event.Y;
    jsMath.Click.w = w; jsMath.Click.h = source.offsetHeight;

    jsMath.Click.DeselectText(x,y);
    return false;
  },

  /*
   *  Get window width, height, and offsets plus
   *  position of pointer relative to the window
   */
  Event: function (event) {
    var W = window.innerWidth  || document.body.clientWidth;
    var H = window.innerHeight || document.body.clientHeight;
    var X = window.pageXOffset; var Y = window.pageYOffset;
    if (X == null) {X = document.body.clientLeft; Y = document.body.clientTop}
    var x = event.pageX; var y = event.pageY;
    if (x == null) {
      x = event.clientX; y = event.clientY;
      if (jsMath.browser == 'MSIE' && document.compatMode == 'CSS1Compat') {
        X = document.documentElement.scrollLeft;
        Y = document.documentElement.scrollTop;
        W = document.documentElement.clientWidth;
        H = document.documentElement.clientHeight;
      } else {
        X = document.body.scrollLeft;
        Y = document.body.scrollTop;
      }
    } else {x -= X; y -= Y}

    return {x: x, y: y, W: W, H: H, X: X, Y: Y};
  },
  
  /*
   *  Unselect whatever text is selected (since double-clicking
   *  usually selects something)
   */
  DeselectText: function (x,y) {
    if (window.getSelection && window.getSelection().removeAllRanges)
      {window.getSelection().removeAllRanges()}
    else if (document.getSelection && document.getSelection().removeAllRanges)
      {document.getSelection().removeAllRanges()}
    else if (document.selection && document.selection.empty)
      {document.selection.empty()}
    else {
      /* Hack to deselect the text in Opera and Safari */
      if (jsMath.browser == 'MSIE') return;  // don't try it if MISE on Mac
      jsMath.hiddenTop.innerHTML =
        '<textarea style="visibility:hidden" ROWS="1" COLS="1">a</textarea>';
      jsMath.hiddenTop.firstChild.style.position = 'absolute';
      jsMath.hiddenTop.firstChild.style.left = x+'px';
      jsMath.hiddenTop.firstChild.style.top  = y+'px';
      setTimeout(jsMath.Click.SelectHidden,1);
    }
  },
  SelectHidden: function () {
    jsMath.hiddenTop.firstChild.focus();
    jsMath.hiddenTop.firstChild.select();
    jsMath.hiddenTop.innerHTML = '';
  },

  /*
   *  Close the TeX source window
   */
  CloseSource: function () {
    jsMath.Click.tex.innerHTML = '';
    jsMath.Click.source.style.display = 'none';
    jsMath.Click.source.style.visibility = 'hidden';
    jsMath.Click.StopDragging();
    return false;
  },
  CheckClose: function (event) {
    if (!event) {event = window.event}
    if (event.altKey) {jsMath.Click.CloseSource(); return false}
  },
  
  /*
   *  Set up for dragging the source panel
   */
  StartDragging: function (event) {
    if (!event) {event = window.event}
    if (jsMath.Click.dragging) {jsMath.Click.StopDragging(event)}
    var event = jsMath.Click.Event(event);
    jsMath.Click.dragging = 1;
    jsMath.Click.x = event.x + 2*event.X - jsMath.Click.left;
    jsMath.Click.y = event.y + 2*event.Y - jsMath.Click.top;
    jsMath.Click.oldonmousemove = document.body.onmousemove;
    jsMath.Click.oldonmouseup = document.body.onmouseup;
    document.body.onmousemove = jsMath.Click.DragSource;
    document.body.onmouseup = jsMath.Click.StopDragging;
    return false;
  },
  
  /*
   *  Stop dragging the source window
   */
  StopDragging: function (event) {
    if (jsMath.Click.dragging) {
      document.body.onmousemove = jsMath.Click.oldonmousemove;
      document.body.onmouseup   = jsMath.Click.oldonmouseup;
      jsMath.Click.oldonmousemove = null;
      jsMath.Click.oldonmouseup   = null;
      jsMath.Click.dragging = 0;
    }
    return false;
  },
  
  /*
   *  Move the source window (but stay within the browser window)
   */
  DragSource: function (event) {
    if (!event) {event = window.event}
    if (jsMath.Browser.buttonCheck && !event.button) {return jsMath.Click.StopDragging(event)}
    event = jsMath.Click.Event(event);
    var x = event.x + event.X - jsMath.Click.x;
    var y = event.y + event.Y - jsMath.Click.y;
    x = Math.max(event.X,Math.min(event.W+event.X-jsMath.Click.w,x));
    y = Math.max(event.Y,Math.min(event.H+event.Y-jsMath.Click.h,y));
    jsMath.Click.source.style.left = x + 'px';
    jsMath.Click.source.style.top  = y + 'px';
    jsMath.Click.left = x + event.X; jsMath.Click.top = y + event.Y;
    return false;
  }

};

/***************************************************************************/

/*
 *  The TeX font information
 */
jsMath.TeX = {

  //
  //  The TeX font parameters
  //
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
  delim2:     1.0,
  axis_height: .25,
  default_rule_thickness: .04,
  big_op_spacing1:  .111111,
  big_op_spacing2:  .166666,
  big_op_spacing3:  .2,
  big_op_spacing4:  .6,
  big_op_spacing5:  .1,

  integer:          6553.6,     // conversion of em's to TeX internal integer
  scriptspace:         .05,
  nulldelimiterspace:  .12,
  delimiterfactor:     901,
  delimitershortfall:   .5,
  scale:                 1,     //  scaling factor for font dimensions
 
  //  The TeX math atom types (see Appendix G of the TeXbook)
  atom: ['ord', 'op', 'bin', 'rel', 'open', 'close', 'punct', 'ord'],

  //  The TeX font families
  fam: ['cmr10','cmmi10','cmsy10','cmex10','cmti10','','cmbx10'],

  /*
   *  The following are the TeX font mappings and metrics.  The metric
   *  information comes directly from the TeX .tfm files, and the
   *  character mappings are for the TrueType TeX fonts.  Browser-specific
   *  adjustments are made to these tables in the Browser.Init() routine
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
};

/***************************************************************************/

/*
 *  Implement image-based fonts for fallback method
 */
jsMath.Img = {
  
  // font sizes available
  fonts: [50, 60, 70, 85, 100, 120, 144, 173, 207, 249, 298, 358, 430],
    
  // em widths for the various font size directories
  w: {'50': 6.9, '60': 8.3, '70': 9.7, '85': 11.8, '100': 13.9,
      '120': 16.7, '144': 20.0, '173': 24.0, '207': 28.8, '249': 34.6,
      '298': 41.4, '358': 49.8, '430': 59.8},
        
  // index of best font size in the fonts list
  best: 4,
    
  // fonts to update (see UpdateFonts below)
  update: {},
    
  // factor by which to shrink images (for better printing)
  factor: 1,
  
  // image fonts are loaded
  loaded: 0,
  
  // add characters to be drawn using images
  SetFont: function (change) {
    for (var font in change) {
      if (!this.update[font]) {this.update[font] = []}
      this.update[font] = this.update[font].concat(change[font]);
    }
  },

  /*
   *  Called by the exta-font definition files to add an image font
   *  into the mix
   */
  AddFont: function (size,def) {
    if (!jsMath.Img[size]) {jsMath.Img[size] = {}};
    jsMath.Add(jsMath.Img[size],def);
  },
    
  /*
   *  Update font(s) to use image data rather than native fonts
   *  It looks in the jsMath.Img.update array to find the names
   *  of the fonts to udpate, and the arrays of character codes
   *  to set (or 'all' to change every character);
   */
  UpdateFonts: function () {
    var change = this.update; if (!this.loaded) return;
    var best = this[jsMath.Img.fonts[this.best]];
    for (var font in change) {
      for (var i = 0; i < change[font].length; i++) {
        var c = change[font][i];
        if (c == 'all') {for (c in jsMath.TeX[font]) {jsMath.TeX[font][c].img = {}}}
          else {jsMath.TeX[font][c].img = {}}
      }
    }
    this.update = {};
  },
  
  /*
   *  Find the font size that best fits our current font
   *  (this is the directory name for the img files used
   *  in some fallback modes).
   */
  BestSize: function () {
    var w = jsMath.em * this.factor;
    var m = this.w[this.fonts[0]];
    for (var i = 1; i < this.fonts.length; i++) {
      if (w < (this.w[this.fonts[i]] + 2*m) / 3) {return i-1}
      m = this.w[this.fonts[i]];
    }
    return i-1;
  },

  /*
   *  Get the scaling factor for the image fonts
   */
  Scale: function () {
    if (!this.loaded) return;
    this.best = this.BestSize();
    this.em = jsMath.Img.w[this.fonts[this.best]];
    this.scale = (jsMath.em/this.em);
    if (Math.abs(this.scale - 1) < .12) {this.scale = 1}
  },

  /*
   *  Get URL to directory for given font and size, based on the
   *  user's alpha/plain setting
   */
  URL: function (name,size,C) {
    var type = (jsMath.Controls.cookie.alpha) ? '/alpha/': '/plain/';
    if (C == null) {C = "def.js"} else {C = 'char'+C+'.png'}
    if (size != "") {size += '/'}
    return this.root+name+type+size+C;
  },

  /*
   *  Laod the data for an image font
   */
  LoadFont: function (name) {
    if (jsMath.Controls.cookie.print) {
      jsMath.Controls.cookie.print = 0;
      var button = jsMath.Element("jsMath");
      if (button) {button.style.display = "none"}
      this.factor *= 3;
      if (window.location.protocol != 'file:') {jsMath.Controls.SetCookie(0)}
      if (jsMath.Browser.alphaPrintBug) {jsMath.Controls.cookie.alpha = 0}
    }
    document.writeln('<SCRIPT SRC="'+this.URL(name,"")+'"></SCRIPT>');
    this.loaded = 1;
  }
  
};

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
    return jsMath.Browser.msieSpaceFix
      + '<SPAN STYLE="margin-left: '
      +    this.Em(w-jsMath.Browser.spaceWidth)+'">'
      + jsMath.Browser.hiddenSpace + '</SPAN>';
  },

  /*
   *  Create a colored frame (for debugging use)
   */
  Frame: function (x,y,w,h,c,pos) {

    h -= 2/jsMath.em; // use 2 pixels to compensate for border size
    w -= 2/jsMath.em;
    y -= 1/jsMath.em;
    if (!c) {c = 'black'};
    if (pos) {pos = 'absolute;'} else
             {pos = 'relative; margin-right: '+this.Em(-(w+2/jsMath.em))+'; '}
    return '<IMG SRC="'+jsMath.blank+'" STYLE="position:' + pos
             + 'vertical-align: '+this.Em(y)+'; left: '+this.Em(x)+'; '
             + 'width:' +this.Em(w*jsMath.Browser.imgScale)+'; '
             + 'height:'+this.Em(h*jsMath.Browser.imgScale)+'; '
             + 'border: 1px solid '+c+';">';
  },

  /*
   *  Create a rule line for fractions, etc.
   *  Height is converted to pixels (with a minimum of 1), so that
   *    the line will not disappear at small font sizes.  This means that
   *    the thickness will not change if you change the font size, or
   *    may not be correct within a header or other enlarged text.
   */
  Rule: function (w,h) {
    if (h == null) {h = jsMath.TeX.default_rule_thickness}
    if (w == 0 || h == 0) return;  // should make an invisible box?
    w *= jsMath.Browser.imgScale;
    h = Math.round(h*jsMath.em*jsMath.Browser.imgScale+.25);
    if (h < 1) {h = 1};
    return '<IMG SRC="'+jsMath.blank+'" HSPACE="0" VSPACE="0" '
              + 'STYLE="width:'+this.Em(w)+'; height:1px; '
              + 'vertical-align:-1px; '
              + 'border:0px none; border-top:'+h+'px solid">';
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
   *  <SPAN>, otherwise the contents will be clipped.  Netscape
   *  also doesn't combine vertical and horizontal spacing well.
   *  Here the x and y positioning are done in separate <SPAN> tags
   */
  PlaceSeparateSkips: function (html,x,y) {
    if (Math.abs(x) < .0001) {x = 0}
    if (Math.abs(y) < .0001) {y = 0}
    if (y) {html = '<SPAN STYLE="position: relative; top:'+this.Em(-y)+';'
                       + '">' + html + '</SPAN>'}
    if (x) {html = jsMath.Browser.msieSpaceFix 
                       + '<SPAN STYLE="margin-left:'
                       +    this.Em(x-jsMath.Browser.spaceWidth)+';">'
                       +  jsMath.Browser.hiddenSpace + '</SPAN>' + html}
    return html;
  },
  
  /*
   *  Place a SPAN with absolute coordinates
   */
  PlaceAbsolute: function (html,x,y) {
    if (Math.abs(x) < .0001) {x = 0}
    if (Math.abs(y) < .0001) {y = 0}
    html = '<SPAN STYLE="position: absolute; left:'+this.Em(x)+'; '
              + 'top:'+this.Em(y)+';">' + html + '&nbsp;</SPAN>';
              //  space normalizes line height
    return html;
  },

  Absolute: function(html,w,h,d,y,H) {
    var align = "";
    if (d && d != "none") {align = ' vertical-align: '+jsMath.HTML.Em(-d)+';'}
    if (y != "none") {
      if (Math.abs(y) < .0001) {y = 0}
      html = '<SPAN STYLE="position: absolute; '
               + 'top:'+jsMath.HTML.Em(y)+'; left: 0em;">'
               + html + '&nbsp;' // space normalizes line height in script styles
             + '</SPAN>';
    }
    html += '<IMG SRC="'+jsMath.blank+'" STYLE="'
              + 'width:' +jsMath.HTML.Em(w*jsMath.Browser.imgScale)+'; '
              + 'height:'+jsMath.HTML.Em(h*jsMath.Browser.imgScale)+';'+align+'">';
    if (jsMath.Browser.msieAbsoluteBug) {           // for MSIE (Mac)
      html = '<SPAN STYLE="position: relative;">' + html + '</SPAN>';
    }
    html =   '<SPAN STYLE="position: relative;'
           +     ' width: '+jsMath.HTML.Em(w)+';'   // for MSIE
           +     ' height: '+jsMath.HTML.Em(H)+';'  // for MSIE
           +     jsMath.Browser.msieInlineBlockFix  // for MSIE
           +     '">'
           +   html
           + '</SPAN>';
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
   *  replaced by TeX() below, but is still used in fallback mode.)
   */
  Text: function (text,tclass,style,size,a,d) {
    var html = jsMath.Typeset.AddClass(tclass,text);
        html = jsMath.Typeset.AddStyle(style,size,html);
    var BB = jsMath.EmBoxFor(html); var TeX = jsMath.Typeset.TeX(style,size);
    var bd = ((tclass == 'cmsy10' || tclass == 'cmex10')? BB.h-TeX.h: TeX.d*BB.h/TeX.hd);
    var box = new jsMath.Box('text',text,BB.w,BB.h-bd,bd);
    box.style = style; box.size = size; box.tclass = tclass;
    if (d != null) {if (d != 1) {box.d = d}} else {box.d = 0}
    if (a == null || a == 1) {box.h = .9*TeX.M_height}
      else {box.h = 1.1*TeX.x_height + 1*a}; // sometimes a is a string?
    return box;
  },

  /*
   *  Produce a box containing a given TeX character from a given font.
   *  The box is a text box (like the ones above), so that characters from
   *  the same font can be combined.
   */
  TeX: function (C,font,style,size) {
    var c = jsMath.TeX[font][C];
    if (c.d == null) {c.d = 0}; if (c.h == null) {c.h = 0}
    if (c.img != null && c.c != '') this.TeXIMG(font,C,jsMath.Typeset.StyleSize(style,size));
    var scale = jsMath.Typeset.TeX(style,size).scale;
    var h = c.h + jsMath.TeX[font].dh
    var box = new jsMath.Box('text',c.c,c.w*scale,h*scale,c.d*scale);
    box.style = style; box.size = size;
    if (c.tclass) {
      box.tclass = c.tclass;
      box.bh = scale*jsMath.h;
      box.bd = scale*jsMath.d;
    } else {
      box.tclass = font;
      box.bh = scale*jsMath.TeX[font].h;
      box.bd = scale*jsMath.TeX[font].d;
      if (jsMath.Browser.msieFontBug) {
        // hack to avoid Font changing back to the default
        // font when a unicode reference is not followed
        // by a letter or number
        box.html += '<SPAN STYLE="display: none">x</SPAN>'
      }
    }
    if (c.img != null) {
      box.bh = c.img.bh; box.bd = c.img.bd;
      box.tclass = "normal";
    }
    return box;
  },
  
  /*
   *  Set the character's string to the appropriate image file
   */
  TeXIMG: function (font,C,size) {
    var c = jsMath.TeX[font][C];
    if (c.img.size != null && c.img.size == size &&
        c.img.best != null && c.img.best == jsMath.Img.best) return;
    var mustScale = (jsMath.Img.scale != 1);
    var id = jsMath.Img.best + size - 4;
    if (id < 0) {id = 0; mustScale = 1} else
    if (id >= jsMath.Img.fonts.length) {id = jsMath.Img.fonts.length-1; mustScale = 1}
    var imgFont = jsMath.Img[jsMath.Img.fonts[id]];
    var img = imgFont[font][C];
    var scale = 1/jsMath.Img.w[jsMath.Img.fonts[id]];
    if (id != jsMath.Img.best + size - 4) {
      if (c.w != null) {scale = c.w/img[0]} else {
        scale *= jsMath.Img.fonts[size]/jsMath.Img.fonts[4]
              *  jsMath.Img.fonts[jsMath.Img.best]/jsMath.Img.fonts[id];
      }
    }
    var w = img[0]*scale; var h = img[1]*scale; var d = -img[2]*scale; var v;
    var wadjust = (c.w == null || Math.abs(c.w-w) < .01)? "" : " margin-right:"+jsMath.HTML.Em(c.w-w)+';';
    var resize = ""; C = this.HexCode(C);
    if (!mustScale && !jsMath.Controls.cookie.scaleImg) {
      if (2*w < h || (jsMath.Browser.msieAlphaBug && jsMath.Controls.cookie.alpha))
         {resize = "height:"+(img[1]*jsMath.Browser.imgScale)+'px;'}
      resize += " width:"+(img[0]*jsMath.Browser.imgScale)+'px;'
      v = -img[2]+'px';
    } else {
      if (2*w < h || (jsMath.Browser.msieAlphaBug && jsMath.Controls.cookie.alpha))
         {resize = "height:"+jsMath.HTML.Em(h*jsMath.Browser.imgScale)+';'}
      resize += " width:"+jsMath.HTML.Em(w*jsMath.Browser.imgScale)+';'
      v = jsMath.HTML.Em(d);
    }
    var vadjust = (Math.abs(d) < .01 && !jsMath.Browser.valignBug)?
                         "": " vertical-align:"+v+';';
    var URL = jsMath.Img.URL(font,jsMath.Img.fonts[id],C);
    if (jsMath.Browser.msieAlphaBug && jsMath.Controls.cookie.alpha) {
      c.c = '<IMG SRC="'+jsMath.blank+'" '
               + 'STYLE="'+jsMath.Browser.msieCenterBugFix
               + resize + vadjust + wadjust
               + ' filter:progid:DXImageTransform.Microsoft.AlphaImageLoader(src=' + "'"
               + URL + "', sizingMethod='scale'" + ');">';
    } else {
      c.c = '<IMG SRC="'+URL+'" STYLE="'+jsMath.Browser.msieCenterBugFix
                  + resize + vadjust + wadjust + '">';
    }
    c.tclass = "normal";
    c.img.bh = h+d; c.img.bd = -d;
    c.img.size = size; c.img.best = jsMath.Img.best;
  },
  
  /*
   *  Get a two-character hex code (some browsers don't know toString(16))
   */
  HexCode: function (C) {
    var codes = '0123456789ABCDEF';
    var h = Math.floor(C/16); var l = C - 16*h;
    return codes.charAt(h)+codes.charAt(l);
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
   *  Get a character from a TeX font, and make sure that it has
   *  its metrics specified.
   */
  GetChar: function (code,font) {
    var c = jsMath.TeX[font][code];
    if (c.img != null) {this.TeXIMG(font,code,4)}
    if (c.tclass == null) {c.tclass = font}
    if (!c.computedW) {
      c.w = jsMath.EmBoxFor(jsMath.Typeset.AddClass(c.tclass,c.c)).w;
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
      if (isSS && .5*h >= H) {return [c,font,'SS',.5*h]}
      if (isS  && .7*h >= H) {return [c,font,'S',.7*h]}
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
    var ext = jsMath.Typeset.AddClass(rep.tclass,rep.c);
    var w = rep.w; var h = rep.h+rep.d
    var y; var dx;
    if (C.delim.mid) {// braces
      var mid = this.GetChar(C.delim.mid,font);
      var n = Math.ceil((H-(top.h+top.d)-(mid.h+mid.d)-(bot.h+bot.d))/(2*(rep.h+rep.d)));
      H = 2*n*(rep.h+rep.d) + (top.h+top.d) + (mid.h+mid.d) + (bot.h+bot.d);
      if (nocenter) {y = 0} else {y = H/2+a}; var Y = y;
      var html = jsMath.HTML.Place(jsMath.Typeset.AddClass(top.tclass,top.c),0,y-top.h)
               + jsMath.HTML.Place(jsMath.Typeset.AddClass(bot.tclass,bot.c),-(top.w+bot.w)/2,y-(H-bot.d))
               + jsMath.HTML.Place(jsMath.Typeset.AddClass(mid.tclass,mid.c),-(bot.w+mid.w)/2,y-(H+mid.h-mid.d)/2);
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
      var html = jsMath.HTML.Place(jsMath.Typeset.AddClass(top.tclass,top.c),0,y-top.h)
      dx = (w-top.w)/2; if (Math.abs(dx) < .0001) {dx = 0}
      if (dx) {html += jsMath.HTML.Spacer(dx)}
      y -= top.h+top.d + rep.h;
      for (var i = 0; i < n; i++) {html += jsMath.HTML.Place(ext,-w,y-i*h)}
      html += jsMath.HTML.Place(jsMath.Typeset.AddClass(bot.tclass,bot.c),-(w+bot.w)/2,Y-(H-bot.d));
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
    
    if (C.delim.mid) {// braces
      var mid = this.GetChar(C.delim.mid,font);
      var n = Math.ceil((H-(top.h+top.d)-(mid.h+mid.d-.05)-(bot.h+bot.d-.05))/(2*(rep.h+rep.d-.05)));
      H = 2*n*(rep.h+rep.d-.05) + (top.h+top.d) + (mid.h+mid.d-.05) + (bot.h+bot.d-.05);
      
      html = jsMath.HTML.PlaceAbsolute(jsMath.Typeset.AddClass(top.tclass,top.c),0,0);
      var h = rep.h+rep.d - .05; var y = top.d-.05 + rep.h;
      var ext = jsMath.Typeset.AddClass(font,rep.c)
      for (var i = 0; i < n; i++) {html += jsMath.HTML.PlaceAbsolute(ext,0,y+i*h)}
      html += jsMath.HTML.PlaceAbsolute(jsMath.Typeset.AddClass(mid.tclass,mid.c),0,y+n*h-rep.h+mid.h);
      y += n*h + mid.h+mid.d - .05;
      for (var i = 0; i < n; i++) {html += jsMath.HTML.PlaceAbsolute(ext,0,y+i*h)}
      html += jsMath.HTML.PlaceAbsolute(jsMath.Typeset.AddClass(bot.tclass,bot.c),0,y+n*h-rep.h+bot.h);
    } else {// all others
      var n = Math.ceil((H - (top.h+top.d) - (bot.h+bot.d-.05))/(rep.h+rep.d-.05));
      H = n*(rep.h+rep.d-.05) + (top.h+top.d) + (bot.h+bot.d-.05);

      html = jsMath.HTML.PlaceAbsolute(jsMath.Typeset.AddClass(top.tclass,top.c),0,0);
      var h = rep.h+rep.d-.05; var y = top.d-.05 + rep.h;
      var ext = jsMath.Typeset.AddClass(rep.tclass,rep.c);
      for (var i = 0; i < n; i++) {html += jsMath.HTML.PlaceAbsolute(ext,0,y+i*h)}
      html += jsMath.HTML.PlaceAbsolute(jsMath.Typeset.AddClass(bot.tclass,bot.c),0,y+n*h-rep.h+bot.h);
    }
    
    var w = top.w;
    if (nocenter) {h = top.h; y = 0} else {h = H/2 + a; y = h - top.h}
    html = jsMath.HTML.Absolute(html,w,Font.h,"none",-y,top.h);
    var box = new jsMath.Box('html',html,rep.w,h,H-h);
    box.bh = jsMath.TeX[font].h; box.bd = jsMath.TeX[font].d;
    return box;
  },
  
  /*
   *  Get the HTML for a given delimiter of a given height.
   *  It will return either a single character, if one exists, or the
   *  more complex HTML needed for a stretchable delimiter.
   */
  Delimiter: function (H,delim,style,nocenter) {
    var size = 4;  //### pass this?
    var TeX = jsMath.Typeset.TeX(style,size);
    if (!delim) {return this.Space(TeX.nulldelimiterspace)}
    var CFSH = this.DelimBestFit(H,delim[2],delim[1],style);
    if (CFSH == null || CFSH[3] < H) 
      {CFSH = this.DelimBestFit(H,delim[4],delim[3],style)}
    if (CFSH == null) {return this.Space(TeX.nulldelimiterspace)}
    if (CFSH[2] == '')
      {return this.DelimExtend(H,CFSH[0],CFSH[1],TeX.axis_height,nocenter)}
    box = jsMath.Box.TeX(CFSH[0],CFSH[1],CFSH[2],size).Styled();
    if (nocenter) {box.y = -jsMath.TeX[CFSH[1]].dh*TeX.scale}
      else {box.y = -((box.h+box.d)/2 - box.d - TeX.axis_height)}
    if (Math.abs(box.y) < .0001) {box.y = 0}
    if (box.y) {box = jsMath.Box.SetList([box],CFSH[2],size)}
    return box;
  },
  
  /*
   *  Get a character by its TeX charcode, and make sure its width
   *  is specified.
   */
  GetCharCode: function (code) {
    var font = jsMath.TeX.fam[code[0]];
    var Font = jsMath.TeX[font];
    var c = Font[code[1]];
    if (c.img != null) {this.TeXIMG(font,code[1],4)}
    if (c.w == null) {c.w = jsMath.EmBoxFor(jsMath.Typeset.AddClass(c.tclass,c.c)).w}
    if (c.font == null) {c.font = font}
    return c;
  },

  /*
   * Add the class to the html, and use the font if there isn't one
   * specified already
   */

  AddClass: function (tclass,html,font) {
    if (tclass == null) {tclass = font}
    return jsMath.Typeset.AddClass(tclass,html);
  },
  
  /*
   *  Create a horizontally stretchable "delimiter" (like over- and
   *  underbraces).
   */
//###  Add size?
  Leaders: function (W,leader) {
    var h; var d; var w; var html; var font;
    if (leader.lmid) {// braces
      font = jsMath.TeX.fam[leader.left[0]];
      var left = this.GetCharCode(leader.left);
      var right = this.GetCharCode(leader.right);
      var lmid = this.GetCharCode(leader.lmid);
      var rmid = this.GetCharCode(leader.rmid);
      w = (W - left.w - right.w - lmid.w - rmid.w)/2 - .1; h = .4; d = .3;
      if (w < 0) {w = 0}
      html = this.AddClass(left.tclass,left.c,left.font) 
           + jsMath.HTML.Rule(w,left.h)
           + this.AddClass(lmid.tclass,lmid.c+rmid.c,lmid.font)
           + jsMath.HTML.Rule(w,right.h)
           + this.AddClass(right.tclass,right.c,right.font);
    } else { //arrows
      font = jsMath.TeX.fam[leader.rep[0]];
      var left = this.GetCharCode(leader.left? leader.left: leader.rep);
      var rep = this.GetCharCode(leader.rep);
      var right = this.GetCharCode(leader.right? leader.right: leader.rep);
      var n = Math.ceil((W - left.w - right.w + .4)/(rep.w - .3));
      w = (W - left.w - right.w + .4 - n*(rep.w - .3));
      if (leader.left) {h = left.h; d = left.d} else {h = right.h; d = right.d}
      if (d == null) {d = 0}; if (h == null) {h = 0}
      var html = this.AddClass(left.tclass,left.c,left.font); var m = Math.floor(n/2);
      var ext = jsMath.HTML.Place(rep.c,-.3,0);
      var ehtml = ''; for (var i = 0; i < m; i++) {ehtml += ext};
      html += this.AddClass(rep.tclass,ehtml,rep.font) + jsMath.HTML.Spacer(w);
      ehtml = ''; for (var i = m; i < n; i++) {ehtml += ext};
      html += this.AddClass(rep.tclass,ehtml,rep.font);
      if (jsMath.Browser.msieFontBug) {html += '<SPAN STYLE="display: none">x</SPAN>'}
      html += jsMath.HTML.Place(this.AddClass(right.tclass,right.c,right.font),-.4,0);
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
  LayoutRelative: function (size,table,align,cspacing) {
    if (align == null) {align = []}
    if (cspacing == null) {cspacing = []}
    
    // get row and column maximum dimensions
    var scale = jsMath.sizes[size]/100;
    var W = []; var H = []; var D = [];
    var unset = -1000; var bh = unset; var bd = unset;
    var i; var j; var row;
    for (i = 0; i < table.length; i++) {
      row = table[i]; H[i] = jsMath.h*scale; D[i] = jsMath.d*scale;
      for (j = 0; j < row.length; j++) {
        row[j] = row[j].Remeasured();
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
    var HD = (jsMath.hd-.01)*scale;
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
        else {y -= Math.max(HD,D[i]+H[i+1]) + scale/10}
      }
      if (cspacing[j] == null) cspacing[j] = scale;
      if (mlist.length > 0) {
        box = jsMath.Box.SetList(mlist,'T',size);
        html += jsMath.HTML.Place(box.html,cW,0);
        cW = W[j] - box.w + cspacing[j];
      } else {cW += cspacing[j]}
    }
    
    // get the full width and height
    w = -cspacing[W.length-1]; y = (H.length-1)*scale/10;
    for (i = 0; i < W.length; i++) {w += W[i] + cspacing[i]}
    for (i = 0; i < H.length; i++) {y += Math.max(HD,H[i]+D[i])}
    h = y/2 + jsMath.TeX.axis_height; var d = y-h;
    
    // adjust the final row width, and vcenter the table
    //   (add 1/6em at each side for the \,)
    html += jsMath.HTML.Spacer(cW-cspacing[W.length-1] + scale/6);
    html = jsMath.HTML.Place(html,scale/6,h);
    box = new jsMath.Box('html',html,w+scale/3,h,d);
    box.bh = bh; box.bd = bd;
    return box;
  },

  /*
   *  Create the HTML for an alignment (e.g., array or matrix)
   *  Use absolute position for elements in the array.
   *  
   *  ###  still need to allow users to specify row and column attributes,
   *       and do things like \span and \multispan  ###
   */
  LayoutAbsolute: function (size,table,align,cspacing) {
    if (align == null) {align = []}
    if (cspacing == null) {cspacing = []}
    
    // get row and column maximum dimensions
    var scale = jsMath.sizes[size]/100;
    var HD = (jsMath.hd-.01)*scale;
    var W = []; var H = []; var D = [];
    var w = 0; var h; var x; var y;
    var i; var j; var row;
    for (i = 0; i < table.length; i++) {
      row = table[i];
      H[i] = jsMath.h*scale; D[i] = jsMath.d*scale;
      for (j = 0; j < row.length; j++) {
        row[j] = row[j].Remeasured();
        if (row[j].h > H[i]) {H[i] = row[j].h}
        if (row[j].d > D[i]) {D[i] = row[j].d}
        if (j >= W.length) {W[j] = row[j].w}
        else if (row[j].w > W[j]) {W[j] = row[j].w}
      }
    }

    // get the height and depth of the centered table
    y = (H.length-1)*scale/6;
    for (i = 0; i < H.length; i++) {y += Math.max(HD,H[i]+D[i])}
    h = y/2 + jsMath.TeX.axis_height; var d = y - h;

    // lay out the columns
    var html = ''; var entry; w = scale/6;
    for (j = 0; j < W.length; j++) {
      y = H[0]-h;
      for (i = 0; i < table.length; i++) {
        entry = table[i][j];
        if (entry && entry.format != 'null') {
          if (align[j] == 'l') {x = 0} else
          if (align[j] == 'r') {x = W[j] - entry.w} else
            {x = (W[j] - entry.w)/2}
          html += jsMath.HTML.PlaceAbsolute(entry.html,w+x,
                    y-Math.max(0,entry.bh-jsMath.h*scale));
        }
        if (i == table.length-1) {y += D[i]}
        else {y += Math.max(HD,D[i]+H[i+1]) + scale/6}
      }
      if (cspacing[j] == null) cspacing[j] = scale;
      w += W[j] + cspacing[j];
    }
    
    // get the full width
    w = -cspacing[W.length-1]+scale/3;
    for (i = 0; i < W.length; i++) {w += W[i] + cspacing[i]}

    html = jsMath.HTML.Spacer(scale/6)+html+jsMath.HTML.Spacer(scale/6);
    if (jsMath.Browser.spanHeightVaries) {y = h-jsMath.h} else {y = 0}
    html = jsMath.HTML.Absolute(html,w,h+d,d,y,H[0]);
    var box = new jsMath.Box('html',html,w+scale/3,h,d);
    return box;
  },

  /*
   *  Look for math within \hbox and other non-math text
   */
  InternalMath: function (text,size) {
    if (!text.match(/\$|\\\(/)) {return this.Text(text,'normal','T',size).Styled()}
    
    var i = 0; var k = 0; var c; var match = '';
    var mlist = []; var parse; var html; var box;
    while (i < text.length) {
      c = text.charAt(i++);
      if (c == '$') {
        if (match == '$') {
          parse = jsMath.Parse(text.slice(k,i-1),null,size);
          if (parse.error) {
            mlist[mlist.length] = this.Text(parse.error,'error','T',size,1,1);
          } else {
            parse.Atomize();
            mlist[mlist.length] = parse.mlist.Typeset('T',size).Styled();
          }
          match = ''; k = i;
        } else {
          mlist[mlist.length] = this.Text(text.slice(k,i-1),'normal','T',size,1,1);
          match = '$'; k = i;
        }
      } else if (c == '\\') {
        c = text.charAt(i++);
        if (c == '(' && match == '') {
          mlist[mlist.length] = this.Text(text.slice(k,i-2),'normal','T',size,1,1);
          match = ')'; k = i;
        } else if (c == ')' && match == ')') {
          parse = jsMath.Parse(text.slice(k,i-2),null,size);
          if (parse.error) {
            mlist[mlist.length] = this.Text(parse.error,'error','T',size,1,1);
          } else {
            parse.Atomize();
            mlist[mlist.length] = parse.mlist.Typeset('T',size).Styled();
          }
          match = ''; k = i;
        }
      }
    }
    mlist[mlist.length] = this.Text(text.slice(k),'normal','T',size,1,1);
    return this.SetList(mlist,'T',size);
  },
  
  /*
   *  Convert an abitrary box to a typeset box.  I.e., make an
   *  HTML version of the contents of the box, at its desired (x,y)
   *  position.
   */
  Set: function (box,style,size,addstyle) {
    if (box) {
      if (box.type == 'typeset') {return box}
      if (box.type == 'mlist') {
        box.mlist.Atomize(style,size);
        return box.mlist.Typeset(style,size);
      }
      if (box.type == 'text') {
        box = this.Text(box.text,box.tclass,style,size,box.ascend,box.descend);
        if (addstyle != 0) {box.Styled()}
        return box;
      }
      box = this.TeX(box.c,box.font,style,size);
      if (addstyle != 0) {box.Styled()}
      return box;
    }
    return jsMath.Box.Null;
  },

  /*
   *  Convert a list of boxes to a single typeset box.  I.e., finalize
   *  the HTML for the list of boxes, properly spaced and positioned.
   */
  SetList: function (boxes,style,size) {
    var mlist = []; var box;
    for (var i = 0; i < boxes.length; i++) {
      box = boxes[i];
      if (box.type == 'typeset') {box = jsMath.mItem.Typeset(box)}
      mlist[mlist.length] = box;
    }
    var typeset = new jsMath.Typeset(mlist);
    return typeset.Typeset(style,size);
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
      this.html = jsMath.Typeset.AddStyle(this.style,this.size,this.html);
      delete this.tclass; delete this.style;
      this.format = 'html';
    }
    return this;
  },
  
  /*
   *  Recompute the box width to make it more accurate.
   */
  Remeasured: function () {
    if (this.w > 0 && !this.html.match(/position: ?absolute/))
      {this.w = jsMath.EmBoxFor(this.html).w}
    return this;
  }

});


/***************************************************************************/

/*
 *  mItems are the building blocks of mLists (math lists) used to
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
    if (a != null) {atom.nuc.ascend = a}
    if (d != null) {atom.nuc.descend = d}
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
jsMath.mList = function (list,font,size,style) {
  if (list) {this.mlist = list} else {this.mlist = []}
  if (style == null) {style = 'T'}; if (size == null) {size = 4}
  this.data = {openI: null, overI: null, overF: null,
               font: font, size: size, style: style};
  this.init = {size: size, style: style};
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
    var box = this.Add(new jsMath.mItem('boundary',{data: this.data}));
    var olddata = this.data;
    this.data = {}; for (var i in olddata) {this.data[i] = olddata[i]}
    delete this.data.overI; delete this.data.overF;
    this.data.openI = this.mlist.length-1;
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
    var atom; var open = this.data.openI;
    var over = this.data.overI; var from = this.data.overF;
    this.data  = this.mlist[open].data;
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
    var over = this.data.overI; var from = this.data.overF
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
  Atomize: function (style,size) {
    var mitem; var prev = '';
    this.style = style; this.size = size;
    for (var i = 0; i < this.mlist.length; i++) {
      mitem = this.mlist[i]; mitem.delta = 0;
      if (mitem.type == 'choice') 
        {this.mlist = this.Atomize.choice(this.style,mitem,i,this.mlist); i--}
      else if (this.Atomize[mitem.type]) {
        var f = this.Atomize[mitem.type]; // Opera needs separate name
        f(this.style,this.size,mitem,prev,this,i);
      }
      prev = mitem;
    }
    if (mitem && mitem.type == 'bin') {mitem.type = 'ord'}
    if (this.mlist.length >= 2 && mitem.type == 'boundary' &&
        this.mlist[0].type == 'boundary') {this.AddDelimiters(style,size)}
  },

  /*
   *  For a list that has boundary delimiters as its first and last
   *  entries, we replace the boundary atoms by open and close
   *  atoms whose nuclii are the specified delimiters properly sized
   *  for the contents of the list.  (Rule 19)
   */
  AddDelimiters: function(style,size) {
    var unset = -10000; var h = unset; var d = unset;
    for (var i = 0; i < this.mlist.length; i++) {
      mitem = this.mlist[i];
      if (mitem.atom || mitem.type == 'box') {
        h = Math.max(h,mitem.nuc.h+mitem.nuc.y);
        d = Math.max(d,mitem.nuc.d-mitem.nuc.y);
      }
    }
    var TeX = jsMath.TeX; var a = jsMath.Typeset.TeX(style,size).axis_height;
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
  Typeset: function (style,size) {
    var typeset = new jsMath.Typeset(this.mlist);
    return typeset.Typeset(style,size);
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
   *  Handle \displaystyle, \textstyle, etc.
   */
  style: function (style,size,mitem,prev,mlist) {
    mlist.style = mitem.style;
  },
  
  /*
   *  Handle \tiny, \small, etc.
   */
  size: function (style,size,mitem,prev,mlist) {
    mlist.size = mitem.size;
  },
  
  /*
   *  Create empty boxes of the proper sizes for the various
   *  phantom-type commands
   */
  phantom: function (style,size,mitem) {
    var box = mitem.nuc = jsMath.Box.Set(mitem.phantom,style,size);
    if (mitem.h) {box.Remeasured(); box.html = jsMath.HTML.Spacer(box.w)}
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
  smash: function (style,size,mitem) {
    var box = mitem.nuc = jsMath.Box.Set(mitem.smash,style,size).Remeasured();
    box.h = box.d = box.bd = box.bh = 0;
    delete mitem.smash;
    mitem.type = 'box';
  },

  /*
   *  Move a box up or down vertically
   */
  raise: function (style,size,mitem) {
    mitem.nuc = jsMath.Box.Set(mitem.nuc,style,size);
    var y = mitem.raise;
    mitem.nuc.html = jsMath.HTML.Place(mitem.nuc.html,0,y);
    mitem.nuc.h += y; mitem.nuc.d -= y;
    mitem.type = 'ord'; mitem.atom = 1;
  },

  /*
   *  Hide the size of a box so that it laps to the left or right, or
   *  up or down.
   */
  lap: function (style,size,mitem) {
    var box = jsMath.Box.Set(mitem.nuc,style,size).Remeasured();
    var mlist = [box];
    if (mitem.lap == 'llap') {box.x = -box.w} else
    if (mitem.lap == 'rlap') {mlist[1] = jsMath.mItem.Space(-box.w)} else
    if (mitem.lap == 'ulap') {box.y = box.d; box.h = box.d = 0} else
    if (mitem.lap == 'dlap') {box.y = -box.h; box.h = box.d = 0}
    mitem.nuc = jsMath.Box.SetList(mlist,style,size);
    if (mitem.lap == 'ulap' || mitem.lap == 'dlap') {mitem.nuc.h = mitem.nuc.d = 0}
    mitem.type = 'box'; delete mitem.atom;
  },

  /*
   *  Handle a Bin atom. (Rule 5)
   */
  bin: function (style,size,mitem,prev) {
    if (prev) {
      var type  = prev.type;
      if (type == 'bin' || type == 'op' || type == 'rel' ||
          type == 'open' || type == 'punct' || type == '' ||
          (type == 'boundary' && prev.left != '')) {mitem.type = 'ord'}
    } else {mitem.type = 'ord'}
    jsMath.mList.prototype.Atomize.SupSub(style,size,mitem);
  },

  /*
   *  Handle a Rel atom.  (Rule 6)
   */
  rel: function (style,size,mitem,prev) {
    if (prev.type == 'bin') {prev.type = 'ord'}
    jsMath.mList.prototype.Atomize.SupSub(style,size,mitem);
  },

  /*
   *  Handle a Close atom.  (Rule 6)
   */
  close: function (style,size,mitem,prev) {
    if (prev.type == 'bin') {prev.type = 'ord'}
    jsMath.mList.prototype.Atomize.SupSub(style,size,mitem);
  },

  /*
   *  Handle a Punct atom.  (Rule 6)
   */
  punct: function (style,size,mitem,prev) {
    if (prev.type == 'bin') {prev.type = 'ord'}
    jsMath.mList.prototype.Atomize.SupSub(style,size,mitem);
  },

  /*
   *  Handle an Open atom.  (Rule 7)
   */
  open: function (style,size,mitem) {
    jsMath.mList.prototype.Atomize.SupSub(style,size,mitem);
  },

  /*
   *  Handle an Inner atom.  (Rule 7)
   */
  inner: function (style,size,mitem) {
    jsMath.mList.prototype.Atomize.SupSub(style,size,mitem);
  },

  /*
   *  Handle a Vcent atom.  (Rule 8)
   */
  vcenter: function (style,size,mitem) {
    var box = jsMath.Box.Set(mitem.nuc,style,size);
    var TeX = jsMath.Typeset.TeX(style,size);
    box.y = TeX.axis_height - (box.h-box.d)/2;
    mitem.nuc = box; mitem.type = 'ord';
    jsMath.mList.prototype.Atomize.SupSub(style,size,mitem);
  },

  /*
   *  Handle an Over atom.  (Rule 9)
   */
  overline: function (style,size,mitem) {
    var TeX = jsMath.Typeset.TeX(style,size);
    var box = jsMath.Box.Set(mitem.nuc,jsMath.Typeset.PrimeStyle(style),size).Remeasured();
    var t = TeX.default_rule_thickness;
    var rule = jsMath.Box.Rule(box.w,t);
    rule.x = -rule.w; rule.y = box.h + 3*t;
    mitem.nuc = jsMath.Box.SetList([box,rule],style,size);
    mitem.nuc.h += t;
    mitem.type = 'ord';
    jsMath.mList.prototype.Atomize.SupSub(style,size,mitem);
  },

  /*
   *  Handle an Under atom.  (Rule 10)
   */
  underline: function (style,size,mitem) {
    var TeX = jsMath.Typeset.TeX(style,size);
    var box = jsMath.Box.Set(mitem.nuc,jsMath.Typeset.PrimeStyle(style),size).Remeasured();
    var t = TeX.default_rule_thickness;
    var rule = jsMath.Box.Rule(box.w,t);
    rule.x = -rule.w; rule.y = -box.d - 3*t - t;
    mitem.nuc = jsMath.Box.SetList([box,rule],style,size);
    mitem.nuc.d += t;
    mitem.type = 'ord';
    jsMath.mList.prototype.Atomize.SupSub(style,size,mitem);
  },

  /*
   *  Handle a Rad atom.  (Rule 11 plus stuff for \root..\of)
   */
  radical: function (style,size,mitem) {
    var TeX = jsMath.Typeset.TeX(style,size);
    var Cp = jsMath.Typeset.PrimeStyle(style);
    var box = jsMath.Box.Set(mitem.nuc,Cp,size).Remeasured();
    var t = TeX.default_rule_thickness;
    var p = t; if (style == 'D' || style == "D'") {p = TeX.x_height}
    var r = t + p/4; 
    var surd = jsMath.Box.Delimiter(box.h+box.d+r+t,[0,2,0x70,3,0x70],style,1);
    t = surd.h; // thickness of rule is height of surd character
    if (surd.d > box.h+box.d+r) {r = (r+surd.d-box.h-box.d)/2}
    surd.y = box.h+r;
    var rule = jsMath.Box.Rule(box.w,t);
    rule.y = surd.y-t/2; rule.h += 3*t/2; box.x = -box.w;
    var Cr = jsMath.Typeset.UpStyle(jsMath.Typeset.UpStyle(style));
    var root = jsMath.Box.Set(mitem.root,Cr,size).Remeasured();
    if (mitem.root) {
      root.y = .55*(box.h+box.d+3*t+r)-box.d;
      surd.x = Math.max(root.w-(11/18)*surd.w,0);
      rule.x = (7/18)*surd.w;
      root.x = -(root.w+rule.x);
    }
    mitem.nuc = jsMath.Box.SetList([surd,root,rule,box],style,size);
    mitem.type = 'ord';
    jsMath.mList.prototype.Atomize.SupSub(style,size,mitem);
  },

  /*
   *  Handle an Acc atom.  (Rule 12)
   */
  accent: function (style,size,mitem) {
    var TeX = jsMath.Typeset.TeX(style,size);
    var Cp = jsMath.Typeset.PrimeStyle(style);
    var box = jsMath.Box.Set(mitem.nuc,Cp,size);
    var u = box.w; var s; var Font;
    if (mitem.nuc.type == 'TeX') {
      Font = jsMath.TeX[mitem.nuc.font];
      if (Font[mitem.nuc.c].krn && Font.skewchar)
        {s = Font[mitem.nuc.c].krn[Font.skewchar]}
    }
    if (s == null) {s = 0}
    
    var c = mitem.accent[2];
    var font = jsMath.TeX.fam[mitem.accent[1]]; Font = jsMath.TeX[font];
    while (Font[c].n && Font[Font[c].n].w <= u) {c = Font[c].n}
    
    var delta = Math.min(box.h,TeX.x_height);
    if (mitem.nuc.type == 'TeX') {
      var nitem = jsMath.mItem.Atom('ord',mitem.nuc);
      nitem.sup = mitem.sup; nitem.sub = mitem.sub; nitem.delta = 0;
      jsMath.mList.prototype.Atomize.SupSub(style,size,nitem);
      delta += (nitem.nuc.h - box.h);
      box = mitem.nuc = nitem.nuc;
      delete mitem.sup; delete mitem.sub;
    }
    var acc = jsMath.Box.TeX(c,font,style,size);
    acc.y = box.h - delta; acc.x = -box.w + s + (u-acc.w)/2;
    if (Font[c].ic) {acc.x -= Font[c].ic * TeX.scale}

    mitem.nuc = jsMath.Box.SetList([box,acc],style,size);
    if (mitem.nuc.w != box.w) {
      var space = jsMath.mItem.Space(box.w-mitem.nuc.w);
      mitem.nuc = jsMath.Box.SetList([mitem.nuc,space],style,size);
    }
    mitem.type = 'ord';
    jsMath.mList.prototype.Atomize.SupSub(style,size,mitem);
  },

  /*
   *  Handle an Op atom.  (Rules 13 and 13a)
   */
  op: function (style,size,mitem) {
    var TeX = jsMath.Typeset.TeX(style,size); var box;
    mitem.delta = 0; var isD = (style.charAt(0) == 'D');
    if (mitem.limits == null && isD) {mitem.limits = 1}

    if (mitem.nuc.type == 'TeX') {
      var C = jsMath.TeX[mitem.nuc.font][mitem.nuc.c];
      if (isD && C.n) {mitem.nuc.c = C.n; C = jsMath.TeX[mitem.nuc.font][C.n]}
      box = jsMath.Box.Set(mitem.nuc,style,size);
      if (C.ic) {
        mitem.delta = C.ic * TeX.scale;
        if (mitem.limits || !mitem.sub || jsMath.Browser.msieIntegralBug) 
          {box = jsMath.Box.SetList([box,jsMath.mItem.Space(mitem.delta)],style,size)}
      }
      box.y = -((box.h+box.d)/2 - box.d - TeX.axis_height);
      if (Math.abs(box.y) < .0001) {box.y = 0}
    }

    if (!box) {box = jsMath.Box.Set(mitem.nuc,style,size).Remeasured()}
    if (mitem.limits) {
      var W = box.w; var x = box.w;
      var mlist = [box]; var dh = 0; var dd = 0;
      if (mitem.sup) {
        var sup = jsMath.Box.Set(mitem.sup,jsMath.Typeset.UpStyle(style),size).Remeasured();
        sup.x = ((box.w-sup.w)/2 + mitem.delta/2) - x; dh = TeX.big_op_spacing5;
        W = Math.max(W,sup.w); x += sup.x + sup.w;
        sup.y = box.h+sup.d + box.y +
                    Math.max(TeX.big_op_spacing1,TeX.big_op_spacing3-sup.d);
        mlist[mlist.length] = sup; delete mitem.sup;
      }
      if (mitem.sub) {
        var sub = jsMath.Box.Set(mitem.sub,jsMath.Typeset.DownStyle(style),size).Remeasured();
        sub.x = ((box.w-sub.w)/2 - mitem.delta/2) - x; dd = TeX.big_op_spacing5;
        W = Math.max(W,sub.w); x += sub.x + sub.w;
        sub.y = -box.d-sub.h + box.y -
                   Math.max(TeX.big_op_spacing2,TeX.big_op_spacing4-sub.h);
        mlist[mlist.length] = sub; delete mitem.sub;
      }
      if (W > box.w) {box.x = (W-box.w)/2; x += box.x}
      if (x < W) {mlist[mlist.length] = jsMath.mItem.Space(W-x)}
      mitem.nuc = jsMath.Box.SetList(mlist,style,size);
      mitem.nuc.h += dh; mitem.nuc.d += dd;
    } else {
      if (jsMath.Browser.msieIntegralBug && mitem.sub && C && C.ic) 
        {mitem.nuc = jsMath.Box.SetList([box,jsMath.Box.Space(-C.ic*TeX.scale)],style,size)}
      else if (box.y) {mitem.nuc = jsMath.Box.SetList([box],style,size)}
      jsMath.mList.prototype.Atomize.SupSub(style,size,mitem);
    }
  },

  /*
   *  Handle an Ord atom.  (Rule 14)
   */
  ord: function (style,size,mitem,prev,mList,i) {
    if (mitem.nuc.type == 'TeX' && !mitem.sup && !mitem.sub) {
      var nitem = mList.mlist[i+1];
      if (nitem && nitem.atom && nitem.type &&
          (nitem.type == 'ord' || nitem.type == 'op' || nitem.type == 'bin' ||
           nitem.type == 'rel' || nitem.type == 'open' ||
           nitem.type == 'close' || nitem.type == 'punct')) {
        if (nitem.nuc.type == 'TeX' && nitem.nuc.font == mitem.nuc.font) {
          mitem.textsymbol = 1;
          var krn = jsMath.TeX[mitem.nuc.font][mitem.nuc.c].krn;
          krn *= jsMath.Typeset.TeX(style,size).scale;
          if (krn && krn[nitem.nuc.c]) {
            for (var k = mList.mlist.length-1; k > i; k--)
              {mList.mlist[k+1] = mList.mlist[k]}
            mList.mlist[i+1] = jsMath.mItem.Space(krn[nitem.nuc.c]);
          }
        }
      }
    }
    jsMath.mList.prototype.Atomize.SupSub(style,size,mitem);
  },

  /*
   *  Handle a generalized fraction.  (Rules 15 to 15e)
   */
  fraction: function (style,size,mitem) {
    var TeX = jsMath.Typeset.TeX(style,size); var t = 0;
    if (mitem.thickness != null) {t = mitem.thickness}
    else if (mitem.from.match(/over/)) {t = TeX.default_rule_thickness}
    var isD = (style.charAt(0) == 'D');
    var Cn = (style == 'D')? 'T': (style == "D'")? "T'": jsMath.Typeset.UpStyle(style);
    var Cd = (isD)? "T'": jsMath.Typeset.DownStyle(style);
    var num = jsMath.Box.Set(mitem.num,Cn,size).Remeasured();
    var den = jsMath.Box.Set(mitem.den,Cd,size).Remeasured();

    var u; var v; var w;
    var H = (isD)? TeX.delim1 : TeX.delim2;
    var mlist = [jsMath.Box.Delimiter(H,mitem.left,style)]
    var right = jsMath.Box.Delimiter(H,mitem.right,style);

    if (num.w < den.w) {
      num.x = (den.w-num.w)/2;
      den.x = -(num.w + num.x);
      w = den.w; mlist[1] = num; mlist[2] = den;
    } else {
      den.x = (num.w-den.w)/2;
      num.x = -(den.w + den.x);
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
    mitem.nuc = jsMath.Box.SetList(mlist,style,size);
    mitem.type = 'ord'; mitem.atom = 1;
    delete mitem.num; delete mitem.den;
    jsMath.mList.prototype.Atomize.SupSub(style,size,mitem);
  },

  /*
   *  Add subscripts and superscripts.  (Rules 17-18f)
   */
  SupSub: function (style,size,mitem) {
    var TeX = jsMath.Typeset.TeX(style,size);
    var nuc = mitem.nuc;
    var box = mitem.nuc = jsMath.Box.Set(mitem.nuc,style,size,0);
    if (box.format == 'null') 
      {box = mitem.nuc = jsMath.Box.Text('','normal',style,size)}

    if (nuc.type == 'TeX') {
      if (!mitem.textsymbol) {
        var C = jsMath.TeX[nuc.font][nuc.c];
        if (C.ic) {
          mitem.delta = C.ic * TeX.scale;
          if (!mitem.sub) {
            box = mitem.nuc = jsMath.Box.SetList([box,jsMath.Box.Space(mitem.delta)],style,size);
            mitem.delta = 0;
          }
        }
      } else {mitem.delta = 0}
    }

    if (!mitem.sup && !mitem.sub) return;
    mitem.nuc.Styled();
    
    var Cd = jsMath.Typeset.DownStyle(style);
    var Cu = jsMath.Typeset.UpStyle(style);
    var q = jsMath.Typeset.TeX(Cu,size).sup_drop;
    var r = jsMath.Typeset.TeX(Cd,size).sub_drop;
    var u = 0; var v = 0; var p;
    if (nuc.type != 'text' && nuc.type != 'TeX' && nuc.type != 'null')
      {u = box.h - q; v = box.d + r}

    if (mitem.sub) {
      var sub = jsMath.Box.Set(mitem.sub,Cd,size);
      sub = jsMath.Box.SetList([sub,jsMath.mItem.Space(TeX.scriptspace)],style,size);
    }

    if (!mitem.sup) {
      sub.y = -Math.max(v,TeX.sub1,sub.h-(4/5)*jsMath.Typeset.TeX(Cd,size).x_height);
      mitem.nuc = jsMath.Box.SetList([box,sub],style,size).Styled(); delete mitem.sub;
      return;
    }

    var sup = jsMath.Box.Set(mitem.sup,Cu,size);
    sup = jsMath.Box.SetList([sup,jsMath.mItem.Space(TeX.scriptspace)],style,size);
    if (style == 'D') {p = TeX.sup1}
    else if (style.charAt(style.length-1) == "'") {p = TeX.sup3}
    else {p = TeX.sup2}
    u = Math.max(u,p,sup.d+jsMath.Typeset.TeX(Cu,size).x_height/4);

    if (!mitem.sub) {
      sup.y = u;
      mitem.nuc = jsMath.Box.SetList([box,sup],style,size); delete mitem.sup;
      return;
    }

    v = Math.max(v,jsMath.Typeset.TeX(Cd,size).sub2);
    var t = TeX.default_rule_thickness;
    if ((u-sup.d) - (sub.h -v) < 4*t) {
      v = 4*t + sub.h - (u-sup.d);
      p = (4/5)*TeX.x_height - (u-sup.d);
      if (p > 0) {u += p; v -= p}
    }
    sup.Remeasured(); sub.Remeasured();
    sup.y = u; sub.y = -v; sup.x = mitem.delta;
    if (sup.w+sup.x > sub.w)
      {sup.x -= sub.w; mitem.nuc = jsMath.Box.SetList([box,sub,sup],style,size)} else
      {sub.x -= (sup.w+sup.x); mitem.nuc = jsMath.Box.SetList([box,sup,sub],style,size)}

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
    if (style == "S" || style == "S'")   {return .7*v}
    if (style == "SS" || style == "SS'") {return .5*v}
    return v;
  },
  
  /*
   *  Return the size associated with a given style and size
   */
  StyleSize: function (style,size) {
    if      (style == "S" || style == "S'")   {size = Math.max(0,size-2)}
    else if (style == "SS" || style == "SS'") {size = Math.max(0,size-4)}
    return size;
  },

  /*
   *  Return the font parameter table for the given style
   */
  TeX: function (style,size) {
    if      (style == "S" || style == "S'")   {size = Math.max(0,size-2)}
    else if (style == "SS" || style == "SS'") {size = Math.max(0,size-4)}
    return jsMath.TeXparams[size];
  },


  /*
   *  Add the CSS class for the given TeX style
   */
  AddStyle: function (style,size,html) {
    if      (style == "S" || style == "S'")   {size = Math.max(0,size-2)}
    else if (style == "SS" || style == "SS'") {size = Math.max(0,size-4)}
    if (size != 4) {html = '<SPAN CLASS="size'+size+'">' + html + '</SPAN>'}
    return html;
  },

  /*
   *  Add the font class, if needed
   */
  AddClass: function (tclass,html) {
    if (tclass != '' && tclass != 'normal') {html = jsMath.HTML.Class(tclass,html)}
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
  Typeset: function (style,size) {
    this.style = style; this.size = size; var unset = -10000
    this.w = 0; this.h = unset; this.d = unset;
    this.bh = this.h; this.bd = this.d;
    this.tbuf = ''; this.tx = 0; this.tclass = '';
    this.cbuf = ''; this.hbuf = ''; this.hx = 0;
    var mitem = null; var prev; this.x = 0; this.dx = 0;

    for (var i = 0; i < this.mlist.length; i++) {
      prev = mitem; mitem = this.mlist[i];
      switch (mitem.type) {

        case 'size':
          this.FlushClassed();
          this.size = mitem.size;
          mitem = prev; // hide this from TeX
          break;

        case 'style':
          this.FlushClassed();
          if (this.style.charAt(this.style.length-1) == "'")
            {this.style = mitem.style + "'"} else {this.style = mitem.style}
          mitem = prev; // hide this from TeX
          break;

        case 'space':
          if (typeof(mitem.w) == 'object') {
            if (this.style.charAt(1) == 'S') {mitem.w = .5*mitem.w[0]/18}
            else if (this.style.charAt(0) == 'S') {mitem.w = .7*mitem.w[0]/18}
            else {mitem.w = mitem.w[0]/18}
          }
          this.dx += mitem.w-0; // mitem.w is sometimes a string?
          mitem = prev; // hide this from TeX
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
          this.h = Math.max(this.h,mitem.nuc.h+mitem.nuc.y); this.bh = Math.max(this.bh,mitem.nuc.bh);
          this.d = Math.max(this.d,mitem.nuc.d-mitem.nuc.y); this.bd = Math.max(this.bd,mitem.nuc.bd);
          break;
      }
    }
    
    this.FlushClassed(); // make sure scaling is included
    if (this.dx) {this.hbuf += jsMath.HTML.Spacer(this.dx); this.w += this.dx}
    if (this.hbuf == '') {return jsMath.Box.Null}
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
    this.hbuf += jsMath.Typeset.AddStyle(this.style,this.size,this.cbuf);
    this.cbuf = '';
  },

  /*
   *  Add a <SPAN> to position an item's HTML, and
   *  adjust the item's height and depth.
   *  (This may be replaced buy one of the following browser-specific
   *   versions by Browser.Init().)
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
   *  For MSIE on Windows, backspacing must be done in a separate
   *  <SPAN>, otherwise the contents will be clipped.  Netscape
   *  also doesn't combine vertical and horizontal spacing well.
   *  Here, the horizontal and vertical spacing are done separately.
   */
  PlaceSeparateSkips: function (item) {
    if (item.y) {
      if (item.html.match(/^<IMG[^>]*>(<SPAN STYLE="margin-left: [-0-9.]*em"><\/SPAN>)?$/i) && !item.html.match(/top:/)) {
        item.html = item.html.replace(/STYLE="/,
            'STYLE="position:relative; top:'+jsMath.HTML.Em(-item.y)+';');
      } else {
        item.html = '<SPAN STYLE="position: relative; '
                       + 'top:'+jsMath.HTML.Em(-item.y)+';'
                       + '">' + item.html + '</SPAN>'
      }
    }
    if (item.x) 
      {item.html = jsMath.Browser.msieSpaceFix
                       + '<SPAN STYLE="margin-left:'
                       +    jsMath.HTML.Em(item.x-jsMath.Browser.spaceWidth)+';">'
                       + jsMath.Browser.hiddenSpace + '</SPAN>' + item.html}
    item.h += item.y; item.d -= item.y;
    item.x = 0; item.y = 0;
  }
  
});



/***************************************************************************/

/*
 *  The Parse object handles the parsing of the TeX input string, and creates
 *  the mList to be typeset by the Typeset object above.
 */

jsMath.Parse = function (s,font,size,style) {
  var parse = new jsMath.Parser(s,font,size,style);
  parse.Parse();
  return parse;
}

jsMath.Parser = function (s,font,size,style) {
  this.string = s; this.i = 0;
  this.mlist = new jsMath.mList(null,font,size,style);
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
    '!': [5,0,0x21],
    '(': [4,0,0x28],
    ')': [5,0,0x29],
    '*': [2,2,0x03], // \ast
    '+': [2,0,0x2B],
    ',': [6,1,0x3B],
    '-': [2,2,0x00],
    '.': [0,1,0x3A],
    '/': [0,1,0x3D],
    ':': [3,0,0x3A],
    ';': [6,0,0x3B],
    '<': [3,1,0x3C],
    '=': [3,0,0x3D],
    '>': [3,1,0x3E],
    '?': [5,0,0x3F],
    '[': [4,0,0x5B],
    ']': [5,0,0x5D],
//  '{': [4,2,0x66],
//  '}': [5,2,0x67],
    '|': [0,2,0x6A]
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
    braceld:      [0,3,0x7A],
    bracerd:      [0,3,0x7B],
    bracelu:      [0,3,0x7C],
    braceru:      [0,3,0x7D],

  // Greek letters
    alpha:        [0,1,0x0B],
    beta:         [0,1,0x0C],
    gamma:        [0,1,0x0D],
    delta:        [0,1,0x0E],
    epsilon:      [0,1,0x0F],
    zeta:         [0,1,0x10],
    eta:          [0,1,0x11],
    theta:        [0,1,0x12],
    iota:         [0,1,0x13],
    kappa:        [0,1,0x14],
    lambda:       [0,1,0x15],
    mu:           [0,1,0x16],
    nu:           [0,1,0x17],
    xi:           [0,1,0x18],
    pi:           [0,1,0x19],
    rho:          [0,1,0x1A],
    sigma:        [0,1,0x1B],
    tau:          [0,1,0x1C],
    upsilon:      [0,1,0x1D],
    phi:          [0,1,0x1E],
    chi:          [0,1,0x1F],
    psi:          [0,1,0x20],
    omega:        [0,1,0x21],
    varepsilon:   [0,1,0x22],
    vartheta:     [0,1,0x23],
    varpi:        [0,1,0x24],
    varrho:       [0,1,0x25],
    varsigma:     [0,1,0x26],
    varphi:       [0,1,0x27],
    
    Gamma:        [7,0,0x00],
    Delta:        [7,0,0x01],
    Theta:        [7,0,0x02],
    Lambda:       [7,0,0x03],
    Xi:           [7,0,0x04],
    Pi:           [7,0,0x05],
    Sigma:        [7,0,0x06],
    Upsilon:      [7,0,0x07],
    Phi:          [7,0,0x08],
    Psi:          [7,0,0x09],
    Omega:        [7,0,0x0A],

  // Ord symbols
    aleph:        [0,2,0x40],
    imath:        [0,1,0x7B],
    jmath:        [0,1,0x7C],
    ell:          [0,1,0x60],
    wp:           [0,1,0x7D],
    Re:           [0,2,0x3C],
    Im:           [0,2,0x3D],
    partial:      [0,1,0x40],
    infty:        [0,2,0x31],
    prime:        [0,2,0x30],
    emptyset:     [0,2,0x3B],
    nabla:        [0,2,0x72],
    surd:         [1,2,0x70],
    top:          [0,2,0x3E],
    bot:          [0,2,0x3F],
    triangle:     [0,2,0x34],
    forall:       [0,2,0x38],
    exists:       [0,2,0x39],
    neg:          [0,2,0x3A],
    lnot:         [0,2,0x3A],
    flat:         [0,1,0x5B],
    natural:      [0,1,0x5C],
    sharp:        [0,1,0x5D],
    clubsuit:     [0,2,0x7C],
    diamondsuit:  [0,2,0x7D],
    heartsuit:    [0,2,0x7E],
    spadesuit:    [0,2,0x7F],

  // big ops
    coprod:      [1,3,0x60],
    bigvee:      [1,3,0x57],
    bigwedge:    [1,3,0x56],
    biguplus:    [1,3,0x55],
    bigcap:      [1,3,0x54],
    bigcup:      [1,3,0x53],
    intop:       [1,3,0x52], 
    prod:        [1,3,0x51],
    sum:         [1,3,0x50],
    bigotimes:   [1,3,0x4E],
    bigoplus:    [1,3,0x4C],
    bigodot:     [1,3,0x4A],
    ointop:      [1,3,0x48],
    bigsqcup:    [1,3,0x46],
    smallint:    [1,2,0x73],

  // binary operations
    triangleleft:      [2,1,0x2F],
    triangleright:     [2,1,0x2E],
    bigtriangleup:     [2,2,0x34],
    bigtriangledown:   [2,2,0x35],
    wedge:       [2,2,0x5E],
    land:        [2,2,0x5E],
    vee:         [2,2,0x5F],
    lor:         [2,2,0x5F],
    cap:         [2,2,0x5C],
    cup:         [2,2,0x5B],
    ddagger:     [2,2,0x7A],
    dagger:      [2,2,0x79],
    sqcap:       [2,2,0x75],
    sqcup:       [2,2,0x74],
    uplus:       [2,2,0x5D],
    amalg:       [2,2,0x71],
    diamond:     [2,2,0x05],
    bullet:      [2,2,0x0F],
    wr:          [2,2,0x6F],
    div:         [2,2,0x04],
    odot:        [2,2,0x0C],
    oslash:      [2,2,0x0B],
    otimes:      [2,2,0x0A],
    ominus:      [2,2,0x09],
    oplus:       [2,2,0x08],
    mp:          [2,2,0x07],
    pm:          [2,2,0x06],
    circ:        [2,2,0x0E],
    bigcirc:     [2,2,0x0D],
    setminus:    [2,2,0x6E], // for set difference A\setminus B
    cdot:        [2,2,0x01],
    ast:         [2,2,0x03],
    times:       [2,2,0x02],
    star:        [2,1,0x3F],

  // Relations
    propto:      [3,2,0x2F],
    sqsubseteq:  [3,2,0x76],
    sqsupseteq:  [3,2,0x77],
    parallel:    [3,2,0x6B],
    mid:         [3,2,0x6A],
    dashv:       [3,2,0x61],
    vdash:       [3,2,0x60],
    leq:         [3,2,0x14],
    le:          [3,2,0x14],
    geq:         [3,2,0x15],
    ge:          [3,2,0x15],
    succ:        [3,2,0x1F],
    prec:        [3,2,0x1E],
    approx:      [3,2,0x19],
    succeq:      [3,2,0x17],
    preceq:      [3,2,0x16],
    supset:      [3,2,0x1B],
    subset:      [3,2,0x1A],
    supseteq:    [3,2,0x13],
    subseteq:    [3,2,0x12],
    'in':        [3,2,0x32],
    ni:          [3,2,0x33],
    owns:        [3,2,0x33],
    gg:          [3,2,0x1D],
    ll:          [3,2,0x1C],
    not:         [3,2,0x36],
    sim:         [3,2,0x18],
    simeq:       [3,2,0x27],
    perp:        [3,2,0x3F],
    equiv:       [3,2,0x11],
    asymp:       [3,2,0x10],
    smile:       [3,1,0x5E],
    frown:       [3,1,0x5F],

  // Arrows
    Leftrightarrow:   [3,2,0x2C],
    Leftarrow:        [3,2,0x28],
    Rightarrow:       [3,2,0x29],
    leftrightarrow:   [3,2,0x24],
    leftarrow:        [3,2,0x20],
    gets:             [3,2,0x20],
    rightarrow:       [3,2,0x21],
    to:               [3,2,0x21],
    mapstochar:       [3,2,0x37],
    leftharpoonup:    [3,1,0x28],
    leftharpoondown:  [3,1,0x29],
    rightharpoonup:   [3,1,0x2A],
    rightharpoondown: [3,1,0x2B],
    nearrow:          [3,2,0x25],
    searrow:          [3,2,0x26],
    nwarrow:          [3,2,0x2D],
    swarrow:          [3,2,0x2E],

    hbarchar:   [0,0,0x16], // for \hbar
    lhook:      [3,1,0x2C],
    rhook:      [3,1,0x2D],

    ldotp:      [6,1,0x3A], // ldot as a punctuation mark
    cdotp:      [6,2,0x01], // cdot as a punctuation mark
    colon:      [6,0,0x3A], // colon as a punctuation mark

    '#':        [7,0,0x23],
    '$':        [7,0,0x24],
    '%':        [7,0,0x25],
    '&':        [7,0,0x26]
  },
  
  // The delimiter table (see Appendix B of the TeXbook)
  delimiter: {
    '(':                [0,0,0x28,3,0x00],
    ')':                [0,0,0x29,3,0x01],
    '[':                [0,0,0x5B,3,0x02],
    ']':                [0,0,0x5D,3,0x03],
    '<':                [0,2,0x68,3,0x0A],
    '>':                [0,2,0x69,3,0x0B],
    '/':                [0,0,0x2F,3,0x0E],
    '|':                [0,2,0x6A,3,0x0C],
    '.':                [0,0,0x00,0,0x00],
    '\\':               [0,2,0x6E,3,0x0F],
    '\\lmoustache':     [4,3,0x7A,3,0x40],  // top from (, bottom from )
    '\\rmoustache':     [5,3,0x7B,3,0x41],  // top from ), bottom from (
    '\\lgroup':         [4,6,0x28,3,0x3A],  // extensible ( with sharper tips
    '\\rgroup':         [5,6,0x29,3,0x3B],  // extensible ) with sharper tips
    '\\arrowvert':      [0,2,0x6A,3,0x3C],  // arrow without arrowheads
    '\\Arrowvert':      [0,2,0x6B,3,0x3D],  // double arrow without arrowheads
//  '\\bracevert':      [0,7,0x7C,3,0x3E],  // the vertical bar that extends braces
    '\\bracevert':      [0,2,0x6A,3,0x3E],  // we don't load tt, so use | instead
    '\\Vert':           [0,2,0x6B,3,0x0D],
    '\\|':              [0,2,0x6B,3,0x0D],
    '\\vert':           [0,2,0x6A,3,0x0C],
    '\\uparrow':        [3,2,0x22,3,0x78],
    '\\downarrow':      [3,2,0x23,3,0x79],
    '\\updownarrow':    [3,2,0x6C,3,0x3F],
    '\\Uparrow':        [3,2,0x2A,3,0x7E],
    '\\Downarrow':      [3,2,0x2B,3,0x7F],
    '\\Updownarrow':    [3,2,0x6D,3,0x77],
    '\\backslash':      [0,2,0x6E,3,0x0F],  // for double coset G\backslash H
    '\\rangle':         [5,2,0x69,3,0x0B],
    '\\langle':         [4,2,0x68,3,0x0A],
    '\\rbrace':         [5,2,0x67,3,0x09],
    '\\lbrace':         [4,2,0x66,3,0x08],
    '\\}':              [5,2,0x67,3,0x09],
    '\\{':              [4,2,0x66,3,0x08],
    '\\rceil':          [5,2,0x65,3,0x07],
    '\\lceil':          [4,2,0x64,3,0x06],
    '\\rfloor':         [5,2,0x63,3,0x05],
    '\\lfloor':         [4,2,0x62,3,0x04]
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
    vdots:              ['Macro','\\mathinner{\\rlap{\\raise8pt{.\\rule 0pt 6pt 0pt}}\\rlap{\\raise4pt{.}}.}'],
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
    mathbb:             ['Macro','{\\bf #1}',1],
    mathit:             ['Macro','{\\it #1}',1],

    TeX:                ['Macro','T\\kern-.1667em\\lower.5ex{E}\\kern-.125em X'],

    limits:       ['Limits',1],
    nolimits:     ['Limits',0],

    ',':          ['Spacer',1/6],
    ':':          ['Spacer',1/6],  // for LaTeX
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
    rule:          ['Rule','colored'],
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
    fbox:       'FBox',

    strut:      'Strut',
    mathstrut:  ['Macro','\\vphantom{(}'],
    phantom:    ['Phantom',1,1],
    vphantom:   ['Phantom',1,0],
    hphantom:   ['Phantom',0,1],
    smash:      'Smash',
    
    acute:      ['MathAccent', [7,0,0x13]],
    grave:      ['MathAccent', [7,0,0x12]],
    ddot:       ['MathAccent', [7,0,0x7F]],
    tilde:      ['MathAccent', [7,0,0x7E]],
    bar:        ['MathAccent', [7,0,0x16]],
    breve:      ['MathAccent', [7,0,0x15]],
    check:      ['MathAccent', [7,0,0x14]],
    hat:        ['MathAccent', [7,0,0x5E]],
    vec:        ['MathAccent', [0,1,0x7E]],
    dot:        ['MathAccent', [7,0,0x5F]],
    widetilde:  ['MathAccent', [0,3,0x65]],
    widehat:    ['MathAccent', [0,3,0x62]],

    '_':        ['Replace','ord','_','normal',-.4,.1],
    ' ':        ['Replace','ord','&nbsp;','normal'],
    angle:      ['Replace','ord','&#x2220;','normal'],
        
    matrix:     'Matrix',
    array:      'Matrix',  // ### still need to do alignment options ###
    pmatrix:    ['Matrix','(',')','c'],
    cases:      ['Matrix','\\{','.',['l','l']],
    cr:         'HandleRow',
    '\\':       'HandleRow',
    
    //  LaTeX
    begin:      'Begin',
    end:        'End',
    tiny:       ['HandleSize',0],
    Tiny:       ['HandleSize',1],  // non-standard
    scriptsize: ['HandleSize',2],
    small:      ['HandleSize',3],
    normalsize: ['HandleSize',4],
    large:      ['HandleSize',5],
    Large:      ['HandleSize',6],
    LARGE:      ['HandleSize',7],
    huge:       ['HandleSize',8],
    Huge:       ['HandleSize',9],
    dots:       ['Macro','\\ldots'],

    //  Extensions to TeX
    color:      'Color',
    href:       'Href',
    'class':    'Class',
    style:      'Style',
    unicode:    'Unicode',

    //  debugging and test routines
    'char':     'Char'
  },
  
  /*
   *  LaTeX environments
   */
  environments: {
    array:      'Array',
    matrix:     ['Array',null,null,'c'],
    pmatrix:    ['Array','(',')','c'],
    bmatrix:    ['Array','[',']','c'],
    Bmatrix:    ['Array','\\{','\\}','c'],
    vmatrix:    ['Array','\\vert','\\vert','c'],
    Vmatrix:    ['Array','\\Vert','\\Vert','c'],
    cases:      ['Array','\\{','.','ll'],
    eqnarray:   ['Array',null,null,'rcl',[5/18,5/18]]
  },

  /*
   *  The horizontally stretchable delimiters
   */
  leaders: {
    downbrace:  {left: [3,0x7A], lmid: [3,0x7D], rmid: [3,0x7C], right: [3,0x7B]},
    upbrace:    {left: [3,0x7C], lmid: [3,0x7B], rmid: [3,0x7A], right: [3,0x7D]},
    leftarrow:  {left: [2,0x20], rep:  [2,0x00]},
    rightarrow: {rep:  [2,0x00], right: [2,0x21]}
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
   *  Check if the next character is a space
   */
  nextIsSpace: function () {
    return this.string.charAt(this.i) == ' ';
  },

  /*
   *  Parse a substring to get its mList, and return it.
   *  Check that no errors occured
   */
  Process: function (arg) {
    var data = this.mlist.data;
    arg = jsMath.Parse(arg,data.font,data.size,data.style);
      if (arg.error) {this.Error(arg); return}
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
    while (this.nextIsSpace()) {this.i++}
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
    while (this.nextIsSpace()) {this.i++}
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
    var rest; var advance = 0;
    if (this.nextIsSpace()) {this.i++}
    if (this.string.charAt(this.i) == '{') {
      rest = this.GetArgument(name);
    } else {
      rest = this.string.slice(this.i);
      advance = 1;
    }
    var match = rest.match(/^\s*([-+]?(\.\d+|\d+(\.\d*)?))(pt|em|ex|mu|px)/);
    if (!match) {this.Error("Missing dimension or its units for "+name); return}
    if (advance) {
      this.i += match[0].length;
      if (this.nextIsSpace()) {this.i++}
    }
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
    while (this.nextIsSpace()) {this.i++}
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
    while (this.nextIsSpace()) {this.i++}
    var start = this.i; var pcount = 0;
    while (this.i < this.string.length) {
      var c = this.string.charAt(this.i++);
      if (c == '{') {pcount++}
      else if (c == '}') {
        if (pcount == 0)
          {this.Error("Extra close brace while looking for "+this.cmd+token); return}
        pcount --;
      } else if (c == this.cmd) {
        // really need separate counter for begin/end
        // and it should really be a stack (new pcount for each begin)
        if (this.string.slice(this.i,this.i+5) == "begin") {pcount++; this.i+=4}
        else if (this.string.slice(this.i,this.i+3) == "end") {
          if (pcount > 0) {pcount--; this.i += 2}
        }
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
  AddHTML: function (name,params) {
    var data = this.mlist.data;
    var arg = this.GetArgument(this.cmd+name); if (this.error) return;
    arg = jsMath.Parse(arg,data.font,data.size,data.style);
      if (arg.error) {this.Error(arg); return}
    this.mlist.Add(jsMath.mItem.HTML(params[0]));
    for (var i = 0; i < arg.mlist.Length(); i++) {this.mlist.Add(arg.mlist.Get(i))}
    this.mlist.Add(jsMath.mItem.HTML(params[1]));
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
    this.mlist.Add(jsMath.mItem.TextAtom('ord',arg[0],arg[1],arg[2],arg[3]));
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
    this.mlist.Add(jsMath.mItem.Typeset(jsMath.Box.TeX(n-0,font,'T',this.mlist.data.size)));
    return;
  },
  
  /*
   *  Create an array or matrix.
   */
  Matrix: function (name,delim) {
    var data = this.mlist.data;
    var arg = this.GetArgument(this.cmd+name); if (this.error) return;
    var parse = new jsMath.Parser(arg+'\\\\',null,data.size);
    parse.matrix = name; parse.row = []; parse.table = [];
    parse.Parse(); if (parse.error) {this.Error(parse); return}
    parse.HandleRow(name,1);  // be sure the last row is recorded
    var box = jsMath.Box.Layout(data.size,parse.table,delim[2]);
    // Add parentheses, if needed
    if (delim[0] && delim[1]) {
      var left  = jsMath.Box.Delimiter(box.h+box.d,this.delimiter[delim[0]],'T');
      var right = jsMath.Box.Delimiter(box.h+box.d,this.delimiter[delim[1]],'T');
      box = jsMath.Box.SetList([left,box,right],data.style,data.size);
    }
    this.mlist.Add(jsMath.mItem.Atom((delim[0]? 'inner': 'ord'),box));
  },
  
  /*
   *  When we see an '&', try to add a matrix entry to the row data.
   *  (Use all the data in the current mList, and then clear it)
   */
  HandleEntry: function (name) {
    if (!this.matrix) 
      {this.Error(name+" can only appear in a matrix or array"); return}
    if (this.mlist.data.openI != null) {
      var open = this.mlist.Get(this.mlist.data.openI);
      if (open.left) {this.Error("Missing "+this.cmd+"right")}
        else {this.Error("Missing close brace")}
    }
    if (this.mlist.data.overI != null) {this.mlist.Over()}
    var data = this.mlist.data;
    this.mlist.Atomize('T',data.size); var box = this.mlist.Typeset('T',data.size);
    this.row[this.row.length] = box;
    this.mlist = new jsMath.mList(null,null,data.size); 
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
  Array: function (name,delim) {
    var columns = delim[2]; var cspacing = delim[3];
    if (!columns) {
      columns = this.GetArgument(this.cmd+'begin{'+name+'}');
      if (this.error) return;
    }
    columns = columns.replace(/[^clr]/g,'');
    columns = columns.split('');
    var data = this.mlist.data;
    var arg = this.GetEnd(name); if (this.error) return;
    var parse = new jsMath.Parser(arg+'\\\\',null,data.size);
    parse.matrix = name; parse.row = []; parse.table = [];
    parse.Parse(); if (parse.error) {this.Error(parse); return}
    parse.HandleRow(name,1);  // be sure the last row is recorded
    var box = jsMath.Box.Layout(data.size,parse.table,columns,cspacing);
    // Add parentheses, if needed
    if (delim[0] && delim[1]) {
      var left  = jsMath.Box.Delimiter(box.h+box.d,this.delimiter[delim[0]],'T');
      var right = jsMath.Box.Delimiter(box.h+box.d,this.delimiter[delim[1]],'T');
      box = jsMath.Box.SetList([left,box,right],data.style,data.size);
    }
    this.mlist.Add(jsMath.mItem.Atom((delim[0]? 'inner': 'ord'),box));
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
    var box = jsMath.Box.InternalMath(text,this.mlist.data.size);
    this.mlist.Add(jsMath.mItem.Typeset(box));
  },
  
  /*
   *  Implement \fbox{...}
   */
  FBox: function (name) {
    var text = this.GetArgument(this.cmd+name); if (this.error) return;
    var arg = jsMath.Box.InternalMath(text,this.mlist.data.size);
    var f = 0.25 * jsMath.sizes[this.mlist.data.size]/100;
    var box = jsMath.Box.Set(arg,this.mlist.data.style,this.mlist.data.size,1).Remeasured();
    var frame = jsMath.HTML.Frame(-f,-box.d-f,box.w+2*f,box.h+box.d+2*f);
    box.html = frame + box.html + jsMath.HTML.Spacer(f);
    box.h += f; box.d += f; box.w +=2*f; box.x += f;
    box.bh = Math.max(box.bh,box.h); box.bd = Math.max(box.bd,box.d);
    this.mlist.Add(jsMath.mItem.Atom('ord',box));
  },
  
  /*
   *  Insert a rule of a particular width, height and depth
   *  This replaces \hrule and \vrule
   *  @@@ not a standard TeX command, and all three parameters must be given @@@
   */
  Rule: function (name,style) {
    var w = this.GetDimen(this.cmd+name,1); if (this.error) return;
    var h = this.GetDimen(this.cmd+name,1); if (this.error) return;
    var d = this.GetDimen(this.cmd+name,1); if (this.error) return;
    h += d; var html;
    if (h != 0) {h = Math.max(1.05/jsMath.em,h)}
    if (h == 0 || w == 0) {style = "blank"}
    if (w == 0) {
      html = '<IMG SRC="'+jsMath.blank+'" STYLE="'
                + 'border:0px none; width:1px; margin-right:-1px; '
                + 'height:'+jsMath.HTML.Em(h*jsMath.Browser.imgScale)+'">';
    } else if (style == "blank") {
      html = '<IMG SRC="'+jsMath.blank+'" STYLE="border:0px none; '
                + 'height:'+jsMath.HTML.Em(h*jsMath.Browser.imgScale)+'; '
                + 'width:' +jsMath.HTML.Em(w*jsMath.Browser.imgScale)+'">';
    } else {
      html = '<IMG SRC="'+jsMath.blank+'" STYLE="'
                + 'position: relative; top:1px; height:1px; border:0px none; '
                + 'border-top:'+jsMath.HTML.Em(h*jsMath.Browser.imgScale)+' solid; '
                + 'width:' +jsMath.HTML.Em(w*jsMath.Browser.imgScale)+'">';
    }
    if (d) {
      html = '<SPAN STYLE="vertical-align:'+jsMath.HTML.Em(-d)+'">'
           +  html + '</SPAN>';
    }
    this.mlist.Add(jsMath.mItem.Typeset(new jsMath.Box('html',html,w,h-d,d)));
  },
  
  /*
   *  Inserts an empty box of a specific height and depth
   */
  Strut: function () {
    var size = this.mlist.data.size;
    var box = jsMath.Box.Text('','normal','T',size).Styled();
    box.bh = box.bd = 0; box.h = .8; box.d = .3; box.w = 0;
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
          if (c == "#") {text += c} else {
            if (!c.match(/[1-9]/) || c > args.length)
              {this.Error("Illegal macro argument reference"); return}
            text += args[c-1];
          }
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
    box = jsMath.Box.Set(box,'D',this.mlist.data.size).Remeasured();
    var leader = jsMath.Box.Leaders(box.w,this.leaders[data[0]]);
    if (data[2]) {leader.y = -leader.h - box.d} else {leader.y = box.h + leader.d}
    leader.x = -(leader.w + box.w)/2;
    box = jsMath.mItem.Atom(data[1]? 'op': 'inner',
      jsMath.Box.SetList([box,leader],'T',this.mlist.data.size));
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
    this.HandleTeXchar(code[0],code[1],code[2]);
  },
  
  /*
   *  Add a specific character from a TeX font (use the current
   *  font if the type is 7 (variable) or the font is not specified)
   */
  HandleTeXchar: function (type,font,code) {
    if (type == 7 && this.mlist.data.font != null) {font = this.mlist.data.font}
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
    this.mlist.data.style = style[0];
    this.mlist.Add(new jsMath.mItem('style',{style: style[0]}));
  },
  
  /*
   *  Implements \small, \large, etc.
   */
  HandleSize: function (name,size) {
    this.mlist.data.size = size[0];
    this.mlist.Add(new jsMath.mItem('size',{size: size[0]}));
  },

  /*
   *  Set the current font (e.g., \rm, etc)
   */
  HandleFont: function (name,font) {
    this.mlist.data.font = font[0];
  },

  /*
   *  Look for and process a control sequence
   */
  HandleCS: function () {
    var cmd = this.GetCommand(); if (this.error) return;
    if (this.macros[cmd]) {
      var macro = this.macros[cmd];
      if (typeof(macro) == "string") {macro = [macro]}
      this[macro[0]](cmd,macro.slice(1)); return;
    }
    if (this.mathchardef[cmd]) {
      this.HandleMathCode(cmd,this.mathchardef[cmd]);
      return;
    }
    if (this.delimiter[this.cmd+cmd]) {
      this.HandleMathCode(cmd,this.delimiter[this.cmd+cmd].slice(0,3))
      return;
    }
    this.Error("Unknown control sequence '"+this.cmd+cmd+"'");
  },

  /*
   *  Process open and close braces
   */
  HandleOpen: function () {this.mlist.Open()},
  HandleClose: function () {
    if (this.mlist.data.openI == null) {this.Error("Extra close brace"); return}
    var open = this.mlist.Get(this.mlist.data.openI);
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
    var open = this.mlist.Get(this.mlist.data.openI);
    if (open && open.left != null) {this.mlist.Close(right)}
      else {this.Error("Extra open brace or missing "+this.cmd+"left");}
  },

  /*
   *  Implements generalized fractions (\over, \above, etc.)
   */
  HandleOver: function (name,data) {
    if (this.mlist.data.overI != null) 
      {this.Error('Ambiguous use of '+this.cmd+name); return}
    this.mlist.data.overI = this.mlist.Length();
    this.mlist.data.overF = {name: name};
    if (data.length > 0) {
      this.mlist.data.overF.left  = this.delimiter[data[0]];
      this.mlist.data.overF.right = this.delimiter[data[1]];
    } else if (name.match(/withdelims$/)) {
      this.mlist.data.overF.left  = this.GetDelimiter(this.cmd+name); if (this.error) return;
      this.mlist.data.overF.right = this.GetDelimiter(this.cmd+name); if (this.error) return;
    }
    if (name.match(/^above/))
    {
      this.mlist.data.overF.thickness = this.GetDimen(this.cmd.name,1);
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
    if (this.mlist.data.openI != null) {
      var open = this.mlist.Get(this.mlist.data.openI);
      if (open.left) {this.Error("Missing "+this.cmd+"right")}
        else {this.Error("Missing close brace")}
    }
    if (this.mlist.data.overI != null) {this.mlist.Over()}
  },

  /*
   *  Perform the processing of Appendix G
   */
  Atomize: function () {
    var data = this.mlist.init;
    if (!this.error) this.mlist.Atomize(data.style,data.size)
  },

  /*
   *  Produce the final HTML.
   *  
   *  We have to wrap the HTML it appropriate <SPAN> tags to hide its
   *  actual dimensions when these don't match the TeX dimensions of the
   *  results.  We also include an image to force the results to take up
   *  the right amount of space.  The results may need to be vertically
   *  adjusted to make the baseline appear in the correct place.
   */
  Typeset: function () {
    var data = this.mlist.init;
    var box = this.typeset = this.mlist.Typeset(data.style,data.size);
    if (this.error) {return '<SPAN CLASS="error">'+this.error+'</SPAN>'}
    if (box.format == 'null') {return ''};

    box.Styled().Remeasured(); var isSmall = 0; var isBig = 0;
    if (box.bh > box.h && box.bh > jsMath.h+.001) {isSmall = 1}
    if (box.bd > box.d && box.bd > jsMath.d+.001) {isSmall = 1}
    if (box.h > jsMath.h || box.d > jsMath.d) {isBig = 1}

    var html = box.html;
    if (isSmall) {// hide the extra size
      if (jsMath.Browser.allowAbsolute) {
        var y = 0;
        if (box.bh > jsMath.h+.001) {y = jsMath.h - box.bh}
        html = jsMath.HTML.Absolute(html,box.w,jsMath.h,0,y,jsMath.h);
      } else if (!jsMath.Browser.valignBug) {
        // remove line height and try to hide the depth
        var dy = jsMath.HTML.Em(Math.max(0,box.bd-jsMath.hd)/3);
        html = '<SPAN STYLE="line-height: 0;'
               + ' position:relative; top:'+dy+'; vertical-align:'+dy
               + '">' + html + '</SPAN>';
      }
      isBig = 1;
    }
    if (isBig) {// add height and depth to the line (force a little
                //    extra to separate lines if needed)
      html += '<IMG SRC="'+jsMath.blank+'" CLASS="mathHD" STYLE="'
               + 'height:'+jsMath.HTML.Em((box.h+box.d+.1)*jsMath.Browser.imgScale)+'; '
               + 'vertical-align:'+jsMath.HTML.Em(-box.d-.05)+';">'
    }
    return '<NOBR><SPAN CLASS="jsM_scale">'+html+'</SPAN></NOBR>';
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
 *      <SCRIPT> jsMath.Macro('x','{\\vec x}_{#1}',1) </SCRIPT>
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
    var parse = jsMath.Parse(s,null,null,'T');
    parse.Atomize();
    var html = parse.Typeset();
    return html;
  },

  /*
   *  Typeset a string in \displaystyle and return the HTML for it
   */
  DisplayMode: function (s) {
    var parse = jsMath.Parse(s,null,null,'D');
    parse.Atomize();
    var html = parse.Typeset();
    return html;
  },
  
  /*
   *  Return the text of a given DOM element
   */
  GetElementText: function (element) {
    var text = element.innerText;
    if (text == null || text == "") {
      try {text = element.textContent} catch (err) {}
      if (text == null || text == "") {text = element.innerHTML}
    }
    if (text.search('&') >= 0) {
      text = text.replace(/&lt;/g,'<');
      text = text.replace(/&gt;/g,'>');
      text = text.replace(/&quot;/g,'"');
      text = text.replace(/&amp;/g,'&');
    }
    return text;
  },
  
  /*
   *  Move hidden to the location of the math element to be
   *  processed and reinitialize sizes for that location.
   */
  ResetHidden: function (element) {
    element.innerHTML =
      '<SPAN CLASS="normal" STYLE="position:absolute; top:0px;left:0px;"></SPAN>'
        + jsMath.Browser.operaHiddenFix; // needed by Opera in tables
    element.className='';
    jsMath.hidden = element.firstChild;
    jsMath.ReInit();
  },

  
  /*
   *  Typeset the contents of an element in \textstyle
   */
  ConvertText: function (element) {
    var text = this.GetElementText(element);
    this.ResetHidden(element);
    element.innerHTML = this.TextMode(text);
    element.className = 'typeset';
    element.alt = text;
  },
  
  /*
   *  Typeset the contents of an element in \displaystyle
   */
  ConvertDisplay: function (element) {
    var text = this.GetElementText(element);
    this.ResetHidden(element);
    element.innerHTML = this.DisplayMode(text);
    element.className = 'typeset';
    element.alt = text;
  },
  
  /*
   *  Process a math element
   */
  ProcessElement: function (element) {
    try {
      if (element.tagName == 'DIV') {
        this.ConvertDisplay(element);
      } else if (element.tagName == 'SPAN') {
        this.ConvertText(element);
        //
        // Overcome a bug in MSIE where were tex2math can't insert DIV's inside
        // some elements, so fake it with SPANs, but can't fake the centering,
        // so do that here.
        //
        if (element.parentNode.className == 'jsMath.recenter') {
          element.parentNode.style.marginLeft =
            Math.floor((element.parentNode.offsetWidth - element.offsetWidth)/2)+"px";
        }
      }
      element.onclick = jsMath.Click.CheckClick;
      element.ondblclick = jsMath.Click.CheckDblClick;
    } catch (err) {}
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
      setTimeout('jsMath.ProcessElements('+(k+1)+')',jsMath.Browser.delay);
    }
  },

  /*
   *  Call this at the bottom of your HTML page to have the
   *  mathematics typeset asynchronously.  This lets the user
   *  start reading the mathematics while the rest of the page
   *  is being processed.
   */
  Process: function (obj) {
    if (!jsMath.initialized) {jsMath.Init()}
    this.element = this.GetMathElements(obj);
    window.status = 'Processing Math...';
    setTimeout('jsMath.ProcessElements(0)',jsMath.Browser.delay);
  },
  
  /*
   *  Call this at the bottom of your HTML page to have the
   *  mathematics typeset before the page is displayed.
   *  This can take a long time, so the user could cancel the
   *  page before it is complete; use it with caution, and only
   *  when there is a relatively small amount of math on the page.
   */
  ProcessBeforeShowing: function (obj) {
    if (!jsMath.initialized) {jsMath.Init()}
    var element = jsMath.GetMathElements(obj);
    window.status = 'Processing Math...';
    for (var i = 0; i < element.length; i++)
      {jsMath.ProcessElement(element[i])}
    jsMath.ProcessComplete();
  },
  
  element: [],  // the list of math elements on the page

  /*
   *  Look up all the math elements on the page and
   *  put them in a list sorted from top to bottom of the page
   */
  GetMathElements: function (obj) {
    var element = [];
    if (!obj) {obj = document}
    if (typeof(obj) == 'string') {obj = document.getElementById(obj)}
    if (!obj.getElementsByTagName) return
    var math = obj.getElementsByTagName('DIV');
    for (var k = 0; k < math.length; k++) {
      if (math[k].className == 'math') {
        if (jsMath.Browser.renameOK && obj.getElementsByName) 
               {math[k].setAttribute('NAME','_jsMath_')}
          else {element[element.length] = math[k]}
      }
    }
    math = obj.getElementsByTagName('SPAN');
    for (var k = 0; k < math.length; k++) {
      if (math[k].className == 'math') {
        if (jsMath.Browser.renameOK && obj.getElementsByName) 
               {math[k].setAttribute('NAME','_jsMath_')}
          else {element[element.length] = math[k]}
      }
    }
    // this gets the SPAN and DIV elements interleaved in order
    if (jsMath.Browser.renameOK && obj.getElementsByName) {
      element = obj.getElementsByName('_jsMath_');
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
    if (jsMath.Browser.renameOK) {
      var element = document.getElementsByName('_jsMath_');
      for (var i = element.length-1; i >= 0; i--) {
        element[i].removeAttribute('NAME');
      }
    }
    jsMath.hidden = jsMath.hiddenTop;
    jsMath.element = [];
    window.status = 'Done';
    if (jsMath.Browser.safariImgBug &&
        (jsMath.Controls.cookie.font == 'symbol' ||
         jsMath.Controls.cookie.font == 'image')) {
      //
      //  For Safari, the images don't always finish
      //  updating, so nudge the window to cause a
      //  redraw.  (Hack!)
      //
      setTimeout("window.resizeBy(-1,0); window.resizeBy(1,0);",2000);
    }
  },
  
  Element: function (name) {return document.getElementById('jsMath.'+name)}
  
});


/***************************************************************************/

/*
 *  Initialize everything
 */
jsMath.Loaded();
jsMath.Controls.GetCookie();
if (document.body) {jsMath.Setup.Body()}

}}
