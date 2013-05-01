/* problemgrader.js

   This is the code which allows you do the preview popovers. 
*/

$(function(){

    $(".preview").popover({html:"true", trigger:"click", placement:"left"});

    $(".preview").click(function(evt) {

	$(evt.target).attr("data-content",$(evt.target).siblings("textarea").val().replace(/</g,'< ').replace(/>/g,' >'));
	$(evt.target).popover('toggle');
	if (window.MathJax) {
	    MathJax.Hub.Queue(["Typeset",MathJax.Hub])
	}
    });

})