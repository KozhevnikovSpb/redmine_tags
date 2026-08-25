(function () {
  var cacheByUrl = {};

  function isTagsUrl(url) {
    return url && String(url).indexOf('auto_completes/redmine_tags') !== -1;
  }

  function parseTags(data) {
    return $.isArray(data) ? data : ((data && data.results) || []);
  }

  function filterTags(items, term) {
    var q = $.trim(term || '').toLowerCase();
    if (!q) {
      return items;
    }
    return $.grep(items, function (item) {
      return String(item.text || item.id || '').toLowerCase().indexOf(q) !== -1;
    });
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

  function patchTagSelect2($el) {
    var ajax = ajaxOptionsOf($el);
    if (!ajax || !isTagsUrl(ajax.url) || ajax.__redmineTagsFullList) {
      return;
    }
    ajax.__redmineTagsFullList = true;
    ajax.cache = false;
    ajax.data = function (params) {
      return { q: params.term || '' };
    };
    ajax.processResults = function (data) {
      return {
        results: parseTags(data),
        pagination: { more: false }
      };
    };
    ajax.transport = function (params, success, failure) {
      var url = ajax.url;
      var term = '';
      if (params && params.data) {
        term = params.data.q || params.data.term || '';
      }
      function respond(items) {
        success({
          results: filterTags(items, term),
          pagination: { more: false }
        });
      }
      if (cacheByUrl[url]) {
        respond(cacheByUrl[url]);
        return;
      }
      $.ajax({
        url: url,
        dataType: 'json',
        data: {}
      }).done(function (data) {
        cacheByUrl[url] = parseTags(data);
        respond(cacheByUrl[url]);
      }).fail(failure);
    };
  }

  function patchHighlight($el) {
    var s2 = $el.data('select2');
    if (!s2 || !s2.results || $el.data('redmine-tags-highlight-patched')) {
      return;
    }
    $el.data('redmine-tags-highlight-patched', true);
    s2.results.highlightFirstItem = function () {
      if (this.$results && this.$results.scrollTop() > 0) {
        return;
      }
      var $options = this.$results.find('.select2-results__option--selectable');
      if ($options.length) {
        $options.first().trigger('mouseenter');
      }
    };
    s2.results.ensureHighlightVisible = function () {};
  }

  function patchAll() {
    $('select').each(function () {
      var $el = $(this);
      patchTagSelect2($el);
      patchHighlight($el);
    });
  }

  $(patchAll);
  $(document).on('ajax:complete ajaxComplete select2:open', function () {
    patchAll();
  });
}());
