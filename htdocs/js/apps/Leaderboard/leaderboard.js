"use strict";

var _createClass = function () { function defineProperties(target, props) { for (var i = 0; i < props.length; i++) { var descriptor = props[i]; descriptor.enumerable = descriptor.enumerable || false; descriptor.configurable = true; if ("value" in descriptor) descriptor.writable = true; Object.defineProperty(target, descriptor.key, descriptor); } } return function (Constructor, protoProps, staticProps) { if (protoProps) defineProperties(Constructor.prototype, protoProps); if (staticProps) defineProperties(Constructor, staticProps); return Constructor; }; }();

function _classCallCheck(instance, Constructor) { if (!(instance instanceof Constructor)) { throw new TypeError("Cannot call a class as a function"); } }

function _possibleConstructorReturn(self, call) { if (!self) { throw new ReferenceError("this hasn't been initialised - super() hasn't been called"); } return call && (typeof call === "object" || typeof call === "function") ? call : self; }

function _inherits(subClass, superClass) { if (typeof superClass !== "function" && superClass !== null) { throw new TypeError("Super expression must either be null or a function, not " + typeof superClass); } subClass.prototype = Object.create(superClass && superClass.prototype, { constructor: { value: subClass, enumerable: false, writable: true, configurable: true } }); if (superClass) Object.setPrototypeOf ? Object.setPrototypeOf(subClass, superClass) : subClass.__proto__ = superClass; }

// Development file only.
var user = null;
var key = null;

// get static values from webwork
var courseName = document.getElementById("courseName").value;
var leaderboardURL = document.getElementById("site_url").value + "/js/apps/Leaderboard/leaderboard.php";
var pointsPerProblem = document.getElementById('achievementPPP').value;
var maxScore = 0;

// we must pull the user + key to authenticate for php
// php script is set to require a valid user/key pair
function checkCookies() {
  var value = getCookie("WeBWorKCourseAuthen." + courseName); // getCookie defined at the bottom
  user = value.split("\t")[0];
  key = value.split("\t")[1];
}
if (!user & !key) {
  checkCookies();
}

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
    key: "componentDidMount",
    value: function componentDidMount() {
      var _this2 = this;

      var requestObject = {
        user: user,
        key: key,
        courseName: courseName
      };

      $.post(leaderboardURL, requestObject, function (data) {
        data.forEach(function (item) {
          if (item.achievementPoints == null) item.achievementPoints = 0;
        });
        maxScore = parseInt(data[0].numOfProblems) * parseInt(pointsPerProblem) + parseInt(data[0].achievementPtsSum);
        data.sort(function (a, b) {
          return b.achievementPoints - a.achievementPoints;
        });
        _this2.setState({ data: data, current: "progress" });
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
      } else if (option.target.id == "Point" || option.target.id == "progress") {
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
      var tableInfo = [];
      if (this.state.data.length > 0) {
        for (var i = 0; i < this.state.data.length; i++) {
          var current = this.state.data[i];
          tableInfo.push(React.createElement(
            LeaderTableItem,
            { rID: current.id },
            React.createElement(
              "td",
              { className: "tdStyleLB" },
              current.username ? current.username : "Anonymous"
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
                percentage: Math.floor(current.achievementPoints / maxScore * 1000) / 10
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

      var tableInfo = this.renderTable();

      return React.createElement(
        "div",
        { className: "lbContainer" },
        React.createElement(
          "table",
          { className: "lbTable" },
          React.createElement(
            "caption",
            null,
            "Sponsored by Santander Bank"
          ),
          React.createElement(
            "thead",
            null,
            React.createElement(
              "tr",
              null,
              React.createElement(
                "th",
                { id: "username" },
                "Username"
              ),
              React.createElement(
                "th",
                {
                  className: "sortButtons",
                  id: "Earned",
                  onClick: this.checkOption
                },
                "Achievements Earned",
                this.state.current == "Earned" ? this.state.currentSort == "Asc" ? React.createElement("i", { className: "ion-android-arrow-dropup" }) : React.createElement("i", { className: "ion-android-arrow-dropdown" }) : null
              ),
              React.createElement(
                "th",
                {
                  className: "sortButtons",
                  id: "Point",
                  onClick: this.checkOption
                },
                "Achievement Points",
                this.state.current == "Point" ? this.state.currentSort == "Asc" ? React.createElement("i", { className: "ion-android-arrow-dropup" }) : React.createElement("i", { className: "ion-android-arrow-dropdown" }) : null
              ),
              React.createElement(
                "th",
                {
                  className: "sortButtons",
                  id: "progress",
                  onClick: this.checkOption
                },
                "Achievement Points Collected",
                this.state.current == "progress" ? this.state.currentSort == "Asc" ? React.createElement("i", { className: "ion-android-arrow-dropup" }) : React.createElement("i", { className: "ion-android-arrow-dropdown" }) : null
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
      if (this.props.rID == user) {
        return React.createElement(
          "tr",
          { className: "myRow" },
          this.props.children
        );
      }
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

      return React.createElement(
        "div",
        null,
        React.createElement(LeaderTable, null)
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
      var perc = parseInt(this.props.percentage);
      var r,
          g,
          b = 0;
      if (perc < 50) {
        r = 255;
        g = Math.round(5.1 * perc);
      } else {
        g = 255;
        r = Math.round(510 - 5.10 * perc);
      }
      var h = r * 0x10000 + g * 0x100 + b * 0x1;
      return '#' + ('000000' + h.toString(16)).slice(-6);
    }
  }, {
    key: "render",
    value: function render() {
      return React.createElement(
        "div",
        { className: "fillerContainer" },
        React.createElement("span", { className: "fillerBar",
          style: {
            width: this.props.percentage + "%",
            background: this.changeColor()
          }
        }),
        React.createElement(
          "div",
          { className: "fillerLabel",
            style: {
              left: this.props.percentage + "%"
            } },
          this.props.percentage,
          "%"
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

ReactDOM.render(React.createElement(Leaderboard, null), document.getElementById("LeaderboardPage"));
