/*  This is the configuration for the require.js loading.  See requirejs.org for more info. 

  It should be loaded directly before the require.js is loaded in a page.  */

var require = {
    paths: {
        "Backbone":             "/webwork2_files/js/vendor/backbone/backbone",
        "backbone-validation":  "/webwork2_files/js/vendor/backbone/modules/backbone-validation",
        "jquery-ui":            "/webwork2_files/js/vendor/jquery/jquery-ui",
        "underscore":           "/webwork2_files/js/vendor/underscore/underscore",
        "jquery":               "/webwork2_files/js/vendor/jquery/jquery",
        "bootstrap":            "/webwork2_files/js/vendor/bootstrap/js/bootstrap",
        "util":                 "/webwork2_files/js/lib/util",
        "XDate":                "/webwork2_files/js/vendor/other/xdate",
        "WebPage":              "/webwork2_files/js/lib/views/WebPage",
        "config":               "/webwork2_files/js/apps/config",
        "Closeable":            "/webwork2_files/js/lib/views/Closeable",
        "stickit": 				"/webwork2_files/js/vendor/backbone/modules/backbone-stickit/backbone.stickit",
        "datepicker":           "/webwork2_files/js/vendor/datepicker/js/bootstrap-datepicker",
        "jquery-truncate":      "/webwork2_files/js/vendor/jquery/modules/jquery.truncate.min",
        "jquery-tablesorter":   "/webwork2_files/js/vendor/jquery/modules/jquery.tablesorter.min",
        "jquery-imagesloaded":  '/webwork2_files/js/vendor/jquery/modules/jquery.imagesloaded.min'

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
        'XDate':{ exports: 'XDate'},
        'config': {deps: ['XDate'], exports: 'config'},
        'stickit': ["Backbone","jquery"],
        'datepicker': ['bootstrap'],
        'jquery-truncate': ['jquery'],
        'jquery-tablesorter': ['jquery'],
        'jquery-imagesloaded': { deps: ['jquery'], exports: 'jquery-imagesloaded'}
    }
};
