(function ($) {
  function normalizeHex(value) {
    var raw = String(value || '').replace(/^#/, '').trim();
    if (/^[0-9a-fA-F]{6}$/.test(raw)) {
      return '#' + raw.toLowerCase();
    }
    return '';
  }

  function initTagColorEditor($root) {
    var $text = $root.find('.tag-color-hex');
    var $native = $root.find('.tag-color-native');
    var $preview = $root.find('.tag-color-preview');
    var mutedAuto = $root.data('auto-muted') || '#93c5fd';

    function highlight(hex) {
      $root.find('.tag-color-swatch').removeClass('is-selected');
      if (hex) {
        $root.find('.tag-color-swatch').filter(function () {
          return String($(this).data('color')).toLowerCase() === hex;
        }).addClass('is-selected');
      }
    }

    function apply(hex, fromAuto) {
      if (fromAuto || !hex) {
        $text.val('');
        $native.val(mutedAuto);
        $preview.css('background-color', mutedAuto);
        highlight('');
        return;
      }
      $text.val(hex);
      $native.val(hex);
      $preview.css('background-color', hex);
      highlight(hex);
    }

    $root.on('click', '.tag-color-swatch', function (e) {
      e.preventDefault();
      apply(normalizeHex($(this).data('color')), false);
    });

    $root.on('click', '.tag-color-auto', function (e) {
      e.preventDefault();
      apply('', true);
    });

    $native.on('input change', function () {
      var hex = normalizeHex(this.value);
      if (hex) {
        apply(hex, false);
      }
    });

    $text.on('change', function () {
      var hex = normalizeHex(this.value);
      if (hex) {
        apply(hex, false);
      } else {
        apply('', true);
      }
    });
  }

  $(function () {
    $('.tag-color-editor').each(function () {
      initTagColorEditor($(this));
    });
  });
})(jQuery);
