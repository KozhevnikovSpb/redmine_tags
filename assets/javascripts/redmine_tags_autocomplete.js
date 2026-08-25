(function () {
  var TAGS_PAGE_SIZE = 30;

  function isTagsUrl(url) {
    return url && String(url).indexOf('auto_completes/redmine_tags') !== -1;
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

  function scrollResultsToStart($el) {
    var s2 = $el.data('select2');
    var $results = (s2 && s2.results && s2.results.$results) ||
      $('.select2-container--open .select2-results__options');
    if (!$results || !$results.length) {
      return;
    }
    $results.scrollTop(0);
  }

  function patchHighlight($el) {
    var s2 = $el.data('select2');
    if (!s2 || !s2.results || $el.data('redmine-tags-highlight-patched')) {
      return;
    }
    $el.data('redmine-tags-highlight-patched', true);

    s2.results.highlightFirstItem = function () {
      if (this.$results.scrollTop() > 0) {
        return;
      }
      var $options = this.$results.find('.select2-results__option--selectable');
      if ($options.length) {
        $options.first().trigger('mouseenter');
      }
    };
    s2.results.ensureHighlightVisible = function () {};

    $el.on('select2:open', function () {
      window.setTimeout(function () {
        scrollResultsToStart($el);
      }, 0);
    });
  }

  function patchAjax($el) {
    var ajax = ajaxOptionsOf($el);
    if (!ajax || !isTagsUrl(ajax.url)) {
      return;
    }
    ajax.cache = false;
    ajax.data = function (params) {
      return {
        q: params.term || '',
        page: params.page || 1,
        limit: TAGS_PAGE_SIZE
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
  }

  function patchAll() {
    $('select').each(function () {
      var $el = $(this);
      patchAjax($el);
      patchHighlight($el);
    });
  }

  $(patchAll);
  $(document).on('ajax:complete ajaxComplete select2:open', function () {
    patchAll();
  });
}());
