// Polyfill for IE11.
if (!Object.values) Object.values = function(o) {
    return Object.keys(o).map(function(i) { return o[i]; });
};

function graphTool(containerId, options) {
    // Do nothing if the graph has already been created.
	if (document.getElementById(containerId + "_graph")) return;

    var snapSizeX = options.snapSizeX ? options.snapSizeX : 1;
    var snapSizeY = options.snapSizeY ? options.snapSizeY : 1;
    var isStatic = 'isStatic' in options ? options.isStatic : false;
    var availableTools = options.availableTools ? options.availableTools : [
        "LineTool",
        "CircleTool",
        "VerticalParabolaTool",
        "HorizontalParabolaTool",
        "FillTool",
        "SolidDashTool"
    ];

    function snapRound(x, snap) {
        return Math.round(Math.round(x / snap) * snap * 100000) / 100000;
    }

    // These are the icons used for the fill tool and fill graph object.
    var fillIcon = "data:image/svg+xml,%3Csvg xmlns:dc='http://purl.org/dc/elements/1.1/' xmlns:cc='http://creativecommons.org/ns%23' xmlns:rdf='http://www.w3.org/1999/02/22-rdf-syntax-ns%23' xmlns:svg='http://www.w3.org/2000/svg' xmlns='http://www.w3.org/2000/svg' id='SVGRoot' version='1.1' viewBox='0 0 32 32' height='32px' width='32px'%3E%3Cdefs id='defs815' /%3E%3Cmetadata id='metadata818'%3E%3Crdf:RDF%3E%3Ccc:Work rdf:about=''%3E%3Cdc:format%3Eimage/svg+xml%3C/dc:format%3E%3Cdc:type rdf:resource='http://purl.org/dc/dcmitype/StillImage' /%3E%3Cdc:title%3E%3C/dc:title%3E%3C/cc:Work%3E%3C/rdf:RDF%3E%3C/metadata%3E%3Cg id='layer1'%3E%3Cpath id='path1382' d='m 13.466084,10.267728 -4.9000003,8.4 4.9000003,4.9 8.4,-4.9 z' style='opacity:1;fill:%23ffffff;fill-opacity:1;stroke:%23000000;stroke-width:1.3;stroke-linecap:butt;stroke-linejoin:miter;stroke-opacity:1;stroke-miterlimit:4;stroke-dasharray:none' /%3E%3Cpath id='path1384' d='M 16.266084,15.780798 V 6.273173' style='fill:none;stroke:%23000000;stroke-width:1.38;stroke-linecap:round;stroke-linejoin:miter;stroke-miterlimit:4;stroke-dasharray:none;stroke-opacity:1' /%3E%3Cpath id='path1405' d='m 20,16 c 0,0 2,-1 3,0 1,0 1,1 2,2 0,1 0,2 0,3 0,1 0,2 0,2 0,0 -1,0 -1,0 -1,-1 -1,-1 -1,-2 0,-1 0,-1 -1,-2 0,-1 0,-2 -1,-2 -1,-1 -2,-1 -1,-1 z' style='fill:%230900ff;fill-opacity:1;stroke:%23000000;stroke-width:0.7px;stroke-linecap:butt;stroke-linejoin:miter;stroke-opacity:1' /%3E%3C/g%3E%3C/svg%3E";

    var fillIconFocused = "data:image/svg+xml,%3Csvg xmlns:dc='http://purl.org/dc/elements/1.1/' xmlns:cc='http://creativecommons.org/ns%23' xmlns:rdf='http://www.w3.org/1999/02/22-rdf-syntax-ns%23' xmlns:svg='http://www.w3.org/2000/svg' xmlns='http://www.w3.org/2000/svg' id='SVGRoot' version='1.1' viewBox='0 0 32 32' height='32px' width='32px'%3E%3Cdefs id='defs815' /%3E%3Cmetadata id='metadata818'%3E%3Crdf:RDF%3E%3Ccc:Work rdf:about=''%3E%3Cdc:format%3Eimage/svg+xml%3C/dc:format%3E%3Cdc:type rdf:resource='http://purl.org/dc/dcmitype/StillImage' /%3E%3Cdc:title%3E%3C/dc:title%3E%3C/cc:Work%3E%3C/rdf:RDF%3E%3C/metadata%3E%3Cg id='layer1'%3E%3Cpath id='path1382' d='m 13.466084,10.267728 -4.9000003,8.4 4.9000003,4.9 8.4,-4.9 z' style='opacity:1;fill:%2300ff00;fill-opacity:1;stroke:%23000000;stroke-width:1.3;stroke-linecap:butt;stroke-linejoin:miter;stroke-opacity:1;stroke-miterlimit:4;stroke-dasharray:none' /%3E%3Cpath id='path1384' d='M 16.266084,15.780798 V 6.273173' style='fill:none;stroke:%23000000;stroke-width:1.38;stroke-linecap:round;stroke-linejoin:miter;stroke-miterlimit:4;stroke-dasharray:none;stroke-opacity:1' /%3E%3Cpath id='path1405' d='m 20,16 c 0,0 2,-1 3,0 1,0 1,1 2,2 0,1 0,2 0,3 0,1 0,2 0,2 0,0 -1,0 -1,0 -1,-1 -1,-1 -1,-2 0,-1 0,-1 -1,-2 0,-1 0,-2 -1,-2 -1,-1 -2,-1 -1,-1 z' style='fill:%230900ff;fill-opacity:1;stroke:%23000000;stroke-width:0.7px;stroke-linecap:butt;stroke-linejoin:miter;stroke-opacity:1' /%3E%3C/g%3E%3C/svg%3E";

    var gt = {}, html_input;
    if ('htmlInputId' in options) html_input = document.getElementById(options.htmlInputId);
    var cfgOptions = {
        showCopyright: false,
        minimizeReflow: "all",
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
        grid: { gridX: snapSizeX, gridY: snapSizeY },
    };

    // Merge options that are set by the problem.
    if ('JSXGraphOptions' in options) $.extend(true, cfgOptions, cfgOptions, options.JSXGraphOptions);

    function setupBoard() {
        gt.board = JXG.JSXGraph.initBoard(containerId + "_graph", cfgOptions);
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
        gt.current_pos_text = gt.board.create('text', [
            function() { return gt.board.getBoundingBox()[2] - 5 / gt.board.unitX; },
            function() { return gt.board.getBoundingBox()[3] + 5 / gt.board.unitY; }, ""],
            { anchorX: 'right', anchorY: 'bottom', fixed: true });
        // Overwrite the popup infobox for points.
        gt.board.highlightInfobox = function (x, y, el) { return gt.board.highlightCustomInfobox('', el); }

        if (!isStatic) {
            gt.board.on('move', function(e) {
                var coords = getMouseCoords(e);
                if (!gt.selectedObj ||
                    Object.keys(gt.selectedObj.definingPts).every(function(point) {
                        if (point == "icon") return true;
                        if (this[point].hasPoint(coords.scrCoords[1], coords.scrCoords[2])) {
                            setTextCoords(this[point].X(), this[point].Y());
                            return false;
                        }
                        return true;
                    }, gt.selectedObj.definingPts)) {
                    if (!("hl_point" in gt.activeTool.hlObjs)) {
                        setTextCoords(coords.usrCoords[1], coords.usrCoords[2]);
                    }
                }

                gt.activeTool.updateHighlights(coords);
            });

            $(document).on('keydown.ToolDeactivate', function(e) {
                if (e.key === 'Escape') gt.tools[0].activate();
            });
        }

        $(window).resize(function(e) {
            if (gt.board.canvasWidth != graphDiv.width() || gt.board.canvasHeight != graphDiv.height())
            {
                gt.board.resizeContainer(graphDiv.width(), graphDiv.height(), true);
                for (var i = 0; i < gt.board.objectsList.length; ++i)
                {
                    if (gt.board.objectsList[i].name === 'FillIcon')
                    {
                        gt.board.objectsList[i].setPosition(JXG.COORDS_BY_USER,
                            [gt.board.objectsList[i].point.X() - 12 / gt.board.unitX,
                                gt.board.objectsList[i].point.Y() - 12 / gt.board.unitY]);
                        gt.board.update();
                    }
                }
            }
        });

        gt.drawSolid = true;
        gt.graphedObjs = [];
        gt.staticObjs = [];
        gt.selectedObj = null;

        gt.board.unsuspendUpdate();
    }

    function setTextCoords(x, y) {
        gt.current_pos_text.setText(
            "(" + snapRound(x, snapSizeX) + ", " + snapRound(y, snapSizeY) + ")"
        );
    };

    function updateText() {
        html_input.value = gt.graphedObjs.reduce(
            function(val, obj) {
                return val + (val.length ? "," : "") + "{" + obj.stringify() + "}";
            }, "");
    }

    function getMouseCoords(e) {
        var i;
        if (e[JXG.touchProperty]) { i = 0; }

        var cPos = gt.board.getCoordsTopLeftCorner(),
            absPos = JXG.getPosition(e, i),
            dx = absPos[0] - cPos[0],
            dy = absPos[1] - cPos[1];

        return new JXG.Coords(JXG.COORDS_BY_SCREEN, [dx, dy], gt.board);
    };

    // Prevent paired points from being moved into the same position.  This
    // prevents lines and circles from being made degenerate.
    function pairedPointDrag(e) {
        if (this.X() == this.paired_point.X() && this.Y() == this.paired_point.Y()) {
            var coords = getMouseCoords(e);
            var x_trans = coords.usrCoords[1] - this.paired_point.X(),
                y_trans = coords.usrCoords[2] - this.paired_point.Y();
            if (y_trans > Math.abs(x_trans))
                this.setPosition(JXG.COORDS_BY_USER, [this.X(), this.Y() + snapSizeY]);
            else if (x_trans > Math.abs(y_trans))
                this.setPosition(JXG.COORDS_BY_USER, [this.X() + snapSizeX, this.Y()]);
            else if (x_trans < -Math.abs(y_trans))
                this.setPosition(JXG.COORDS_BY_USER, [this.X() - snapSizeX, this.Y()]);
            else
                this.setPosition(JXG.COORDS_BY_USER, [this.X(), this.Y() - snapSizeY]);
        }
        updateObjects();
        updateText();
    }

    // Prevent paired points from being moved onto the same horizontal or
    // vertical line.  This prevents parabolas from being made degenerate.
    function pairedPointDragRestricted(e) {
        var coords = getMouseCoords(e);
        var new_x = this.X(), new_y = this.Y();
        if (this.X() == this.paired_point.X())
        {
            if (coords.usrCoords[1] > this.paired_point.X()) new_x += snapSizeX;
            else new_x -= snapSizeX;
        }
        if (this.Y() == this.paired_point.Y())
        {
            if (coords.usrCoords[2] > this.paired_point.Y()) new_y += snapSizeX;
            else new_y -= snapSizeX;
        }
        if (this.X() == this.paired_point.X() || this.Y() == this.paired_point.Y())
            this.setPosition(JXG.COORDS_BY_USER, [new_x, new_y]);
        updateObjects();
        updateText();
    }

    function createPoint(x, y, paired_point, restrict) {
        var point = gt.board.create('point', [x, y],
            { size: 2, snapToGrid: true, snapSizeX: snapSizeX, snapSizeY: snapSizeY, withLabel: false });
        point.on('down', function() { gt.board.containerObj.style.cursor = 'none'; });
        point.on('up', function() { gt.board.containerObj.style.cursor = 'auto'; });
        if (typeof(paired_point) !== 'undefined') {
            point.paired_point = paired_point;
            paired_point.paired_point = point;
            paired_point.on('drag', restrict ? pairedPointDragRestricted : pairedPointDrag);
            point.on('drag', restrict ? pairedPointDragRestricted : pairedPointDrag);
        }
        return point;
    }

    function updateObjects() {
        gt.graphedObjs.forEach(function(obj) { obj.update(); });
        gt.staticObjs.forEach(function(obj) { obj.update(); });
    }

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
    };
    GraphObject.prototype.focus = function() {
        Object.values(this.definingPts).forEach(function(obj) {
            obj.setAttribute({ visible: true });
        });
        gt.drawSolid = this.baseObj.getAttribute('dash') == 0;
        solidButton.prop('disabled', gt.drawSolid);
        dashedButton.prop('disabled', !gt.drawSolid);
    };
    GraphObject.prototype.update = function() { };
    GraphObject.prototype.remove = function() {
        Object.values(this.definingPts).forEach(function(obj) {
            gt.board.removeObject(obj);
        });
        gt.board.removeObject(this.baseObj);
    };
    GraphObject.prototype.setSolid = function(solid) {
        this.baseObj.setAttribute({ dash: solid ? 0 : 2 });
    }
    GraphObject.prototype.stringify = function() { return ""; };
    GraphObject.prototype.id = function() { return this.baseObj.id; };
    GraphObject.prototype.on = function(e, handler, context) { this.baseObj.on(e, handler, context); };
    GraphObject.prototype.off = function(e, handler) { this.baseObj.off(e, handler); };
    GraphObject.restore = function(string) {
        var data = string.match(/^(.*?),(.*)/);
        if (data.length < 3) return false;
        var obj = false;
        switch (data[1]) {
            case 'line': obj = Line.restore(data[2]); break;
            case 'parabola': obj = Parabola.restore(data[2]); break;
            case 'circle': obj = Circle.restore(data[2]); break;
            case 'fill': obj = Fill.restore(data[2]); break;
        }
        if (obj !== false) obj.blur();
        return obj;
    };

    // Line graph object
    function Line(point1, point2, solid) {
        GraphObject.call(this, gt.board.create('line', [point1, point2],
            { fixed: true, highlight: false, dash: solid ? 0 : 2 }));
        this.definingPts.point1 = point1;
        this.definingPts.point2 = point2;
    };
    Line.prototype = Object.create(GraphObject.prototype);
    Object.defineProperty(Line.prototype, 'constructor',
        { value: Line, enumerable: false, writable: true });
    Line.prototype.stringify = function() {
        return "line," + (this.baseObj.getAttribute('dash') == 0 ? 'solid' : 'dashed') +
            ",(" + snapRound(this.definingPts.point1.X(), snapSizeX) + "," +
            snapRound(this.definingPts.point1.Y(), snapSizeY) + ")," +
            "(" + snapRound(this.definingPts.point2.X(), snapSizeX) + "," +
            snapRound(this.definingPts.point2.Y(), snapSizeY) + ")";
    }
    Line.restore = function(string) {
        var pointRegexp = /\((-?[0-9]*(?:\.[0-9]*)?),(-?[0-9]*(?:\.[0-9]*)?)\)/g;
        var pointData;
        var points = [];
        while (pointData = pointRegexp.exec(string))
        { points.push(pointData.slice(1, 3)); }
        if (points.length < 2) return false;
        var point1 = createPoint(parseFloat(points[0][0]), parseFloat(points[0][1]));
        var point2 = createPoint(parseFloat(points[1][0]), parseFloat(points[1][1]), point1);
        return new Line(point1, point2, /solid/.test(string));
    };

    // Circle graph object
    function Circle(center, point, solid) {
        GraphObject.call(this, gt.board.create('circle', [center, point],
            { fixed: true, highlight: false, dash: solid ? 0 : 2 }));
        this.definingPts.center = center;
        this.definingPts.point = point;
    };
    Circle.prototype = Object.create(GraphObject.prototype);
    Object.defineProperty(Circle.prototype, 'constructor',
        { value: Circle, enumerable: false, writable: true });
    Circle.prototype.stringify = function() {
        return "circle," + (this.baseObj.getAttribute('dash') == 0 ? 'solid' : 'dashed') +
            ",(" + snapRound(this.definingPts.center.X(), snapSizeX) + "," +
            snapRound(this.definingPts.center.Y(), snapSizeY) + ")," +
            "(" + snapRound(this.definingPts.point.X(), snapSizeX) + "," +
            snapRound(this.definingPts.point.Y(), snapSizeY) + ")";
    }
    Circle.restore = function(string) {
        var pointRegexp = /\((-?[0-9]*(?:\.[0-9]*)?),(-?[0-9]*(?:\.[0-9]*)?)\)/g;
        var pointData;
        var points = [];
        while (pointData = pointRegexp.exec(string))
        { points.push(pointData.slice(1, 3)); }
        if (points.length < 2) return false;
        var center = createPoint(parseFloat(points[0][0]), parseFloat(points[0][1]));
        var point = createPoint(parseFloat(points[1][0]), parseFloat(points[1][1]), center);
        return new Circle(center, point, /solid/.test(string));
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
        var curveOptions = { strokeWidth: 2, highlight: false, dash: solid ? 0 : 2 };
        if (color !== undefined) curveOptions.strokeColor = color;
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
        ], curveOptions)
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
        ], curveOptions);
    }

    function Parabola(vertex, point, vertical, solid) {
        GraphObject.call(this, createParabola(vertex, point, vertical, solid));
        this.definingPts.vertex = vertex;
        this.definingPts.point = point;
        this.vertical = vertical;
    };
    Parabola.prototype = Object.create(GraphObject.prototype);
    Object.defineProperty(Parabola.prototype, 'constructor',
        { value: Parabola, enumerable: false, writable: true });
    Parabola.prototype.stringify = function() {
        return "parabola," + (this.baseObj.getAttribute('dash') == 0 ? 'solid' : 'dashed') + "," +
            (this.vertical ? 'vertical' : 'horizontal') +
            ",(" + snapRound(this.definingPts.vertex.X(), snapSizeX) + "," +
            snapRound(this.definingPts.vertex.Y(), snapSizeY) + ")," +
            "(" + snapRound(this.definingPts.point.X(), snapSizeX) + "," +
            snapRound(this.definingPts.point.Y(), snapSizeY) + ")";
    }
    Parabola.restore = function(string) {
        var pointRegexp = /\((-?[0-9]*(?:\.[0-9]*)?),(-?[0-9]*(?:\.[0-9]*)?)\)/g;
        var pointData;
        var points = [];
        while (pointData = pointRegexp.exec(string))
        { points.push(pointData.slice(1, 3)); }
        if (points.length < 2) return false;
        var vertex = createPoint(parseFloat(points[0][0]), parseFloat(points[0][1]));
        var point = createPoint(parseFloat(points[1][0]), parseFloat(points[1][1]), vertex, true);
        return new Parabola(vertex, point, /vertical/.test(string), /solid/.test(string));
    };

    // Fill graph object
    function Fill(point) {
        point.setAttribute({ visible: false });
        GraphObject.call(this, point);
        this.focused = true;
        this.definingPts.point = point;
        this.updateTimeout = 0;
        this.update();
        var this_tool = this;
        // The snapToGrid option does not allow centering an image on a point.
        // The following implements a snap to grid method that does allow that.
        this.definingPts.icon = gt.board.create('image',
            [
                function() { return this_tool.focused ? fillIconFocused : fillIcon; },
                [point.X() - 12 / gt.board.unitX, point.Y() - 12 / gt.board.unitY],
                [function() { return 24 / gt.board.unitX; }, function() { return 24 / gt.board.unitY; }]
            ],
            { withLabel: false, highlight: false, layer: 9, name: 'FillIcon' });
        this.definingPts.icon.gtGraphObject = this;
        this.definingPts.icon.point = point;
        this.isStatic = isStatic;
        if (!isStatic)
        {
            this.definingPts.icon.on('down', function() { gt.board.containerObj.style.cursor = 'none'; });
            this.definingPts.icon.on('up', function() { gt.board.containerObj.style.cursor = 'auto'; });
            this.definingPts.icon.on('drag', function(e) {
                var coords = getMouseCoords(e);
                var x = snapRound(coords.usrCoords[1], snapSizeX),
                    y = snapRound(coords.usrCoords[2], snapSizeY);
                this.setPosition(JXG.COORDS_BY_USER,
                    [x - 12 / gt.board.unitX, y - 12 / gt.board.unitY]);
                this.point.setPosition(JXG.COORDS_BY_USER, [x, y]);
                this_tool.update();
                updateText();
            });
        }
    };
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

    function sign(x) {
        x = +x;
        if (Math.abs(x) < JXG.Math.eps) { return 0; }
        return x > 0 ? 1 : -1;
    }
    Fill.prototype.update = function() {
        if (this.isStatic) return;
        if (this.updateTimeout) clearTimeout(this.updateTimeout);
        var this_tool = this;
        this.updateTimeout = setTimeout(function() {
            this_tool.updateTimeout = 0;
            if ('fillObj' in this_tool) {
                gt.board.removeObject(this_tool.fillObj);
                delete this_tool.fillObj;
            }

            var centerPt = this_tool.definingPts.point.coords.usrCoords;
            var allObjects = gt.graphedObjs.concat(gt.staticObjs);

            // Determine which side of each object needs to be shaded.  If the point
            // is on a graphed object, then don't fill.
            var a_vals = Array(allObjects.length);
            for (var i = 0; i < allObjects.length; ++i) {
                switch (allObjects[i].baseObj.elType) {
                    case 'line':
                        a_vals[i] = sign(JXG.Math.innerProduct(centerPt, allObjects[i].baseObj.stdform));
                        break;
                    case 'circle':
                        a_vals[i] = sign(allObjects[i].baseObj.stdform[3] *
                            (centerPt[1] * centerPt[1] + centerPt[2] * centerPt[2])
                            + JXG.Math.innerProduct(centerPt, allObjects[i].baseObj.stdform));
                        break;
                    case 'curve':
                        if (allObjects[i].vertical)
                            a_vals[i] = sign(centerPt[2] - allObjects[i].baseObj.Y(centerPt[1]));
                        else
                            a_vals[i] = sign(centerPt[1] - allObjects[i].baseObj.X(centerPt[2]));
                        break;
                    default:
                        a_vals[i] = 1;
                        break;
                }
                if (a_vals[i] == 0) return;
            }

            var canvas = document.createElement('canvas');
            canvas.width = gt.board.canvasWidth;
            canvas.height = gt.board.canvasHeight;
            var context = canvas.getContext('2d');
            var colorLayerData = context.getImageData(0, 0, canvas.width, canvas.height);

            var fillPixel = function(pixelPos) {
                colorLayerData.data[pixelPos] = 255;
                colorLayerData.data[pixelPos + 1] = 255;
                colorLayerData.data[pixelPos + 2] = 150;
                colorLayerData.data[pixelPos + 3] = 255;
            };

            var isFillPixel = function(x, y) {
                var curPixel = [1.0, (x - gt.board.origin.scrCoords[1]) / gt.board.unitX,
                    (gt.board.origin.scrCoords[2] - y) / gt.board.unitY];
                for (var i = 0; i < allObjects.length; ++i) {
                    switch (allObjects[i].baseObj.elType) {
                        case 'line':
                            if (sign(JXG.Math.innerProduct(curPixel, allObjects[i].baseObj.stdform)) != a_vals[i])
                                return false;
                            break;
                        case 'circle':
                            if (sign(allObjects[i].baseObj.stdform[3] *
                                (curPixel[1] * curPixel[1] + curPixel[2] * curPixel[2])
                                + JXG.Math.innerProduct(curPixel, allObjects[i].baseObj.stdform)) != a_vals[i])
                                return false
                            break;
                        case 'curve':
                            if ((allObjects[i].vertical &&
                                sign(curPixel[2] - allObjects[i].baseObj.Y(curPixel[1])) != a_vals[i]) ||
                                (!allObjects[i].vertical &&
                                    sign(curPixel[1] - allObjects[i].baseObj.X(curPixel[2])) != a_vals[i]))
                                return false;
                            break;
                    }
                }
                return true;
            }

            for (var j = 0; j < canvas.width; ++j) {
                for (var k = 0; k < canvas.height; ++k) {
                    if (isFillPixel(j, k)) fillPixel((k * canvas.width + j) * 4);
                }
            }

            context.putImageData(colorLayerData, 0, 0);
            var dataURL = canvas.toDataURL('image/png');
            canvas.remove();

            var boundingBox = gt.board.getBoundingBox();
            this_tool.fillObj = gt.board.create('image', [
                dataURL,
                [boundingBox[0], boundingBox[3]],
                [boundingBox[2] - boundingBox[0], boundingBox[1] - boundingBox[3]]
            ], { withLabel: false, highlight: false, fixed: true, layer: 0 });

        }, 100);
    };
    Fill.prototype.stringify = function() {
        return "fill" + ",(" + snapRound(this.baseObj.X(), snapSizeX) + "," +
            snapRound(this.baseObj.Y(), snapSizeY) + ")";
    }
    Fill.restore = function(string) {
        var pointRegexp = /\((-?[0-9]*(?:\.[0-9]*)?),(-?[0-9]*(?:\.[0-9]*)?)\)/g;
        var pointData;
        var points = [];
        while (pointData = pointRegexp.exec(string))
        { points.push(pointData.slice(1, 3)); }
        if (!points.length) return false;
        return new Fill(createPoint(parseFloat(points[0][0]), parseFloat(points[0][1])));
    };

    // Generic tool class from which all the graphing tools derive.  Most of
    // the methods, if overridden, must call the corresponding generic method.
    // At this point the updateHighlights method is the only one that this
    // doesn't need to be done with.
    function GenericTool(container, name, tooltip) {
        this.button = $("<button type=button class='btn gt-button gt-tool-button gt-" +
            name + "-tool' data-tooltip='" + tooltip + "'>&nbsp;</button>");
        var this_tool = this;
        this.button.on('click', function () { this_tool.activate(); });
        container.append(this.button);
        this.hlObjs = {};
    };
    GenericTool.prototype.activate = function() {
        gt.activeTool.deactivate();
        gt.activeTool = this;
        this.button.blur();
        this.button.prop('disabled', true);
    };
    GenericTool.prototype.updateHighlights = function(coords) {};
    GenericTool.prototype.removeHighlights = function() {
        Object.keys(this.hlObjs).forEach(function(obj) {
            gt.board.removeObject(this[obj]);
            delete this[obj];
        }, this.hlObjs);
    };
    GenericTool.prototype.deactivate = function() {
        this.button.prop('disabled', false);
        this.removeHighlights();
    };

    // Select tool
    function SelectTool(container) { GenericTool.call(this, container, "select", "Object Selection Tool"); };
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
                var coords = getMouseCoords(e);
                var points = Object.values(gt.selectedObj.definingPts);
                for (var i = 0; i < points.length; ++i)
                {
                    if (points[i].X() == snapRound(coords.usrCoords[1], snapSizeX) &&
                        points[i].Y() == snapRound(coords.usrCoords[2], snapSizeY))
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
        GenericTool.prototype.activate.call(this);
        // If only one object has been graphed, select it.
        if (!initialize && gt.graphedObjs.length == 1) {
            gt.selectedObj = gt.graphedObjs[0];
            gt.selectedObj.focus();
        }
        gt.graphedObjs.forEach(function(obj) { obj.on('down', this.selectionChanged); }, this);
    };
    SelectTool.prototype.deactivate = function() {
        gt.graphedObjs.forEach(function(obj) { obj.off('down', this.selectionChanged); }, this);
        GenericTool.prototype.deactivate.call(this);
    };

    // Line graphing tool
    function LineTool(container) { GenericTool.call(this, container, "line", "Line Tool"); };
    LineTool.prototype = Object.create(GenericTool.prototype);
    Object.defineProperty(LineTool.prototype, 'constructor',
        { value: LineTool, enumerable: false, writable: true });
    LineTool.prototype.updateHighlights = function(coords) {
        if ('hl_line' in this.hlObjs) this.hlObjs.hl_line.setAttribute({ dash: gt.drawSolid ? 0 : 2 });
        if (typeof(coords) === 'undefined') return;
        if (!('hl_point' in this.hlObjs)) {
            this.hlObjs.hl_point = gt.board.create('point', [coords.usrCoords[1], coords.usrCoords[2]], {
                size: 2, color: "orange", fixed: true, snapToGrid: true,
                snapSizeX: snapSizeX, snapSizeY: snapSizeY, withLabel: false
            });
            if ('point1' in this)
                this.hlObjs.hl_line = gt.board.create('line', [this.point1, this.hlObjs.hl_point],
                    { fixed: true, strokeColor: "orange", highlight: false, dash: gt.drawSolid ? 0 : 2 });
        }
        else
            this.hlObjs.hl_point.setPosition(JXG.COORDS_BY_USER, [coords.usrCoords[1], coords.usrCoords[2]]);

        setTextCoords(this.hlObjs.hl_point.X(), this.hlObjs.hl_point.Y());
        gt.board.update();
    };
    LineTool.prototype.deactivate = function() {
        gt.board.off('up');
        if ('point1' in this) gt.board.removeObject(this.point1);
        delete this.point1;
        gt.board.containerObj.style.cursor = 'auto';
        GenericTool.prototype.deactivate.call(this);
    }
    LineTool.prototype.activate = function() {
        GenericTool.prototype.activate.call(this);
        if (gt.selectedObj) { gt.selectedObj.blur(); }
        gt.selectedObj = null;
        gt.board.containerObj.style.cursor = 'none';
        var this_tool = this;
        gt.board.on('up', function(e) {
            var coords = getMouseCoords(e);
            // Don't allow the point to be created off the board.
            if (!gt.board.hasPoint(coords.usrCoords[1], coords.usrCoords[2])) return;
            gt.board.off('up');
            this_tool.point1 = gt.board.create('point', [coords.usrCoords[1], coords.usrCoords[2]],
                { size: 2, snapToGrid: true, snapSizeX: snapSizeX, snapSizeY: snapSizeY, withLabel: false });
            this_tool.point1.setAttribute({ fixed: true });
            this_tool.removeHighlights();

            gt.board.on('up', function(e) {
                var coords = getMouseCoords(e);

                // Don't allow the second point to be created on top of the first or off the board
                if ((this_tool.point1.X() == snapRound(coords.usrCoords[1], snapSizeX) &&
                    this_tool.point1.Y() == snapRound(coords.usrCoords[2], snapSizeY)) ||
                    !gt.board.hasPoint(coords.usrCoords[1], coords.usrCoords[2]))
                    return;
                gt.board.off('up');

                this_tool.point1.setAttribute({ fixed: false });
                this_tool.point1.on('down', function() { gt.board.containerObj.style.cursor = 'none'; });
                this_tool.point1.on('up', function() { gt.board.containerObj.style.cursor = 'auto'; });

                gt.selectedObj = new Line(this_tool.point1,
                    createPoint(coords.usrCoords[1], coords.usrCoords[2], this_tool.point1),
                    gt.drawSolid);
                gt.graphedObjs.push(gt.selectedObj);
                delete this_tool.point1;

                updateObjects();
                updateText();
                gt.board.update();
                gt.tools[0].activate();
            });

            gt.board.update();
        });
    };

    // Circle graphing tool
    function CircleTool(container) { GenericTool.call(this, container, "circle", "Circle Tool"); };
    CircleTool.prototype = Object.create(GenericTool.prototype);
    Object.defineProperty(CircleTool.prototype, 'constructor',
        { value: CircleTool, enumerable: false, writable: true });
    CircleTool.prototype.updateHighlights = function(coords) {
        if ('hl_circle' in this.hlObjs) this.hlObjs.hl_circle.setAttribute({ dash: gt.drawSolid ? 0 : 2 });
        if (typeof(coords) === 'undefined') return;
        if (!('hl_point' in this.hlObjs)) {
            this.hlObjs.hl_point = gt.board.create('point', [coords.usrCoords[1], coords.usrCoords[2]], {
                size: 2, color: "orange", fixed: true, snapToGrid: true,
                snapSizeX: snapSizeX, snapSizeY: snapSizeY, withLabel: false
            });
            if ('center' in this)
                this.hlObjs.hl_circle = gt.board.create('circle', [this.center, this.hlObjs.hl_point],
                    { fixed: true, strokeColor: "orange", highlight: false, dash: gt.drawSolid ? 0 : 2 });
        }
        else
            this.hlObjs.hl_point.setPosition(JXG.COORDS_BY_USER, [coords.usrCoords[1], coords.usrCoords[2]]);

        setTextCoords(this.hlObjs.hl_point.X(), this.hlObjs.hl_point.Y());
        gt.board.update();
    };
    CircleTool.prototype.deactivate = function() {
        gt.board.off('up');
        if ('center' in this) gt.board.removeObject(this.center);
        delete this.center;
        gt.board.containerObj.style.cursor = 'auto';
        GenericTool.prototype.deactivate.call(this);
    }
    CircleTool.prototype.activate = function() {
        GenericTool.prototype.activate.call(this);
        if (gt.selectedObj) { gt.selectedObj.blur(); }
        gt.selectedObj = null;
        gt.board.containerObj.style.cursor = 'none';
        var this_tool = this;
        gt.board.on('up', function(e) {
            var coords = getMouseCoords(e);
            // Don't allow the point to be created off the board.
            if (!gt.board.hasPoint(coords.usrCoords[1], coords.usrCoords[2])) return;
            gt.board.off('up');
            this_tool.center = gt.board.create('point', [coords.usrCoords[1], coords.usrCoords[2]],
                { size: 2, snapToGrid: true, snapSizeX: snapSizeX, snapSizeY: snapSizeY, withLabel: false });
            this_tool.center.setAttribute({ fixed: true });
            this_tool.removeHighlights();

            gt.board.on('up', function(e) {
                var coords = getMouseCoords(e);

                // Don't allow the second point to be created on top of the center or off the board
                if ((this_tool.center.X() == snapRound(coords.usrCoords[1], snapSizeX) &&
                    this_tool.center.Y() == snapRound(coords.usrCoords[2], snapSizeY)) ||
                    !gt.board.hasPoint(coords.usrCoords[1], coords.usrCoords[2]))
                    return;
                gt.board.off('up');

                this_tool.center.setAttribute({ fixed: false });
                this_tool.center.on('down', function() { gt.board.containerObj.style.cursor = 'none'; });
                this_tool.center.on('up', function() { gt.board.containerObj.style.cursor = 'auto'; });

                gt.selectedObj = new Circle(this_tool.center,
                    createPoint(coords.usrCoords[1], coords.usrCoords[2], this_tool.center),
                    gt.drawSolid);
                gt.graphedObjs.push(gt.selectedObj);
                delete this_tool.center;

                updateObjects();
                updateText();
                gt.board.update();
                gt.tools[0].activate();
            });

            gt.board.update();
        });
    };

    // Parabola graphing tool
    function ParabolaTool(container, vertical) {
        GenericTool.call(this, container,
            vertical ? "vertical-parabola" : "horizontal-parabola",
            vertical ? "Vertical Parabola Tool" : "Horizontal Parabola Tool");
        this.vertical = vertical;
    };
    ParabolaTool.prototype = Object.create(GenericTool.prototype);
    Object.defineProperty(ParabolaTool.prototype, 'constructor',
        { value: ParabolaTool, enumerable: false, writable: true });
    ParabolaTool.prototype.updateHighlights = function(coords) {
        if ('hl_parabola' in this.hlObjs) this.hlObjs.hl_parabola.setAttribute({ dash: gt.drawSolid ? 0 : 2 });
        if (typeof(coords) === 'undefined') return;
        if (!('hl_point' in this.hlObjs)) {
            this.hlObjs.hl_point = gt.board.create('point', [coords.usrCoords[1], coords.usrCoords[2]], {
                size: 2, color: "orange", fixed: true, snapToGrid: true,
                snapSizeX: snapSizeX, snapSizeY: snapSizeY,
                highlight: false, withLabel: false
            });
            if ('vertex' in this)
                this.hlObjs.hl_parabola =
                    createParabola(this.vertex, this.hlObjs.hl_point, this.vertical, gt.drawSolid, 'orange');
        }
        else
            this.hlObjs.hl_point.setPosition(JXG.COORDS_BY_USER, [coords.usrCoords[1], coords.usrCoords[2]]);

        setTextCoords(this.hlObjs.hl_point.X(), this.hlObjs.hl_point.Y());
        gt.board.update();
    };
    ParabolaTool.prototype.deactivate = function() {
        gt.board.off('up');
        if ('vertex' in this) gt.board.removeObject(this.vertex);
        delete this.vertex;
        gt.board.containerObj.style.cursor = 'auto';
        GenericTool.prototype.deactivate.call(this);
    }
    ParabolaTool.prototype.activate = function() {
        GenericTool.prototype.activate.call(this);
        if (gt.selectedObj) { gt.selectedObj.blur(); }
        gt.selectedObj = null;
        gt.board.containerObj.style.cursor = 'none';
        var this_tool = this;
        gt.board.on('up', function(e) {
            var coords = getMouseCoords(e);
            // Don't allow the point to be created off the board.
            if (!gt.board.hasPoint(coords.usrCoords[1], coords.usrCoords[2])) return;
            gt.board.off('up');
            this_tool.vertex = gt.board.create('point', [coords.usrCoords[1], coords.usrCoords[2]],
                { size: 2, snapToGrid: true, snapSizeX: snapSizeX, snapSizeY: snapSizeY, withLabel: false });
            this_tool.vertex.setAttribute({ fixed: true });
            this_tool.removeHighlights();

            gt.board.on('up', function(e) {
                var coords = getMouseCoords(e);

                // Don't allow the second point to be created on the same
                // horizontal or vertical line as the vertex or off the board.
                if ((this_tool.vertex.X() == snapRound(coords.usrCoords[1], snapSizeX) ||
                    this_tool.vertex.Y() == snapRound(coords.usrCoords[2], snapSizeY)) ||
                    !gt.board.hasPoint(coords.usrCoords[1], coords.usrCoords[2]))
                    return;

                gt.board.off('up');

                this_tool.vertex.setAttribute({ fixed: false });
                this_tool.vertex.on('down', function() { gt.board.containerObj.style.cursor = 'none'; });
                this_tool.vertex.on('up', function() { gt.board.containerObj.style.cursor = 'auto'; });

                gt.selectedObj = new Parabola(this_tool.vertex,
                    createPoint(coords.usrCoords[1], coords.usrCoords[2], this_tool.vertex, true),
                    this_tool.vertical, gt.drawSolid);
                gt.graphedObjs.push(gt.selectedObj);
                delete this_tool.vertex;

                updateObjects();
                updateText();
                gt.board.update();
                gt.tools[0].activate();
            });

            gt.board.update();
        });
    };

    // Fill tool
    function FillTool(container) { GenericTool.call(this, container, "fill", "Region Shading Tool"); };
    FillTool.prototype = Object.create(GenericTool.prototype);
    Object.defineProperty(FillTool.prototype, 'constructor',
        { value: FillTool, enumerable: false, writable: true });
    FillTool.prototype.updateHighlights = function(coords) {
        if (typeof(coords) === 'undefined') return;
        if (!('hl_point' in this.hlObjs)) {
            this.hlObjs.hl_point = gt.board.create('image', [fillIcon, [
                    snapRound(coords.usrCoords[1], snapSizeX) - 12 / gt.board.unitX,
                    snapRound(coords.usrCoords[2], snapSizeY) - 12 / gt.board.unitY
                ], [24 / gt.board.unitX, 24 / gt.board.unitY]
            ], { withLabel: false, highlight: false, layer: 9 });
        }
        else
            this.hlObjs.hl_point.setPosition(JXG.COORDS_BY_USER, [
                snapRound(coords.usrCoords[1], snapSizeX) - 12 / gt.board.unitX,
                snapRound(coords.usrCoords[2], snapSizeY) - 12 / gt.board.unitY
            ]);

        setTextCoords(coords.usrCoords[1], coords.usrCoords[2]);
        gt.board.update();
    };
    FillTool.prototype.deactivate = function() {
        gt.board.off('up');
        gt.board.containerObj.style.cursor = 'auto';
        GenericTool.prototype.deactivate.call(this);
    }
    FillTool.prototype.activate = function() {
        GenericTool.prototype.activate.call(this);
        if (gt.selectedObj) { gt.selectedObj.blur(); }
        gt.selectedObj = null;
        gt.board.containerObj.style.cursor = 'none';
        gt.board.on('up', function(e) {
            gt.board.off('up');
            var coords = getMouseCoords(e);

            // Don't allow the fill to be created off the board
            if (!gt.board.hasPoint(coords.usrCoords[1], coords.usrCoords[2])) return;
            gt.board.off('up');

            gt.selectedObj = new Fill(createPoint(coords.usrCoords[1], coords.usrCoords[2]));
            gt.graphedObjs.push(gt.selectedObj);

            updateText();
            gt.board.update();
            gt.tools[0].activate();
        });
    };

    // Draw objects solid or dashed. Makes the currently selected object (if
    // any) solid or dashed, and anything drawn while the tool is selected will
    // be drawn solid or dashed.
    function toggleSolidity(e) {
        this.blur();
        solidButton.prop('disabled', e.data.solid);
        dashedButton.prop('disabled', !e.data.solid);
        if (gt.selectedObj)
        {
            gt.selectedObj.setSolid(e.data.solid);
            updateText();
        }
        gt.drawSolid = e.data.solid;
        gt.activeTool.updateHighlights();
    }

    // Delete the selected object.
    function deleteObject() {
        this.blur();
        if (!gt.selectedObj) return;

        $("<div>Do you want to delete the selected object?</div>").dialog({
            title: "Delete Selected Object", width: 'auto', height: 'auto',
            modal: true, resizable: false,
            buttons: {
                Yes: function() {
                    for (var i = 0; i < gt.graphedObjs.length; ++i) {
                        if (gt.graphedObjs[i].id() === gt.selectedObj.id()) {
                            gt.graphedObjs[i].remove();
                            gt.graphedObjs.splice(i, 1);
                            break;
                        }
                    }
                    gt.selectedObj = null;
                    updateObjects();
                    updateText();
                    $(this).dialog("close");
                },
                No: function() { $(this).dialog("close"); }
            },
            close: function() { $(this).remove(); }
        });
    }

    // Remove all graphed objects.
    function clearGraph() {
        this.blur();
        if (gt.graphedObjs.length == 0) return;

        $("<div>Do you want to remove all graphed objects?</div>").dialog({
            title: "Clear Graph", width: 'auto', height: 'auto',
            modal: true, resizable: false,
            buttons: {
                Yes: function() {
                    gt.graphedObjs.forEach(function(obj) { obj.remove(); });
                    gt.graphedObjs = [];
                    gt.selectedObj = null;
                    gt.tools[0].activate();
                    html_input.value = "";
                    $(this).dialog("close");
                },
                No: function() { $(this).dialog("close"); }
            },
            close: function() { $(this).remove(); }
        });
    }

    gt.tools = [];

    // Create the tools and html elements.
    var graphContainer = $('#' + containerId);
    var graphDiv = $("<div id='" + containerId + "_graph' class='jxgbox graphtool-graph'></div>");
    graphContainer.append(graphDiv);

    if (!isStatic)
    {
        var buttonBox = $("<div class='gt-toolbar-container'></div>");
        gt.tools.push(new SelectTool(buttonBox));
        if (availableTools.indexOf('LineTool') > -1)
            gt.tools.push(new LineTool(buttonBox));
        if (availableTools.indexOf('CircleTool') > -1)
            gt.tools.push(new CircleTool(buttonBox));
        if (availableTools.indexOf('VerticalParabolaTool') > -1)
            gt.tools.push(new ParabolaTool(buttonBox, true));
        if (availableTools.indexOf('HorizontalParabolaTool') > -1)
            gt.tools.push(new ParabolaTool(buttonBox, false));
        if (availableTools.indexOf('FillTool') > -1)
            gt.tools.push(new FillTool(buttonBox, false));

        var solidDashBox = $("<div class='gt-solid-dash-box'></div>");
        // The draw solid button is active by default.
        var solidButton =
            $("<button type=button class='btn gt-button gt-tool-button gt-solid-tool' " +
                "data-tooltip='Make Selected Object Solid' disabled>&nbsp;</button>")
            .on('click', { solid: true }, toggleSolidity);
        solidDashBox.append(solidButton);
        var dashedButton =
            $("<button type=button class='btn gt-button gt-tool-button gt-dashed-tool' " +
                "data-tooltip='Make Selected Object Dashed'>&nbsp;</button>")
            .on('click', { solid: false }, toggleSolidity);
        solidDashBox.append(dashedButton);
        if (availableTools.indexOf("SolidDashTool") > -1)
            buttonBox.append(solidDashBox);

        buttonBox.append($("<button type=button class='btn gt-button' " +
            "data-tooltip='Delete Selected Object'>Delete</button>")
            .on('click', deleteObject));
        buttonBox.append($("<button type=button class='btn gt-button' " +
            "data-tooltip='Clear All Objects From Graph'>Clear</button>")
            .on('click', clearGraph));

        graphContainer.append(buttonBox);

        // Avoid conflicts with bootstrap.
        $.widget.bridge('uitooltip', $.ui.tooltip);

        $(".gt-button").uitooltip({
            items: "[data-tooltip]",
            position: {my: "center top", at: "center bottom+5px"},
            show: {delay: 1000, effect: "none"},
            hide: {delay: 0, effect: "none"},
            content: function() {
                var element = $(this);
                if (element.is("[data-tooltip]")) { return element.attr("data-tooltip"); }
            }
        });
    }

    setupBoard();

    // Restore data from previous attempts if available
    function restoreObjects(data, objectsAreStatic) {
        gt.board.suspendUpdate();
        var tmpIsStatic = isStatic;
        isStatic = objectsAreStatic;
        var objectRegexp = /{(.*?)}/g;
        var objectData;
        while (objectData = objectRegexp.exec(data)) {
            var obj = GraphObject.restore(objectData[1]);
            if (obj !== false)
            {
                if (objectsAreStatic) gt.staticObjs.push(obj)
                else gt.graphedObjs.push(obj);
            }
        }
        isStatic = tmpIsStatic;
        updateObjects();
        gt.board.unsuspendUpdate();
    }
    if (html_input) restoreObjects(html_input.value, false);
    if ('staticObjects' in options && typeof(options.staticObjects) === 'string' && options.staticObjects.length)
        restoreObjects(options.staticObjects, true);
    if (!isStatic)
    {
        updateText();
        gt.activeTool = gt.tools[0];
        gt.activeTool.activate(true);
    }
}
