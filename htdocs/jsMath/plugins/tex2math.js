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

jsMath.Add(jsMath,{
  
  ConvertTeX: function (element) {jsMath.tex2math.ConvertMath("tex",element)},
  ConvertTeX2: function (element) {jsMath.tex2math.ConvertMath("tex2",element)},
  ConvertLaTeX: function (element) {jsMath.tex2math.ConvertMath("latex",element)},
  
  tex2math: {
    
    pattern: {
      tex:   /((^|[^\\])(\\[^\[\(])*)(\\\((([^\\]|\\[^\)])*)\\\)|\\\[(([^\\]|\\[^\]])*)\\\]|\$\$((\\.|\$[^$\\]|[^$\\])*)\$\$|\$(([^$\\]|\\.)*)\$)/,
      tex2:  /((^|[^\\])(\\[^\[\(])*)(\\\((([^\\]|\\[^\)])*)\\\)|\\\[(([^\\]|\\[^\]])*)\\\]|\$\$((\\.|\$[^$\\]|[^$\\])*)\$\$)/,
      latex: /((^|[^\\])(\\[^\[\(])*)(\\\((([^\\]|\\[^\)])*)\\\)|\\\[(([^\\]|\\[^\]])*)\\\])/
    },
  
    ConvertMath: function (method,element,recurse) {
      if (!element) {
        if (recurse) return;
        element = document.body;
      }
      if (typeof(element) == 'string') {element = document.getElementById(element)}
      
      var pattern = jsMath.tex2math.pattern[method];
      while (element) {
        if (element.nodeName == '#text') {
          if (!element.parentNode.tagName ||
              !element.parentNode.tagName.match(/^(SCRIPT|NOSCRIPT|STYLE|TEXTAREA)$/i)) {
            element = jsMath.tex2math.TeX2math(pattern,element);
          }
        } else {
          this.ConvertMath(method,element.firstChild,1);
        }
        element = element.nextSibling;
      }
    },
  
    TeX2math: function (pattern,element) {
      var result; var text; var tag; var math; var rest;
      while (result = pattern.exec(element.nodeValue.replace(/\n/g,' '))) {
        math = element.splitText(result.index+result[1].length);
        rest = math.splitText(result[4].length);
        if (element.nodeValue.search(/\\\$/) >= 0)
          {element.nodeValue = element.nodeValue.replace(/\\\$/g,'')}
        math.parentNode.removeChild(math);
        if (text = (result[5] || result[7] || result[9] || result[11])) {
          tag = jsMath.tex2math.createMathTag(result[4].substr(0,2),text);
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
    
    createMathTag: function (type,text) {
      type = (type == '\\[' || type == '$$')? "div" : "span";
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
      if (type == '\\[' || type == '$$') {
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
