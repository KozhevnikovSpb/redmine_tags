(function () {
  function initLocalTagSelect($el) {
    if (!$el.length) {
      return;
    }
    if ($el.data('select2')) {
      $el.select2('destroy');
    }
    $el.select2({
      width: '100%',
      tags: true,
      tokenSeparators: [',', ' '],
      multiple: true
    });
    $el.data('redmine-tags-local', true);
  }

  function initAll() {
    $('.redmine-tags-local-select').each(function () {
      initLocalTagSelect($(this));
    });
  }

  $(initAll);
  $(document).on('ajax:complete ajaxComplete', function () {
    setTimeout(initAll, 0);
  });
}());
