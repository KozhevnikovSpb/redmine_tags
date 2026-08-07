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

    // ---- Tag cloud form: collapsible toggle filters ----
    function syncFilterPanel($panel) {
        var filterName = $panel.data('filter');
        var $list = $panel.find('.tag-cloud-filter-list');
        var $chips = $panel.find('.tag-cloud-filter-chips');
        var $inputs = $panel.find('.tag-cloud-filter-inputs');
        var selected = [];

        $list.find('.tag-cloud-filter-option.is-selected').each(function () {
            selected.push({
                id: String($(this).data('id')),
                name: $(this).data('name') || $(this).text()
            });
        });

        $chips.empty();
        if (selected.length === 0) {
            $chips.prop('hidden', true);
        } else {
            $chips.prop('hidden', false);
            $.each(selected, function (_, item) {
                $('<span>', {
                    class: 'tag-cloud-filter-chip',
                    'data-id': item.id,
                    text: item.name
                }).appendTo($chips);
            });
        }

        $inputs.empty();
        $.each(selected, function (_, item) {
            $('<input>', {
                type: 'hidden',
                name: 'tag_cloud[' + filterName + '][]',
                value: item.id
            }).appendTo($inputs);
        });
    }

    $(document).on('click', '.tag-cloud-filter-add', function (e) {
        e.preventDefault();
        var $panel = $(this).closest('.tag-cloud-filter-panel');
        var $list = $panel.find('.tag-cloud-filter-list');
        var open = !$list.prop('hidden');
        // close other open lists in the same form
        $panel.closest('.tag-cloud-filters-grid').find('.tag-cloud-filter-list').prop('hidden', true);
        $list.prop('hidden', open);
    });

    $(document).on('click', '.tag-cloud-filter-option', function (e) {
        e.preventDefault();
        $(this).toggleClass('is-selected');
        syncFilterPanel($(this).closest('.tag-cloud-filter-panel'));
    });

    // Click on chip removes selection
    $(document).on('click', '.tag-cloud-filter-chip', function (e) {
        e.preventDefault();
        var $panel = $(this).closest('.tag-cloud-filter-panel');
        var id = String($(this).data('id'));
        $panel.find('.tag-cloud-filter-option').filter(function () {
            return String($(this).data('id')) === id;
        }).removeClass('is-selected');
        syncFilterPanel($panel);
    });
});
