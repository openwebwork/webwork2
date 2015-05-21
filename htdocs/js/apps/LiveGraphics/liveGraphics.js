var LiveGraphics3D = function (container, options) {
    var my = this;    
    
    // define x3d container and scene
    var x3d = $("<x3d/>").appendTo(container)
	.css('width',options.width+'px')
	.css('height',options.height+'px')
	.css('border','none');

    var scene = $("<scene/>").appendTo(x3d);
	
    // extend options by default values
    var defaults = {
	width : 200,
	height : 200,
	numTicks : 10,
	tickSize : .1,
	tickFontSize : .05,
	axisKey : ['X','Y','Z']
    };
    var options = $.extend({}, defaults, options);
    
    var coordMins;
    var coordMaxs;
    
    var surfacecoords = [];
    var surfaceindex = [];
    
    // This is the color map for shading surfaces based on elevation
    var colormap = [
	[0.00000,   0.00000,   0.50000],
	[0.00000,   0.00000,   0.56349],
	[0.00000,   0.00000,   0.62698],
	[0.00000,   0.00000,   0.69048],
	[0.00000,   0.00000,   0.75397],
	[0.00000,   0.00000,   0.81746],
	[0.00000,   0.00000,   0.88095],
	[0.00000,   0.00000,   0.94444],
	[0.00000,   0.00794,   1.00000],
	[0.00000,   0.07143,   1.00000],
	[0.00000,   0.13492,   1.00000],
	[0.00000,   0.19841,   1.00000],
	[0.00000,   0.26190,   1.00000],
	[0.00000,   0.32540,   1.00000],
	[0.00000,   0.38889,   1.00000],
	[0.00000,   0.45238,   1.00000],
	[0.00000,   0.51587,   1.00000],
	[0.00000,   0.57937,   1.00000],
	[0.00000,   0.64286,   1.00000],
	[0.00000,   0.70635,   1.00000],
	[0.00000,   0.76984,   1.00000],
	[0.00000,   0.83333,   1.00000],
	[0.00000,   0.89683,   1.00000],
	[0.00000,   0.96032,   1.00000],
	[0.02381,   1.00000,   0.97619],
	[0.08730,   1.00000,   0.91270],
	[0.15079,   1.00000,   0.84921],
	[0.21429,   1.00000,   0.78571],
	[0.27778,   1.00000,   0.72222],
	[0.34127,   1.00000,   0.65873],
	[0.40476,   1.00000,   0.59524],
	[0.46825,   1.00000,   0.53175],
	[0.53175,   1.00000,   0.46825],
	[0.59524,   1.00000,   0.40476],
	[0.65873,   1.00000,   0.34127],
	[0.72222,   1.00000,   0.27778],
	[0.78571,   1.00000,   0.21429],
	[0.84921,   1.00000,   0.15079],
	[0.91270,   1.00000,   0.08730],
	[0.97619,   1.00000,   0.02381],
	[1.00000,   0.96032,   0.00000],
	[1.00000,   0.89683,   0.00000],
	[1.00000,   0.83333,   0.00000],
	[1.00000,   0.76984,   0.00000],
	[1.00000,   0.70635,   0.00000],
	[1.00000,   0.64286,   0.00000],
	[1.00000,   0.57937,   0.00000],
	[1.00000,   0.51587,   0.00000],
	[1.00000,   0.45238,   0.00000],
	[1.00000,   0.38889,   0.00000],
	[1.00000,   0.32540,   0.00000],
	[1.00000,   0.26190,   0.00000],
	[1.00000,   0.19841,   0.00000],
	[1.00000,   0.13492,   0.00000],
	[1.00000,   0.07143,   0.00000],
	[1.00000,   0.00794,   0.00000],
	[0.94444,   0.00000,   0.00000],
	[0.88095,   0.00000,   0.00000],
	[0.81746,   0.00000,   0.00000],
	[0.75397,   0.00000,   0.00000],
	[0.69048,   0.00000,   0.00000],
	[0.62698,   0.00000,   0.00000],
	[0.56349,   0.00000,   0.00000],
	[0.50000,   0.00000,   0.00000]];
    
    // intialization function.  This takes the mathmatica data string
    // and actually sets up the dom structure for the graph. 
    // the actual graphing is done automatically by x3dom
    var initialize = function (datastring) {

	// parse matlab string
	parseLive3DData(datastring);

	// find extremum for axis and window scale
	setExtremum();
		
	// set up scene veiwpoint to be along the x axis looking to the
	// origin
	scene.append($("<transform/>").
		     attr('rotation',[1,0,0,Math.PI/2])
		     .append($("<viewpoint/>")
			     .attr( "fieldofview", .9)
			     .attr( "position", [2.5*windowScale,0,0] )
			     .attr( "orientation", [0,1,0,Math.PI/2])));
	
	scene.append($('<background/>').attr('skycolor','1 1 1'));
	
	// draw components of scene

	drawAxes();
	drawSurface();
    };
    
    var parseLive3DData = function(text) {
	
	// Find the polygon commands.  This defines the mesh data
	var polystrings = text.match(/Polygon\[\s*\{([^\]]+)\}\]/g);
	if (!polystrings) {
	    $(container).html('Error parsing graph data');
	    return;
	}
	
	polystrings.forEach(function(polystring) {
	    var pointstrings = polystring.match(/\{\s*-?\d*\.?\d*\s*,\s*-?\d*\.?\d*\s*,\s*-?\d*\.?\d*\s*\}/g);
	    var poly = [];
	    
	    // for each polygont extract all the points
	    pointstrings.forEach(function(pointstring) {
		var strpoint = pointstring.match(/\{\s*(-?\d*\.?\d*)\s*,\s*(-?\d*\.?\d*)\s*,\s*(-?\d*\.?\d*)\s*\}/);
		var point = [parseFloat(strpoint[1]),parseFloat(strpoint[2]),parseFloat(strpoint[3])];
		
		// find the index of the point in surfacecoords.  If 
		// the point is not in surfacecoords, add it
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

	    // add the exact same polygon with a reversed normal.
	    // this causes the surface to render on both sides. 
	    surfaceindex.push(poly[0]);
	    surfaceindex.push(poly[2]);
	    surfaceindex.push(poly[1]);
	    surfaceindex.push(poly[3]);
	    surfaceindex.push(-1);
	    
	});
    };
    
    // find max and min of all mesh coordinate points and
    // the maximum coordinate value for the scale. 
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
	
	// build a string with all the surface coodinates
	surfacecoords.forEach(function(point) {
	    coordstr += point[0]+' '+point[1]+' '+point[2]+' ';
	});
	
	
	// build a string with all the surface indexes
	// at the same time build a string with color data
	// and the associated color indexes
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
	    colorstr += color[0]+' '+color[1]+' '+color[2]+' ';
	});
	
	// Add surface to scene as an indexedfaceset
	var shape = $("<shape/>").appendTo(scene);
	
	var appearance = $("<appearance/>").appendTo(shape);
	
	appearance .append($("<material/>")
			   .attr("shininess","0.145"));
	
	var indexedfaceset = $("<indexedfaceset/>")
	    .attr('coordindex',indexstr)
	    .attr('creaseAngle','3.14')
	    .attr('solid','false')
	    .attr('colorindex',colorindstr);
	
	indexedfaceset.append($("<coordinate/>")
			      .attr('point',coordstr));
	
	indexedfaceset.append($("<color/>")
			      .attr('color',colorstr));

	// append the indexed face set to the shape after its assembled.  
	// otherwise sometimes x3d tries to access the various data before 
	// its ready
	indexedfaceset.appendTo(shape);
    }	

    function drawAxes() {

	// build x axis and add the ticks. 
	// all of this is done in two dimensions and then rotated and shifted 
	// into place
	var xgroup = $("<group/>").appendTo($("<transform/>")
					   .appendTo(scene)
					   .attr('translation',[0,coordMins[1],coordMins[2]]));
	
	var xaxis = $("<shape/>").append($("<appearance/>")
					 .append($("<material/>")
						 .attr("emissiveColor", 'black')
						))
	    .append($("<Polyline2D/>")
		    .attr("lineSegments", coordMins[0]+' 0 '+coordMaxs[0]+' 0'));
	xgroup.append(xaxis);
	
	$.each(makeAxisTicks(0),function() {
	    this.appendTo(xgroup)});

	// build y axis and add the ticks
	var ygroup = $("<group/>").appendTo($("<transform/>")
					    .appendTo(scene)
					    .attr('translation',[coordMins[0],0,coordMins[2]])
					    .attr('rotation',[0,0,1,Math.PI/2]));
	
	var yaxis = $("<shape/>").append($("<appearance/>")
					 .append($("<material/>")
						 .attr("emissiveColor", 'black')
						))
	    .append($("<Polyline2D/>")
		    .attr("lineSegments", coordMins[1]+' 0 '+coordMaxs[1]+' 0'));
	ygroup.append(yaxis);

	$.each(makeAxisTicks(1),function() {
	    this.appendTo(ygroup)});


	// build z axis and add the ticks
	var zgroup = $("<group/>").appendTo($("<transform/>")
					   .appendTo(scene)
					   .attr('translation',[coordMins[0],coordMins[1],0])
					    .attr('rotation',[0,1,0,-Math.PI/2]));
	
	var zaxis = $("<shape/>").append($("<appearance/>")
					 .append($("<material/>")
						 .attr("emissiveColor", 'black')
						 ))
	    .append($("<Polyline2D/>")
		    .attr("lineSegments", coordMins[2]+' 0 '+coordMaxs[2]+' 0'));

	zgroup.append(zaxis);

	$.each(makeAxisTicks(2),function() {
	    this.appendTo(zgroup)});

    }
    
    // biuilds the ticks, the tick labels, and the axis label for 
    // axisindex I
    var makeAxisTicks = function (I) {
	var shapes = [];

	for(i=0; i<options.numTicks-1; i++) {
	    // coordinate of tick and label
	    var coord = (coordMaxs[I]-coordMins[I])/options.numTicks*(i+1)+coordMins[I];

	    //ticks are boxes defined by tickSize
	    var tick = $("<shape/>").append($($("<appearance/>")
					      .append($("<material/>")
						      .attr("diffuseColor","black"))));
	    tick.appendTo($("<transform/>")
			  .attr('translation',[coord,0,0]));

	    tick.append($("<box/>")
			.attr('size', options.tickSize+' '
			      +options.tickSize+' '+
			      options.tickSize));
	
	    shapes.push(tick.parent());

	    // labels have two decimal places and always point towards view
	    var ticklabel = $("<shape/>").append($($("<appearance/>")
					      .append($("<material/>")
						      .attr("diffuseColor","black"))));
	    
	    ticklabel.appendTo($("<billboard/>")
			       .attr("axisOfRotation", "0 0 0")
			       .appendTo($("<transform/>")
					 .attr('translation',[coord,.1,0])));

	    ticklabel.append($("<text/>")
			     .attr('string',coord.toFixed(2))
			     .attr('solid','true')
			     .append($("<fontstyle/>")
				     .attr('size',options.tickFontSize*(coordMaxs[I]-coordMins[I]))
				     .attr('family', 'sans')
				     .attr('style', 'bold')
				     .attr('justify', 'MIDDLE')));
	    
	    shapes.push(ticklabel.parent().parent());
	}
	
	// axis label goes on the end of the axis. 
	var axislabel = $("<shape/>").append($($("<appearance/>")
					       .append($("<material/>")
						       .attr("diffuseColor","black"))));
	
	axislabel.appendTo($("<billboard/>")
			   .attr("axisOfRotation", "0 0 0")
			   .appendTo($("<transform/>")
				     .attr('translation',[coordMaxs[I],.1,0])));
	
	axislabel.append($("<text/>")
			 .attr('string',options.axisKey[I])
			 .attr('solid','true')
			 .append($("<fontstyle/>")
				 .attr('size',options.tickFontSize*(coordMaxs[I]-coordMins[I]))
				 .attr('family', 'sans')
				 .attr('style', 'bold')
				 .attr('justify', 'MIDDLE')));
	
	shapes.push(axislabel.parent().parent());

	return shapes;
    }
	    
    // This section of code is run whenever the object is created
    // run intialize with the mathematica string, possibly getting the string
    // form an ajax call if necessary
    
    if (options.input) {
	initialize(options.input);
    } else if (options.file) {
	
	$.ajax({
	    url : options.file,
	    dataType : 'text',
	    async : 'true',
	    success : function(data) {
		initialize(data);
	    },
	    error : function(x,y,error) {
		console.log(error);
		$(container).html('Failed to get input file');
	    }});
    } else if (options.archive) {
	// not supported yet. 
	$(container).html('Archive input not supported');
    } else {
	$(container).html('No input data provided');
    }
}
