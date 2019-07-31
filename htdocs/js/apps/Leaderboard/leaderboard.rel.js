"use strict";

var _createClass = function () { function defineProperties(target, props) { for (var i = 0; i < props.length; i++) { var descriptor = props[i]; descriptor.enumerable = descriptor.enumerable || false; descriptor.configurable = true; if ("value" in descriptor) descriptor.writable = true; Object.defineProperty(target, descriptor.key, descriptor); } } return function (Constructor, protoProps, staticProps) { if (protoProps) defineProperties(Constructor.prototype, protoProps); if (staticProps) defineProperties(Constructor, staticProps); return Constructor; }; }();

function _classCallCheck(instance, Constructor) { if (!(instance instanceof Constructor)) { throw new TypeError("Cannot call a class as a function"); } }

function _possibleConstructorReturn(self, call) { if (!self) { throw new ReferenceError("this hasn't been initialised - super() hasn't been called"); } return call && (typeof call === "object" || typeof call === "function") ? call : self; }

function _inherits(subClass, superClass) { if (typeof superClass !== "function" && superClass !== null) { throw new TypeError("Super expression must either be null or a function, not " + typeof superClass); } subClass.prototype = Object.create(superClass && superClass.prototype, { constructor: { value: subClass, enumerable: false, writable: true, configurable: true } }); if (superClass) Object.setPrototypeOf ? Object.setPrototypeOf(subClass, superClass) : subClass.__proto__ = superClass; }

// Development file only.
var user = null;
var key = null;

// uncomment the following two lines,
// replace courseinfo.name with courseName
// replace hard-coded leaderboard URL,
// and place leaderboard.php in /opt/webwork/webwork2/htdocs/js/apps/Leaderboard/
// along with "compiled" version of this app.js

var courseNameStr = document.getElementById("courseName").value;
var leaderboardURL = getRootUrl(document.location) + document.getElementById("site_url").value + "/js/apps/Leaderboard/leaderboard.php";

// to do: construct maxExperience in Leaderboards.pm and stash it in id='maxExperience'
// then uncomment this bad boy
// const maxExperience = document.getElementByID('maxExperience').value;

// instead: keep track of highest experience for the class
var maxScore = 0;

function checkCookies() {
  var value = getCookie("WeBWorKCourseAuthen." + courseNameStr); // getCookie defined at the bottom
  user = value.split("\t")[0];
  key = value.split("\t")[1];
}
if (!user & !key) {
  checkCookies();
}

// is it possible to move this css to a leaderboard.css file?
// along with the css styles from the Leaderboards.tmpl file?
// place combined leaderboard.css file in /opt/webwork/webwork2/htdocs/js/apps/Leaderboard

var styles = {
  tableStyle: {
    width: "100%",
    tableLayout: "fixed",
    borderSpacing: "0px",
    border: "1px solid #e6e6e6",
    boxShadow: "0 6px 10px 0 rgba(0, 0, 0, .14), 0 1px 18px 0 rgba(0, 0, 0, .12), 0 3px 5px -1px rgba(0, 0, 0, .2)"
  },
  pStyle: {
    fontFamily: "Helvetica Neue, Helvetica, Arial, sans-serif",
    fontWeight: "300",
    fontSize: "13px",
    textAlign: "center",
    paddingRight: "10%"
  },
  buttonStyle: {
    background: "none",
    color: "inherit",
    border: "none",
    padding: 0,
    font: "inherit",
    cursor: "pointer",
    outline: "inherit"
  },
  divStyle: {
    overflowY: "auto",
    height: "80%",
    width: "70%",
    minWidth: "550px"
  },
  thStyle: {
    backgroundColor: "#003388",
    color: "white",
    fontFamily: "Helvetica Neue, Helvetica, Arial, sans-serif",
    padding: "15px",
    cursor: "pointer"
  },
  tdStyle: {
    textAlign: "center",
    padding: "15px"
  },
  trStyle: {
    height: "2%"
  },
  LeaderItemTrStyle: {
    backgroundColor: "#f6f6f6",
    color: "black",
    fontFamily: "Helvetica Neue, Helvetica, Arial, sans-serif",
    fontWeight: "300",
    padding: "15px",
    borderSpacing: "2px"
  }
};

var LeaderTable = function (_React$Component) {
  _inherits(LeaderTable, _React$Component);

  function LeaderTable() {
    _classCallCheck(this, LeaderTable);

    var _this = _possibleConstructorReturn(this, (LeaderTable.__proto__ || Object.getPrototypeOf(LeaderTable)).call(this));

    _this.state = {
      data: [],
      option: null,
      clicks: 0,
      current: null,
      currentSort: null
    };
    _this.checkOption = _this.checkOption.bind(_this);
    return _this;
  }

  _createClass(LeaderTable, [{
    key: "componentWillMount",
    value: function componentWillMount() {
      var _this2 = this;

      var requestObject = {
        user: user,
        key: key,
        courseName: courseNameStr // replace this with courseName
      };
      // The url  needs to be taken from a global environment variable
      // This would idealy be a variable in the leaderboards.tmpl file
      // leaderboard.php should be placed in /var/www/html/
      // fetch("http://mathww.citytech.cuny.edu/leaderboard.php", {
      //   method: "POST",
      //   headers: { "Content-type": "application/x-www-form-urlencoded" },
      //   body: formEncode(requestObject) // formEncode defined at the bottom
      // })
      //   .then(response => {
      //     if (!response.ok) {
      //       throw Error(response.statusText);
      //     }
      //     return response.json();
      //   })
      //   .then(data => {
      //     data.forEach(item => {
      //       if (item.achievementPoints == null) item.achievementPoints = 0;
      //     });
      //     this.setState({ data });
      //   })
      //   .catch(err => {
      //     console.log("An error has occurred: " + err);
      //   });

      $.post(leaderboardURL,
      //      "http://mathww.citytech.cuny.edu/leaderboard.php", // replace this with leaderboardURL
      requestObject, function (data) {
        data.forEach(function (item) {
          if (item.achievementPoints == null) item.achievementPoints = 0;

          if (parseInt(item.achievementPoints) > maxScore) maxScore = item.achievementPoints;
        });
        console.log(data);
        _this2.setState({ data: data });
      }, "json");
    }
  }, {
    key: "checkOption",
    value: function checkOption(option) {
      this.setState({ clicks: this.state.clicks + 1 });
      var newData = this.state.data;
      if (option.target.id == "Earned") {
        newData.sort(function (a, b) {
          return parseFloat(a.achievementsEarned) - parseFloat(b.achievementsEarned);
        });
        if (this.state.current == "Point") this.setState({ clicks: 0 });
      } else if (option.target.id == "Point") {
        newData.sort(function (a, b) {
          return parseFloat(a.achievementPoints) - parseFloat(b.achievementPoints);
        });
        if (this.state.current == "Earned") this.setState({ clicks: 0 });
      }
      if (this.state.clicks % 2 == 0) {
        this.setState({
          data: newData.reverse(),
          current: option.target.id,
          currentSort: "Desc"
        });
      } else {
        this.setState({
          data: newData,
          current: option.target.id,
          currentSort: "Asc"
        });
      }
    }
  }, {
    key: "renderTable",
    value: function renderTable() {
      var tdStyle = styles.tdStyle;

      var tableInfo = [];
      if (this.state.data.length > 0) {
        for (var i = 0; i < this.state.data.length; i++) {
          var current = this.state.data[i];
          tableInfo.push(React.createElement(
            LeaderTableItem,
            null,
            React.createElement(
              "td",
              { className: "tdStyleLB" },
              current.username ? current.username : current.id
            ),
            React.createElement(
              "td",
              { className: "tdStyleLB" },
              current.achievementsEarned
            ),
            React.createElement(
              "td",
              { className: "tdStyleLB" },
              current.achievementPoints ? current.achievementPoints : 0
            ),
            React.createElement(
              "td",
              { className: "tdStyleLB" },
              React.createElement(Filler, {
                percentage: Math.floor(current.achievementPoints / maxScore * 1000) / 10,
                score: current.achievementPoints
              })
            )
          ));
        }
      }

      return tableInfo;
    }
  }, {
    key: "render",
    value: function render() {
      var tableStyle = styles.tableStyle,
          thStyle = styles.thStyle,
          tdStyle = styles.tdStyle,
          trStyle = styles.trStyle,
          divStyle = styles.divStyle,
          pStyle = styles.pStyle;

      var tableInfo = this.renderTable();

      return React.createElement(
        "div",
        { className: "divStyleLB" },
        React.createElement(
          "table",
          { className: "tableStyleLB" },
          React.createElement(
            "tbody",
            null,
            React.createElement(
              "tr",
              { className: "trStyleLB" },
              React.createElement(
                "th",
                { id: "username", className: "thStyleLB" },
                "Username"
              ),
              React.createElement(
                "th",
                {
                  className: "sortButtons thStyleLB",
                  style: thStyle,
                  id: "Earned",
                  onClick: this.checkOption
                },
                "Achievements Earned",
                this.state.current == "Earned" ? this.state.currentSort == "Asc" ? React.createElement("i", { className: "ion-android-arrow-dropup" }) : React.createElement("i", { className: "ion-android-arrow-dropdown" }) : null
              ),
              React.createElement(
                "th",
                {
                  className: "sortButtons thStyleLB",
                  style: thStyle,
                  id: "Point",
                  onClick: this.checkOption
                },
                "Achievement Points",
                this.state.current == "Point" ? this.state.currentSort == "Asc" ? React.createElement("i", { className: "ion-android-arrow-dropup" }) : React.createElement("i", { className: "ion-android-arrow-dropdown" }) : null
              ),
              React.createElement(
                "th",
                { className: "thStyleLB" },
                "Progress"
              )
            )
          ),
          React.createElement(
            "tbody",
            null,
            tableInfo
          )
        )
      );
    }
  }]);

  return LeaderTable;
}(React.Component);

var LeaderTableItem = function (_React$Component2) {
  _inherits(LeaderTableItem, _React$Component2);

  function LeaderTableItem() {
    _classCallCheck(this, LeaderTableItem);

    return _possibleConstructorReturn(this, (LeaderTableItem.__proto__ || Object.getPrototypeOf(LeaderTableItem)).apply(this, arguments));
  }

  _createClass(LeaderTableItem, [{
    key: "render",
    value: function render() {
      var LeaderItemTrStyle = styles.LeaderItemTrStyle;

      return React.createElement(
        "tr",
        { className: "LeaderItemTr" },
        this.props.children
      );
    }
  }]);

  return LeaderTableItem;
}(React.Component);

var Leaderboard = function (_React$Component3) {
  _inherits(Leaderboard, _React$Component3);

  function Leaderboard() {
    _classCallCheck(this, Leaderboard);

    return _possibleConstructorReturn(this, (Leaderboard.__proto__ || Object.getPrototypeOf(Leaderboard)).apply(this, arguments));
  }

  _createClass(Leaderboard, [{
    key: "render",
    value: function render() {
      var tableStyle = styles.tableStyle,
          thStyle = styles.thStyle,
          tdStyle = styles.tdStyle,
          trStyle = styles.trStyle,
          divStyle = styles.divStyle,
          pStyle = styles.pStyle,
          LeaderItemTrStyle = styles.LeaderItemTrStyle;

      return React.createElement(
        "div",
        null,
        React.createElement(LeaderTable, null),
        React.createElement(
          "p",
          { className: "pStyleLB" },
          React.createElement(
            "i",
            null,
            "Sponsored by Santander Bank"
          )
        )
      );
    }
  }]);

  return Leaderboard;
}(React.Component);

var Filler = function (_React$Component4) {
  _inherits(Filler, _React$Component4);

  function Filler() {
    _classCallCheck(this, Filler);

    var _this5 = _possibleConstructorReturn(this, (Filler.__proto__ || Object.getPrototypeOf(Filler)).call(this));

    _this5.state = { color: null };
    _this5.changeColor = _this5.changeColor.bind(_this5);
    return _this5;
  }

  _createClass(Filler, [{
    key: "changeColor",
    value: function changeColor() {
      var percentage = parseInt(this.props.percentage);
      var colorValue = "";

      switch (true) {
        case percentage < 20:
          colorValue = "#ff6961";
          break;
        case percentage >= 20 && percentage < 40:
          colorValue = "#FF7F50";
          break;
        case percentage >= 40 && percentage < 60:
          colorValue = "#fada5e";
          break;
        case percentage >= 60 && percentage < 80:
          colorValue = "#aedb30";
          break;
        case percentage >= 80:
          colorValue = "#4dff88";
          break;
      }
      return colorValue;
    }
  }, {
    key: "render",
    value: function render() {
      return React.createElement(
        "div",
        {
          className: "filler",
          style: {
            width: this.props.percentage + "%",
            background: this.changeColor()
          }
        },
        React.createElement(
          "p",
          { style: { fontWeight: "100" } },
          this.props.score
        )
      );
    }
  }]);

  return Filler;
}(React.Component);

//Utility functions


function formEncode(obj) {
  var str = [];
  for (var p in obj) {
    str.push(encodeURIComponent(p) + "=" + encodeURIComponent(obj[p]));
  }return str.join("&");
}

function getCookie(cname) {
  var name = cname + "=";
  var decodedCookie = decodeURIComponent(document.cookie);
  var ca = decodedCookie.split(";");
  for (var i = 0; i < ca.length; i++) {
    var c = ca[i];
    while (c.charAt(0) == " ") {
      c = c.substring(1);
    }
    if (c.indexOf(name) == 0) {
      return c.substring(name.length, c.length);
    }
  }
  return "";
}

function getRootUrl(url) {
  return url.toString().replace(/^(.*\/\/[^\/?#]*).*$/, "$1");
}

ReactDOM.render(React.createElement(Leaderboard, null), document.getElementById("LeaderboardPage"));
