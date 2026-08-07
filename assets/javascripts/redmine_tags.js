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

    // Project settings: drag-and-drop reorder (custom clouds only; system fixed)
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
                    return $(this).data('id');
                }).get();

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
    });

    // ---- Tag cloud form: filter lists ----
    // + opens list and keeps it open; click toggles selection; empty = all
    function syncFilterInputs($panel) {
        var filterName = $panel.data('filter');
        var $inputs = $panel.find('.tag-cloud-filter-inputs');
        $inputs.empty();
        $panel.find('.tag-cloud-filter-option.is-selected').each(function () {
            $('<input>', {
                type: 'hidden',
                name: 'tag_cloud[' + filterName + '][]',
                value: $(this).data('id')
            }).appendTo($inputs);
        });
    }

    $(document).on('click', '.tag-cloud-filter-add', function (e) {
        e.preventDefault();
        var $list = $(this).closest('.tag-cloud-filter-panel').find('.tag-cloud-filter-list');
        $list.prop('hidden', false);
    });

    $(document).on('click', '.tag-cloud-filter-option', function (e) {
        e.preventDefault();
        $(this).toggleClass('is-selected');
        syncFilterInputs($(this).closest('.tag-cloud-filter-panel'));
    });
});
