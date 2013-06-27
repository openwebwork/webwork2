var svg_source="";
var FullSize;
function writeSVGFullSize(svg_xml) {
	if (FullSize==null || FullSize.closed) {
		FullSize = window.open("/html-templates/window_svg.html","FullSize");
	}
//	window.alert(svg_xml);
	window.alert('Larger graph has been drawn in the "Larger Graph" window.');
	FullSize.document.getElementById("graph").innerHTML=svg_xml;
//	window.alert(FullSize.document.getElementById("graph").innerHTML);
}
function writePNGFullSize(png_url,width,height) {
	if (FullSize==null || FullSize.closed) {
		FullSize = window.open("/html-templates/window_png.html","FullSize");
	}
//	window.alert(png_url);
//	window.alert(width);
	window.alert('Larger graph has been drawn in the "Larger Graph" window.');
	FullSize.document.getElementById("png_object").src=png_url;
	FullSize.document.getElementById("png_object").width=width;
	FullSize.document.getElementById("png_object").height=height;
//	window.alert(FullSize.document.getElementById("graph").innerHTML);
}  
