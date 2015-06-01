// liveGraphics.js
// This is a javascript based replacement for the LiveGraphics3D java library
// 
// This program is free software; you can redistribute it and/or modify it under
// the terms of either: (a) the GNU General Public License as published by the
// Free Software Foundation; either version 2, or (at your option) any later
// version, or (b) the "Artistic License" which comes with this package.
// 
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE.  See either the GNU General Public License or the
// Artistic License for more details.

var LiveGraphics3D = function (container, options) {
    var my = this;    
    
    // define x3d container and scene
    var x3d = $("<x3d/>").appendTo(container)
	.css('width',options.width+'px')
	.css('height',options.height+'px')
	.css('border','none')
	.css('overflow','hidden')
	.attr('swfpath','/webwork2_files/js/vendor/x3dom/x3dom.swf');

    $("<div/>").addClass('sr-only')
	.text('A manipulable 3d graph.')
	.prependTo(container);

    // disable mousewheel on container because its used for zoom
    $(x3d).bind('DOMMouseScroll mousewheel',function(event) {
	event.preventDefault();
    });

    var scene = $("<scene/>").appendTo(x3d);
	
    // extend options by default values
    var defaults = {
	width : 200,
	height : 200,
	// Controls if axis are shown or not
	showAxes : false,
	// If the axis are shown determines if a full cube is drawn or just
	// the three axis lines
	showAxesCube : true,
        numTicks : 4,
	tickSize : .1,
	tickFontSize : .15,
	axisKey : ['X','Y','Z'],
	// Determines if the polygons forming the surface have their edges 
	// drawn
	drawMesh : true,
    };

    var options = $.extend({}, defaults, options);

    //global variables
    //arrays of colors and thicknesses drawn from input
    var colors = {};
    var lineThickness = {};

    //scale elements capturing scale of plotted data
    var windowScale;
    var coordMins;
    var coordMaxs;

    //block indexes are used to associate objects to colors and thicknesses
    var blockIndex = 0;
    var surfaceBlockIndex = 0;

    //data from input
    var surfaceCoords = [];
    var surfaceIndex = [];
    var lineCoords = [];
    var lonePoints = [];
    var loneLabels = [];

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
			     .attr( "position", [2*windowScale,0,0] )
			     .attr( "orientation", [0,1,0,Math.PI/2])));
	
	scene.append($('<background/>').attr('skycolor','1 1 1'));
	
	// draw components of scene
	if (options.showAxes) {
	    drawAxes();
	}

	drawSurface();
	drawLines();
	drawLonePoints();
	drawLoneLabels();

    };
    
    var parseLive3DData = function(text) {
	// Set up variables
	$.each(options.vars, function (name, data) {
	    eval(name+'='+data);
	});

	// this parses axes commands.  
	if (text.match(/Axes\s*->\s*True/)) {
	    options.showAxes = true;
	}

	// get some initial global configuration 
	var labels = text.match(/AxesLabel\s*->\s*\{\s*(\w+),\s*(\w+),\s*(\w+)\s*\}/);

	if (labels) {
	    options.axisKey = [labels[1],labels[2],labels[3]];
	}

	// split the input into blocks and parse
	var blocks = recurseMathematicaBlocks(text);

	parseMathematicaBlocks(blocks);

    };
    
    // find max and min of all mesh coordinate points and
    // the maximum coordinate value for the scale. 
    var setExtremum = function () {
	var min = [0,0,0];
	var max = [0,0,0];
	
	surfaceCoords.forEach(function(point) {
	    for (var i=0; i< 3; i++) {
		if (point[i] < min[i]) {
		    min[i] = point[i];
		} else if (point[i]>max[i]) {
		    max[i] = point[i];
		}
	    }
	});
	
	lineCoords.forEach(function(line) {
	    for (var i=0; i<2; i++) {
		for (var j=0; j<3; j++) {
		    if (line[i][j] < min[j]) {
			min[j] = line[i][j];
		    } else if (line[i][j]>max[j]) {
			max[j] = line[i][j];
		    }   
		}
	    }
	});
	coordMins = min;
	coordMaxs = max;
	
	var sum = 0;

	for (var i=0; i< 3; i++) {
	    sum += max[i]-min[i];
	}
	
	windowScale = sum/3;
    };
    
    var drawLines = function() {
	if (lineCoords.length==0) {
	    return;
	}

	// Add surface to scene as an indexedfaceset
	
	var linegroup = $('<group/>');

	lineCoords.forEach(function(line){

	    // lines are cylinders that start centered at the origin 
	    // along the y axis.  We have to translate and rotate them
	    // into place
	    var length = Math.sqrt(Math.pow((line[0][0]-line[1][0]),2)+
				   Math.pow((line[0][1]-line[1][1]),2)+
				   Math.pow((line[0][2]-line[1][2]),2));
	    var rotation = [];

	    if (length == 0) {
		return;
	    }
	    
	    rotation[0] = (line[1][2]-line[0][2]);
	    rotation[1] = 0;
	    rotation[2] = (line[0][0]-line[1][0]);
	    rotation[3] = Math.acos((line[1][1]-line[0][1])/length);

	    var trans = [0,0,0];
	    
	    for (var i=0; i < 3; i++) {
		trans[i] = (line[1][i] + line[0][i])/2;
	    }

	    var shape = $("<shape/>").appendTo($("<transform/>")
					       .attr('translation',trans)
					       .attr('rotation',rotation)
					       .appendTo(linegroup));
	    var color = [0,0,0];
	    var radius = .005;

	    // line[2] contains the block index
	    if (line[2] in colors) {
		color = colors[line[2]];
	    }
	    
	    if (line[2] in lineThickness) {
		radius = Math.max(lineThickness[line[2]],.005);
	    }

	    $("<appearance/>").appendTo(shape)
		.append($("<material/>")
			.attr('diffusecolor',color));
	    
	    shape.append($("<Cylinder/>")
			 .attr("height", length)
			 .attr("radius", radius*2));
	});
	
	scene.append(linegroup);
    }
    
    var drawSurface = function() {
	var coordstr = '';
	var indexstr = '';
	var colorstr = '';
	var colorindstr = '';

	if (surfaceCoords.length == 0) {
	    return;
	}

	// build a string with all the surface coodinates
	surfaceCoords.forEach(function(point) {
	    coordstr += point[0]+' '+point[1]+' '+point[2]+' ';
	});
	
	// build a string with all the surface indexes
	// at the same time build a string with color data
	// and the associated color indexes
	surfaceIndex.forEach(function(index) {
	    indexstr += index+' ';
	    
	    if (index == -1) {
		colorindstr += '-1 ';
		return;
	    }

	    var cindex = parseInt((surfaceCoords[index][2]-coordMins[2])/(coordMaxs[2]-coordMins[2])*colormap.length);
	    
	    if (cindex == colormap.length) {
		cindex--;
	    }
	    
	    colorindstr += cindex+' ';
	    
	});
	
	colormap.forEach(function(color) {
	    for (var i=0; i<3; i++) {
		color[i] += .2;
		color[i] = Math.min(color[i],1);
	    }
	    
	    colorstr += color[0]+' '+color[1]+' '+color[2]+' ';
	});
	
	var flatcolor = false;
	var color = [];

	if (surfaceBlockIndex in colors) {
	    flatcolor = true;
	    color = colors[surfaceBlockIndex];
	}

	// Add surface to scene as an indexedfaceset
	var shape = $("<shape/>").appendTo(scene);
	
	var appearance = $("<appearance/>").appendTo(shape);
	
	appearance .append($("<material/>")
			   .attr("ambientIntensity",'0')
			   .attr('convex','false')
			   .attr('creaseangle',Math.PI)
			   .attr('diffusecolor',color)
			   .attr("shininess",".015"));
	
	var indexedfaceset = $("<indexedfaceset/>")
	    .attr('coordindex',indexstr)
	    .attr('solid','false');
	
	indexedfaceset.append($("<coordinate/>")
			      .attr('point',coordstr));

	if (!flatcolor) {
	    indexedfaceset.attr('colorindex',colorindstr);
	    indexedfaceset.append($("<color/>")
				  .attr('color',colorstr));
	}

	// append the indexed face set to the shape after its assembled.  
	// otherwise sometimes x3d tries to access the various data before 
	// its ready
	indexedfaceset.appendTo(shape);

	if (options.drawMesh) {

	    shape = $("<shape/>").appendTo(scene);
	
	    appearance = $("<appearance/>").appendTo(shape);
	    
	    appearance .append($("<material/>")
			       .attr('diffusecolor',[0,0,0]));
	    
	    var indexedlineset = $("<indexedlineset/>")
		.attr('coordindex',indexstr)
		.attr('solid','true');
	    
	    indexedlineset.append($("<coordinate/>")
				  .attr('point',coordstr));
	    
	    indexedlineset.appendTo(shape);
	}

    }	

    var drawAxes = function() {

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

	if (options.showAxesCube) {
	    
	    var trans = [[0,coordMins[1],coordMaxs[2]],
			 [0,coordMaxs[1],coordMins[2]],
			 [0,coordMaxs[1],coordMaxs[2]]];

	    trans.forEach(function (tran) {
		$("<transform/>").attr('translation',tran)
		    .appendTo(scene)
		    .append($("<shape/>").append($("<appearance/>")
						 .append($("<material/>")
							 .attr("emissiveColor", 'black')
							))
			    .append($("<Polyline2D/>")
				    .attr("lineSegments", coordMins[0]+' 0 '+coordMaxs[0]+' 0')));
	    });
	}

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
	
	if (options.showAxesCube) {
	    
	    var trans = [[coordMins[0],0,coordMaxs[2]],
			 [coordMaxs[0],0,coordMins[2]],
			 [coordMaxs[0],0,coordMaxs[2]]];
	    
	    trans.forEach(function (tran) {
		$("<transform/>").attr('translation',tran)
		    .attr('rotation',[0,0,1,Math.PI/2])
		    .appendTo(scene)
		    .append($("<shape/>").append($("<appearance/>")
						 .append($("<material/>")
							 .attr("emissiveColor", 'black')
							))
			    .append($("<Polyline2D/>")
				    .attr("lineSegments", coordMins[1]+' 0 '+coordMaxs[1]+' 0')));
	    });
	}
	
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

	if (options.showAxesCube) {
	    
	    var trans = [[coordMins[0],coordMaxs[1],0],
			 [coordMaxs[0],coordMins[1],0],
			 [coordMaxs[0],coordMaxs[1],0]];

	    trans.forEach(function (tran) {
		$("<transform/>").attr('translation',tran)
		    .attr('rotation',[0,1,0,-Math.PI/2])
		    .appendTo(scene)
		    .append($("<shape/>").append($("<appearance/>")
						 .append($("<material/>")
							 .attr("emissiveColor", 'black')
							))
			    .append($("<Polyline2D/>")
				    .attr("lineSegments", coordMins[2]+' 0 '+coordMaxs[2]+' 0')));
	    });
	}
	
    }
    
    // biuilds the ticks, the tick labels, and the axis label for 
    // axisindex I
    var makeAxisTicks = function (I) {
	var shapes = [];

	for(var i=0; i<options.numTicks-1; i++) {
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
				     .attr('size',options.tickFontSize*windowScale)
				     .attr('family', "mono")
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
				 .attr('size',options.tickFontSize*windowScale)
				 .attr('family', "mono")
				 .attr('style', 'bold')
				 .attr('justify', 'MIDDLE')));
	
	shapes.push(axislabel.parent().parent());

	return shapes;
    }
	    
    var drawLonePoints = function () {
	
	lonePoints.forEach(function (point) {
	    
	    var color = 'black';
	    if (point.rgb) {
		color=point.rgb;
	    }
	    
	    // lone points are drawn as spheres so they have mass
	    var sphere = $("<shape/>").append($($("<appearance/>")
						.append($("<material/>")
							.attr("diffuseColor",color))));
	    sphere.appendTo($("<transform/>")
			  .attr('translation',point.coords));

	    sphere.append($("<sphere/>")
			.attr('radius',point.radius*2.25));

	    sphere.parent().appendTo(scene);
	    
	});
	
    }

    var drawLoneLabels = function () {
	
	loneLabels.forEach(function (label) {
	    
	    // the text is a billboard that automatically faces the user
	    var text = $("<shape/>").append($($("<appearance/>")
					      .append($("<material/>")
						      .attr("diffuseColor",'black'))));
	    
	    text.appendTo($("<billboard/>")
			  .attr("axisOfRotation", "0 0 0")
			  .appendTo($("<transform/>")
				    .attr('translation',label.coords)));
	    
	    var size = '.5';
	    if (label.size) {
		//mathematica label sizes are fontsizes, where 
		//the units for x3dom are local coord sizes
		size = label.size/(1.5*windowScale);
	    }
	    
	    text.append($("<text/>")
			.attr('string',label.text)
			.attr('solid','true')
			.append($("<fontstyle/>")
				.attr('size',size)
				.attr('family', "mono")
				.attr('justify', 'MIDDLE')));
	    
	    text.parent().parent().appendTo(scene);
	    
	});
	
    }

    var parseMathematicaBlocks = function (blocks) {

	blocks.forEach(function(block) {
	    blockIndex++;
	    
	    if (block.match(/^\s*\{/)) {
		// This is a block inside of a block.
		// so recurse
		var subblocks = recurseMathematicaBlocks(block);
		parseMathematicaBlocks(subblocks);

	    } else if (block.match(/Point/)) {
		// now find any individual points that need to be plotted
		// points are defined by short blocks so we dont split into
		// individual commands
		var str = block.match(/Point\[\s*\{\s*(-?\d*\.?\d*)\s*,\s*(-?\d*\.?\d*)\s*,\s*(-?\d*\.?\d*)\s*\}/);
		var point = {};
		
		if (!str) {
		    console.log('Error Parsing Point');
		    return;
		}
		
		point.coords = [parseFloat(str[1]),parseFloat(str[2]),parseFloat(str[3])];
		
		str = block.match(/PointSize\[\s*(\d*\.?\d*)\s*\]/);
		
		if (str) {
		    point.radius = parseFloat(str[1]);
		}
		
		str = block.match(/RGBColor\[\s*(\d*\.?\d*)\s*,\s*(\d*\.?\d*)\s*,\s*(\d*\.?\d*)\s*\]/);
		
		if (str) {
		    point.rgb = [parseFloat(str[1]),parseFloat(str[2]),parseFloat(str[3])];
		}
		
		lonePoints.push(point);
		
	    } else {
		// Otherwise its a list of commands that we need to 
		// process individually
		var commands = splitMathematicaBlocks(block);
		
		commands.forEach(function(command) {
		    if (command.match(/^\s*\{/)) {
			// This is a block inside of a block.
			// so recurse
			var subblocks = recurseMathematicaBlocks(block);
			parseMathematicaBlocks(subblocks);
		    } else if (command.match(/Polygon/)) {
			if (!surfaceBlockIndex) {
			    surfaceBlockIndex = blockIndex;
			}

			var polystring = command.replace(/Polygon\[([^\]]*)\]/,"$1");
			var pointstrings = recurseMathematicaBlocks(polystring,-1);
			// for each polygon extract all the points
			pointstrings.forEach(function(pointstring) {
			    pointstring = pointstring.replace(/\{([^\{]*)\}/,"$1");
			    
			    var splitstring = pointstring.split(',');
			    var point = [];
			    
			    for (var i=0; i < 3; i++) {
				point[i] = parseFloat(eval(splitstring[i]));
			    }
			    
			    // find the index of the point in surfaceCoords.  If 
			    // the point is not in surfaceCoords, add it
			    for (var i=0; i<surfaceCoords.length; i++) {
				if (surfaceCoords[i][0] == point[0] &&
				    surfaceCoords[i][1] == point[1] &&
				    surfaceCoords[i][2] == point[2]) {
				    surfaceIndex.push(i);
				    
				    return;
				}
			    }
			    
			    surfaceIndex.push(surfaceCoords.length);
			    surfaceCoords.push(point);
			    
			});
			
			surfaceIndex.push(-1);
		       
		    } else if (command.match(/Line/)) {
			//Add a line to the line array
			
			var str = command.replace(/Line\[([^\]]*)\],/,"$1");
			
			var pointstrings = recurseMathematicaBlocks(str,-1);
			
			var line = [];
			
			for (var i=0; i<2; i++) {
			    pointstrings[i] = pointstrings[i].replace(/\{([^\{]*)\}/,"$1");
			    var splitstring = pointstrings[i].split(',');
			    var point = [];
			    
			    for (var j=0; j<3; j++) {
				point[j] = parseFloat(eval(splitstring[j]));
			    }
			    
			    if (point) {
				line.push(point);
			    } else {
				console.log('Error Parsing Line');
				return;
			    }
			}

			line.push(blockIndex);

			lineCoords.push(line);

		    } else if (command.match(/RGBColor/)) {
			var str = command.match(/RGBColor\[\s*(\d*\.?\d*)\s*,\s*(\d*\.?\d*)\s*,\s*(\d*\.?\d*)\s*\]/);

			colors[blockIndex] = [parseFloat(str[1]),parseFloat(str[2]),parseFloat(str[3])];

		    } else if (command.match(/Thickness/)) {
			var str = command.match(/Thickness\[\s*(\d*\.?\d*)\s*\]/);

			lineThickness[blockIndex] = parseFloat(str[1]);
			
		    } else if (command.match(/Text/)) {
			// now find any individual labels that need to be plotted
			var str = command.match(/\{\s*(-?\d*\.?\d*)\s*,\s*(-?\d*\.?\d*)\s*,\s*(-?\d*\.?\d*)\s*\}/);
			var label = {};
			
			if (!str) {
			    console.log('Error Parsing Label');
			    return;
			}
			
			label.coords = [parseFloat(str[1]),parseFloat(str[2]),parseFloat(str[3])];
			str = command.match(/StyleForm\[\s*(\w+),\s*FontSize\s*->\s*(\d+)\s*\]/);
			
			if (!str) {
			    console.log('Error Parsing Label');
			    return;
			}
			
			label.text = str[1];
			label.fontSize = str[2];
			
			loneLabels.push(label);
			
		    }
		});
			   	
	    }
	});
    }
    
    var splitMathematicaBlocks = function (text) {
	// This splits a list of mathematica commands on the commas
	
	var bracketcount = 0;
	var blocks = [];
	var block = '';
	
	for (var i=0; i < text.length; i++) {

	    block += text.charAt(i);
	    
	    if (text.charAt(i) === '[') {
		bracketcount++;
	    }

	    if (text.charAt(i) == ']') {
		bracketcount--;
		if (bracketcount == 0) {
		    i++;
		    blocks.push(block);
		    block = '';
		}

	    }
	}

	return blocks;
    }



    var recurseMathematicaBlocks = function (text,initialcount) {
	// the mathematica code comes in blocks encolsed by {}
	// this code makes an array of those blocks.  The largest of them will
	// be the polygon block which defines the surface.  
	var bracketcount = 0;
	var blocks = [];
	var block = '';
	
	if (initialcount) {
	    bracketcount = initialcount;
	}

	for (var i=0; i < text.length; i++) {

	    if (text.charAt(i) === '{') {
		bracketcount++;
	    }

	    if (bracketcount > 0) {
		block += text.charAt(i);
	    }

	    if (text.charAt(i) == '}') {
		bracketcount--;
		if (bracketcount == 0) {
		    blocks.push(block.substring(1,block.length-1));
		    block = '';
		}

	    }
	}

	return blocks;
    }


    // This section of code is run whenever the object is created
    // run intialize with the mathematica string, possibly getting the string
    // form an ajax call if necessary
    
    if (options.input) {
	initialize(options.input);
    } else if (options.archive) {
	// If an archive file is provided then that is the file we get
	// the file name is then the file we want inside the archive. 
	JSZipUtils.getBinaryContent(options.archive, function (error, data) {
	    if (error) {
		console.log(error);
		$(container).html('Failed to get input archive');
	    }
	    
	    var zip = new JSZip(data);
	  
	    initialize(zip.file(options.file).asBinary());
	});

	    
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

    } else {
	$(container).html('No input data provided');
    }
}
