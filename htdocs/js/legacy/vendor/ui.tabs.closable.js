/*!
 * Copyright (c) 2010 Andrew Watts
 *
 * Dual licensed under the MIT (MIT_LICENSE.txt)
 * and GPL (GPL_LICENSE.txt) licenses
 * 
 * http://github.com/andrewwatts/ui.tabs.closable
 */
(function() {
    
var ui_tabs_tabify = $.ui.tabs.prototype._tabify;

$.extend($.ui.tabs.prototype, {

    _tabify: function() {
        var self = this;

        ui_tabs_tabify.apply(this, arguments);

        // if closable tabs are enable, add a close button
        if (self.options.closable === true) {

            var unclosable_lis = this.lis.filter(function() {
                // return the lis that do not have a close button
                return $('a.ui-icon-circle-close', this).length === 0;
            });

            // append the close button and associated events
            unclosable_lis.each(function() {
                $(this)
                    .append('<a class="close ui-icon-circle-close" style="cursor: pointer; margin:.5em 1em; padding:0px;" href="#">&times;</a>')
                    .find('a:last')
                        .click(function() {
                            var index = self.lis.index($(this).parent());
                            if (index > -1) {
                                // call _trigger to see if remove is allowed
                                if (false === self._trigger("closableClick", null, self._ui( $(self.lis[index]).find( "a" )[ 0 ], self.panels[index] ))) return;

                                // remove this tab
                                self.remove(index)
                            }

                            // don't follow the link
                            return false;
                        })
                    .end();
            });
        }
    }
});
    
})(jQuery);
