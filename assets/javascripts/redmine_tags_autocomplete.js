(function () {
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
        return {
          q: params.term || '',
          page: params.page || 1,
          limit: 30
        };
      };
    });
  }

  $(patchTagAjaxData);
  $(document).on('ajax:complete ajaxComplete', function () {
    setTimeout(patchTagAjaxData, 0);
  });
}());
