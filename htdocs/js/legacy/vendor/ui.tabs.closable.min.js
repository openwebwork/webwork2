/*!
 * Copyright (c) 2010 Andrew Watts
 *
 * Dual licensed under the MIT (MIT_LICENSE.txt)
 * and GPL (GPL_LICENSE.txt) licenses
 * 
 * http://github.com/andrewwatts/ui.tabs.closable
 */
(function(){var c=$.ui.tabs.prototype._tabify;$.extend($.ui.tabs.prototype,{_tabify:function(){var a=this;c.apply(this,arguments);a.options.closable===true&&this.lis.filter(function(){return $("span.ui-icon-circle-close",this).length===0}).each(function(){$(this).append('<a href="#"><span class="ui-icon ui-icon-circle-close"></span></a>').find("a:last").hover(function(){$(this).css("cursor","pointer")},function(){$(this).css("cursor","default")}).click(function(){var b=a.lis.index($(this).parent());
if(b>-1){if(false===a._trigger("closableClick",null,a._ui($(a.lis[b]).find("a")[0],a.panels[b])))return;a.remove(b)}return false}).end()})}})})(jQuery);