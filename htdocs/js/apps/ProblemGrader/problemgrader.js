/* problemgrader.js

   This is the code which allows you do the preview popovers. 
*/

$(function(){

    $(".preview").popover({html:"true", trigger:"manual", placement:"left", delay: { show: 0, hide: 2 }});

    $(".preview").click(function(evt) {

	$(evt.target).attr("data-content",$(evt.target).siblings("textarea").val().replace(/</g,'< ').replace(/>/g,' >'));
	$(evt.target).popover('toggle');
	if (window.MathJax) {
	    MathJax.Hub.Queue(["Typeset",MathJax.Hub])
	}
    });

}) 
