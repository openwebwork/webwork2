
// #Library Browser 3
//
// This is the current iteration of the library browser for webwork.
// It's built out of models contained in the `webwork.*` framework that
// you can find in the `js/lib` folder.
//
// The idea was to use this as a proof of concept of how to write single page
// webapps for webwork out of a general client side framework quickly, easily
// and in a way that's maintainable.
//
// The javascript framework is currently written with extensibility in mind.
// So base models in the webwork.js file are added too and additional models are
// provided for different situations.  For instance since library browser is used
// by teachers we include the files in the `teacher` subdirectory and add in features
// like adding and remove problems from a sets ProblemList and browsing a Library.

//require config
require.config({
    //baseUrl: "/webwork2_files/js/",
    paths: {
        "Backbone": "/webwork2_files/js/vendor/backbone/backbone",  //ok
        "underscore": "/webwork2_files/js/vendor/underscore/underscore", // ok
        "jquery": "/webwork2_files/js/vendor/jquery/jquery", // ok
        "jquery-ui": "/webwork2_files/js/legacy/jquery-ui-1.8.16.custom.min", //FIXMEJS
        "touch-pinch": "/webwork2_files/js/vendor/jquery/modules/jquery.ui.touch-punch", //ok
        "tabs": "/webwork2_files/js/vendor/jquery/modules/ui.tabs.closable", //ok
        //this is important:
        "config":"/webwork2_files/js/apps/LibraryBrowser/config", // ok
    },
    //urlArgs: "bust=" +  (new Date()).getTime(),
    waitSeconds: 15,
    shim: {
        //ui specific shims:
        'jquery-ui': ['jquery'],
        'touch-pinch': ['jquery'],
        'tabs': ['jquery-ui', 'jquery'],

        //required shims
        'underscore': {
            exports: '_'
        },
        'backbone': {
            //These script dependencies should be loaded before loading
            //backbone.js
            deps: ['underscore', 'jquery'],
            //Once loaded, use the global 'Backbone' as the
            //module value.
            exports: 'Backbone'
        }

        
    }
});

//Start things off by wrapping everything in requirejs
require(['LibraryBrowser', 'jquery-ui', 'touch-pinch', 'tabs'], function(LibraryBrowser){    

    //instantiate an instance of our app.
    var App = new LibraryBrowser({el: "#app_box"});

});
