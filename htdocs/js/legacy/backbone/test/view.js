$(document).ready(function() {

  var view;

  module("Backbone.View", {

    setup: function() {
      view = new Backbone.View({
        id        : 'test-view',
        className : 'test-view'
      });
    }

  });

  test("View: constructor", function() {
    equal(view.el.id, 'test-view');
    equal(view.el.className, 'test-view');
    equal(view.options.id, 'test-view');
    equal(view.options.className, 'test-view');
  });

  test("View: jQuery", function() {
    view.setElement(document.body);
    ok(view.$('#qunit-header a').get(0).innerHTML.match(/Backbone Test Suite/));
    ok(view.$('#qunit-header a').get(1).innerHTML.match(/Backbone Speed Suite/));
  });

  test("View: make", function() {
    var div = view.make('div', {id: 'test-div'}, "one two three");
    equal(div.tagName.toLowerCase(), 'div');
    equal(div.id, 'test-div');
    equal($(div).text(), 'one two three');
  });

  test("View: make can take falsy values for content", function() {
    var div = view.make('div', {id: 'test-div'}, 0);
    equal($(div).text(), '0');

    var div = view.make('div', {id: 'test-div'}, '');
    equal($(div).text(), '');
  });

  test("View: initialize", function() {
    var View = Backbone.View.extend({
      initialize: function() {
        this.one = 1;
      }
    });
    var view = new View;
    equal(view.one, 1);
  });

  test("View: delegateEvents", function() {
    var counter = 0;
    var counter2 = 0;
    view.setElement(document.body);
    view.increment = function(){ counter++; };
    view.$el.bind('click', function(){ counter2++; });
    var events = {"click #qunit-banner": "increment"};
    view.delegateEvents(events);
    $('#qunit-banner').trigger('click');
    equal(counter, 1);
    equal(counter2, 1);
    $('#qunit-banner').trigger('click');
    equal(counter, 2);
    equal(counter2, 2);
    view.delegateEvents(events);
    $('#qunit-banner').trigger('click');
    equal(counter, 3);
    equal(counter2, 3);
  });

  test("View: delegateEvents allows functions for callbacks", function() {
    view.counter = 0;
    view.setElement("#qunit-banner");
    var events = {"click": function() { this.counter++; }};
    view.delegateEvents(events);
    $('#qunit-banner').trigger('click');
    equal(view.counter, 1);
    $('#qunit-banner').trigger('click');
    equal(view.counter, 2);
    view.delegateEvents(events);
    $('#qunit-banner').trigger('click');
    equal(view.counter, 3);
  });

  test("View: undelegateEvents", function() {
    var counter = 0;
    var counter2 = 0;
    view.setElement(document.body);
    view.increment = function(){ counter++; };
    $(view.el).unbind('click');
    $(view.el).bind('click', function(){ counter2++; });
    var events = {"click #qunit-userAgent": "increment"};
    view.delegateEvents(events);
    $('#qunit-userAgent').trigger('click');
    equal(counter, 1);
    equal(counter2, 1);
    view.undelegateEvents();
    $('#qunit-userAgent').trigger('click');
    equal(counter, 1);
    equal(counter2, 2);
    view.delegateEvents(events);
    $('#qunit-userAgent').trigger('click');
    equal(counter, 2);
    equal(counter2, 3);
  });

  test("View: _ensureElement with DOM node el", function() {
    var ViewClass = Backbone.View.extend({
      el: document.body
    });
    var view = new ViewClass;
    equal(view.el, document.body);
  });

  test("View: _ensureElement with string el", function() {
    var ViewClass = Backbone.View.extend({
      el: "body"
    });
    var view = new ViewClass;
    equal(view.el, document.body);

    ViewClass = Backbone.View.extend({
      el: "body > h2"
    });
    view = new ViewClass;
    equal(view.el, $("#qunit-banner").get(0));

    ViewClass = Backbone.View.extend({
      el: "#nonexistent"
    });
    view = new ViewClass;
    ok(!view.el);
  });

  test("View: with attributes", function() {
    var view = new Backbone.View({attributes : {'class': 'one', id: 'two'}});
    equal(view.el.className, 'one');
    equal(view.el.id, 'two');
  });

  test("View: with attributes as a function", function() {
    var viewClass = Backbone.View.extend({
      attributes: function() {
        return {'class': 'dynamic'};
      }
    });
    equal((new viewClass).el.className, 'dynamic');
  });

  test("View: multiple views per element", function() {
    var count = 0, ViewClass = Backbone.View.extend({
      el: $("body"),
      events: {
        "click": "click"
      },
      click: function() {
        count++;
      }
    });

    var view1 = new ViewClass;
    $("body").trigger("click");
    equal(1, count);

    var view2 = new ViewClass;
    $("body").trigger("click");
    equal(3, count);

    view1.delegateEvents();
    $("body").trigger("click");
    equal(5, count);
  });

  test("View: custom events, with namespaces", function() {
    var count = 0;
    var ViewClass = Backbone.View.extend({
      el: $('body'),
      events: function() {
        return {"fake$event.namespaced": "run"};
      },
      run: function() {
        count++;
      }
    });

    var view = new ViewClass;
    $('body').trigger('fake$event').trigger('fake$event');
    equal(count, 2);
    $('body').unbind('.namespaced');
    $('body').trigger('fake$event');
    equal(count, 2);
  });

  test("#1048 - setElement uses provided object.", function() {
    var $el = $('body');
    var view = new Backbone.View({el: $el});
    ok(view.$el === $el);
    view.setElement($el = $($el));
    ok(view.$el === $el);
  });

  test("#986 - Undelegate before changing element.", 1, function() {
    var a = $('<button></button>');
    var b = $('<button></button>');
    var View = Backbone.View.extend({
      events: {click: function(e) { ok(view.el === e.target); }}
    });
    var view = new View({el: a});
    view.setElement(b);
    a.trigger('click');
    b.trigger('click');
  });

});
