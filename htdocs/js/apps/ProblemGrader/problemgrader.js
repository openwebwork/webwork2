/* problemgrader.js

   This is the code which allows you do the preview popovers.
*/

$(function() {
	$(".preview").popover({html: "true", trigger: "manual", placement: "left", delay: { show: 0, hide: 2 }});

	$(".preview").click(function(evt) {
		var previewBtn = $(evt.target);
		previewBtn.attr("data-content",
			"<span>" + previewBtn.siblings("textarea").val().replace(/</g, '< ').replace(/>/g, ' >')) + "</span>";
		previewBtn.popover('toggle');
		if (window.MathJax) {
			MathJax.startup.promise = MathJax.startup.promise.then(function() { return MathJax.typesetPromise(['.popover-content']); });
		}
	});
})
