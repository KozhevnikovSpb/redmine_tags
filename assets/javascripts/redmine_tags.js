$(function () {
    $('body').on('click', '.most_used_tags .most_used_tag', function (e) {
        var $tagsSelect = $('select#issue_tag_list');
        var tag = $(e.currentTarget).text();

        if ($tagsSelect.find('option').filter(function () { return $(this).val() === tag; }).length === 0) {
            var newOption = new Option(tag, tag, true, true);
            $tagsSelect.append(newOption).trigger('change');
        }

        window.mostUsedTags = $.grep(window.mostUsedTags || [], function (item) { return item !== tag; });
        var $container = $(e.currentTarget).parent('.most_used_tags').empty();

        $.each(window.mostUsedTags, function (index, item) {
            if (index > 0) {
                $container.append(document.createTextNode(', '));
            }
            $('<span>', { class: 'most_used_tag', text: item }).appendTo($container);
        });
    });

    function initTagCloudsSettingsSortable() {
        var $tbody = $('#tag-clouds-sortable-settings');
        if (!$tbody.length || typeof $.fn.sortable !== 'function') {
            return;
        }
        if ($tbody.data('ui-sortable')) {
            return;
        }

        var reorderUrl = $tbody.data('reorder-url');

        $tbody.sortable({
            handle: '.tag-cloud-drag-handle',
            axis: 'y',
            items: 'tr:not(.system)',
            cancel: 'tr.system, a, button',
            helper: function (e, tr) {
                var $originals = tr.children();
                var $helper = tr.clone();
                $helper.children().each(function (index) {
                    $(this).width($originals.eq(index).outerWidth());
                });
                return $helper;
            },
            placeholder: 'tag-cloud-settings-placeholder',
            tolerance: 'pointer',
            update: function () {
                var $system = $tbody.children('tr.system');
                if ($system.length) {
                    $tbody.prepend($system);
                }

                var ids = $tbody.find('tr[data-id]').map(function () {
                    var id = $(this).data('id');
                    return (id && id !== 'system') ? id : null;
                }).get().filter(function (id) { return id !== null; });

                if (!reorderUrl || !ids.length) {
                    return;
                }

                $.ajax({
                    url: reorderUrl,
                    type: 'POST',
                    dataType: 'text',
                    data: {
                        tag_cloud_ids: ids,
                        authenticity_token: $('meta[name="csrf-token"]').attr('content')
                    }
                });
            }
        });
    }

    initTagCloudsSettingsSortable();
    $(document).on('ajax:complete', function () {
        initTagCloudsSettingsSortable();
        syncTagCloudsCheckAll();
    });

    function visibleTagCloudBoxes() {
        return $('#select-visible-tag-clouds-form .tag-clouds-visibility-list input[type="checkbox"]');
    }

    function syncTagCloudsCheckAll() {
        var $master = $('#tag-clouds-check-all');
        var $boxes = visibleTagCloudBoxes();
        if (!$master.length || !$boxes.length) {
            return;
        }
        var total = $boxes.length;
        var checked = $boxes.filter(':checked').length;
        $master.prop('checked', checked === total);
        $master.prop('indeterminate', checked > 0 && checked < total);
    }

    $(document).on('change', '#tag-clouds-check-all', function () {
        visibleTagCloudBoxes().prop('checked', $(this).is(':checked'));
        $(this).prop('indeterminate', false);
    });

    $(document).on('change', '#select-visible-tag-clouds-form .tag-clouds-visibility-list input[type="checkbox"]', function () {
        syncTagCloudsCheckAll();
    });

    syncTagCloudsCheckAll();

    function fitSelectWidth($select) {
        var el = $select[0];
        if (!el || !el.options || !el.options.length) {
            return;
        }
        var longest = '';
        for (var i = 0; i < el.options.length; i++) {
            var t = el.options[i].text || '';
            if (t.length > longest.length) {
                longest = t;
            }
        }
        var $probe = $('<span>').css({
            position: 'absolute',
            visibility: 'hidden',
            whiteSpace: 'nowrap',
            font: $select.css('font'),
            fontSize: $select.css('font-size'),
            fontFamily: $select.css('font-family'),
            padding: '0 8px'
        }).text(longest).appendTo('body');
        var multi = $select.is('[multiple]') || parseInt($select.attr('size'), 10) > 1;
        var extra = multi ? 44 : 28;
        var w = Math.max(160, Math.ceil($probe.outerWidth()) + extra);
        $probe.remove();
        $select.css('width', w + 'px');
    }

    var VALUE_OPS = ['=', '!', 'ev', '!ev', 'cf'];
    var previewTimer = null;

    function rowNeedsValues($row) {
        var op = $row.find('.tag-cloud-filter-operator').val();
        return VALUE_OPS.indexOf(op) !== -1;
    }

    function setToggleHidden($el, hidden) {
        $el.prop('hidden', hidden);
        if (hidden) {
            $el.attr('hidden', 'hidden');
        } else {
            $el.removeAttr('hidden');
        }
    }

    function setFilterOpen($row, open, opts) {
        opts = opts || {};
        var $btn = $row.find('.tag-cloud-filter-toggle');
        var $select = $row.find('select.tag-cloud-filter-select').first();
        var count = $select.find('option').length;
        $btn.attr('data-open', open ? '1' : '0');
        $btn.text(open ? '\u2212' : '+');
        $row.toggleClass('is-open', !!open);
        if (open) {
            $select.attr('multiple', 'multiple');
            $select.attr('size', Math.min(Math.max(count, 4), 6));
        } else {
            var val = $select.val();
            $select.removeAttr('multiple');
            $select.attr('size', 1);
            if ($.isArray(val)) {
                $select.val(val.length ? val[0] : null);
            }
        }
        fitSelectWidth($select);
        if (!opts.silent) {
            schedulePreview();
        }
    }

    function syncOperatorRow($row, opts) {
        opts = opts || {};
        var needs = rowNeedsValues($row);
        var $select = $row.find('select.tag-cloud-filter-select').first();
        var $btn = $row.find('.tag-cloud-filter-toggle');
        $row.toggleClass('no-values', !needs);
        if (!needs) {
            $select.val(null);
            setFilterOpen($row, false, { silent: true });
            setToggleHidden($select, true);
            setToggleHidden($btn, true);
        } else {
            setToggleHidden($select, false);
            setToggleHidden($btn, false);
            setFilterOpen($row, $btn.attr('data-open') === '1', { silent: true });
        }
        if (!opts.silent) {
            schedulePreview();
        }
    }

    function selectedValues($select) {
        if (!$select.length || $select.prop('hidden') || $select.is('[hidden]')) {
            return [];
        }
        var val = $select.val();
        if (val == null || val === '') {
            return [];
        }
        return $.isArray(val) ? val : [val];
    }

    function collectPreviewParams() {
        var $form = $('.tag-cloud-form');
        var tagFilterOn = $('#tag_cloud_tag_filter').is(':checked');
        return {
            status_operator: $form.find('select[name="tag_cloud[status_operator]"]').val() || '*',
            version_operator: $form.find('select[name="tag_cloud[version_operator]"]').val() || '*',
            tracker_operator: $form.find('select[name="tag_cloud[tracker_operator]"]').val() || '*',
            status_filter: selectedValues($form.find('select[name="tag_cloud[status_filter][]"]')),
            version_filter: selectedValues($form.find('select[name="tag_cloud[version_filter][]"]')),
            tracker_filter: selectedValues($form.find('select[name="tag_cloud[tracker_filter][]"]')),
            tag_filter: tagFilterOn ? '1' : '0',
            tag_ids: tagFilterOn ? ($form.find('select[name="tag_cloud[tag_ids][]"]').val() || []) : [],
            include_subprojects: $('#tag_cloud_include_subprojects').is(':checked') ? '1' : '0',
            authenticity_token: $('meta[name="csrf-token"]').attr('content')
        };
    }

    function refreshPreview() {
        var $form = $('.tag-cloud-form');
        var url = $form.data('preview-url');
        var $body = $('#tag-cloud-preview-body');
        if (!url || !$form.length || !$body.length) {
            return;
        }
        $.ajax({
            url: url,
            type: 'POST',
            dataType: 'html',
            data: collectPreviewParams()
        }).done(function (html) {
            $body.html(html || '');
        }).fail(function () {
            var emptyLabel = $form.data('label-empty') || '\u2014';
            $body.html($('<p>', { class: 'tag-cloud-empty', text: emptyLabel }));
        });
    }

    function schedulePreview() {
        if (previewTimer) {
            clearTimeout(previewTimer);
        }
        previewTimer = setTimeout(refreshPreview, 250);
    }

    $(document).on('click', '.tag-cloud-filter-toggle', function (e) {
        e.preventDefault();
        e.stopPropagation();
        var $row = $(this).closest('.tag-cloud-filter-row');
        if (!rowNeedsValues($row)) {
            return;
        }
        var open = $(this).attr('data-open') === '1';
        setFilterOpen($row, !open);
    });

    $(document).on('change', '.tag-cloud-form select.tag-cloud-filter-operator', function () {
        var $row = $(this).closest('.tag-cloud-filter-row');
        syncOperatorRow($row);
        fitSelectWidth($(this));
    });

    $(document).on('change', '.tag-cloud-form select.tag-cloud-filter-select', function () {
        schedulePreview();
    });

    $('.tag-cloud-form .tag-cloud-filter-row').each(function () {
        syncOperatorRow($(this), { silent: true });
    });

    $('.tag-cloud-form .tag-cloud-filter-select:not([hidden])').each(function () {
        fitSelectWidth($(this));
    });

    $('.tag-cloud-form .tag-cloud-filter-operator').each(function () {
        fitSelectWidth($(this));
    });

    $(document).on('change', '#tag_cloud_tag_filter', function () {
        var on = $(this).is(':checked');
        var $panel = $('#tag-cloud-tags-panel');
        $panel.prop('hidden', !on);
        if (!on) {
            $panel.find('select').val(null);
        } else {
            $panel.find('.tag-cloud-filter-select').each(function () {
                fitSelectWidth($(this));
            });
        }
        schedulePreview();
    });

    $(document).on('change', '#tag_cloud_include_subprojects', function () {
        schedulePreview();
    });

    function syncVisibilityPanels() {
        var value = $('input[name="tag_cloud[visibility]"]:checked').val() || 'all';
        var roles = value === 'roles';
        var $panel = $('#tag-cloud-roles-panel');
        $panel.prop('hidden', !roles);
        if (!roles) {
            $panel.find('select').val(null);
        } else {
            $panel.find('.tag-cloud-filter-select').each(function () {
                fitSelectWidth($(this));
            });
        }
    }

    $(document).on('change', 'input[name="tag_cloud[visibility]"]', function () {
        syncVisibilityPanels();
    });

    if ($('.tag-cloud-form').length) {
        syncVisibilityPanels();
        if (!$('#tag_cloud_tag_filter').is(':checked')) {
            $('#tag-cloud-tags-panel').prop('hidden', true);
        }
        refreshPreview();
    }
});
