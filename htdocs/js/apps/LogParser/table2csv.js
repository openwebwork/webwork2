// From https://github.com/OmbraDiFenice/table2csv
(function ($) {
    var optionsDefaults = {
        /* action='download' options */
        filename: "table.csv",

        /* action='output' options */
        appendTo: "body",

        /* general options */
        separator: ",",
        newline: "\n",
        quoteFields: true,
        trimContent: true,
        excludeColumns: "",
        excludeRows: ""
    };

    var options = {};

    function quote(text) {
        return "\"" + text.replace(/"/g, "\"\"") + "\"";
    }

    // taken from http://stackoverflow.com/questions/3665115/create-a-file-in-memory-for-user-to-download-not-through-server
    function download(filename, text) {
        var element = document.createElement("a");
        element.setAttribute("href", "data:text/csv;charset=utf-8,\ufeff" + encodeURIComponent(text));
        element.setAttribute("download", filename);

        element.style.display = "none";
        document.body.appendChild(element);

        element.click();

        document.body.removeChild(element);
    }

    function convert(table) {
        var output = "";

        var rows = table.find("tr").not(options.excludeRows);

        var numCols = rows.first().find("td,th").filter(":visible").not(options.excludeColumns).length;

        rows.each(function (ignore, elem) {
            $(elem).find("td,th").filter(":visible").not(options.excludeColumns)
                .each(function (i, col) {
                    var column = $(col);

                    // Strip whitespaces
                    var content = options.trimContent
                        ? $.trim(column.text())
                        : column.text();

                    output += options.quoteFields
                        ? quote(content)
                        : content;
                    if (i !== numCols - 1) {
                        output += options.separator;
                    } else {
                        output += options.newline;
                    }
                });
        });

        return output;
    }

    $.fn.table2csv = function (action, opt) {
        if (typeof action === "object") {
            opt = action;
            action = "download";
        } else if (action === undefined) {
            action = "download";
        }

        // type checking
        if (typeof action !== "string") {
            throw new Error("\"action\" argument must be a string");
        }
        if (opt !== undefined && typeof opt !== "object") {
            throw new Error("\"options\" argument must be an object");
        }

        options = $.extend({}, optionsDefaults, opt);

        var table = this.filter("table"); // TODO use $.each

        if (table.length <= 0) {
            throw new Error("table2csv must be called on a <table> element");
        }

        if (table.length > 1) {
            throw new Error("converting multiple table elements at once is not supported yet");
        }

        var csv = convert(table);

        switch (action) {
        case "download":
            download(options.filename, csv);
            break;
        case "output":
            $(options.appendTo).append($("<pre>").text(csv));
            break;
        case "return":
            return csv;
        default:
            throw new Error("\"action\" argument must be one of the supported action strings");
        }

        return this;
    };

}(jQuery));
