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
        "util":                 "/webwork2_files/js/lib/util",
        "stickit":              "/webwork2_files/js/components/backbone.stickit/backbone.stickit",
        "imagesloaded":         "/webwork2_files/js/components/imagesloaded/imagesloaded",
        "jquery-truncate":      "/webwork2_files/js/components/jquery-truncate/jquery.truncate",
        "eventie":              "/webwork2_files/js/components/eventie/eventie",
        "eventEmitter":         "/webwork2_files/js/components/eventEmitter/EventEmitter",
        
        "WebPage":              "/webwork2_files/js/lib/views/WebPage",
        "config":               "/webwork2_files/js/apps/config",
        "Closeable":            "/webwork2_files/js/lib/views/Closeable",
        
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
        //'jquery-tablesorter': ['jquery'],
        'imagesloaded': { deps: ['eventie','eventEmitter'], exports: 'imagesloaded'}
    }
};
