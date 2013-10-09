$(document).ready(function() {

  module("view.unstickit");

  test('unstickit', function() {
    
    model.set({'water':'fountain', 'test':'nada', 'copy':'cat', 'fickle':'brat'});
    view.model = model;
    view.templateId = 'jst10';
    view.bindings = {
      '.test10': {
        observe: 'water',
        attributes: [{
          name: 'class',
          observe: 'copy'
        }, {
          name: 'data-test',
          observe: 'fickle'
        }]
      }
    };
    $('#qunit-fixture').html(view.render().el);

    equal(_.keys(view.model._callbacks).length, 3);

    view.unstickit();

    equal(_.keys(view.model._callbacks).length, 0);
  });

  test('unstickit (multiple models)', function() {
    
    var model1, model2, view, model3;

    model1 = new (Backbone.Model)({one:'', two:''});
    model2 = new (Backbone.Model)({three:'', four:''});
    model3 = new (Backbone.Model)({five:'', six:''});

    view = new (Backbone.View.extend({
      initialize: function() {
        this.model = model1;
      },
      bindings: {
        '.test12-1': 'one',
        '.test12-2': 'two'
      },
      otherBindings: {
        '.test12-3': 'three',
        '.test12-4': 'four'
      },
      moreBindings: {
        '.test12-5': 'five',
        '.test12-6': 'six'
      },
      render: function() {
        var html = document.getElementById('jst12').innerHTML;
        this.$el.html(_.template(html)());
        this.stickit();
        this.stickit(model2, this.otherBindings);
        this.stickit(model3, this.moreBindings);
        return this;
      }
    }))().render();

    equal(_.keys(model1._callbacks).length, 2);
    equal(_.keys(model2._callbacks).length, 2);
    equal(_.keys(model3._callbacks).length, 2);
    equal(view._modelBindings.length, 6);

    view.unstickit(model3);

    equal(_.keys(model1._callbacks).length, 2);
    equal(_.keys(model2._callbacks).length, 2);
    equal(_.keys(model3._callbacks).length, 0);
    equal(view._modelBindings.length, 4);

    view.unstickit();

    equal(_.keys(model1._callbacks).length, 0);
    equal(_.keys(model2._callbacks).length, 0);
    equal(view._modelBindings.length, 0);
  });

});
