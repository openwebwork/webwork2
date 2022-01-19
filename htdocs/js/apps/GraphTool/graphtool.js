/* global JXG, bootstrap, $ */

'use strict';

function graphTool(containerId, options) {
	// Do nothing if the graph has already been created.
	if (document.getElementById(containerId + '_graph')) return;

	var graphContainer = document.getElementById(containerId);
	if (getComputedStyle(graphContainer).width == '0px') {
		setTimeout(function () { graphTool(containerId, options); }, 100);
		return;
	}

	var gt = {};

	// Semantic color control

	// dark blue
	// > 13:1 with white
	gt.curveColor = '#0000a6';

	// blue
	// > 9:1 with white
	gt.focusCurveColor = '#0000f5';

	// fillColor must use 6-digit hex
	// medium purple
	// 3:1 with white
	// 4.5:1 with #0000a6
	// > 3:1 with #0000f5
	gt.fillColor  = '#a384e5';

	// strict contrast ratios are less important for these colors
	gt.pointColor = 'orange';
	gt.pointHighlightColor = 'yellow';
	gt.underConstructionColor = 'orange';

	gt.snapSizeX = options.snapSizeX ? options.snapSizeX : 1;
	gt.snapSizeY = options.snapSizeY ? options.snapSizeY : 1;
	gt.isStatic = 'isStatic' in options ? options.isStatic : false;
	var availableTools = options.availableTools ? options.availableTools : [
		'LineTool',
		'CircleTool',
		'VerticalParabolaTool',
		'HorizontalParabolaTool',
		'FillTool',
		'SolidDashTool'
	];

	// These are the icons used for the fill tool and fill graph object.
	gt.fillIcon = "data:image/svg+xml,%3Csvg xmlns:dc='http://purl.org/dc/elements/1.1/' xmlns:cc='http://creativecommons.org/ns%23' xmlns:rdf='http://www.w3.org/1999/02/22-rdf-syntax-ns%23' xmlns:svg='http://www.w3.org/2000/svg' xmlns='http://www.w3.org/2000/svg' id='SVGRoot' version='1.1' viewBox='0 0 32 32' height='32px' width='32px'%3E%3Cdefs id='defs815' /%3E%3Cmetadata id='metadata818'%3E%3Crdf:RDF%3E%3Ccc:Work rdf:about=''%3E%3Cdc:format%3Eimage/svg+xml%3C/dc:format%3E%3Cdc:type rdf:resource='http://purl.org/dc/dcmitype/StillImage' /%3E%3Cdc:title%3E%3C/dc:title%3E%3C/cc:Work%3E%3C/rdf:RDF%3E%3C/metadata%3E%3Cg id='layer1'%3E%3Cpath id='path1382' d='m 13.466084,10.267728 -4.9000003,8.4 4.9000003,4.9 8.4,-4.9 z' style='opacity:1;fill:" + gt.fillColor.replace(/#/, '%23') + ";fill-opacity:1;stroke:%23000000;stroke-width:1.3;stroke-linecap:butt;stroke-linejoin:miter;stroke-opacity:1;stroke-miterlimit:4;stroke-dasharray:none' /%3E%3Cpath id='path1384' d='M 16.266084,15.780798 V 6.273173' style='fill:none;stroke:%23000000;stroke-width:1.38;stroke-linecap:round;stroke-linejoin:miter;stroke-miterlimit:4;stroke-dasharray:none;stroke-opacity:1' /%3E%3Cpath id='path1405' d='m 20,16 c 0,0 2,-1 3,0 1,0 1,1 2,2 0,1 0,2 0,3 0,1 0,2 0,2 0,0 -1,0 -1,0 -1,-1 -1,-1 -1,-2 0,-1 0,-1 -1,-2 0,-1 0,-2 -1,-2 -1,-1 -2,-1 -1,-1 z' style='fill:%230900ff;fill-opacity:1;stroke:%23000000;stroke-width:0.7px;stroke-linecap:butt;stroke-linejoin:miter;stroke-opacity:1' /%3E%3C/g%3E%3C/svg%3E";

	gt.fillIconFocused = "data:image/svg+xml,%3Csvg xmlns:dc='http://purl.org/dc/elements/1.1/' xmlns:cc='http://creativecommons.org/ns%23' xmlns:rdf='http://www.w3.org/1999/02/22-rdf-syntax-ns%23' xmlns:svg='http://www.w3.org/2000/svg' xmlns='http://www.w3.org/2000/svg' id='SVGRoot' version='1.1' viewBox='0 0 32 32' height='32px' width='32px'%3E%3Cdefs id='defs815' /%3E%3Cmetadata id='metadata818'%3E%3Crdf:RDF%3E%3Ccc:Work rdf:about=''%3E%3Cdc:format%3Eimage/svg+xml%3C/dc:format%3E%3Cdc:type rdf:resource='http://purl.org/dc/dcmitype/StillImage' /%3E%3Cdc:title%3E%3C/dc:title%3E%3C/cc:Work%3E%3C/rdf:RDF%3E%3C/metadata%3E%3Cg id='layer1'%3E%3Cpath id='path1382' d='m 13.466084,10.267728 -4.9000003,8.4 4.9000003,4.9 8.4,-4.9 z' style='opacity:1;fill:" + gt.pointHighlightColor.replace(/#/, '%23') + ";fill-opacity:1;stroke:%23000000;stroke-width:1.3;stroke-linecap:butt;stroke-linejoin:miter;stroke-opacity:1;stroke-miterlimit:4;stroke-dasharray:none' /%3E%3Cpath id='path1384' d='M 16.266084,15.780798 V 6.273173' style='fill:none;stroke:%23000000;stroke-width:1.38;stroke-linecap:round;stroke-linejoin:miter;stroke-miterlimit:4;stroke-dasharray:none;stroke-opacity:1' /%3E%3Cpath id='path1405' d='m 20,16 c 0,0 2,-1 3,0 1,0 1,1 2,2 0,1 0,2 0,3 0,1 0,2 0,2 0,0 -1,0 -1,0 -1,-1 -1,-1 -1,-2 0,-1 0,-1 -1,-2 0,-1 0,-2 -1,-2 -1,-1 -2,-1 -1,-1 z' style='fill:%230900ff;fill-opacity:1;stroke:%23000000;stroke-width:0.7px;stroke-linecap:butt;stroke-linejoin:miter;stroke-opacity:1' /%3E%3C/g%3E%3C/svg%3E";

	if ('htmlInputId' in options) gt.html_input = document.getElementById(options.htmlInputId);
	var cfgOptions = {
		showCopyright: false,
		//minimizeReflow: "all",
		pan: { enabled: false },
		zoom: { enabled: false },
		showNavigation: false,
		boundingBox: [-10, 10, 10, -10],
		defaultAxes: {},
		axis: {
			ticks: {
				label: { highlight: false },
				insertTicks: false,
				ticksDistance: 2,
				minorTicks: 1,
				minorHeight: 6,
				majorHeight: 6,
				tickEndings: [1, 1]
			},
			highlight: false,
			firstArrow: { size: 7 },
			lastArrow: { size: 7 },
			straightFirst: false,
			straightLast: false
		},
		grid: { gridX: gt.snapSizeX, gridY: gt.snapSizeY },
	};

	// Merge options that are set by the problem.  Note that this is the last usage of jQuery in this file.
	if ('JSXGraphOptions' in options) $.extend(true, cfgOptions, options.JSXGraphOptions);

	function setupBoard() {
		gt.board = JXG.JSXGraph.initBoard(containerId + '_graph', cfgOptions);
		gt.board.suspendUpdate();

		// Move the axes defining points to the end so that the arrows go to the board edges.
		var bbox = gt.board.getBoundingBox();
		gt.board.defaultAxes.x.point1.setPosition(JXG.COORDS_BY_USER, [bbox[0], 0]);
		gt.board.defaultAxes.x.point2.setPosition(JXG.COORDS_BY_USER, [bbox[2], 0]);
		gt.board.defaultAxes.y.point1.setPosition(JXG.COORDS_BY_USER, [0, bbox[3]]);
		gt.board.defaultAxes.y.point2.setPosition(JXG.COORDS_BY_USER, [0, bbox[1]]);

		gt.board.create('text', [
			function() { return gt.board.getBoundingBox()[2] - 3 / gt.board.unitX; },
			function() { return 1.5 / gt.board.unitY; },
			function() { return '\\(x\\)'; }
		], {
			anchorX: 'right', anchorY: 'bottom', highlight: false,
			color: 'black', fixed: true, useMathJax: true
		});
		gt.board.create('text', [
			function() { return 4.5 / gt.board.unitX; },
			function() { return gt.board.getBoundingBox()[1] + 2.5 / gt.board.unitY; },
			function() { return '\\(y\\)'; }
		], {
			anchorX: 'left', anchorY: 'top', highlight: false,
			color: 'black', fixed: true, useMathJax: true
		});
		gt.current_pos_text = gt.board.create('text',
			[
				function() { return gt.board.getBoundingBox()[2] - 5 / gt.board.unitX; },
				function() { return gt.board.getBoundingBox()[3] + 5 / gt.board.unitY; }, ''
			],
			{ anchorX: 'right', anchorY: 'bottom', fixed: true });
		// Overwrite the popup infobox for points.
		gt.board.highlightInfobox = function (x, y, el) { return gt.board.highlightCustomInfobox('', el); };

		if (!gt.isStatic) {
			gt.board.on('move', function(e) {
				var coords = gt.getMouseCoords(e);
				if (gt.activeTool.updateHighlights(coords)) return;
				if (!gt.selectedObj || !gt.selectedObj.updateTextCoords(coords))
					gt.setTextCoords(coords.usrCoords[1], coords.usrCoords[2]);
			});

			document.addEventListener('keydown', function(e) {
				if (e.key === 'Escape') gt.selectTool.activate();
			});
		}

		window.addEventListener('resize', function() {
			if (gt.board.canvasWidth != graphDiv.offsetWidth - 2 || gt.board.canvasHeight != graphDiv.offsetHeight - 2)
			{
				gt.board.resizeContainer(graphDiv.offsetWidth - 2, graphDiv.offsetHeight - 2, true);
				gt.graphedObjs.forEach(function(object) { object.onResize(); });
				gt.staticObjs.forEach(function(object) { object.onResize(); });
			}
		});

		gt.drawSolid = true;
		gt.graphedObjs = [];
		gt.staticObjs = [];
		gt.selectedObj = null;

		gt.board.unsuspendUpdate();
	}

	// Some utility functions.
	gt.snapRound = function(x, snap) {
		return Math.round(Math.round(x / snap) * snap * 100000) / 100000;
	};

	gt.setTextCoords = function(x, y) {
		gt.current_pos_text.setText(
			'(' + gt.snapRound(x, gt.snapSizeX) + ', ' + gt.snapRound(y, gt.snapSizeY) + ')'
		);
	};

	gt.updateText = function() {
		gt.html_input.value = gt.graphedObjs.reduce(
			function(val, obj) {
				return val + (val.length ? ',' : '') + '{' + obj.stringify() + '}';
			}, '');
	};

	gt.getMouseCoords = function(e) {
		var i;
		if (e[JXG.touchProperty]) { i = 0; }

		var cPos = gt.board.getCoordsTopLeftCorner(),
			absPos = JXG.getPosition(e, i),
			dx = absPos[0] - cPos[0],
			dy = absPos[1] - cPos[1];

		return new JXG.Coords(JXG.COORDS_BY_SCREEN, [dx, dy], gt.board);
	};

	gt.sign = function(x) {
		x = +x;
		if (Math.abs(x) < JXG.Math.eps) { return 0; }
		return x > 0 ? 1 : -1;
	};

	gt.pointRegexp = /\( *(-?[0-9]*(?:\.[0-9]*)?), *(-?[0-9]*(?:\.[0-9]*)?) *\)/g;

	// Prevent paired points from being moved into the same position.  This
	// prevents lines and circles from being made degenerate.
	gt.pairedPointDrag = function(e) {
		if (this.X() == this.paired_point.X() && this.Y() == this.paired_point.Y()) {
			var coords = gt.getMouseCoords(e);
			var x_trans = coords.usrCoords[1] - this.paired_point.X(),
				y_trans = coords.usrCoords[2] - this.paired_point.Y();
			if (y_trans > Math.abs(x_trans))
				this.setPosition(JXG.COORDS_BY_USER, [this.X(), this.Y() + gt.snapSizeY]);
			else if (x_trans > Math.abs(y_trans))
				this.setPosition(JXG.COORDS_BY_USER, [this.X() + gt.snapSizeX, this.Y()]);
			else if (x_trans < -Math.abs(y_trans))
				this.setPosition(JXG.COORDS_BY_USER, [this.X() - gt.snapSizeX, this.Y()]);
			else
				this.setPosition(JXG.COORDS_BY_USER, [this.X(), this.Y() - gt.snapSizeY]);
		}
		gt.updateObjects();
		gt.updateText();
	};

	// Prevent paired points from being moved onto the same horizontal or
	// vertical line.  This prevents parabolas from being made degenerate.
	gt.pairedPointDragRestricted = function(e) {
		var coords = gt.getMouseCoords(e);
		var new_x = this.X(), new_y = this.Y();
		if (this.X() == this.paired_point.X())
		{
			if (coords.usrCoords[1] > this.paired_point.X()) new_x += gt.snapSizeX;
			else new_x -= gt.snapSizeX;
		}
		if (this.Y() == this.paired_point.Y())
		{
			if (coords.usrCoords[2] > this.paired_point.Y()) new_y += gt.snapSizeX;
			else new_y -= gt.snapSizeX;
		}
		if (this.X() == this.paired_point.X() || this.Y() == this.paired_point.Y())
			this.setPosition(JXG.COORDS_BY_USER, [new_x, new_y]);
		gt.updateObjects();
		gt.updateText();
	};

	gt.createPoint = function(x, y, paired_point, restrict) {
		var point = gt.board.create('point', [x, y],
			{ size: 2, snapToGrid: true, snapSizeX: gt.snapSizeX, snapSizeY: gt.snapSizeY, withLabel: false });
		point.on('down', function() { gt.board.containerObj.style.cursor = 'none'; });
		point.on('up', function() { gt.board.containerObj.style.cursor = 'auto'; });
		if (typeof(paired_point) !== 'undefined') {
			point.paired_point = paired_point;
			paired_point.paired_point = point;
			paired_point.on('drag', restrict ? gt.pairedPointDragRestricted : gt.pairedPointDrag);
			point.on('drag', restrict ? gt.pairedPointDragRestricted : gt.pairedPointDrag);
		}
		return point;
	};

	gt.updateObjects = function() {
		gt.graphedObjs.forEach(function(obj) { obj.update(); });
		gt.staticObjs.forEach(function(obj) { obj.update(); });
	};

	// Generic graph object class from which all the specific graph objects
	// derive.
	function GraphObject(jsxGraphObject) {
		this.baseObj = jsxGraphObject;
		this.baseObj.gtGraphObject = this;
		this.definingPts = {};
	};
	GraphObject.prototype.blur = function() {
		Object.values(this.definingPts).forEach(function(obj) {
			obj.setAttribute({ visible: false });
		});
		this.baseObj.setAttribute({ strokeColor: gt.curveColor, strokeWidth: 2 });
	};
	GraphObject.prototype.focus = function() {
		Object.values(this.definingPts).forEach(function(obj) {
			obj.setAttribute({
				visible: true, strokeColor: gt.focusCurveColor, strokeWidth: 1, size: 3,
				fillColor: gt.pointColor, highlightStrokeColor: gt.focusCurveColor,
				highlightFillColor: gt.pointHighlightColor
			});
		});
		this.baseObj.setAttribute({ strokeColor: gt.focusCurveColor, strokeWidth: 3 });
		gt.drawSolid = this.baseObj.getAttribute('dash') == 0;
		if ('solidButton' in gt) gt.solidButton.disabled = gt.drawSolid;
		if ('dashedButton' in gt) gt.dashedButton.disabled = !gt.drawSolid;
	};
	GraphObject.prototype.update = function() { };
	GraphObject.prototype.fillCmp = function(/* point */) { return 1; };
	GraphObject.prototype.remove = function() {
		Object.values(this.definingPts).forEach(function(obj) {
			gt.board.removeObject(obj);
		});
		gt.board.removeObject(this.baseObj);
	};
	GraphObject.prototype.setSolid = function(solid) {
		this.baseObj.setAttribute({ dash: solid ? 0 : 2 });
	};
	GraphObject.prototype.stringify = function() { return ''; };
	GraphObject.prototype.id = function() { return this.baseObj.id; };
	GraphObject.prototype.on = function(e, handler, context) { this.baseObj.on(e, handler, context); };
	GraphObject.prototype.off = function(e, handler) { this.baseObj.off(e, handler); };
	GraphObject.prototype.onResize = function() { };
	GraphObject.prototype.updateTextCoords = function(coords) {
		return !Object.keys(this.definingPts).every(function(point) {
			if (this[point].hasPoint(coords.scrCoords[1], coords.scrCoords[2])) {
				gt.setTextCoords(this[point].X(), this[point].Y());
				return false;
			}
			return true;
		}, this.definingPts);
	};
	GraphObject.restore = function(string) {
		var data = string.match(/^(.*?),(.*)/);
		if (data.length < 3) return false;
		var obj = false;
		Object.keys(gt.graphObjectTypes).every(function(type) {
			if (data[1] == gt.graphObjectTypes[type].strId) {
				obj = gt.graphObjectTypes[type].restore(data[2]);
				return false;
			}
			return true;
		});
		if (obj !== false) obj.blur();
		return obj;
	};

	// Line graph object
	function Line(point1, point2, solid, color) {
		GraphObject.call(this, gt.board.create('line', [point1, point2], {
			fixed: true, highlight: false, strokeColor: color ? color : gt.underConstructionColor,
			dash: solid ? 0 : 2
		}));
		this.definingPts.point1 = point1;
		this.definingPts.point2 = point2;
	};
	Line.prototype = Object.create(GraphObject.prototype);
	Object.defineProperty(Line.prototype, 'constructor',
		{ value: Line, enumerable: false, writable: true });
	Line.prototype.stringify = function() {
		return [
			Line.strId, this.baseObj.getAttribute('dash') == 0 ? 'solid' : 'dashed',
			'(' + gt.snapRound(this.definingPts.point1.X(), gt.snapSizeX) + ',' +
			gt.snapRound(this.definingPts.point1.Y(), gt.snapSizeY) + ')',
			'(' + gt.snapRound(this.definingPts.point2.X(), gt.snapSizeX) + ',' +
			gt.snapRound(this.definingPts.point2.Y(), gt.snapSizeY) + ')'
		].join(',');
	};
	Line.prototype.fillCmp = function(point) {
		return gt.sign(JXG.Math.innerProduct(point, this.baseObj.stdform));
	};
	Line.strId = 'line';
	Line.restore = function(string) {
		var pointData = gt.pointRegexp.exec(string);
		var points = [];
		while (pointData) {
			points.push(pointData.slice(1, 3));
			pointData = gt.pointRegexp.exec(string);
		}
		if (points.length < 2) return false;
		var point1 = gt.createPoint(parseFloat(points[0][0]), parseFloat(points[0][1]));
		var point2 = gt.createPoint(parseFloat(points[1][0]), parseFloat(points[1][1]), point1);
		return new gt.graphObjectTypes.line(point1, point2, /solid/.test(string), gt.curveColor);
	};

	// Circle graph object
	function Circle(center, point, solid, color) {
		GraphObject.call(this, gt.board.create('circle', [center, point], {
			fixed: true, highlight: false, strokeColor: color ? color : gt.underConstructionColor,
			dash: solid ? 0 : 2
		}));
		this.definingPts.center = center;
		this.definingPts.point = point;
	};
	Circle.prototype = Object.create(GraphObject.prototype);
	Object.defineProperty(Circle.prototype, 'constructor',
		{ value: Circle, enumerable: false, writable: true });
	Circle.prototype.stringify = function() {
		return [
			Circle.strId, (this.baseObj.getAttribute('dash') == 0 ? 'solid' : 'dashed'),
			'(' + gt.snapRound(this.definingPts.center.X(), gt.snapSizeX) + ',' +
			gt.snapRound(this.definingPts.center.Y(), gt.snapSizeY) + ')',
			'(' + gt.snapRound(this.definingPts.point.X(), gt.snapSizeX) + ',' +
			gt.snapRound(this.definingPts.point.Y(), gt.snapSizeY) + ')'
		].join(',');
	};
	Circle.prototype.fillCmp = function(point) {
		return gt.sign(this.baseObj.stdform[3] *
			(point[1] * point[1] + point[2] * point[2])
			+ JXG.Math.innerProduct(point, this.baseObj.stdform));
	};
	Circle.strId = 'circle';
	Circle.restore = function(string) {
		var pointData = gt.pointRegexp.exec(string);
		var points = [];
		while (pointData) {
			points.push(pointData.slice(1, 3));
			pointData = gt.pointRegexp.exec(string);
		}
		if (points.length < 2) return false;
		var center = gt.createPoint(parseFloat(points[0][0]), parseFloat(points[0][1]));
		var point = gt.createPoint(parseFloat(points[1][0]), parseFloat(points[1][1]), center);
		return new gt.graphObjectTypes.circle(center, point, /solid/.test(string), gt.curveColor);
	};

	// Parabola graph object.
	// The underlying jsxgraph object is really a curve.  The problem with the
	// jsxgraph parabola object is that it can not be created from the vertex
	// and a point on the graph of the parabola.
	function aVal(vertex, point, vertical) {
		return vertical ?
			(point.Y() - vertex.Y()) / Math.pow(point.X() - vertex.X(), 2) :
			(point.X() - vertex.X()) / Math.pow(point.Y() - vertex.Y(), 2);
	}

	function createParabola(vertex, point, vertical, solid, color) {
		if (vertical) return gt.board.create('curve', [
			// x coordinate of point on curve
			function(x) { return x; },
			// y coordinate of point on curve
			function(x) {
				return aVal(vertex, point, vertical) *
					Math.pow(x - vertex.X(), 2) + vertex.Y();
			},
			// domain minimum
			function() { return gt.board.getBoundingBox()[0]; },
			// domain maximum
			function() { return gt.board.getBoundingBox()[2]; }
		], {
			strokeWidth: 2, highlight: false, strokeColor: color ? color : gt.underConstructionColor,
			dash: solid ? 0 : 2
		});
		else return gt.board.create('curve', [
			// x coordinate of point on curve
			function(x) {
				return aVal(vertex, point, vertical) *
					Math.pow(x - vertex.Y(), 2) + vertex.X();
			},
			// y coordinate of point on curve
			function(x) { return x; },
			// domain minimum
			function() { return gt.board.getBoundingBox()[3]; },
			// domain maximum
			function() { return gt.board.getBoundingBox()[1]; }
		], {
			strokeWidth: 2, highlight: false, strokeColor: color ? color : gt.underConstructionColor,
			dash: solid ? 0 : 2
		});
	}

	function Parabola(vertex, point, vertical, solid, color) {
		GraphObject.call(this, createParabola(vertex, point, vertical, solid, color));
		this.definingPts.vertex = vertex;
		this.definingPts.point = point;
		this.vertical = vertical;
	}
	Parabola.prototype = Object.create(GraphObject.prototype);
	Object.defineProperty(Parabola.prototype, 'constructor',
		{ value: Parabola, enumerable: false, writable: true });
	Parabola.prototype.stringify = function() {
		return [
			Parabola.strId, this.baseObj.getAttribute('dash') == 0 ? 'solid' : 'dashed',
			this.vertical ? 'vertical' : 'horizontal',
			'(' + gt.snapRound(this.definingPts.vertex.X(), gt.snapSizeX) + ',' +
			gt.snapRound(this.definingPts.vertex.Y(), gt.snapSizeY) + ')',
			'(' + gt.snapRound(this.definingPts.point.X(), gt.snapSizeX) + ',' +
			gt.snapRound(this.definingPts.point.Y(), gt.snapSizeY) + ')'
		].join(',');
	};
	Parabola.prototype.fillCmp = function(point) {
		if (this.vertical)
			return gt.sign(point[2] - this.baseObj.Y(point[1]));
		else
			return gt.sign(point[1] - this.baseObj.X(point[2]));
	};
	Parabola.strId = 'parabola';
	Parabola.restore = function(string) {
		var pointData = gt.pointRegexp.exec(string);
		var points = [];
		while (pointData) {
			points.push(pointData.slice(1, 3));
			pointData = gt.pointRegexp.exec(string);
		}
		if (points.length < 2) return false;
		var vertex = gt.createPoint(parseFloat(points[0][0]), parseFloat(points[0][1]));
		var point = gt.createPoint(parseFloat(points[1][0]), parseFloat(points[1][1]), vertex, true);
		return new gt.graphObjectTypes.parabola(vertex, point,
			/vertical/.test(string), /solid/.test(string), gt.curveColor);
	};

	// Fill graph object
	function Fill(point) {
		point.setAttribute({ visible: false });
		GraphObject.call(this, point);
		this.focused = true;
		this.definingPts.point = point;
		this.updateTimeout = 0;
		this.update();
		var this_obj = this;
		// The snapToGrid option does not allow centering an image on a point.
		// The following implements a snap to grid method that does allow that.
		this.definingPts.icon = gt.board.create('image',
			[
				function() { return this_obj.focused ? gt.fillIconFocused : gt.fillIcon; },
				[point.X() - 12 / gt.board.unitX, point.Y() - 12 / gt.board.unitY],
				[function() { return 24 / gt.board.unitX; }, function() { return 24 / gt.board.unitY; }]
			],
			{ withLabel: false, highlight: false, layer: 9, name: 'FillIcon' });
		this.definingPts.icon.gtGraphObject = this;
		this.definingPts.icon.point = point;
		this.isStatic = gt.isStatic;
		if (!gt.isStatic)
		{
			this.on('down', function() { gt.board.containerObj.style.cursor = 'none'; });
			this.on('up', function() { gt.board.containerObj.style.cursor = 'auto'; });
			this.on('drag', function(e) {
				var coords = gt.getMouseCoords(e);
				var x = gt.snapRound(coords.usrCoords[1], gt.snapSizeX),
					y = gt.snapRound(coords.usrCoords[2], gt.snapSizeY);
				this.setPosition(JXG.COORDS_BY_USER,
					[x - 12 / gt.board.unitX, y - 12 / gt.board.unitY]);
				this.point.setPosition(JXG.COORDS_BY_USER, [x, y]);
				this_obj.update();
				gt.updateText();
			});
		}
	}
	Fill.prototype = Object.create(GraphObject.prototype);
	Object.defineProperty(Fill.prototype, 'constructor',
		{ value: Fill, enumerable: false, writable: true });
	// The fill object has a non-standard focus object.  So focus/blur and
	// on/off methods need to be overridden.
	Fill.prototype.blur = function() {
		this.focused = false;
		this.definingPts.icon.setAttribute({ fixed: true });
	};
	Fill.prototype.focus = function() {
		this.focused = true;
		this.definingPts.icon.setAttribute({ fixed: false });
	};
	Fill.prototype.on = function(e, handler, context) { this.definingPts.icon.on(e, handler, context); };
	Fill.prototype.off = function(e, handler) { this.definingPts.icon.off(e, handler); };
	Fill.prototype.remove = function() {
		if ('fillObj' in this) gt.board.removeObject(this.fillObj);
		GraphObject.prototype.remove.call(this);
	};
	Fill.prototype.update = function() {
		if (this.isStatic) return;
		if (this.updateTimeout) clearTimeout(this.updateTimeout);
		var this_obj = this;
		this.updateTimeout = setTimeout(function() {
			this_obj.updateTimeout = 0;
			if ('fillObj' in this_obj) {
				gt.board.removeObject(this_obj.fillObj);
				delete this_obj.fillObj;
			}

			var centerPt = this_obj.definingPts.point.coords.usrCoords;
			var allObjects = gt.graphedObjs.concat(gt.staticObjs);

			// Determine which side of each object needs to be shaded.  If the point
			// is on a graphed object, then don't fill.
			var a_vals = Array(allObjects.length);
			for (var i = 0; i < allObjects.length; ++i) {
				a_vals[i] = allObjects[i].fillCmp(centerPt);
				if (a_vals[i] == 0) return;
			}

			var canvas = document.createElement('canvas');
			canvas.width = gt.board.canvasWidth;
			canvas.height = gt.board.canvasHeight;
			var context = canvas.getContext('2d');
			var colorLayerData = context.getImageData(0, 0, canvas.width, canvas.height);

			var fillPixel = function(pixelPos) {
				colorLayerData.data[pixelPos] = Number('0x' + gt.fillColor.slice(1, 3));
				colorLayerData.data[pixelPos + 1] = Number('0x' + gt.fillColor.slice(3, 5));
				colorLayerData.data[pixelPos + 2] = Number('0x' + gt.fillColor.slice(5));
				colorLayerData.data[pixelPos + 3] = 255;
			};

			var isFillPixel = function(x, y) {
				var curPixel = [1.0, (x - gt.board.origin.scrCoords[1]) / gt.board.unitX,
					(gt.board.origin.scrCoords[2] - y) / gt.board.unitY];
				for (var i = 0; i < allObjects.length; ++i) {
					if (allObjects[i].fillCmp(curPixel) != a_vals[i])
						return false;
				}
				return true;
			};

			for (var j = 0; j < canvas.width; ++j) {
				for (var k = 0; k < canvas.height; ++k) {
					if (isFillPixel(j, k)) fillPixel((k * canvas.width + j) * 4);
				}
			}

			context.putImageData(colorLayerData, 0, 0);
			var dataURL = canvas.toDataURL('image/png');
			canvas.remove();

			var boundingBox = gt.board.getBoundingBox();
			this_obj.fillObj = gt.board.create('image', [
				dataURL,
				[boundingBox[0], boundingBox[3]],
				[boundingBox[2] - boundingBox[0], boundingBox[1] - boundingBox[3]]
			], { withLabel: false, highlight: false, fixed: true, layer: 0 });

		}, 100);
	};
	Fill.prototype.onResize = function() {
		this.definingPts.icon.setPosition(JXG.COORDS_BY_USER,
			[this.definingPts.point.X() - 12 / gt.board.unitX,
				this.definingPts.point.Y() - 12 / gt.board.unitY]);
		gt.board.update();
	};
	Fill.prototype.updateTextCoords = function(coords) {
		if (this.definingPts.point.hasPoint(coords.scrCoords[1], coords.scrCoords[2])) {
			gt.setTextCoords(this.definingPts.point.X(), this.definingPts.point.Y());
			return true;
		}
		return false;
	};
	Fill.prototype.stringify = function() {
		return [
			Fill.strId,
			'(' + gt.snapRound(this.baseObj.X(), gt.snapSizeX) + ',' +
			gt.snapRound(this.baseObj.Y(), gt.snapSizeY) + ')'
		].join(',');
	};
	Fill.strId = 'fill';
	Fill.restore = function(string) {
		var pointData = gt.pointRegexp.exec(string);
		var points = [];
		while (pointData) {
			points.push(pointData.slice(1, 3));
			pointData = gt.pointRegexp.exec(string);
		}
		if (!points.length) return false;
		return new gt.graphObjectTypes.fill(gt.createPoint(parseFloat(points[0][0]), parseFloat(points[0][1])));
	};

	gt.graphObjectTypes = {};
	gt.graphObjectTypes[Line.strId] = Line;
	gt.graphObjectTypes[Parabola.strId] = Parabola;
	gt.graphObjectTypes[Circle.strId] = Circle;
	gt.graphObjectTypes[Fill.strId] = Fill;

	// Load any custom graph objects.
	if ('customGraphObjects' in options) {
		Object.keys(options.customGraphObjects).forEach(function(name) {
			var graphObject = this[name];
			var parentObject = 'parent' in graphObject ?
				(graphObject.parent ? gt.graphObjectTypes[graphObject.parent] : null) : GraphObject;
			var customGraphObject;
			if (parentObject) {
				customGraphObject = function() {
					if ('preInit' in graphObject)
						parentObject.call(this, graphObject.preInit.apply(this,
							[gt].concat(Array.prototype.slice.call(arguments))));
					else
						parentObject.apply(this, arguments);
					if ('postInit' in graphObject)
						graphObject.postInit.apply(this,
							[gt].concat(Array.prototype.slice.call(arguments)));
				};
				customGraphObject.prototype = Object.create(parentObject.prototype);
				Object.defineProperty(customGraphObject.prototype, 'constructor',
					{ value: customGraphObject, enumerable: false, writable: true });
			} else {
				customGraphObject = function() {
					graphObject.preInit.apply(this, [gt].concat(Array.prototype.slice.call(arguments)));
				};
			}
			if ('blur' in graphObject) {
				customGraphObject.prototype.blur = function() {
					if (graphObject.blur.call(this, gt) && parentObject) {
						parentObject.prototype.blur.call(this);
					}
				};
			}
			if ('focus' in graphObject) {
				customGraphObject.prototype.focus = function() {
					if (graphObject.focus.call(this, gt) && parentObject) {
						parentObject.prototype.focus.call(this);
					}
				};
			}
			if ('update' in graphObject) {
				customGraphObject.prototype.update = function() {
					graphObject.update.call(this, gt);
				};
			}
			if ('onResize' in graphObject) {
				customGraphObject.prototype.onResize = function() {
					graphObject.onResize.call(this, gt);
				};
			}
			if ('updateTextCoords' in graphObject) {
				customGraphObject.prototype.updateTextCoords = function(coords) {
					return graphObject.updateTextCoords.call(this, gt, coords);
				};
			}
			if ('fillCmp' in graphObject) {
				customGraphObject.prototype.fillCmp = function(point) {
					return graphObject.fillCmp.call(this, gt, point);
				};
			}
			if ('remove' in graphObject) {
				customGraphObject.prototype.remove = function() {
					graphObject.remove.call(this, gt);
					if (parentObject) parentObject.prototype.remove.call(this);
				};
			}
			if ('setSolid' in graphObject) {
				customGraphObject.prototype.setSolid = function(solid) {
					graphObject.setSolid.call(this, gt, solid);
				};
			}
			if ('on' in graphObject) {
				customGraphObject.prototype.on = function(e, handler, context) {
					graphObject.on.call(this, e, handler, context);
				};
			}
			if ('off' in graphObject) {
				customGraphObject.prototype.off = function(e, handler) {
					graphObject.off.call(this, e, handler);
				};
			}
			if ('stringify' in graphObject) {
				customGraphObject.prototype.stringify = function() {
					return [customGraphObject.strId, graphObject.stringify.call(this, gt)].join(',');
				};
			}
			if ('restore' in graphObject) {
				customGraphObject.restore = function(string) {
					return graphObject.restore.call(this, gt, string);
				};
			} else if (parentObject)
				customGraphObject.restore = parentObject.restore;

			if ('helperMethods' in graphObject) {
				Object.keys(graphObject.helperMethods).forEach(function(method) {
					customGraphObject[method] = function() {
						return graphObject.helperMethods[method].apply(this,
							[gt].concat(Array.prototype.slice.call(arguments)));
					};
				});
			}
			customGraphObject.strId = name;
			gt.graphObjectTypes[customGraphObject.strId] = customGraphObject;
		}, options.customGraphObjects);
	}

	// Generic tool class from which all the graphing tools derive.  Most of
	// the methods, if overridden, must call the corresponding generic method.
	// At this point the updateHighlights method is the only one that this
	// doesn't need to be done with.
	function GenericTool(container, name, tooltip) {
		var div = document.createElement('div');
		div.classList.add('gt-button-div');
		div.dataset.bsToggle = 'tooltip';
		div.title = tooltip;
		this.button = document.createElement('button');
		this.button.type = 'button';
		this.button.classList.add('btn', 'btn-light', 'gt-button', 'gt-tool-button', 'gt-' + name + '-tool');
		var this_tool = this;
		this.button.addEventListener('click', function () { this_tool.activate(); });
		div.append(this.button);
		container.append(div);
		this.hlObjs = {};
	}
	GenericTool.prototype.activate = function() {
		gt.activeTool.deactivate();
		gt.activeTool = this;
		this.button.blur();
		this.button.disabled = true;
		if (gt.selectedObj) { gt.selectedObj.blur(); }
		gt.selectedObj = null;
	};
	GenericTool.prototype.finish = function() {
		gt.updateObjects();
		gt.updateText();
		gt.board.update();
		gt.selectTool.activate();
	};
	GenericTool.prototype.updateHighlights = function(/* coords */) { return false; };
	GenericTool.prototype.removeHighlights = function() {
		Object.keys(this.hlObjs).forEach(function(obj) {
			gt.board.removeObject(this[obj]);
			delete this[obj];
		}, this.hlObjs);
	};
	GenericTool.prototype.deactivate = function() {
		this.button.disabled = false;
		this.removeHighlights();
	};

	// Select tool
	function SelectTool(container) { GenericTool.call(this, container, 'select', 'Object Selection Tool'); }
	SelectTool.prototype = Object.create(GenericTool.prototype);
	Object.defineProperty(SelectTool.prototype, 'constructor',
		{ value: SelectTool, enumerable: false, writable: true });
	SelectTool.prototype.selectionChanged = function(e) {
		if (gt.selectedObj)
		{
			if (gt.selectedObj.id() != this.gtGraphObject.id())
			{
				// Don't allow the selection of a new object if the pointer
				// is in the vicinity of one of the currently selected
				// object's defining points.
				var coords = gt.getMouseCoords(e);
				var points = Object.values(gt.selectedObj.definingPts);
				for (var i = 0; i < points.length; ++i)
				{
					if (points[i].X() == gt.snapRound(coords.usrCoords[1], gt.snapSizeX) &&
						points[i].Y() == gt.snapRound(coords.usrCoords[2], gt.snapSizeY))
						return;
				}
				gt.selectedObj.blur();
			}
			else return;
		}
		gt.selectedObj = this.gtGraphObject;
		gt.selectedObj.focus();
	};
	SelectTool.prototype.activate = function(initialize) {
		// Cache the currently selected object to re-select after the GenericTool
		// activate method de-selects it.
		var selectedObj = gt.selectedObj;
		GenericTool.prototype.activate.call(this);
		if (selectedObj) gt.selectedObj = selectedObj;
		// If only one object has been graphed, select it.
		if (!initialize && gt.graphedObjs.length == 1) {
			gt.selectedObj = gt.graphedObjs[0];
		}
		if (gt.selectedObj) { gt.selectedObj.focus(); }
		gt.graphedObjs.forEach(function(obj) { obj.on('down', this.selectionChanged); }, this);
	};
	SelectTool.prototype.deactivate = function() {
		gt.graphedObjs.forEach(function(obj) { obj.off('down', this.selectionChanged); }, this);
		GenericTool.prototype.deactivate.call(this);
	};

	// Line graphing tool
	function LineTool(container, iconName, tooltip) {
		GenericTool.call(this, container, iconName ? iconName : 'line', tooltip ? tooltip : 'Line Tool');
	}
	LineTool.prototype = Object.create(GenericTool.prototype);
	Object.defineProperty(LineTool.prototype, 'constructor',
		{ value: LineTool, enumerable: false, writable: true });
	LineTool.prototype.updateHighlights = function(coords) {
		if ('hl_line' in this.hlObjs) this.hlObjs.hl_line.setAttribute({ dash: gt.drawSolid ? 0 : 2 });
		if (typeof(coords) === 'undefined') return false;
		if ('point1' in this && gt.snapRound(coords.usrCoords[1], gt.snapSizeX) == this.point1.X() &&
			gt.snapRound(coords.usrCoords[2], gt.snapSizeY) == this.point1.Y())
			return false;
		if (!('hl_point' in this.hlObjs)) {
			this.hlObjs.hl_point = gt.board.create('point', [coords.usrCoords[1], coords.usrCoords[2]], {
				size: 2, color: gt.underConstructionColor, fixed: true, snapToGrid: true,
				snapSizeX: gt.snapSizeX, snapSizeY: gt.snapSizeY, withLabel: false
			});
			if ('point1' in this)
				this.hlObjs.hl_line = gt.board.create('line', [this.point1, this.hlObjs.hl_point], {
					fixed: true, strokeColor: gt.underConstructionColor, highlight: false,
					dash: gt.drawSolid ? 0 : 2
				});
		}
		else
			this.hlObjs.hl_point.setPosition(JXG.COORDS_BY_USER, [coords.usrCoords[1], coords.usrCoords[2]]);

		gt.setTextCoords(this.hlObjs.hl_point.X(), this.hlObjs.hl_point.Y());
		gt.board.update();
		return true;
	};
	LineTool.prototype.deactivate = function() {
		gt.board.off('up');
		if ('point1' in this) gt.board.removeObject(this.point1);
		delete this.point1;
		gt.board.containerObj.style.cursor = 'auto';
		GenericTool.prototype.deactivate.call(this);
	};
	LineTool.prototype.activate = function() {
		GenericTool.prototype.activate.call(this);
		gt.board.containerObj.style.cursor = 'none';
		var this_tool = this;
		gt.board.on('up', function(e) {
			var coords = gt.getMouseCoords(e);
			// Don't allow the point to be created off the board.
			if (!gt.board.hasPoint(coords.usrCoords[1], coords.usrCoords[2])) return;
			gt.board.off('up');
			this_tool.point1 = gt.board.create('point', [coords.usrCoords[1], coords.usrCoords[2]],
				{ size: 2, snapToGrid: true, snapSizeX: gt.snapSizeX, snapSizeY: gt.snapSizeY, withLabel: false });
			this_tool.point1.setAttribute({ fixed: true });
			this_tool.removeHighlights();

			gt.board.on('up', function(e) {
				var coords = gt.getMouseCoords(e);

				// Don't allow the second point to be created on top of the first or off the board
				if ((this_tool.point1.X() == gt.snapRound(coords.usrCoords[1], gt.snapSizeX) &&
					this_tool.point1.Y() == gt.snapRound(coords.usrCoords[2], gt.snapSizeY)) ||
					!gt.board.hasPoint(coords.usrCoords[1], coords.usrCoords[2]))
					return;
				gt.board.off('up');

				this_tool.point1.setAttribute({ fixed: false });
				this_tool.point1.on('down', function() { gt.board.containerObj.style.cursor = 'none'; });
				this_tool.point1.on('up', function() { gt.board.containerObj.style.cursor = 'auto'; });

				gt.selectedObj = new gt.graphObjectTypes.line(this_tool.point1,
					gt.createPoint(coords.usrCoords[1], coords.usrCoords[2], this_tool.point1),
					gt.drawSolid);
				gt.graphedObjs.push(gt.selectedObj);
				delete this_tool.point1;

				this_tool.finish();
			});

			gt.board.update();
		});
	};

	// Circle graphing tool
	function CircleTool(container, iconName, tooltip) {
		GenericTool.call(this, container, iconName ? iconName : 'circle', tooltip ? tooltip : 'Circle Tool');
	}
	CircleTool.prototype = Object.create(GenericTool.prototype);
	Object.defineProperty(CircleTool.prototype, 'constructor',
		{ value: CircleTool, enumerable: false, writable: true });
	CircleTool.prototype.updateHighlights = function(coords) {
		if ('hl_circle' in this.hlObjs) this.hlObjs.hl_circle.setAttribute({ dash: gt.drawSolid ? 0 : 2 });
		if (typeof(coords) === 'undefined') return false;
		if ('center' in this && gt.snapRound(coords.usrCoords[1], gt.snapSizeX) == this.center.X() &&
			gt.snapRound(coords.usrCoords[2], gt.snapSizeY) == this.center.Y())
			return false;
		if (!('hl_point' in this.hlObjs)) {
			this.hlObjs.hl_point = gt.board.create('point', [coords.usrCoords[1], coords.usrCoords[2]], {
				size: 2, color: gt.underConstructionColor, fixed: true, snapToGrid: true,
				snapSizeX: gt.snapSizeX, snapSizeY: gt.snapSizeY, withLabel: false
			});
			if ('center' in this)
				this.hlObjs.hl_circle = gt.board.create('circle', [this.center, this.hlObjs.hl_point], {
					fixed: true, strokeColor: gt.underConstructionColor, highlight: false,
					dash: gt.drawSolid ? 0 : 2
				});
		}
		else
			this.hlObjs.hl_point.setPosition(JXG.COORDS_BY_USER, [coords.usrCoords[1], coords.usrCoords[2]]);

		gt.setTextCoords(this.hlObjs.hl_point.X(), this.hlObjs.hl_point.Y());
		gt.board.update();
		return true;
	};
	CircleTool.prototype.deactivate = function() {
		gt.board.off('up');
		if ('center' in this) gt.board.removeObject(this.center);
		delete this.center;
		gt.board.containerObj.style.cursor = 'auto';
		GenericTool.prototype.deactivate.call(this);
	};
	CircleTool.prototype.activate = function() {
		GenericTool.prototype.activate.call(this);
		gt.board.containerObj.style.cursor = 'none';
		var this_tool = this;
		gt.board.on('up', function(e) {
			var coords = gt.getMouseCoords(e);
			// Don't allow the point to be created off the board.
			if (!gt.board.hasPoint(coords.usrCoords[1], coords.usrCoords[2])) return;
			gt.board.off('up');
			this_tool.center = gt.board.create('point', [coords.usrCoords[1], coords.usrCoords[2]],
				{ size: 2, snapToGrid: true, snapSizeX: gt.snapSizeX, snapSizeY: gt.snapSizeY, withLabel: false });
			this_tool.center.setAttribute({ fixed: true });
			this_tool.removeHighlights();

			gt.board.on('up', function(e) {
				var coords = gt.getMouseCoords(e);

				// Don't allow the second point to be created on top of the center or off the board
				if ((this_tool.center.X() == gt.snapRound(coords.usrCoords[1], gt.snapSizeX) &&
					this_tool.center.Y() == gt.snapRound(coords.usrCoords[2], gt.snapSizeY)) ||
					!gt.board.hasPoint(coords.usrCoords[1], coords.usrCoords[2]))
					return;
				gt.board.off('up');

				this_tool.center.setAttribute({ fixed: false });
				this_tool.center.on('down', function() { gt.board.containerObj.style.cursor = 'none'; });
				this_tool.center.on('up', function() { gt.board.containerObj.style.cursor = 'auto'; });

				gt.selectedObj = new gt.graphObjectTypes.circle(this_tool.center,
					gt.createPoint(coords.usrCoords[1], coords.usrCoords[2], this_tool.center),
					gt.drawSolid);
				gt.graphedObjs.push(gt.selectedObj);
				delete this_tool.center;

				this_tool.finish();
			});

			gt.board.update();
		});
	};

	// Parabola graphing tool
	function ParabolaTool(container, vertical, iconName, tooltip) {
		GenericTool.call(this, container,
			iconName ? iconName : (vertical ? 'vertical-parabola' : 'horizontal-parabola'),
			tooltip ? tooltip : (vertical ? 'Vertical Parabola Tool' : 'Horizontal Parabola Tool'));
		this.vertical = vertical;
	}
	ParabolaTool.prototype = Object.create(GenericTool.prototype);
	Object.defineProperty(ParabolaTool.prototype, 'constructor',
		{ value: ParabolaTool, enumerable: false, writable: true });
	ParabolaTool.prototype.updateHighlights = function(coords) {
		if ('hl_parabola' in this.hlObjs) this.hlObjs.hl_parabola.setAttribute({ dash: gt.drawSolid ? 0 : 2 });
		if (typeof(coords) === 'undefined') return false;
		if ('vertex' in this &&
			(gt.snapRound(coords.usrCoords[1], gt.snapSizeX) == this.vertex.X() ||
				gt.snapRound(coords.usrCoords[2], gt.snapSizeY) == this.vertex.Y()))
			return false;
		if (!('hl_point' in this.hlObjs)) {
			this.hlObjs.hl_point = gt.board.create('point', [coords.usrCoords[1], coords.usrCoords[2]], {
				size: 2, color: gt.underConstructionColor, fixed: true, snapToGrid: true,
				snapSizeX: gt.snapSizeX, snapSizeY: gt.snapSizeY,
				highlight: false, withLabel: false
			});
			if ('vertex' in this)
				this.hlObjs.hl_parabola = createParabola(this.vertex, this.hlObjs.hl_point, this.vertical,
					gt.drawSolid, gt.underConstructionColor);
		}
		else
			this.hlObjs.hl_point.setPosition(JXG.COORDS_BY_USER, [coords.usrCoords[1], coords.usrCoords[2]]);

		gt.setTextCoords(this.hlObjs.hl_point.X(), this.hlObjs.hl_point.Y());
		gt.board.update();
		return true;
	};
	ParabolaTool.prototype.deactivate = function() {
		gt.board.off('up');
		if ('vertex' in this) gt.board.removeObject(this.vertex);
		delete this.vertex;
		gt.board.containerObj.style.cursor = 'auto';
		GenericTool.prototype.deactivate.call(this);
	};
	ParabolaTool.prototype.activate = function() {
		GenericTool.prototype.activate.call(this);
		gt.board.containerObj.style.cursor = 'none';
		var this_tool = this;
		gt.board.on('up', function(e) {
			var coords = gt.getMouseCoords(e);
			// Don't allow the point to be created off the board.
			if (!gt.board.hasPoint(coords.usrCoords[1], coords.usrCoords[2])) return;
			gt.board.off('up');
			this_tool.vertex = gt.board.create('point', [coords.usrCoords[1], coords.usrCoords[2]],
				{ size: 2, snapToGrid: true, snapSizeX: gt.snapSizeX, snapSizeY: gt.snapSizeY, withLabel: false });
			this_tool.vertex.setAttribute({ fixed: true });
			this_tool.removeHighlights();

			gt.board.on('up', function(e) {
				var coords = gt.getMouseCoords(e);

				// Don't allow the second point to be created on the same
				// horizontal or vertical line as the vertex or off the board.
				if ((this_tool.vertex.X() == gt.snapRound(coords.usrCoords[1], gt.snapSizeX) ||
					this_tool.vertex.Y() == gt.snapRound(coords.usrCoords[2], gt.snapSizeY)) ||
					!gt.board.hasPoint(coords.usrCoords[1], coords.usrCoords[2]))
					return;

				gt.board.off('up');

				this_tool.vertex.setAttribute({ fixed: false });
				this_tool.vertex.on('down', function() { gt.board.containerObj.style.cursor = 'none'; });
				this_tool.vertex.on('up', function() { gt.board.containerObj.style.cursor = 'auto'; });

				gt.selectedObj = new gt.graphObjectTypes.parabola(this_tool.vertex,
					gt.createPoint(coords.usrCoords[1], coords.usrCoords[2], this_tool.vertex, true),
					this_tool.vertical, gt.drawSolid);
				gt.graphedObjs.push(gt.selectedObj);
				delete this_tool.vertex;

				this_tool.finish();
			});

			gt.board.update();
		});
	};

	function VerticalParabolaTool(container, iconName, tooltip) {
		ParabolaTool.call(this, container, true, iconName, tooltip);
	}
	VerticalParabolaTool.prototype = Object.create(ParabolaTool.prototype);
	Object.defineProperty(VerticalParabolaTool.prototype, 'constructor',
		{ value: VerticalParabolaTool, enumerable: false, writable: true });

	function HorizontalParabolaTool(container, iconName, tooltip) {
		ParabolaTool.call(this, container, false, iconName, tooltip);
	}
	HorizontalParabolaTool.prototype = Object.create(ParabolaTool.prototype);
	Object.defineProperty(HorizontalParabolaTool.prototype, 'constructor',
		{ value: HorizontalParabolaTool, enumerable: false, writable: true });

	// Fill tool
	function FillTool(container, iconName, tooltip) {
		GenericTool.call(this, container, iconName ? iconName : 'fill', tooltip ? tooltip : 'Region Shading Tool');
	}
	FillTool.prototype = Object.create(GenericTool.prototype);
	Object.defineProperty(FillTool.prototype, 'constructor',
		{ value: FillTool, enumerable: false, writable: true });
	FillTool.prototype.updateHighlights = function(coords) {
		if (typeof(coords) === 'undefined') return false;
		if (!('hl_point' in this.hlObjs)) {
			this.hlObjs.hl_point = gt.board.create('image', [
				gt.fillIcon, [
					gt.snapRound(coords.usrCoords[1], gt.snapSizeX) - 12 / gt.board.unitX,
					gt.snapRound(coords.usrCoords[2], gt.snapSizeY) - 12 / gt.board.unitY
				], [24 / gt.board.unitX, 24 / gt.board.unitY]
			], { withLabel: false, highlight: false, layer: 9 });
		}
		else
			this.hlObjs.hl_point.setPosition(JXG.COORDS_BY_USER, [
				gt.snapRound(coords.usrCoords[1], gt.snapSizeX) - 12 / gt.board.unitX,
				gt.snapRound(coords.usrCoords[2], gt.snapSizeY) - 12 / gt.board.unitY
			]);

		gt.setTextCoords(coords.usrCoords[1], coords.usrCoords[2]);
		gt.board.update();
		return true;
	};
	FillTool.prototype.deactivate = function() {
		gt.board.off('up');
		gt.board.containerObj.style.cursor = 'auto';
		GenericTool.prototype.deactivate.call(this);
	};
	FillTool.prototype.activate = function() {
		GenericTool.prototype.activate.call(this);
		gt.board.containerObj.style.cursor = 'none';
		gt.board.on('up', function(e) {
			gt.board.off('up');
			var coords = gt.getMouseCoords(e);

			// Don't allow the fill to be created off the board
			if (!gt.board.hasPoint(coords.usrCoords[1], coords.usrCoords[2])) return;
			gt.board.off('up');

			gt.selectedObj = new gt.graphObjectTypes.fill(gt.createPoint(coords.usrCoords[1], coords.usrCoords[2]));
			gt.graphedObjs.push(gt.selectedObj);

			gt.updateText();
			gt.board.update();
			gt.selectTool.activate();
		});
	};

	// Draw objects solid or dashed. Makes the currently selected object (if
	// any) solid or dashed, and anything drawn while the tool is selected will
	// be drawn solid or dashed.
	function toggleSolidity(button, drawSolid) {
		button.blur();
		if ('solidButton' in gt) gt.solidButton.disabled = drawSolid;
		if ('dashedButton' in gt) gt.dashedButton.disabled = !drawSolid;
		if (gt.selectedObj)
		{
			gt.selectedObj.setSolid(drawSolid);
			gt.updateText();
		}
		gt.drawSolid = drawSolid;
		gt.activeTool.updateHighlights();
	}

	function confirmDialog(title, titleId, message, yesAction) {
		var modal = document.createElement('div');
		modal.classList.add('modal', 'modal-dialog-centered', 'gt-modal');
		modal.tabIndex = -1;
		modal.setAttribute('aria-labelledby', titleId);
		modal.setAttribute('aria-hidden', 'true');

		var modalDialog = document.createElement('div');
		modalDialog.classList.add('modal-dialog');
		var modalContent = document.createElement('div');
		modalContent.classList.add('modal-content');

		var modalHeader = document.createElement('div');
		modalHeader.classList.add('modal-header');

		var titleH3 = document.createElement('h3');
		titleH3.id = titleId;
		titleH3.textContent = title;

		var closeButton = document.createElement('button');
		closeButton.type = 'button';
		closeButton.classList.add('btn-close');
		closeButton.dataset.bsDismiss = 'modal';
		closeButton.setAttribute('aria-label', 'close');

		modalHeader.append(titleH3, closeButton);

		var modalBody = document.createElement('div');
		modalBody.classList.add('modal-body');
		var modalBodyContent = document.createElement('div');
		modalBodyContent.textContent = message;
		modalBody.append(modalBodyContent);

		var modalFooter = document.createElement('div');
		modalFooter.classList.add('modal-footer');

		var yesButton = document.createElement('button');
		yesButton.classList.add('btn', 'btn-primary');
		yesButton.textContent = 'Yes';
		yesButton.addEventListener('click', function () { yesAction(); bsModal.hide(); });

		var noButton = document.createElement('button');
		noButton.classList.add('btn', 'btn-primary');
		noButton.dataset.bsDismiss = 'modal';
		noButton.textContent = 'No';

		modalFooter.append(yesButton, noButton);
		modalContent.append(modalHeader, modalBody, modalFooter);
		modalDialog.append(modalContent);
		modal.append(modalDialog);

		var bsModal = new bootstrap.Modal(modal);
		bsModal.show();
		document.querySelector('.modal-backdrop').style.opacity = '0.2';
		modal.addEventListener('hidden.bs.modal', function () { bsModal.dispose(); modal.remove(); });
	}

	// Delete the selected object.
	function deleteObject() {
		this.blur();
		if (!gt.selectedObj) return;

		confirmDialog('Delete Selected Object', 'deleteObjectDialog',
			'Do you want to delete the selected object?',
			function() {
				for (var i = 0; i < gt.graphedObjs.length; ++i) {
					if (gt.graphedObjs[i].id() === gt.selectedObj.id()) {
						gt.graphedObjs[i].remove();
						gt.graphedObjs.splice(i, 1);
						break;
					}
				}
				gt.selectedObj = null;
				gt.updateObjects();
				gt.updateText();
			}
		);
	}

	// Remove all graphed objects.
	function clearGraph() {
		this.blur();
		if (gt.graphedObjs.length == 0) return;

		confirmDialog('Clear Graph', 'clearGraphDialog',
			'Do you want to remove all graphed objects?',
			function() {
				gt.graphedObjs.forEach(function(obj) { obj.remove(); });
				gt.graphedObjs = [];
				gt.selectedObj = null;
				gt.selectTool.activate();
				gt.html_input.value = '';
			}
		);
	}

	function SolidDashTool(container) {
		var solidDashBox = document.createElement('div');
		solidDashBox.classList.add('gt-solid-dash-box');
		// The draw solid button is active by default.
		var solidButtonDiv = document.createElement('div');
		solidButtonDiv.classList.add('gt-button-div', 'gt-solid-button-div');
		solidButtonDiv.dataset.bsToggle = 'tooltip';
		solidButtonDiv.title = 'Make Selected Object Solid';
		gt.solidButton = document.createElement('button');
		gt.solidButton.classList.add('btn', 'btn-light', 'gt-button', 'gt-tool-button', 'gt-solid-tool');
		gt.solidButton.type = 'button';
		gt.solidButton.disabled = true;
		gt.solidButton.addEventListener('click', function () { toggleSolidity(gt.solidButton, true); });
		solidButtonDiv.append(gt.solidButton);
		solidDashBox.append(solidButtonDiv);

		var dashedButtonDiv = document.createElement('div');
		dashedButtonDiv.classList.add('gt-button-div', 'gt-dashed-button-div');
		dashedButtonDiv.dataset.bsToggle = 'tooltip';
		dashedButtonDiv.title = 'Make Selected Object Dashed';
		gt.dashedButton = document.createElement('button');
		gt.dashedButton.classList.add('btn', 'btn-light', 'gt-button', 'gt-tool-button', 'gt-dashed-tool');
		gt.dashedButton.type = 'button';
		gt.dashedButton.addEventListener('click', function () { toggleSolidity(gt.dashedButton, false); });
		dashedButtonDiv.append(gt.dashedButton);
		solidDashBox.append(dashedButtonDiv);
		container.append(solidDashBox);
	}

	gt.toolTypes = {
		LineTool: LineTool,
		CircleTool: CircleTool,
		VerticalParabolaTool: VerticalParabolaTool,
		HorizontalParabolaTool:  HorizontalParabolaTool,
		FillTool: FillTool,
		SolidDashTool: SolidDashTool
	};

	// Create the tools and html elements.
	var graphDiv = document.createElement('div');
	graphDiv.id = containerId + '_graph';
	graphDiv.classList.add('jxgbox', 'graphtool-graph');
	graphContainer.append(graphDiv);

	if (!gt.isStatic) {
		var buttonBox = document.createElement('div');
		buttonBox.classList.add('gt-toolbar-container');
		gt.selectTool = new SelectTool(buttonBox);

		// Load any custom tools.
		if ('customTools' in options) {
			Object.keys(options.customTools).forEach(function(tool) {
				var toolObject = this[tool];
				var parentTool = 'parent' in toolObject ?
					(toolObject.parent ? gt.toolTypes[toolObject.parent] : null) : GenericTool;
				var customTool;
				if (parentTool) {
					customTool = function(container) {
						parentTool.call(this, container, toolObject.iconName, toolObject.tooltip);
						if ('initialize' in toolObject) toolObject.initialize.call(this, gt, container);
					};
					customTool.prototype = Object.create(parentTool.prototype);
					Object.defineProperty(customTool.prototype, 'constructor',
						{ value: customTool, enumerable: false, writable: true });
				} else {
					customTool = function(container) {
						toolObject.initialize.call(this, gt, container);
					};
				}
				if ('activate' in toolObject) {
					customTool.prototype.activate = function() {
						parentTool.prototype.activate.call(this);
						toolObject.activate.call(this, gt);
					};
				}
				if ('deactivate' in toolObject) {
					customTool.prototype.deactivate = function() {
						toolObject.deactivate.call(this, gt);
						parentTool.prototype.deactivate.call(this);
					};
				}
				if ('updateHighlights' in toolObject) {
					customTool.prototype.updateHighlights = function(coords) {
						return toolObject.updateHighlights.call(this, gt, coords);
					};
				}
				if ('removeHighlights' in toolObject) {
					customTool.prototype.removeHighlights = function() {
						toolObject.removeHighlights.call(this, gt);
						parentTool.prototype.removeHighlights.call(this);
					};
				}
				if ('helperMethods' in toolObject) {
					Object.keys(toolObject.helperMethods).forEach(function(method) {
						customTool[method] = function() {
							return toolObject.helperMethods[method].apply(this,
								[gt].concat(Array.prototype.slice.call(arguments)));
						};
					});
				}
				gt.toolTypes[tool] = customTool;
			}, options.customTools);
		}

		availableTools.forEach(function(tool) {
			if (tool in gt.toolTypes) {
				new gt.toolTypes[tool](buttonBox);
			} else
				console.log('Unknown tool: ' + tool);
		});

		var deleteButton = document.createElement('button');
		deleteButton.type = 'button';
		deleteButton.classList.add('btn', 'btn-light', 'gt-button');
		deleteButton.dataset.bsToggle = 'tooltip';
		deleteButton.title = 'Delete Selected Object';
		deleteButton.textContent = 'Delete';
		deleteButton.addEventListener('click', deleteObject);
		buttonBox.append(deleteButton);

		var clearButton = document.createElement('button');
		clearButton.type = 'button';
		clearButton.classList.add('btn', 'btn-light', 'gt-button');
		clearButton.dataset.bsToggle = 'tooltip';
		clearButton.title = 'Clear All Objects From Graph';
		clearButton.textContent = 'Clear';
		clearButton.addEventListener('click', clearGraph);
		buttonBox.append(clearButton);

		graphContainer.append(buttonBox);

		document.querySelectorAll('.gt-button-div[data-bs-toggle="tooltip"],.gt-button[data-bs-toggle="tooltip"]')
			.forEach(function(tooltip) {
				new bootstrap.Tooltip(tooltip, {
					placement: 'bottom', trigger: 'hover', delay: { show: 500, hide: 0 }
				});
			});
	}

	setupBoard();

	// Restore data from previous attempts if available
	function restoreObjects(data, objectsAreStatic) {
		gt.board.suspendUpdate();
		var tmpIsStatic = gt.isStatic;
		gt.isStatic = objectsAreStatic;
		var objectRegexp = /{(.*?)}/g;
		var objectData = objectRegexp.exec(data);
		while (objectData) {
			var obj = GraphObject.restore(objectData[1]);
			if (obj !== false)
			{
				if (objectsAreStatic) gt.staticObjs.push(obj);
				else gt.graphedObjs.push(obj);
			}
			objectData = objectRegexp.exec(data);
		}
		gt.isStatic = tmpIsStatic;
		gt.updateObjects();
		gt.board.unsuspendUpdate();
	}
	if ('html_input' in gt) restoreObjects(gt.html_input.value, false);
	if ('staticObjects' in options && typeof(options.staticObjects) === 'string' && options.staticObjects.length)
		restoreObjects(options.staticObjects, true);
	if (!gt.isStatic) {
		gt.updateText();
		gt.activeTool = gt.selectTool;
		gt.activeTool.activate(true);
	}
}
