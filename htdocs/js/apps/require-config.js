/*  This is the configuration for the require.js loading.  See requirejs.org for more info. 

  It should be loaded directly before the require.js is loaded in a page.  */

var require = {
    paths: {
        "Backbone":             "/webwork2_files/js/components/backbone/backbone",
        "backbone-validation":  "/webwork2_files/js/components/backbone-validation/dist/backbone-validation",
        "jquery-ui":            "/webwork2_files/js/components/jquery-ui/ui/jquery-ui",
        "underscore":           "/webwork2_files/js/components/underscore/underscore",
        "jquery":               "/webwork2_files/js/components/jquery/jquery",
        "bootstrap":            "/webwork2_files/js/components/bootstrap/docs/assets/js/bootstrap",
        "moment":               "/webwork2_files/js/components/moment/moment",
        "stickit":              "/webwork2_files/js/components/backbone.stickit/backbone.stickit",
        "imagesloaded":         "/webwork2_files/js/components/imagesloaded/imagesloaded",
        "jquery-truncate":      "/webwork2_files/js/components/jquery-truncate/jquery.truncate",
        "eventie":              "/webwork2_files/js/components/eventie/eventie",
        "eventEmitter":         "/webwork2_files/js/components/eventEmitter/EventEmitter",
        "editablegrid":         "/webwork2_files/js/components/editablegrid/editablegrid-2.0.1/editablegrid-2.0.1",
        "blob":                 "/webwork2_files/js/components/blob/Blob",
        "blob-builder":         "/webwork2_files/js/components/blob/BlobBuilder",
        "file-saver":           "/webwork2_files/js/components/file-saver/FileSaver",

        "WebPage":              "/webwork2_files/js/lib/views/WebPage",
        "config":               "/webwork2_files/js/apps/config",
        "Closeable":            "/webwork2_files/js/lib/views/Closeable",
        "globals":              "/webwork2_files/js/apps/globals",
        "globalVariables":      "/webwork2_files/js/apps/globalVariables",
        "util":                 "/webwork2_files/js/lib/util",
        
    },
    urlArgs: "bust=" +  (new Date()).getTime(),
    waitSeconds: 15,
     shim: {
        'jquery-ui': ['jquery'],
        'jquery-ui-custom': ['jquery'],
        'underscore': { exports: '_' },
        'Backbone': { deps: ['underscore', 'jquery'], exports: 'Backbone'},
        'bootstrap':['jquery'],
        'backbone-validation': ['Backbone'],
        'moment': {exports: 'moment'},
        'config': {deps: ['moment'], exports: 'config'},
        'stickit': ["Backbone","jquery"],
        'datepicker': ['bootstrap'],
        'jquery-truncate': ['jquery'],
        'editablegrid': {deps: ['jquery'], exports: 'EditableGrid'},
        'blob': {exports : 'Blob'},
        'blob-builder': {exports: 'BlobBuilder'},
        //'jquery-tablesorter': ['jquery'],
        'imagesloaded': { deps: ['eventie','eventEmitter'], exports: 'imagesloaded'}
    }
};
