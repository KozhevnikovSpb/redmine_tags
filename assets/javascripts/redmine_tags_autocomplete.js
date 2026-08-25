(function () {
  var allTags = null;
  var loading = false;

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

  function isTagSelect($el) {
    if ($el.is('#issue_tag_list') || $el.attr('name') === 'issue[tag_list][]') {
      return true;
    }
    return isTagsUrl(ajaxUrlOf($el));
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

  function applyLocal($el) {
    if (!allTags || $el.data('redmine-tags-local')) {
      return;
    }
    if (!isTagSelect($el)) {
      return;
    }
    var select2opts = copySelect2Options($el);
    var s2 = $el.data('select2');
    var wasOpen = s2 && typeof s2.isOpen === 'function' && s2.isOpen();
    if (s2) {
      $el.select2('destroy');
    }
    fillOptions($el, allTags);
    $el.select2(select2opts);
    $el.data('redmine-tags-local', true);
    if (wasOpen) {
      $el.select2('open');
    }
  }

  function convertAll() {
    if (!allTags) {
      return;
    }
    $('select').each(function () {
      applyLocal($(this));
    });
  }

  function preload() {
    if (allTags || loading) {
      convertAll();
      return;
    }
    loading = true;
    var url = '/auto_completes/redmine_tags';
    $('select').each(function () {
      var found = ajaxUrlOf($(this));
      if (isTagsUrl(found)) {
        url = found;
        return false;
      }
    });
    $.ajax({
      url: url,
      dataType: 'json',
      data: {}
    }).done(function (data) {
      allTags = parseTags(data);
      loading = false;
      convertAll();
    }).fail(function () {
      loading = false;
    });
  }

  $(preload);
  $(document).on('ajax:complete ajaxComplete select2:open select2:opening', function () {
    preload();
    convertAll();
  });
  window.setTimeout(preload, 0);
  window.setTimeout(preload, 300);
  window.setTimeout(preload, 1000);
}());
