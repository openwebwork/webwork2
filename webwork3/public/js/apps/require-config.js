/*  This is the configuration for the require.js loading.  See requirejs.org for more info. 

  It should be loaded directly before the require.js is loaded in a page.  */

var require = {
    paths: {
        "backbone":             "/webwork3/js/bower_components/backbone/backbone", // backbone.stickit requires a lower-case "b"
        "backbone-validation":  "/webwork3/js/bower_components/backbone-validation/dist/backbone-validation",
        "jquery-ui":            "/webwork3/js/bower_components/jquery-ui/ui/jquery-ui",
        "underscore":           "/webwork3/js/bower_components/underscore/underscore",
        "jquery":               "/webwork3/js/bower_components/jquery/jquery",
        "bootstrap":            "/webwork3/js/bower_components/bootstrap/dist/js/bootstrap",
        //"bootstrap":            "/webwork3/js/bower_components/bootstrap-2/docs/assets/js/bootstrap",
        "moment":               "/webwork3/js/bower_components/moment/moment",
        "stickit":              "/webwork3/js/bower_components/backbone.stickit/backbone.stickit",
        "imagesloaded":         "/webwork3/js/bower_components/imagesloaded/imagesloaded",
        "jquery-truncate":      "/webwork3/js/bower_components/jquery-truncate/jquery.truncate",
        "editablegrid":         "/webwork3/js/bower_components/editablegrid/editablegrid-2.0.1",
        "blob":                 "/webwork3/js/bower_components/blob/Blob",
        "file-saver":           "/webwork3/js/bower_components/file-saver/FileSaver",
        "eventie":              "/webwork3/js/bower_components/eventie",
        "eventEmitter":         "/webwork3/js/bower_components/eventEmitter",
        "knowl":                "/webwork2_files/js/vendor/other/knowl",
        "views":                "/webwork3/js/views",
        "models":               "/webwork3/js/models",
        "apps":                 "/webwork3/js/apps",
        "config":               "/webwork3/js/apps/config"
    },
    //urlArgs: "bust=" +  (new Date()).getTime(),
    waitSeconds: 10,
    shim: {
        'jquery-ui': ['jquery'],
        'jquery-ui-custom': ['jquery'],
        'underscore': { exports: '_' },
        'backbone': { deps: ['underscore', 'jquery'], exports: 'backbone'},
        'bootstrap':['jquery','jquery-ui'], // saying that bootstrap requires jquery-ui makes bootstrap (javascript) buttons work.
        'backbone-validation': ['backbone'],
        'moment': {exports: 'moment'},
        'config': {deps: ['moment','backbone-validation'], exports: 'config'},
        'stickit': ["backbone","jquery"],
        'datepicker': ['bootstrap'],
        'jquery-truncate': ['jquery'],
        'editablegrid': {deps: ['jquery'], exports: 'EditableGrid'},
        'blob': {exports : 'Blob'},
        //'eventie' : {exports :'Eventie'},
        //'eventEmitter': {exports: 'EventEmitter'},
        //'jquery-tablesorter': ['jquery'],
        'imagesloaded': ['jquery'],
        'knowl': ['jquery']
    }
};