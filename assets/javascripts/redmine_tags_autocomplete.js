(function () {
  function isTagsUrl(url) {
    return url && String(url).indexOf('auto_completes/redmine_tags') !== -1;
  }

  function parseTags(data) {
    return $.isArray(data) ? data : ((data && data.results) || []);
  }

  function ajaxUrlOf($el) {
    var s2 = $el.data('select2');
    if (!s2) {
      return '';
    }
    if (s2.dataAdapter && s2.dataAdapter.ajaxOptions && s2.dataAdapter.ajaxOptions.url) {
      return s2.dataAdapter.ajaxOptions.url;
    }
    if (s2.options && s2.options.options && s2.options.options.ajax) {
      return s2.options.options.ajax.url || '';
    }
    return '';
  }

  function copySelect2Options($el) {
    var s2 = $el.data('select2');
    var current = (s2 && s2.options && s2.options.options) || {};
    return {
      width: current.width || '100%',
      placeholder: current.placeholder,
      allowClear: current.allowClear,
      tags: current.tags,
      tokenSeparators: current.tokenSeparators || [',', ' '],
      multiple: true,
      closeOnSelect: current.closeOnSelect
    };
  }

  function fillOptions($el, items) {
    var selected = $el.val() || [];
    if (!$.isArray(selected)) {
      selected = selected ? [selected] : [];
    }
    var selectedMap = {};
    $.each(selected, function (_, name) {
      selectedMap[String(name)] = true;
    });
    $el.empty();
    $.each(items, function (_, item) {
      var name = String(item.id || item.text || '');
      if (!name) {
        return;
      }
      $el.append(new Option(item.text || name, name, !!selectedMap[name], !!selectedMap[name]));
    });
  }

  function convertToLocal($el) {
    if ($el.data('redmine-tags-local') || $el.data('redmine-tags-local-loading')) {
      return;
    }
    var url = ajaxUrlOf($el);
    if (!isTagsUrl(url)) {
      return;
    }
    $el.data('redmine-tags-local-loading', true);
    var select2opts = copySelect2Options($el);
    $.ajax({
      url: url,
      dataType: 'json',
      data: {}
    }).done(function (data) {
      var items = parseTags(data);
      var wasOpen = false;
      var s2 = $el.data('select2');
      if (s2 && typeof s2.isOpen === 'function') {
        wasOpen = s2.isOpen();
      }
      if (s2) {
        $el.select2('destroy');
      }
      fillOptions($el, items);
      $el.select2(select2opts);
      $el.data('redmine-tags-local', true);
      $el.data('redmine-tags-local-loading', false);
      if (wasOpen) {
        $el.select2('open');
      }
    }).fail(function () {
      $el.data('redmine-tags-local-loading', false);
    });
  }

  function patchAll() {
    $('select').each(function () {
      convertToLocal($(this));
    });
  }

  $(patchAll);
  $(document).on('ajax:complete ajaxComplete', function () {
    setTimeout(patchAll, 0);
  });
}());
