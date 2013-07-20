(function ($) {
  'use strict';
  function findTruncPoint(dim, max, txt, start, end, $worker, token, reverse) {
    var makeContent = function (content) {
      return (reverse ? token : '') + content + (reverse ? '' : token);
    };

    var opt1, opt2, mid, opt1dim, opt2dim;

    if (reverse) {
      opt1 = start === 0 ? '' : txt.slice(-start);
      opt2 = txt.slice(-end);
    } else {
      opt1 = txt.slice(0, start);
      opt2 = txt.slice(0, end);
    }

    if (max < $worker.html(token)[dim]()) {
      return 0;
    }

    opt1dim = $worker.html(makeContent(opt2))[dim]();
    opt2dim = $worker.html(makeContent(opt1))[dim]();
    if (opt1dim < opt2dim) {
      return end;
    }

    mid = parseInt((start + end) / 2, 10);
    opt1 = reverse ? txt.slice(-mid) : txt.slice(0, mid);

    $worker.html(makeContent(opt1));
    if ($worker[dim]() === max) {
      return mid;
    }

    if ($worker[dim]() > max) {
      end = mid - 1;
    } else {
      start = mid + 1;
    }

    return findTruncPoint(dim, max, txt, start, end, $worker, token, reverse);
  }

  $.fn.truncate = function (options) {
    // backward compatibility
    if (options && !!options.center && !options.side) {
      options.side = 'center';
      delete options.center;
    }

    if (options && !(/^(left|right|center)$/).test(options.side)) {
      delete options.side;
    }

    var defaults = {
      width: 'auto',
      token: '&hellip;',
      side: 'right',
      addclass: false,
      addtitle: false,
      multiline: false
    };
    options = $.extend(defaults, options);

    return this.each(function () {
      var $element = $(this);
      var fontCSS = {
        'fontFamily': $element.css('fontFamily'),
        'fontSize': $element.css('fontSize'),
        'fontStyle': $element.css('fontStyle'),
        'fontWeight': $element.css('fontWeight'),
        'font-variant': $element.css('font-variant'),
        'text-indent': $element.css('text-indent'),
        'text-transform': $element.css('text-transform'),
        'letter-spacing': $element.css('letter-spacing'),
        'word-spacing': $element.css('word-spacing'),
        'display': 'none'
      };
      var elementText = $element.text();
      var $truncateWorker = $('<span/>')
                            .css(fontCSS)
                            .html(elementText)
                            .appendTo('body');
      var originalWidth = $truncateWorker.width();
      var truncateWidth = parseInt(options.width, 10) || $element.width();
      var dimension = 'width';
      var truncatedText, originalDim, truncateDim;

      if (options.multiline) {
        $truncateWorker.width($element.width());
        dimension = 'height';
        originalDim = $truncateWorker.height();
        truncateDim = $element.height() + 1;
      }
      else {
        originalDim = originalWidth;
        truncateDim = truncateWidth;
      }

      if (originalDim > truncateDim) {
        var truncPoint, truncPoint2;
        $truncateWorker.text('');

        if (options.side === 'left') {
          truncPoint = findTruncPoint(
            dimension, truncateDim, elementText, 0, elementText.length,
            $truncateWorker, options.token, true
          );
          truncatedText = [
            options.token,
            elementText.slice(-1 * truncPoint)
          ].join('');

        } else if (options.side === 'center') {
          truncateDim = parseInt(truncateDim / 2, 10) - 1;
          truncPoint = findTruncPoint(
            dimension, truncateDim, elementText, 0, elementText.length,
            $truncateWorker, options.token, false
          );
          truncPoint2 = findTruncPoint(
            dimension, truncateDim, elementText, 0, elementText.length,
            $truncateWorker, '', true
          );
          truncatedText = [
            elementText.slice(0, truncPoint),
            options.token,
            elementText.slice(-1 * truncPoint2)
          ].join('');

        } else if (options.side === 'right') {
          truncPoint = findTruncPoint(
            dimension, truncateDim, elementText, 0, elementText.length,
            $truncateWorker, options.token, false
          );
          truncatedText = [
            elementText.slice(0, truncPoint),
            options.token
          ].join('');
        }

        if (options.addclass) {
          $element.addClass(options.addclass);
        }

        if (options.addtitle) {
          $element.attr('title', elementText);
        }

        $element.empty().append(truncatedText);

      }

      $truncateWorker.remove();
    });
  };
})(jQuery);
