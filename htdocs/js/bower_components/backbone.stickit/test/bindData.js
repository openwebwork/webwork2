$(document).ready(function() {

  module("view.stickit");

  test('input:text', function() {
    
    model.set({'water':'fountain'});
    view.model = model;
    view.templateId = 'jst1';
    view.bindings = {
      '#test1': {
        observe: 'water'
      }
    };
    $('#qunit-fixture').html(view.render().el);

    equal(view.$('#test1').val(), 'fountain');

    model.set('water', 'evian');
    equal(view.$('#test1').val(), 'evian');
    
    view.$('#test1').val('dasina').trigger('keyup');
    equal(model.get('water'), 'dasina');
  });

  test('textarea', function() {
    
    model.set({'water':'fountain'});
    view.model = model;
    view.templateId = 'jst2';
    view.bindings = {
      '#test2': {
        observe: 'water'
      }
    };
    $('#qunit-fixture').html(view.render().el);

    equal(view.$('#test2').val(), 'fountain');

    model.set('water', 'evian');
    equal(view.$('#test2').val(), 'evian');
    
    view.$('#test2').val('dasina').trigger('keyup');
    equal(model.get('water'), 'dasina');
  });

  test('contenteditable', function() {
    
    model.set({'water':'<span>fountain</span>'});
    view.model = model;
    view.templateId = 'jst17';
    view.bindings = {
      '#test17': {
        observe: 'water'
      }
    };
    $('#qunit-fixture').html(view.render().el);

    equal(view.$('#test17').html(), '<span>fountain</span>');

    model.set('water', '<span>evian</span>');
    equal(view.$('#test17').html(), '<span>evian</span>');
    
    view.$('#test17').html('<span>dasina</span>').trigger('keyup');
    equal(model.get('water'), '<span>dasina</span>');
  });

  test('checkbox', function() {
    
    model.set({'water':true});
    view.model = model;
    view.templateId = 'jst3';
    view.bindings = {
      '#test3': {
        observe: 'water'
      }
    };
    $('#qunit-fixture').html(view.render().el);

    equal(view.$('#test3').prop('checked'), true);

    model.set('water', false);
    equal(view.$('#test3').prop('checked'), false);
    
    view.$('#test3').prop('checked', true).trigger('change');
    equal(model.get('water'), true);
  });

  test('radio', function() {
    
    model.set({'water':'fountain'});
    view.model = model;
    view.templateId = 'jst4';
    view.bindings = {
      '.test4': {
        observe: 'water'
      }
    };
    $('#qunit-fixture').html(view.render().el);

    equal(view.$('.test4:checked').val(), 'fountain');

    model.set('water', 'evian');
    equal(view.$('.test4:checked').val(), 'evian');
    
    view.$('.test4[value=fountain]').prop('checked', true).trigger('change');
    equal(model.get('water'), 'fountain');
  });

  test('div', function() {
    
    model.set({'water':'fountain'});
    view.model = model;
    view.templateId = 'jst5';
    view.bindings = {
      '#test5': {
        observe: 'water'
      }
    };
    $('#qunit-fixture').html(view.render().el);

    equal(view.$('#test5').text(), 'fountain');

    model.set('water', 'evian');
    equal(view.$('#test5').text(), 'evian');
  });

  test(':el selector', function() {
    
    model.set({'water':'fountain'});
    view.model = model;
    view.templateId = 'jst5';
    view.bindings = {
      ':el': {
        observe: 'water'
      }
    };
    $('#qunit-fixture').html(view.render().el);

    equal(view.$el.text(), 'fountain');

    model.set('water', 'evian');
    equal(view.$el.text(), 'evian');
  });

  test('stickit (shorthand bindings)', function() {
    model.set({'water':'fountain'});
    view.model = model;
    view.templateId = 'jst5';
    view.bindings = {
      '#test5': 'water'
    };
    $('#qunit-fixture').html(view.render().el);
    
    equal(view.$('#test5').text(), 'fountain');

    model.set('water', 'evian');

    equal(view.$('#test5').text(), 'evian');

  });

  test('stickit (multiple models and bindings)', function() {
  
    // Test sticking two times to two different models and configs.
    var model1, model2, testView;
    
    model1 = new (Backbone.Model)({id:1, water:'fountain', candy:'twix'});
    model2 = new (Backbone.Model)({id:2, water:'evian', candy:'snickers'});
    
    testView = new (Backbone.View.extend({
      initialize: function() {
        this.model = model1;
        this.otherModel = model2;
      },
      bindings: {
        '#test0-div': {
          observe: 'water'
        },
        '#test0-textarea': {
          observe: 'candy'
        }
      },
      otherBindings: {
        '#test0-span': {
          observe: 'water'
        },
        '#test0-input': {
          observe: 'candy'
        }
      },
      render: function() {
        var html = document.getElementById('jst0').innerHTML;
        this.$el.html(_.template(html)());
        this.stickit();
        this.stickit(this.otherModel, this.otherBindings);
        return this;
      }
    }))();

    $('#qunit-fixture').html(testView.render().el);

    equal(testView.$('#test0-div').text(), 'fountain');
    equal(testView.$('#test0-textarea').val(), 'twix');
    equal(testView.$('#test0-span').text(), 'evian');
    equal(testView.$('#test0-input').val(), 'snickers');

    model1.set({water:'dasina', candy: 'mounds'});
    model2.set({water:'poland springs', candy: 'almond joy'});

    equal(testView.$('#test0-div').text(), 'dasina');
    equal(testView.$('#test0-textarea').val(), 'mounds');
    equal(testView.$('#test0-span').text(), 'poland springs');
    equal(testView.$('#test0-input').val(), 'almond joy');

    testView.$('#test0-textarea').val('kit kat').trigger('keyup');
    testView.$('#test0-input').val('butterfinger').trigger('keyup');

    equal(model1.get('candy'), 'kit kat');
    equal(model2.get('candy'), 'butterfinger');
  });

  test('stickit (existing events property as hash with multiple models and bindings)', function() {

    var model1, testView;

    model1 = new (Backbone.Model)({id:1, candy:'twix' });
    model2 = new (Backbone.Model)({id:2, candy:'snickers'});

    testView = new (Backbone.View.extend({

      initialize: function() {
        this.model = model1;
        this.otherModel = model2;
      },

      events: {
        click: 'handleClick'
      },

      bindings: {
        '#test0-textarea': 'candy'
      },

      otherBindings: {
        '#test0-input': 'candy'
      },

      render: function() {
        var html = document.getElementById('jst0').innerHTML;
        this.$el.html(_.template(html)());
        this.stickit();
        this.stickit(this.otherModel, this.otherBindings);
        return this;
      },

      handleClick: function() {
        this.clickHandled = true;
      }

    }))();

    $('#qunit-fixture').html(testView.render().el);

    testView.$('#test0-textarea').val('kit kat').trigger('keyup');
    testView.$('#test0-input').val('butterfinger').trigger('keyup');

    equal(model1.get('candy'), 'kit kat');
    equal(model2.get('candy'), 'butterfinger');

    testView.$el.trigger('click');

    equal(testView.clickHandled, true);

    // Remove the view which should unbind the event handlers.
    testView.remove();

    testView.$('#test0-textarea').val('mounds').trigger('keyup');
    testView.$('#test0-input').val('skittles').trigger('keyup');

    equal(model1.get('candy'), 'kit kat');
    equal(model2.get('candy'), 'butterfinger');
  });

  test('stickit (existing events property as function with multiple models and bindings)', function() {

    var model1, testView;

    model1 = new (Backbone.Model)({id:1, candy:'twix' });
    model2 = new (Backbone.Model)({id:2, candy:'snickers'});

    testView = new (Backbone.View.extend({

      initialize: function() {
        this.model = model1;
        this.otherModel = model2;
      },

      events: function() {

        var self = this;

        return {
          click: function() {
            self.clickHandled = true;
          }
        };

      },

      bindings: {
        '#test0-textarea': 'candy'
      },

      otherBindings: {
        '#test0-input': 'candy'
      },

      render: function() {
        var html = document.getElementById('jst0').innerHTML;
        this.$el.html(_.template(html)());
        this.stickit();
        this.stickit(this.otherModel, this.otherBindings);
        return this;
      }

    }))();

    $('#qunit-fixture').html(testView.render().el);

    testView.$('#test0-textarea').val('kit kat').trigger('keyup');
    testView.$('#test0-input').val('butterfinger').trigger('keyup');

    equal(model1.get('candy'), 'kit kat');
    equal(model2.get('candy'), 'butterfinger');

    testView.$el.trigger('click');

    equal(testView.clickHandled, true);

  });

  test('bindings:setOptions', function() {
    
    model.set({'water':'fountain'});
    view.model = model;
    view.templateId = 'jst1';
    view.bindings = {
      '#test1': {
        observe: 'water',
        setOptions: {silent:true}
      }
    };
    $('#qunit-fixture').html(view.render().el);

    equal(view.$('#test1').val(), 'fountain');
    
    view.$('#test1').val('dasina').trigger('keyup');
    equal(model.get('water'), 'dasina');
    equal(model.changedAttributes().water, 'dasina');
  });

  test('bindings:updateMethod', function() {
    
    model.set({'water':'<a href="www.test.com">river</a>'});
    view.model = model;
    view.templateId = 'jst5';
    view.bindings = {
      '#test5': {
        observe: 'water',
        updateMethod: 'html'
      }
    };
    $('#qunit-fixture').html(view.render().el);

    equal(view.$('#test5').text(), 'river');
  });

  test('bindings:escape', function() {
    
    model.set({'water':'<a href="www.test.com">river</a>'});
    view.model = model;
    view.templateId = 'jst5';
    view.bindings = {
      '#test5': {
        observe: 'water',
        updateMethod: 'html',
        escape: true
      }
    };

    $('#qunit-fixture').html(view.render().el);

    equal(view.$('#test5').text(), '<a href="www.test.com">river</a>');
  });

  test('bindings:onSet/onGet', 6, function() {
    
    model.set({'water':'_fountain'});
    view.model = model;
    view.templateId = 'jst1';
    view.bindings = {
      '#test1': {
        observe: 'water',
        onGet: function(val, options) {
          equal(val, this.model.get('water'));
          equal(options.observe, 'water');
          return val.substring(1);
        },
        onSet: function(val, options) {
          equal(val, view.$('#test1').val());
          equal(options.observe, 'water');
          return '_' + val;
        }
      }
    };

    $('#qunit-fixture').html(view.render().el);

    equal(view.$('#test1').val(), 'fountain');
    view.$('#test1').val('evian').trigger('keyup');
    equal(model.get('water'), '_evian');
  });

  test('bindings:afterUpdate', 14, function() {
    
    model.set({'water':'fountain', 'candy':true});
    view.model = model;
    view.templateId = 'jst15';
    view.bindings = {
      '#test15-1': {
        observe: 'water',
        afterUpdate: function($el, val, options) {
          equal($el.text(), model.get('water'));
          equal(val, 'evian');
          equal(options.observe, 'water');
        }
      },
      '#test15-2': {
        observe: 'water',
        afterUpdate: function($el, val, options) {
          equal($el.val(), model.get('water'));
          equal(val, 'evian');
          equal(options.observe, 'water');
        }
      },
      '#test15-3': {
        observe: 'candy',
        afterUpdate: function($el, val, options) {
          equal(val, false);
          equal(options.observe, 'candy');
        }
      },
      '.test15-4': {
        observe: 'water',
        afterUpdate: function($el, val, options) {
          equal(val, 'evian');
          equal(options.observe, 'water');
        }
      },
      '#test15-6': {
        observe: 'water',
        afterUpdate: function($el, val, options) {
          equal(val, 'evian');
          equal(options.observe, 'water');
        }
      },
      '#test15-7': {
        observe: 'water',
        selectOptions: {
          collection: function() { return [{id:1,name:'fountain'}, {id:2,name:'evian'}, {id:3,name:'dasina'}]; },
          labelPath: 'name',
          valuePath: 'name'
        },
        afterUpdate: function($el, val, options) {
          equal(val, 'evian');
          equal(options.observe, 'water');
        }
      }
    };
    $('#qunit-fixture').html(view.render().el);

    model.set('water', 'evian');
    model.set('candy', false);
  });

  test('bindings:selectOptions', 7, function() {

    model.set({'water':'fountain'});
    view.model = model;
    view.templateId = 'jst8';
    view.bindings = {
      '#test8': {
        observe: 'water',
        selectOptions: {
          collection: function($el, options) {
            ok($el.is('select'));
            equal(options.observe, 'water');
            return [{id:1,name:'fountain'}, {id:2,name:'evian'}, {id:3,name:'dasina'}];
          },
          labelPath: 'name',
          valuePath: 'name'
        }
      }
    };

    $('#qunit-fixture').html(view.render().el);

    equal(getSelectedOption(view.$('#test8')).data('stickit_bind_val'), 'fountain');

    model.set('water', 'evian');
    equal(getSelectedOption(view.$('#test8')).data('stickit_bind_val'), 'evian');

    view.$('#test8 option').eq(2).prop('selected', true).trigger('change');
    equal(model.get('water'), 'dasina');
  });

  test('bindings:selectOptions:defaultOption', 8, function() {

    model.set({'water':null});
    view.model = model;
    view.templateId = 'jst8';
    view.bindings = {
      '#test8': {
        observe: 'water',
        selectOptions: {
          collection: function($el, options) {
            ok($el.is('select'));
            equal(options.observe, 'water');
            return [{id:1,type:{name:'fountain'}}, {id:2,type:{name:'evian'}}, {id:3,type:{name:'dasina'}}];
          },
          defaultOption: {
            label: 'Choose one...',
            value: null
          },
          labelPath: 'type.name',
          valuePath: 'type.name'
        }
      }
    };

    $('#qunit-fixture').html(view.render().el);

    equal(view.$('#test8 option').eq(0).text(), 'Choose one...');
    equal(getSelectedOption(view.$('#test8')).data('stickit_bind_val'), null);

    model.set('water', 'evian');
    equal(getSelectedOption(view.$('#test8')).data('stickit_bind_val'), 'evian');

    view.$('#test8 option').eq(3).prop('selected', true).trigger('change');
    equal(model.get('water'), 'dasina');
  });

  test('bindings:selectOptions (pre-rendered)', 3, function() {

    model.set({'water':'1'});
    view.model = model;
    view.templateId = 'jst21';
    view.bindings = {
      '#test21': {
        observe: 'water'
      }
    };

    $('#qunit-fixture').html(view.render().el);

    equal(getSelectedOption(view.$('#test21')).data('stickit_bind_val'), '1');

    model.set('water', '2');
    equal(getSelectedOption(view.$('#test21')).data('stickit_bind_val'), '2');

    view.$('#test21 option').eq(2).prop('selected', true).trigger('change');
    equal(model.get('water'), '3');
  });

  test('bindings:selectOptions (Backbone.Collection)', function() {

    var collection = new Backbone.Collection([{id:1,name:'fountain'}, {id:2,name:'evian'}, {id:3,name:'dasina'}]);
    model.set({'water':'fountain'});
    view.model = model;
    view.templateId = 'jst8';
    view.bindings = {
      '#test8': {
        observe: 'water',
        selectOptions: {
          collection: function() { return collection; },
          labelPath: 'name',
          valuePath: 'name'
        }
      }
    };

    $('#qunit-fixture').html(view.render().el);

    equal(getSelectedOption(view.$('#test8')).data('stickit_bind_val'), 'fountain');

    model.set('water', 'evian');
    equal(getSelectedOption(view.$('#test8')).data('stickit_bind_val'), 'evian');
    
    view.$('#test8 option').eq(2).prop('selected', true).trigger('change');
    equal(model.get('water'), 'dasina');
  });

  test('bindings:selectOptions (collection path relative to `this`)', function() {

    view.collection = new Backbone.Collection([{id:1,name:'fountain'}, {id:2,name:'evian'}, {id:3,name:'dasina'}]);
    model.set({'water':'fountain'});
    view.model = model;
    view.templateId = 'jst8';
    view.bindings = {
      '#test8': {
        observe: 'water',
        selectOptions: {
          collection: 'this.collection',
          labelPath: 'name',
          valuePath: 'name'
        }
      }
    };

    $('#qunit-fixture').html(view.render().el);

    equal(getSelectedOption(view.$('#test8')).data('stickit_bind_val'), 'fountain');

    model.set('water', 'evian');
    equal(getSelectedOption(view.$('#test8')).data('stickit_bind_val'), 'evian');

    view.$('#test8 option').eq(2).prop('selected', true).trigger('change');
    equal(model.get('water'), 'dasina');
  });

  test('bindings:selectOptions (empty valuePath)', function() {

    model.set({'water':{id:1, name:'fountain'}});
    window.test = {
      collection: [{id:1,name:'fountain'}, {id:2,name:'evian'}, {id:3,name:'dasina'}]
    };
    view.model = model;
    view.templateId = 'jst8';
    view.bindings = {
      '#test8': {
        observe: 'water',
        selectOptions: {
          collection: 'window.test.collection',
          labelPath: 'name'
        }
      }
    };
    $('#qunit-fixture').html(view.render().el);

    equal(getSelectedOption(view.$('#test8')).data('stickit_bind_val').id, 1);

    model.set('water', {id:2, name:'evian'});
    equal(getSelectedOption(view.$('#test8')).data('stickit_bind_val').id, 2);

    view.$('#test8 option').eq(2).prop('selected', true).trigger('change');
    equal(model.get('water').id, 3);
  });

  test('bindings:selectOptions (empty string label)', function() {

    model.set({'water':'session'});
    view.model = model;
    view.templateId = 'jst8';
    view.bindings = {
      '#test8': {
        observe: 'water',
        selectOptions: {
          collection: function() {
            return [{label:'c',value:''}, {label:'s',value:'session'}];
          },
          labelPath: "label",
          valuePath: "value"
        }
      }
    };

    $('#qunit-fixture').html(view.render().el);

    equal(getSelectedOption(view.$('#test8')).data('stickit_bind_val'), 'session');
    equal(view.$('#test8 option').eq(0).data('stickit_bind_val'), '');

    model.set('water', '');
    equal(getSelectedOption(view.$('#test8')).data('stickit_bind_val'), '');
  });

  test('bindings:selectOptions (default labelPath/valuePath)', function() {
  
    model.set({'water':'evian'});
    view.model = model;
    view.templateId = 'jst8';
    view.bindings = {
      '#test8': {
        observe: 'water',
        selectOptions: {
          collection: function() {
            return [{label:'c',value:'fountain'}, {label:'s',value:'evian'}];
          }
        }
      }
    };

    $('#qunit-fixture').html(view.render().el);

    equal(getSelectedOption(view.$('#test8')).data('stickit_bind_val'), 'evian');

    model.set('water', 'fountain');
    equal(getSelectedOption(view.$('#test8')).data('stickit_bind_val'), 'fountain');
  });

  test('bindings:selectOptions (multi-select without valuePath)', function() {

    var collection = [{id:1,name:'fountain'}, {id:2,name:'evian'}, {id:3,name:'dasina'}, {id:4,name:'aquafina'}];

    model.set({'water': [{id:1,name:'fountain'}, {id:3,name:'dasina'}] });
    view.model = model;
    view.templateId = 'jst16';
    view.bindings = {
      '#test16': {
        observe: 'water',
        selectOptions: {
          collection: function() { return collection; },
          labelPath: 'name'
        }
      }
    };

    $('#qunit-fixture').html(view.render().el);

    equal(getSelectedOption(view.$('#test16')).eq(0).data('stickit_bind_val').name, 'fountain');
    equal(getSelectedOption(view.$('#test16')).eq(1).data('stickit_bind_val').name, 'dasina');

    var field = _.clone(model.get('water'));
    field.push({id:2,name:'evian'});

    model.set({'water':field});
    equal(getSelectedOption(view.$('#test16')).eq(1).data('stickit_bind_val').name, 'evian');

    view.$('#test16 option').eq(3).prop('selected', true).trigger('change');

    equal(model.get('water').length, 4);

  });

  test('bindings:selectOptions (multi-select with valuePath)', function() {

    var collection = [{id:1,name:'fountain'}, {id:2,name:'evian'}, {id:3,name:'dasina'}, {id:4,name:'aquafina'}];

    model.set({'water': [1, 3]});
    view.model = model;
    view.templateId = 'jst16';
    view.bindings = {
      '#test16': {
        observe: 'water',
        selectOptions: {
          collection: function() { return collection; },
          labelPath: 'name',
          valuePath: 'id'
        }
      }
    };

    $('#qunit-fixture').html(view.render().el);

    equal(getSelectedOption(view.$('#test16')).eq(0).data('stickit_bind_val'), 1);
    equal(getSelectedOption(view.$('#test16')).eq(1).data('stickit_bind_val'), 3);

    var field = _.clone(model.get('water'));
    field.push(2);

    model.set({'water':field});
    equal(getSelectedOption(view.$('#test16')).eq(1).data('stickit_bind_val'), 2);

    view.$('#test16 option').eq(3).prop('selected', true).trigger('change');

    equal(model.get('water').length, 4);

  });

  test('bindings:selectOptions (pre-rendered multi-select)', function() {

    model.set({'water': ['1', '3']});
    view.model = model;
    view.templateId = 'jst23';
    view.bindings = {
      '#test23': {
        observe: 'water'
      }
    };

    $('#qunit-fixture').html(view.render().el);

    equal(getSelectedOption(view.$('#test23')).eq(0).data('stickit_bind_val'), '1');
    equal(getSelectedOption(view.$('#test23')).eq(1).data('stickit_bind_val'), '3');

    var field = _.clone(model.get('water'));
    field.push('2');

    model.set({'water':field});
    equal(getSelectedOption(view.$('#test23')).eq(1).data('stickit_bind_val'), '2');

    view.$('#test23 option').eq(3).prop('selected', true).trigger('change');

    equal(model.get('water').length, '4');

  });

  test('bindings:selectOptions (multi-select with onGet/onSet)', function() {

    var collection = [{id:1,name:'fountain'}, {id:2,name:'evian'}, {id:3,name:'dasina'}, {id:4,name:'aquafina'}];

    model.set({'water':'1-3'});
    view.model = model;
    view.templateId = 'jst16';
    view.bindings = {
      '#test16': {
        observe: 'water',
        onGet: function(val) {
          return _.map(val.split('-'), function(id) {return Number(id);});
        },
        onSet: function(vals) {
          return vals.join('-');
        },
        selectOptions: {
          collection: function() { return collection; },
          labelPath: 'name',
          valuePath: 'id'
        }
      }
    };

    $('#qunit-fixture').html(view.render().el);

    equal(getSelectedOption(view.$('#test16')).eq(0).data('stickit_bind_val'), 1);
    equal(getSelectedOption(view.$('#test16')).eq(1).data('stickit_bind_val'), 3);

    var field = _.clone(model.get('water'));
    field += '-2';

    model.set({'water':field});
    equal(getSelectedOption(view.$('#test16')).eq(1).data('stickit_bind_val'), 2);

    view.$('#test16 option').eq(3).prop('selected', true).trigger('change');

    equal(model.get('water'), '1-2-3-4');

  });

  test('bindings:selectOptions (optgroup)', function() {

    model.set({'character':3});
    view.model = model;
    view.templateId = 'jst8';
    view.bindings = {
      '#test8': {
        observe: 'character',
        selectOptions: {
          collection: function() {
            return {
              'opt_labels': ['Looney Tunes', 'Three Stooges'],
              'Looney Tunes': [{id: 1, name: 'Bugs Bunny'}, {id: 2, name: 'Donald Duck'}],
              'Three Stooges': [{id: 3, name : 'moe'}, {id: 4, name : 'larry'}, {id: 5, name : 'curly'}]
            };
          },
          labelPath: 'name',
          valuePath: 'id'
        }
      }
    };

    $('#qunit-fixture').html(view.render().el);

    equal(getSelectedOption(view.$('#test8')).parent().is('optgroup'), true);
    equal(getSelectedOption(view.$('#test8')).parent().attr('label'), 'Three Stooges');
    equal(getSelectedOption(view.$('#test8')).data('stickit_bind_val'), 3);

    model.set({'character':2});
    equal(getSelectedOption(view.$('#test8')).data('stickit_bind_val'), 2);

    view.$('#test8 option').eq(3).prop('selected', true).trigger('change');
    equal(model.get('character'), 4);
  });

  test('bindings:selectOptions (pre-rendered optgroup)', function() {

    model.set({'character':'3'});
    view.model = model;
    view.templateId = 'jst22';
    view.bindings = {
      '#test22': {
        observe: 'character'
      }
    };

    $('#qunit-fixture').html(view.render().el);

    equal(getSelectedOption(view.$('#test22')).parent().is('optgroup'), true);
    equal(getSelectedOption(view.$('#test22')).parent().attr('label'), 'Three Stooges');
    equal(getSelectedOption(view.$('#test22')).data('stickit_bind_val'), '3');

    model.set({'character':'2'});
    equal(getSelectedOption(view.$('#test22')).data('stickit_bind_val'), '2');

    view.$('#test22 option').eq(3).prop('selected', true).trigger('change');
    equal(model.get('character'), '4');
  });

  test('bindings:attributes:name', function() {

    model.set({'water':'fountain'});
    view.model = model;
    view.templateId = 'jst5';
    view.bindings = {
      '#test5': {
        observe: 'water',
        attributes: [{
          name: 'data-name'

        }]
      }
    };

    $('#qunit-fixture').html(view.render().el);

    equal(view.$('#test5').attr('data-name'), 'fountain');

    model.set('water', 'evian');
    equal(view.$('#test5').attr('data-name'), 'evian');
  });

  test('bindings:attributes:name:class', function() {

    model.set({'water':'fountain'});
    view.model = model;
    view.templateId = 'jst9';
    view.bindings = {
      '#test9': {
        observe: 'water',
        attributes: [{
          name: 'class'
        }]
      }
    };

    $('#qunit-fixture').html(view.render().el);

    ok(view.$('#test9').hasClass('test') && view.$('#test9').hasClass('fountain'));

    model.set('water', 'evian');
    ok(view.$('#test9').hasClass('test') && view.$('#test9').hasClass('evian'));
  });

  test('bindings:attributes:onGet', function() {

    model.set({'water':'fountain'});
    view.model = model;
    view.templateId = 'jst5';
    view.bindings = {
      '#test5': {
        observe: 'water',
        attributes: [{
          name: 'data-name',
          onGet: function(val, options) { return '_' + val + '_' + options.observe; }
        }]
      }
    };

    $('#qunit-fixture').html(view.render().el);

    equal(view.$('#test5').attr('data-name'), '_fountain_water');

    model.set('water', 'evian');
    equal(view.$('#test5').attr('data-name'), '_evian_water');
  });

  test('bindings:attributes:observe', function() {

    model.set({'water':'fountain', 'candy':'twix'});
    view.model = model;
    view.templateId = 'jst5';
    view.bindings = {
      '#test5': {
        attributes: [{
          name: 'data-name',
          observe: 'candy',
          onGet: function(val) {
            equal(val, this.model.get('candy'));
            return this.model.get('water') + '-' + this.model.get('candy');
          }
        }]
      }
    };

    $('#qunit-fixture').html(view.render().el);

    equal(view.$('#test5').attr('data-name'), 'fountain-twix');

    model.set({'water':'evian', 'candy':'snickers'});
    equal(view.$('#test5').attr('data-name'), 'evian-snickers');
  });

  test('bindings:attributes:observe (array)', 11, function() {

    model.set({'water':'fountain', 'candy':'twix'});
    view.model = model;
    view.templateId = 'jst5';
    view.bindings = {
      '#test5': {
        attributes: [{
          name: 'data-name',
          observe: ['water', 'candy'],
          onGet: function(val, options) {
            _.each(options.observe, _.bind(function(attr, i) {
              equal(val[i], this.model.get(attr));
            }, this));
            equal(options.observe.toString(), 'water,candy');
            return model.get('water') + '-' + model.get('candy');
          }
        }]
      }
    };

    $('#qunit-fixture').html(view.render().el);

    equal(view.$('#test5').attr('data-name'), 'fountain-twix');

    model.set({'water':'evian', 'candy':'snickers'});
    equal(view.$('#test5').attr('data-name'), 'evian-snickers');
  });

  test('bindings:attributes (properties)', function() {

    model.set({'water':true});
    view.model = model;
    view.templateId = 'jst1';
    view.bindings = {
      '#test1': {
        attributes: [{
          name: 'readonly',
          observe: 'water'
        }]
      }
    };

    $('#qunit-fixture').html(view.render().el);

    equal(view.$('#test1').prop('readonly'), true);

    model.set({'water':false});
    equal(view.$('#test1').prop('readonly'), false);
  });

  test('input:number', function() {

    model.set({'code':1});
    view.model = model;
    view.templateId = 'jst11';
    view.bindings = {
      '#test11': {
        observe: 'code'
      }
    };
    $('#qunit-fixture').html(view.render().el);

    equal(Number(view.$('#test11').val()), 1);

    model.set('code', 2);
    equal(Number(view.$('#test11').val()), 2);
  });

  test('visible', 19, function() {

    model.set({'water':false, 'candy':'twix', 'costume':false});
    view.model = model;
    view.templateId = 'jst14';
    view.bindings = {
      '#test14-1': {
        observe: 'water',
        visible: true
      },
      '#test14-2': {
        observe: 'candy',
        visible: function(val, options) {
          equal(val, this.model.get('candy'));
          equal(options.observe, 'candy');
          return this.model.get('candy') == 'twix';
        }
      },
      '#test14-3': {
        observe: ['candy', 'costume'],
        visible: true,
        visibleFn: function($el, isVisible, options) {
          equal($el.attr('id'), 'test14-3');
          ok(isVisible);
          equal(options.observe.toString(), 'candy,costume');
        }
      }
    };
    $('#qunit-fixture').html(view.render().el);

    equal(view.$('#test14-1').css('display') == 'block' , false);
    equal(view.$('#test14-2').css('display') == 'block' , true);
    equal(view.$('#test14-3').css('display') == 'block' , true);

    model.set('water', true);
    model.set('candy', 'snickers');
    model.set('costume', true);

    equal(view.$('#test14-1').css('display') == 'block' , true);
    equal(view.$('#test14-2').css('display') == 'block' , false);
    equal(view.$('#test14-3').css('display') == 'block' , true);
  });

  test('observe (multiple; array)', 12, function() {

    model.set({'water':'fountain', 'candy':'twix'});
    view.model = model;
    view.templateId = 'jst5';
    view.bindings = {
      '#test5': {
        observe: ['water', 'candy'],
        onGet: function(val, options) {
          _.each(options.observe, _.bind(function(attr, i) {
            equal(val[i], this.model.get(attr));
          }, this));
          equal(options.observe.toString(), 'water,candy');
          return model.get('water') + ' ' + model.get('candy');
        }
      }
    };
    $('#qunit-fixture').html(view.render().el);

    equal(view.$('#test5').text(), 'fountain twix');

    model.set('water', 'evian');
    equal(view.$('#test5').text(), 'evian twix');

    model.set('candy', 'snickers');
    equal(view.$('#test5').text(), 'evian snickers');
  });

  test('bindings:updateView', 9, function() {

    model.set({'water':'fountain'});
    view.model = model;
    view.templateId = 'jst1';
    view.bindings = {
      '#test1': {
        observe: 'water',
        updateView: function(val, options) {
          equal(options.observe, 'water');
          equal(val, model.get('water'));
          return val == 'evian';
        }
      }
    };
    $('#qunit-fixture').html(view.render().el);

    equal(view.$('#test1').val(), '');

    model.set({water:'evian'});
    equal(view.$('#test1').val(), 'evian');

    model.set({water:'dasina'});
    equal(view.$('#test1').val(), 'evian');
  });

  test('bindings:updateModel', 6, function() {

    model.set({'water':'fountain'});
    view.model = model;
    view.templateId = 'jst1';
    view.bindings = {
      '#test1': {
        observe: 'water',
        updateModel: function(val, options) {
          equal(val, view.$('#test1').val());
          equal(options.observe, 'water');
          return val == 'evian';
        }
      }
    };
    $('#qunit-fixture').html(view.render().el);

    view.$('#test1').val('dasina').trigger('keyup');
    equal(model.get('water'), 'fountain');

    view.$('#test1').val('evian').trigger('keyup');
    equal(model.get('water'), 'evian');
  });

  test('bindings:events', function() {

    model.set({'water':'fountain'});
    view.model = model;
    view.templateId = 'jst1';
    view.bindings = {
      '#test1': {
        observe: 'water',
        events: ['blur', 'keydown']
      }
    };
    $('#qunit-fixture').html(view.render().el);

    equal(view.$('#test1').val(), 'fountain');

    // keyup should be overriden, so no change...
    view.$('#test1').val('dasina').trigger('keyup');
    equal(model.get('water'), 'fountain');

    view.$('#test1').trigger('blur');
    equal(model.get('water'), 'dasina');

    view.$('#test1').val('evian').trigger('keydown');
    equal(model.get('water'), 'evian');
  });

  test('checkbox multiple', function() {

    model.set({'water':['fountain', 'dasina']});
    view.model = model;
    view.templateId = 'jst18';
    view.bindings = {
      '.boxes': 'water'
    };
    $('#qunit-fixture').html(view.render().el);

    equal(view.$('.boxes[value="fountain"]').prop('checked'), true);
    equal(view.$('.boxes[value="evian"]').prop('checked'), false);
    equal(view.$('.boxes[value="dasina"]').prop('checked'), true);

    model.set('water', ['evian']);
    equal(view.$('.boxes[value="fountain"]').prop('checked'), false);
    equal(view.$('.boxes[value="evian"]').prop('checked'), true);
    equal(view.$('.boxes[value="dasina"]').prop('checked'), false);

    view.$('.boxes[value="dasina"]').prop('checked', true).trigger('change');
    equal(model.get('water').length, 2);
    equal(_.indexOf(model.get('water'), 'evian') > -1, true);
    equal(_.indexOf(model.get('water'), 'dasina') > -1, true);
  });

  test('checkbox (single with value defined)', function() {

    model.set({'water':null});
    view.model = model;
    view.templateId = 'jst19';
    view.bindings = {
      '.box': 'water'
    };
    $('#qunit-fixture').html(view.render().el);

    equal(view.$('.box').prop('checked'), false);

    model.set('water', 'fountain');
    equal(view.$('.box').prop('checked'), true);

    view.$('.box').prop('checked', false).trigger('change');
    equal(model.get('water'), null);
  });

  test('getVal', 4, function() {

    model.set({'water':'fountain'});
    view.model = model;
    view.templateId = 'jst1';
    view.bindings = {
      '#test1': {
        observe: 'water',
        getVal: function($el, event, options) {
          equal($el.attr('id'), 'test1');
          equal(event.type, 'keyup');
          equal(options.observe, 'water');
          return 'test-' + $el.val();
        }
      }
    };
    $('#qunit-fixture').html(view.render().el);
    
    view.$('#test1').val('dasina').trigger('keyup');
    equal(model.get('water'), 'test-dasina');
  });

  test('update', 8, function() {

    model.set({'water':'fountain'});
    view.model = model;
    view.templateId = 'jst1';
    view.bindings = {
      '#test1': {
        observe: 'water',
        update: function($el, val, model, options) {
          equal($el.attr('id'), 'test1');
          equal(val, model.get('water'));
          equal(options.observe, 'water');
          $el.val('test-' + val);
        }
      }
    };
    $('#qunit-fixture').html(view.render().el);

    equal(view.$('#test1').val(), 'test-fountain');

    model.set('water', 'dasina');
    equal(view.$('#test1').val(), 'test-dasina');
  });

  test('initialize', 3, function() {

    model.set({'water':'fountain'});
    view.model = model;
    view.templateId = 'jst1';
    view.bindings = {
      '#test1': {
        observe: 'water',
        initialize: function($el, model, options) {
          equal($el.val(), 'fountain');
          equal(model.get('water'), 'fountain');
          equal(options.observe, 'water');
        }
      }
    };
    $('#qunit-fixture').html(view.render().el);
  });

});
