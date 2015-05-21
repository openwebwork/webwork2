var LiveGraphics3D = function (container, options) {
    var my = this;    
    var options = $.extend({}, defaults, options);
    
    var x3d;
    
    var scene;
    
    var defaults = {
	width : 200,
	height : 200,
	perspectiveFactor: 4,
    };
    
    var coordMins;
    var coordMaxs;
    var axisKeys = ['x','y','z']
    
    var surfacecoords = [];
    var surfaceindex = [];
    
    var colormap = [
	[     0,     0,   127],
	[     0,     0,   143],
	[     0,     0,   159],
	[     0,     0,   176],
	[     0,     0,   192],
	[     0,     0,   208],
	[     0,     0,   224],
	[     0,     0,   240],
	[     0,     2,   255],
	[     0,    18,   255],
	[     0,    34,   255],
	[     0,    50,   255],
	[     0,    66,   255],
	[     0,    82,   255],
	[     0,    99,   255],
	[     0,   115,   255],
	[     0,   131,   255],
	[     0,   147,   255],
	[     0,   163,   255],
	[     0,   180,   255],
	[     0,   196,   255],
	[     0,   212,   255],
	[     0,   228,   255],
	[     0,   244,   255],
	[     6,   255,   248],
	[    22,   255,   232],
	[    38,   255,   216],
	[    54,   255,   200],
	[    70,   255,   184],
	[    87,   255,   167],
	[   103,   255,   151],
	[   119,   255,   135],
	[   135,   255,   119],
	[   151,   255,   103],
	[   167,   255,    87],
	[   184,   255,    70],
	[   200,   255,    54],
	[   216,   255,    38],
	[   232,   255,    22],
	[   248,   255,     6],
	[   255,   244,     0],
	[   255,   228,     0],
	[   255,   212,     0],
	[   255,   196,     0],
	[   255,   180,     0],
	[   255,   163,     0],
	[   255,   147,     0],
	[   255,   131,     0],
	[   255,   115,     0],
	[   255,    99,     0],
	[   255,    82,     0],
	[   255,    66,     0],
	[   255,    50,     0],
	[   255,    34,     0],
	[   255,    18,     0],
	[   255,     2,     0],
	[   240,     0,     0],
	[   224,     0,     0],
	[   208,     0,     0],
	[   192,     0,     0],
	[   176,     0,     0],
	[   159,     0,     0],
	[   143,     0,     0],
	[   127,     0,     0]];
    
    var initialize = function (error,text) {
	
	if (error || text.match('WeBWorK error')) {
	    $(container).html('Error fetching graph data');
	}
	
	parseLive3DData(text);
	
	setExtremum();
	
	x3d = d3.select(container).append("x3d")
	    .style('width',options.width+'px')
	    .style('height',options.height+'px')
	    .style('border','none');
	
	scene = x3d.append("scene");
	
	scene.append("viewpoint")
	    .attr( "fieldofview", .9)
	    .attr( "position", [2*windowScale,2*windowScale,0] )
	    .attr( "orientation", [-.707,.707,0,3.14/2]);
	
	scene.append('background').attr('skycolor','1 1 1');
	
	drawSurface();
	
    };
    
    var parseLive3DData = function(text) {
	
	var polystrings = text.match(/Polygon\[\s*\{([^\]]+)\}\]/g);
	if (!polystrings) {
	    d3.select(container).html('Error parsing graph data');
	    return;
	}
	
	polystrings.forEach(function(polystring) {
	    var pointstrings = polystring.match(/\{\s*-?\d*\.?\d*\s*,\s*-?\d*\.?\d*\s*,\s*-?\d*\.?\d*\s*\}/g);
	    var poly = [];
	    
	    pointstrings.forEach(function(pointstring) {
		var strpoint = pointstring.match(/\{\s*(-?\d*\.?\d*)\s*,\s*(-?\d*\.?\d*)\s*,\s*(-?\d*\.?\d*)\s*\}/);
		var point = [parseFloat(strpoint[1]),parseFloat(strpoint[2]),parseFloat(strpoint[3])];
		
		for (i=0; i<surfacecoords.length; i++) {
		    if (surfacecoords[i][0] == point[0] &&
			surfacecoords[i][1] == point[1] &&
			surfacecoords[i][2] == point[2]) {
			surfaceindex.push(i);
			poly.push(i);
			return;
		    }
		}
		
		surfaceindex.push(surfacecoords.length);
		poly.push(surfacecoords.length);
		surfacecoords.push(point);
	    });
	    surfaceindex.push(-1);
	    
	    surfaceindex.push(poly[0]);
	    surfaceindex.push(poly[2]);
	    surfaceindex.push(poly[1]);
	    surfaceindex.push(poly[3]);
	    surfaceindex.push(-1);
	    
	});
    };
    
    
    var setExtremum = function () {
	var scale = 1;
	var min = [0,0,0];
	var max = [0,0,0];
	
	surfacecoords.forEach(function(point) {
	    for (i=0; i< 3; i++) {
		if (point[i] < min[i]) {
		    min[i] = point[i];
		} else if (point[i]>max[i]) {
		    max[i] = point[i];
		}
	    }
	});
	
	coordMins = min;
	coordMaxs = max;
	
	for (i=0; i< 3; i++) {
	    if (Math.abs(min[i]) > scale) {
		scale = Math.abs(min[i]);
	    }
	    if (Math.abs(max[i]) > scale) {
		scale = Math.abs(max[i]);
	    }
	}
	
	windowScale = scale;
    };
    
    function drawSurface() {
	coordstr = '';
	indexstr = '';
	colorstr = '';
	colorindstr = '';
	
	
	surfacecoords.forEach(function(point) {
	    coordstr += point[0]+' '+point[1]+' '+point[2]+' ';
	});
	
	
	surfaceindex.forEach(function(index) {
	    indexstr += index+' ';
	    
	    if (index == -1) {
		colorindstr += '-1 ';
		return;
	    }
	    
	    var cindex = parseInt((surfacecoords[index][2]-coordMins[2])/(coordMaxs[2]-coordMins[2])*colormap.length);
	    
	    if (cindex == colormap.length) {
		cindex--;
	    }
	    
	    colorindstr += cindex+' ';
	    
	});
	
	colormap.forEach(function(color) {
	    colorstr += color[0]/255+' '+color[1]/255+' '+color[2]/255+' ';
	});
	
	var shape = scene.append("shape")
	    .attr('render','true');
	
	var appearance = shape.append("appearance");
	
	appearance .append("twosidedmaterial")
	    .attr("shininess","0.145")
	    .attr("backshininess","0.145")
	    .attr("separatebackcolor",'false');
	
	var indexedfaceset = shape.append("indexedfaceset")
	    .attr('coordindex',indexstr)
	    .attr('creaseAngle','3.14')
            .attr('solid','false')
	    .attr('colorindex',colorindstr);
	
	indexedfaceset.append("coordinate")
	    .attr('point',coordstr);
	
	indexedfaceset.append("color")
	    .attr('color',colorstr);
    }	

 //   function drawAxis() {
	
//	xaxis = scene.append("shape")

//	xaxis.append("appearance")
//	    .append("material")
  //          .attr("emissiveColor", "lightgray")
//	xaxis.append("polyline2d")
  //           .attr("lineSegments", "0 0," + scaleMax + " 0")

    
    // Start initialization
    if (options.input) {
	    initialize('',options.input);
    } else if (options.file) {
	d3.text(options.file,initialize);
    } else if (options.archive) {
	// not supported yet. 
	d3.select(container).html('Archive input not supported');
    } else {
	d3.select(container).html('No input data provided');
    }
}
