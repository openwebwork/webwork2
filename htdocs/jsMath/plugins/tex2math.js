/*
 *  tex2math.js
 *  
 *  Part of the jsMath package for mathematics on the web.
 *
 *  This file is a plugin that searches text wthin a web page
 *  for \(...\), \[...\], $...$ and $$...$$ and converts them to
 *  the appropriate <SPAN CLASS="math">...</SPAN> or
 *  <DIV CLASS="math">...</DIV> tags.
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

jsMath.Insert(jsMath,{
  
  ConvertTeX: function (element) {jsMath.tex2math.Convert("tex",element)},
  ConvertTeX2: function (element) {jsMath.tex2math.Convert("tex2",element)},
  ConvertLaTeX: function (element) {jsMath.tex2math.Convert("latex",element)},
  
  tex2math: {
    
    /*
     *  Set up for the correct type of search, and recursively
     *  convert the mathematics.  Disable tex2math if the cookie
     *  isn't set, or of there is an element with ID of 'tex2math_off'.
     */
    Convert: function (type,element) {
      if (jsMath.Controls.cookie.tex2math && 
          (!jsMath.tex2math.allowDisableTag || !document.getElementById('tex2math_off'))) {
        var pattern = jsMath.tex2math.pattern[type];
        if (type == 'custom') {jsMath.tex2math.isDisplay = jsMath.tex2math.customIsDisplay}
                         else {jsMath.tex2math.isDisplay = jsMath.tex2math.standardIsDisplay}
        jsMath.tex2math.ConvertMath(pattern,element);
      }
    },
    
    /*
     *  Patterns for the various types of conversions
     */
    pattern: {
      tex:   /((^|[^\\])(\\[^\[\(])*)(\\\((([^\\]|\\[^\)])*)\\\)|\\\[(([^\\]|\\[^\]])*)\\\]|\$\$((\\.|\$[^$\\]|[^$\\])*)\$\$|\$(([^$\\]|\\.)*)\$)/,
      tex2:  /((^|[^\\])(\\[^\[\(])*)(\\\((([^\\]|\\[^\)])*)\\\)|\\\[(([^\\]|\\[^\]])*)\\\]|\$\$((\\.|\$[^$\\]|[^$\\])*)\$\$)/,
      latex: /((^|[^\\])(\\[^\[\(])*)(\\\((([^\\]|\\[^\)])*)\\\)|\\\[(([^\\]|\\[^\]])*)\\\])/
    },

    /*
     *  Test if we have a string that initiates display math mode
     */
    standardIsDisplay: function (string) {
      string = string.substr(0,2);
      return (string == '\\[' ||
             (!jsMath.tex2math.doubleDollarsAreInLine && string == '$$'));
    },
    
    /*
     *  Create a pattern for custom math and display indicators.  E.g.
     *
     *   jsMath.tex2math.CustomSearch('[math]','[/math]','[display]','[/display]');
     *
     *  would make in-line math be delimted by [math]...[/math] and
     *  display math by [display]...[/display].  Make sure that the opening
     *  delimiter is not something that would appear within the
     *  mathematics, or tex2math might not be able to match the delimiters 
     *  properly.
     */
    CustomSearch: function (mathopen,mathclose,displayopen,displayclose) {
      var pattern = this.patternCombine(mathopen,displayopen);
      this.pattern.custom = new RegExp('(()())('
        + this.patternQuote(displayopen) + pattern + this.patternQuote(displayclose) 
        + '|'
        + this.patternQuote(mathopen) + pattern + this.patternQuote(mathclose)
        + ')');
      this.customIsDisplay = function (string) {
        return (string.substr(0,displayopen.length) == displayopen);
      };
      jsMath.ConvertCustom = function (element) {jsMath.tex2math.Convert('custom',element)};
    },
    
    patternCombine: function (s1,s2) {
      for (var i = 0; i < s1.length && i < s2.length && s1.charAt(i) == s2.charAt(i); i++) {};
      var pattern = this.patternAdd('',s1.substr(0,i),0);
      if (i) {pattern += '|'}
      pattern += this.patternQuote(s1.substr(0,i))
              + '[^' + this.patternQuote(s1.charAt(i)+s2.charAt(i)) + ']';
      pattern = this.patternAdd(pattern,s1,i+1);
      pattern = this.patternAdd(pattern,s2,i+1);
      return '((' + pattern + ')*)';
      return pattern;
    },
    
    patternAdd: function (pattern,string,i) {
      while (i < string.length) {
        if (pattern != "") {pattern += '|'}
        pattern += this.patternQuote(string.substr(0,i))
                + '[^' + this.patternQuote(string.charAt(i)) + ']';
        i++;
      }
      return pattern;
    },
    
    patternQuote: function (s) {
      s = s.replace(/([\^(){}+*?\-|\[\]\:\\])/g,'\\$1');
      return s;
    },
  
    /*
     *  Recursively look through text nodes for mathematics
     *  that needs to be surrounded by SPAN or DIV tags.
     *  Don't process SCRIPT, NOSCRIPT, STYLE, TEXTAREA or PRE
     *  tags (unless they are of class "tex2math_process") and don't
     *  process any that are of class "tex2math_ignore").
     */
    ConvertMath: function (pattern,element,recurse,ignore) {
      if (!element) {if (recurse) {return} else {element = document.body}}
      if (typeof(element) == 'string') {element = document.getElementById(element)}

      while (element) {
        if (element.nodeName == '#text') {
          if (!ignore) {element = jsMath.tex2math.TeX2math(pattern,element)}
        } else if (element.firstChild) {
          var off = ignore || element.className == 'tex2math_ignore' ||
                    (element.tagName && element.tagName.match(/^(SCRIPT|NOSCRIPT|STYLE|TEXTAREA|PRE)$/i));
          off = off && element.className != 'tex2math_process';
          this.ConvertMath(pattern,element.firstChild,1,off);
        }
        element = element.nextSibling;
      }
    },
  
    /*
     *  Search a string for the math pattern and and replace it
     *  by the proper type of SPAN or DIV
     */
    TeX2math: function (pattern,element) {
      var result; var text; var tag; var math; var rest;
      while (result = pattern.exec(element.nodeValue.replace(/\n/g,' '))) {
        math = element.splitText(result.index+result[1].length);
        rest = math.splitText(result[4].length);
        if (element.nodeValue.search(/\\\$/) >= 0)
          {element.nodeValue = element.nodeValue.replace(/\\\$/g,'')}
        math.parentNode.removeChild(math);
        if (text = (result[5] || result[7] || result[9] || result[11])) {
          tag = jsMath.tex2math.createMathTag(result[4],text);
	  if (rest.parentNode) {
	    rest.parentNode.insertBefore(tag,rest);
	  } else if (element.nextSibling) {
	    element.parentNode.insertBefore(tag,element.nextSibling);
	  } else {
	    element.parentNode.appendChild(tag);
	  }
        }
        element = rest;
      }
      if (element.nodeValue.search(/\\\$/) >= 0)
        {element.nodeValue = element.nodeValue.replace(/\\\$/g,'$')}
      return element;
    },
    
    /*
     *  Create an element for the mathematics
     */
    createMathTag: function (type,text) {
      type = (jsMath.tex2math.isDisplay(type))? "div" : "span";
      var tag = document.createElement(type); tag.className = "math";
      var math = document.createTextNode(text);
      tag.appendChild(math);
      return tag;
    },

    //
    //  MSIE won't let you insert a DIV within tags that are supposed to
    //  contain in-line data (like <P> or <SPAN>), so we have to fake it
    //  using SPAN tags that force the formatting to work like DIV.  We
    //  use a separate SPAN that is the full width of the containing
    //  item, and that has the margins from the div.typeset style
    //  and we name is jsMath.recenter to get jsMath to recenter it when
    //  it is typeset (HACK!!!)
    //
    MSIEcreateMathTag: function (type,text) {
      var tag = document.createElement("span");
      tag.className = "math";
      if (jsMath.tex2math.isDisplay(type)) {
        tag.className = (jsMath.tex2math.center)? "jsMath.recenter": "";
        tag.style.width = "100%"; tag.style.margin = jsMath.tex2math.margin;
        tag.style.display = "inline-block";
        text = '<SPAN CLASS="math">\\displaystyle{'+text+'}</SPAN>';
      }
      tag.innerHTML = text;
      return tag;
    }
    
  }
});

/*
 *  Enable this plugin by default
 */
if (jsMath.Controls.cookie.tex2math == null) {jsMath.Controls.cookie.tex2math = 1}
if (jsMath.tex2math.allowDisableTag == null) {jsMath.tex2math.allowDisableTag = 1}

/*
 *  MSIE can't handle the DIV's properly, so we need to do it by
 *  hand.  Look up the style for typeset math to see if the user
 *  has changed it, and get whether it is centered or indented
 *  so we can mirror that using a SPAN
 */
if (jsMath.browser == 'MSIE' && navigator.platform == 'Win32') {
  jsMath.tex2math.createMathTag = jsMath.tex2math.MSIEcreateMathTag;
  jsMath.Add(jsMath.tex2math,{margin: "", center: 0});
  for (var i = 0; i < document.styleSheets.length; i++) {
    var rules = document.styleSheets[i].cssRules;
    if (!rules) {rules = document.styleSheets[i].rules}
    for (var j = 0; j < rules.length; j++) {
      if (rules[j].selectorText == 'DIV.typeset') {
        if (rules[j].style.margin != "") 
        {jsMath.tex2math.margin = rules[j].style.margin}
        jsMath.tex2math.center =
          (rules[j].style.textAlign == 'center')? 1: 0;
      }
    }
  }
}
