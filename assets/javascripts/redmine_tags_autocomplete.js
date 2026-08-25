(function () {
  var TAGS_PAGE_SIZE = 30;

  function lastSelectedTag($el) {
    var selected = $el.val() || [];
    if (!$.isArray(selected)) {
      selected = selected ? [selected] : [];
    }
    return selected.length ? String(selected[selected.length - 1]) : '';
  }

  function patchTagSelect2($el) {
    var s2 = $el.data('select2');
    if (!s2 || !s2.options || !s2.options.options) {
      return;
    }
    var ajax = s2.options.options.ajax;
    if (!ajax || !ajax.url || String(ajax.url).indexOf('auto_completes/redmine_tags') === -1) {
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
      }, 80);
    });
  }

  function highlightLastSelected($el) {
    var last = lastSelectedTag($el);
    if (!last) {
      return;
    }
    var $opts = $('.select2-results__option');
    if (!$opts.length) {
      return;
    }
    $opts.removeClass('select2-results__option--highlighted');
    var $target = $opts.filter(function () {
      return $.trim($(this).text()) === last;
    }).first();
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
  $(document).on('ajax:complete ajaxComplete', function () {
    setTimeout(patchAll, 0);
  });
}());
