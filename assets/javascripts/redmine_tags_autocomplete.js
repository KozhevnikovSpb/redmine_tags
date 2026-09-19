(function () {
  function truthy(value) {
    return value === true || value === 1 || value === '1' || value === 'true';
  }

  function initLocalTagSelect($el) {
    if (!$el.length) {
      return;
    }
    if ($el.data('select2')) {
      $el.select2('destroy');
    }
    var allowCreate = $el.data('allowCreate');
    if (allowCreate === undefined) {
      allowCreate = $el.data('allow-create');
    }
    $el.select2({
      width: '100%',
      tags: truthy(allowCreate),
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
