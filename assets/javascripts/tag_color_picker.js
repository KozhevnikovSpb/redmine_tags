(function ($) {
  function normalizeHex(value) {
    var raw = String(value || '').replace(/^#/, '').trim();
    if (/^[0-9a-fA-F]{6}$/.test(raw)) {
      return '#' + raw.toLowerCase();
    }
    return '';
  }

  function textColor(hex) {
    var n = normalizeHex(hex);
    if (!n) {
      return '#1f2937';
    }
    function lin(c) {
      c = c / 255;
      return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
    }
    var r = parseInt(n.slice(1, 3), 16);
    var g = parseInt(n.slice(3, 5), 16);
    var b = parseInt(n.slice(5, 7), 16);
    var lum = 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b);
    return lum < 0.45 ? '#f8fafc' : '#1f2937';
  }

  function paintPreview($preview, hex) {
    $preview.css({
      'background-color': hex,
      color: textColor(hex)
    });
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
        paintPreview($preview, mutedAuto);
        highlight('');
        return;
      }
      $text.val(hex);
      $native.val(hex);
      paintPreview($preview, hex);
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
