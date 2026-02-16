# Theming WeBWorK 2

This folder contains the themes for webwork2. If you would like to create a custom theme, then copy one of the existing
theme directories, and modify it as desired. It is recommended that you use either the `math4-green`, `math4-red`, or
`math4-yellow` theme as the basis for a new custom theme, but for more advanced theming you can copy the `math4`
directory itself. Generally only the `_theme-colors.scss` and `_theme-overrides.scss` files need to be modified. The
important things to change are the colors in the `_theme-colors.scss` file. Overrides for special cases can be done in
the `_theme-overrides.scss` file. The `math4-yellow` theme uses a light primary color, and so it is a good example to
follow if you also need a light primary color. It also shows how the `_theme-overrides.scss` file can be used to handle
certain special cases.

The `math4-overrides.css` and `math4-overrides.js` files can also be created in the theme directory and customizations
can also be added to those files. However, usage of these files is deprecated and support for them will eventually be
dropped. There are `.dist` files in the `math4` directory you can copy, but the `.dist` files do not have anything of
value in them.

Note that any changes made to the files in the `math4`, `math4-green`, `math4-red`, and `math4-yellow` files will cause
problems when you upgrade webwork2, (other than copies of the `math4-overrides.css.dist` and `math4-overrides.css.js`
files).

To make the custom theme available for webwork2 to use, run `npm ci` from the `htdocs` directory. Then either set the
theme as the `$defaultTheme` in `conf/localOverrides.conf` or choose the theme in the `Course Configuration` of a course
to use it. Note that for any changes in the theme files to take effect, you must run `npm ci` again. You can also
execute `./generate-assets.js` from the `htdocs` directory to update the theme (this is actually part of what `npm ci`
does). See more details on theme creation on [the WeBWork Wiki](https://wiki.openwebwork.org/wiki/Customizing_WeBWorK).

The theming system uses Sass which is an extension of CSS, and is compiled into CSS (by the `generate-assets.js`
script). Sass variables can be set in the `_theme-colors.scss` file that control many display aspects of the user
interface. Bootstrap has many Sass variables that can be customized. In addition there are CSS variables that can be
set. Many of these are set initially from the Sass variables, but they can also be changed in the
`_theme-overrides.scss` file. See the [Bootstrap documentation](https://getbootstrap.com/docs/5.3) for available Sass
and CSS variables. There are also Sass and CSS variables specifically for webwork2 that can be used. These are
documented below. In addition Bootstrap functions can be used to manipulate colors in the `_theme-colors.scss` file.
See the [Boottrap Sass function documentation](https://getbootstrap.com/docs/5.3/customize/sass/#functions).

## WeBWorK 2 Sass Variables

These must be set in the `_theme-colors.scss` file.

- `$ww-logo-background-color`: WeBWorK logo background color in the banner.
- `$ww-achievement-level-color`: Color of the level progress bar on the achievements page.

## WeBWorK 2 CSS Variables

All of these are set to a default value in the `bootstrap.scss` file, but can be overridden in the
`_theme-overrides.scss` file. Note that values can even be set for a specific CSS selector to only apply to the elements
that match the selector and descendants of those elements.

- `--ww-primary-foreground-color`: The color of text that is displayed before a primary colored background in the page
  header, site navigation menu, and the course list on the webwork2 home page. This defaults to the result of
  `#{color-contrast($primary)}` and rarely needs to be changed.
- `--ww-layout-divider-color`: This is the color of the border that separates the page header, site navigation menu, and
  main content area. It is also used for the color of the border separates the primary part of the site navigation menu
  from page specific sub menus (such as the list of problems when viewing a problem in a homework set). This defaults to
  `#aaa` in light mode and `#666` in dark mode.
- `--ww-layout-border-color`: This is the border color for other regions such as the breadcrumb navigation at the top of
  every page and the info box shown (the course information or set header box). This defaults to `#e6e6e6` in light mode
  and `#495057` in dark mode.
- `--ww-toggle-sidebar-icon-color-rgb`: The color of the site navigation menu toggle button in RGB color components.
  This defaults to `255, 255, 255`.
- `--ww-toggle-sidebar-icon-hover-color`: The color of the site navigation menu toggle button when it is hovered over
  with the mouse cursor or has keyboard focus. This defaults to `#fff`.
- `--ww-site-nav-link-active-background-color`: The background color of the links in the site navigation menu when they
  have keyboard focus. This defaults to `#{$primary}`.
- `--ww-site-nav-link-hover-background-color`: The background color of the links in the site navigation menu when the
  mouse cursor hovers over them. This defaults to `#e1e1e1` in light mode and `#{shade-color($primary, 40%)}` in dark
  mode.
- `--ww-course-config-tab-link-focus-outline-color`: The outline color of the tab selection buttons on the course
  configuration page when they have keyboard focus. This defaults to `#{rgba($primary, $focus-ring-opacity)}` in light
  mode and `#{rgba(color-contrast($body-bg-dark), $focus-ring-opacity)}` in dark mode.
- `--ww-logo-background-color`: The background color for the top left region of the page header that contains the
  WeBWorK logo. This is set to the value of the `#{$ww-logo-background-color}` Sass variable, and there is no need to
  ever modify this. Just set the Sass variable directly to what this should be. This is really only needed to get the
  theme color to the other CSS files used by webwork2.
- `--ww-achievement-level-color`: The color of the level progress bar on the achievements page. This defaults to the
  value of the `#{$ww-achievement-level-color}` Sass variable, and there is no need to ever modify this. Just set the
  Sass variable directly to what this should be. This is really only needed to get the theme color to the other CSS
  files used by webwork2.
