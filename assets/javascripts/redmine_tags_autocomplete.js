(function () {
  var TAGS_PAGE_SIZE = 30;

  function lastSelectedTag($el) {
    var selected = $el.val() || [];
    if (!$.isArray(selected)) {
      selected = selected ? [selected] : [];
    }
    return selected.length ? String(selected[selected.length - 1]) : '';
  }

  function ajaxOptionsOf($el) {
    var s2 = $el.data('select2');
    if (!s2) {
      return null;
    }
    if (s2.dataAdapter && s2.dataAdapter.ajaxOptions) {
      return s2.dataAdapter.ajaxOptions;
    }
    if (s2.options && s2.options.options && s2.options.options.ajax) {
      return s2.options.options.ajax;
    }
    return null;
  }

  function isTagsUrl(url) {
    return url && String(url).indexOf('auto_completes/redmine_tags') !== -1;
  }

  function patchTagSelect2($el) {
    var ajax = ajaxOptionsOf($el);
    if (!ajax || !isTagsUrl(ajax.url)) {
      return;
    }

    ajax.cache = false;
    ajax.data = function (params) {
      var searching = !!(params.term && String(params.term).trim());
      return {
        q: params.term || '',
        page: params.page || 1,
        limit: TAGS_PAGE_SIZE,
        from: searching ? '' : lastSelectedTag($el)
      };
    };
    ajax.processResults = function (data, params) {
      params.page = params.page || 1;
      var items = $.isArray(data) ? data : ((data && data.results) || []);
      var more = data && data.pagination ? !!data.pagination.more : items.length >= TAGS_PAGE_SIZE;
      return {
        results: items,
        pagination: { more: more }
      };
    };

    if ($el.data('redmine-tags-open-bound')) {
      return;
    }
    $el.data('redmine-tags-open-bound', true);
    $el.on('select2:open', function () {
      window.setTimeout(function () {
        highlightLastSelected($el);
      }, 120);
    });
  }

  function highlightLastSelected($el) {
    var last = lastSelectedTag($el);
    var $opts = $('.select2-container--open .select2-results__option');
    if (!$opts.length) {
      return;
    }
    $opts.removeClass('select2-results__option--highlighted');
    var $target = $();
    if (last) {
      $target = $opts.filter(function () {
        return $.trim($(this).text()) === last;
      }).first();
    }
    if (!$target.length) {
      $target = $opts.first();
    }
    $target.addClass('select2-results__option--highlighted');
    if ($target[0] && $target[0].scrollIntoView) {
      $target[0].scrollIntoView({ block: 'start' });
    }
  }

  function patchAll() {
    $('select').each(function () {
      patchTagSelect2($(this));
    });
  }

  $(patchAll);
  $(document).on('ajax:complete ajaxComplete select2:open', function () {
    patchAll();
  });

  // Fallback if adapter options were copied: inject from/page into the request.
  if ($.ajaxPrefilter) {
    $.ajaxPrefilter(function (options) {
      if (!isTagsUrl(options.url)) {
        return;
      }
      var $open = $('select').filter(function () {
        var s2 = $(this).data('select2');
        return s2 && typeof s2.isOpen === 'function' && s2.isOpen();
      }).first();
      if (!$open.length) {
        $open = $('select#issue_tag_list');
      }
      var searching = false;
      var data = options.data;
      if (typeof data === 'string' && /(?:^|&)q=[^&]+/.test(data)) {
        searching = true;
      }
      var extra = {
        page: 1,
        limit: TAGS_PAGE_SIZE
      };
      if (!searching) {
        extra.from = lastSelectedTag($open);
      }
      if (typeof data === 'string') {
        if (!/(?:^|&)page=/.test(data)) {
          options.data += (data ? '&' : '') + $.param(extra);
        } else if (!searching && extra.from && !/(?:^|&)from=/.test(data)) {
          options.data += '&from=' + encodeURIComponent(extra.from);
        }
      } else if (data && typeof data === 'object') {
        if (!data.page) {
          data.page = extra.page;
        }
        data.limit = extra.limit;
        if (!searching && extra.from) {
          data.from = extra.from;
        }
      }
    });
  }
}());
