(function () {
  function lastSelectedTag($el) {
    var selected = $el.val() || [];
    if (!$.isArray(selected)) {
      selected = selected ? [selected] : [];
    }
    return selected.length ? selected[selected.length - 1] : '';
  }

  function patchTagAjaxData() {
    $('select').each(function () {
      var $el = $(this);
      var s2 = $el.data('select2');
      if (!s2 || !s2.options || !s2.options.options) {
        return;
      }
      var ajax = s2.options.options.ajax;
      if (!ajax || !ajax.url || String(ajax.url).indexOf('auto_completes/redmine_tags') === -1) {
        return;
      }
      ajax.data = function (params) {
        var searching = !!(params.term && String(params.term).trim());
        return {
          q: params.term || '',
          page: params.page || 1,
          limit: 30,
          from: searching ? '' : lastSelectedTag($el)
        };
      };
    });
  }

  $(patchTagAjaxData);
  $(document).on('ajax:complete ajaxComplete', function () {
    setTimeout(patchTagAjaxData, 0);
  });
}());
