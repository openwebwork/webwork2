# WeBWorK Accessibility Guide

## Purpose of this guide

Accessibility in WeBWorK comes from three different layers:

1. **The WeBWorK web application** which renders the course interface:
   navigation, grades, login, the instructor tools, and so on.
2. **The PG rendering** engine that converts problem code into problems a
   user will interact with.
3. **PG problems** which are written by individual problem authors. They may
   come from a shared library of problem files, might be uploaded into a
   course, or might be written by the course instructor.

A course can run with fully accessible infrastructure from 1 and 2 above
and still have individual problems with accessibility concerns because the
problem content (an image, a graph, a table) was authored without
accessibility in mind. Sections 1 and 2 below describe the interface itself.
Section 3 addresses problem content and gives problem authors (including
course instructors) concrete steps they can take to write or maintain
accessible problems.

---

## 1. The student experience

### What works well

- There is a Student Orientation that ships with WeBWorK, which orients
  students to navigation and accessibility features.
- Site navigation is built with accessibility and user experience in mind.
- Answer blanks have labeling and other accessible features.
- Popups announce themselves.
- Light, dark, and auto color themes are available.
- Math is rendered with MathJax v4, providing a large array of features that
  make math accessible.
- Timed tests may have their times adjusted, and students can be assigned an
  "accommodation factor" to expand all timed tests by the same factor.

### Known shortfalls

- An alternative to viewing problems in pages at the WeBWorK site is to
  generate PDF hardcopies of problem sets. These PDFs are far from accessible.
- Some problems that a student might be assigned may have accessibility
  shortcomings. See section 3 below.

---

## 2. The instructor experience

The instructor interface has historically had less attention addressing
accessibility concerns, but has been catching up with recent versions of
WeBWorK.

### What works well

- Instructor tools share the same accessible base layout and theming as
  student pages.
- Forms are built from labeled, standard HTML controls.
- The PG Problem Editor is a plain-text code editor with standard
  textarea/CodeMirror editing semantics.

### Known shortfalls

- Certain instructor tools are dense interactive HTML tables with many form
  controls. While the structure of these tables uses correct markup, screen
  reader operation of these tools may be challenging.
- The tool for browsing problems works by rendering lots of problems down a
  page. While a sighted user might quickly scroll and assess which problems
  they are looking for, a screen reader user might need much more time
  entering each problem.

---

## 3. Problem content (PG problems)

Every PG problem is a small program written by an instructor or author, not by
the WeBWorK/PG development team. The PG rendering engine provides substantial
accessibility *tools*, but whether an individual problem is accessible depends
heavily on whether its author used them, and used them correctly.

A problem file might be:

- Local, within a course. In this case the instructor has permissions needed to
  edit it.
- Within a communal library. In this case, an instructor cannot directly edit
  the file. However they will be able to make a local copy of the file, edit
  that file, and easily replace all instances that are assigned to students to
  use the local copy.

If a problem comes from a communal library and you make accessibility
improvements, please contribute your improvements upstream to that library.

### Guidance for problem authors and editors

**Use PGML.**
Write new problems using PGML, and convert old ones to PGML. When in the
problem editor, there is a PGML link leading to tutorials on how to write
using PGML. There are also tools to automatically convert problem code to
PGML and to give code critiques in the problem editor, under Code Maintenance.

**Describe images.**
All images/graphs need to include a description of important content in the
image — not "a picture of a triangle" but what a sighted student would
actually read off the image (the given measurements, the shape of a graph,
labels in a diagram, etc).

- Graphs should be created using the `plots.pl` macro. When creating the
  `Plots::Plot` object, use the `aria_label` to add a short title to the
  graph — such as "Graph of y equals x squared" (default is "Graph"). When
  displaying the graph, the `alt` text is converted to an `aria_description`
  which has no character limit. An optional `long_description` can be added
  to give both a shorter `aria_descripition` and longer description.

- Descriptions of static images (`.png`, `.jpeg`, etc) are provided via the
  `alt` text. `alt` text should be short, under ~125 characters, since many
  screen readers may only read the first ~125 characters of the `alt` text.
  See the PGML help for syntax options to add `alt` text. For anything more
  complicated than a one-line description, provide both a short `alt` text
  and a full `long_descripition` of the image.

- Graphs created using the `PGlatex.pl`, `PGtikz.pl`, or `PGgraphmacros.pl`
  macros generate static images and follow the same guidelines as static
  images above. Graphs created using the deprecated `PGgraphmacros.pl` should
  migrate to using `plots.pl`. Consider also migrating images created using
  `PGlatex.pl` or `PGtikz.pl` to `plots.pl` as well.

- `long_descripition` can include more than a sentence or paragraph for
  the image. It can include data tables (for example, a table of (x, y)
  points a plotted curve passes through), and is included in both the HTML
  and hardcopy PDF output, and is visible for sighted users.

- If an image is purely decorative (a border, a logo, a flourish), use
  `alt => ''` explicitly. Leaving `alt` unset is different from setting it to
  an empty string — an unset `alt` is a signal that the author simply forgot,
  so always set one or the other deliberately.

**A note on interactive graphing tools.**
Problems that use `parserGraphTool.pl` have an interactive graph with buttons
for creating plots of lines, circles, and more. Recent versions of WeBWorK
have made significant accessibility improvements for this tool, and it is
expected to be largely accessible. Field tests and issue reports are still
welcome, and the development team will work to address any reports.

There are other interactive tools used by older problems in the communal
libraries. These tools may fall short of accessibility standards and should be
avoided.

**Use headers and captions with tables.**
See the PGML help for the syntax to include headers and captions in a table.

**Don't rely on color alone.**
If a problem distinguishes cases, categories, or correct/incorrect regions
using color (e.g. "the red curve" vs. "the blue curve"), also distinguish
them with a label, line style, or position in the text ("the curve labeled
f" or "the dashed curve"), since colorblind students and screen reader
users get no information from color alone.

**Test with a keyboard.**
Before publishing a problem with anything beyond a plain answer blank (pop-up
menus, checkboxes, custom JavaScript widgets such as GraphTool or a custom
applet), tab through it without using a mouse. If you cannot complete the
problem using only the keyboard, a keyboard-only student cannot either.

---

## Reporting problems

If you experience an accessibility shortcoming with WeBWorK, please report the
issue.

- When you believe the issue is with the WeBWorK interface (navigation,
  grades, login, instructor tools, and more) report at the
  [webwork2 repository](https://github.com/openwebwork/webwork2/issues)
- When you believe the issue is a systemic issue with problem rendering or
  with how a student submits an answer, report at the
  [pg repository](https://github.com/openwebwork/pg/issues)
- If the issue stems from how a specific problem was (mis)coded, please see
  section 3 of this guide. And if you improve the accessibility of the
  problem, contact your WeBWorK administrator to ask how you could contirubute
  the improvement upstream.

