# Hardcopy Themes

A hardcopy theme is an XML file with root `<theme>`.  The `<theme>` element has an attirubute `label` that is used to
define a label for the theme, for example, `label="Empty"`.  It has children:

* `<description>`
* `<preamble>`
* `<presetheader>`
* `<postsetheader>`
* `<problemheader>`
* `<problemfooter>`
* `<problemdivider>`
* `<setfooter>`
* `<setdivider>`
* `<userdivider>`
* `<postamble>`

The `<description>` element contains a simple text description of the theme.  All other elements contain text snippets
that will be inserted into a `.tex` file.

The `<preamble>` and `<postamble>` wrap the file.  Note that `webwork2` will write `\batchmode` to the `.tex` file even
before `<preamble>` is written.  The `<preamble>` must include `\usepackage{webwork2}` to load `webwork2.sty` for many
things to work.

Next `webwork2` will loop through users (often just one) and loop through problem sets (often just one) and write TeX
for all combinations.  `<userdivider>` and `<setdivider>` are snippets of TeX that are inserted when transitioning to a
new user or a new set.  Typically these should just start a new page and reset page numbering.

When an individual user-set is being processed, first the `<presetheader>` snippet will be used.  Then the PG header
file will be processed.  Then the `<postsetheader>` snippet will be used.  At the end of the set `webwork2` attempts to
make the last page display a copyright claim.  Then the `<setfooter>` snippet is used.

Each problem is wrapped in `<problemheader>` and `<problemfooter>`, and `<problemdivider>` is used between adjacent
problems.

## Packages

A theme preamble can load packages, but as soon as it loads `webwork2`, it is already loading `path`, `listings`,
`hyperref`, and `ifthen`.  So you can use tools from these packages without loading them in your theme.

Also `webwork2` loads `pg.sty` from the `pg` distribution.  This loads `amsmath`, `amsfonts`, `amssymb`, `booktabs`,
`tabularx`, `colortbl`, `caption`, `xcolor`, `multicol`, `mhchem`, and `graphicx`.  So again you can use tools from
these packages without loading them in your theme.

## Macros

The following macros are provided by the `webwork2` package. They may be empty, but `webwork2` should populate them
with appropriate values as the `.tex` file is built. So you can use these when building your theme.

* `\webworkCourseName`
* `\webworkCourseTitle`
* `\webworkCourseURL`
* `\webworkUserId` (the user's username)
* `\webworkStudentId` (the user's Student ID)
* `\webworkFirstName`
* `\webworkLastName`
* `\webworkEmailAddress`
* `\webworkSection`
* `\webworkRecitation`
* `\webworkSetId` (the actual name of the set which may have underscores)
* `\webworkPrettySetId` (a version where underscores have been converted to spaces)
* `\webworkDescription`
* `\webworkOpenDate`
* `\webworkReducedScoringDate`
* `\webworkDueDate`
* `\webworkAnswerDate`
* `\webworkProblemNumber` (the number of the problem in the set)
* `\webworkProblemId` (may differ from the problem number for a versioned test with randomized order)
* `\webworkProblemWeight`
* `\webworkLeftHeader` (a multiline expression with the set name and due date(s))
* `\webworkCenterHeader` (empty by default)
* `\webworkRightHeader` (a multiline expression with the user's name, ID, section, and recitation)
* `\webworkLeftFooter` (a hyperlink to the course with text the course title)
* `\webworkCenterFooter` (empty by default)
* `\webworkRightFooter` (localized "Page" followed by the page number)

Words and phrases might be localized automatically by `webwork2` in the future, but a theme can override these.

* `\webworkLocalizeAssignment`
* `\webworkLocalizeSet`
* `\webworkLocalizeProblem`
* `\webworkLocalizeUsername`
* `\webworkLocalizeFullCreditBy`
* `\webworkLocalizeCloses`
* `\webworkLocalizeSection`
* `\webworkLocalizeRecitation`
* `\webworkLocalizePage`
* `\webworkLocalizePoint`

## Config

Theme files belong in `webwork2/assets/hardcopyThemes` or in a course's `templates/hardcopyThemes` folder.  Both of
these paths can be configured in `localOverrides.conf`, following the initialization in `defaults.config`. If a theme
in `templates/hardcopyThemes` has the same filename as a theme in `webwork2/assets/hardcopyThemes`, the one from
`templates/hardcopyThemes` will be used.

A course will "see" all the theme files in these locations and make them available to be enabled in Course Config.
Only the enabled themes will be offered for use when producing a hardcopy.

In addition to enabling themes in Course Config, you can also set the default hardcopy theme for regular hardcopy
production, and separately set a default hardcopy theme for use by the PG Editor.
