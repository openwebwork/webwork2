$(document).ready(function() {

  module("Backbone.noConflict");

  test('Backbone.noConflict', function() {
    var noconflictBackbone = Backbone.noConflict();
    equal(window.Backbone, undefined, 'Returned window.Backbone');
    window.Backbone = noconflictBackbone;
    equal(window.Backbone, noconflictBackbone, 'Backbone is still pointing to the original Backbone');
  });

});
