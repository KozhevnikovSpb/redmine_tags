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
    });

    // ---- Tag cloud form: filter lists ----
    function labelAll() {
        return $('.tag-cloud-form').data('label-all') || 'all';
    }

    function syncFilterPanel($panel) {
        var filterName = $panel.data('filter');
        var $inputs = $panel.find('.tag-cloud-filter-inputs');
        var $count = $panel.find('.tag-cloud-filter-count');
        var count = $panel.find('.tag-cloud-filter-option.is-selected').length;

        $inputs.empty();
        $panel.find('.tag-cloud-filter-option.is-selected').each(function () {
            $('<input>', {
                type: 'hidden',
                name: 'tag_cloud[' + filterName + '][]',
                value: $(this).data('id')
            }).appendTo($inputs);
        });

        if ($count.length) {
            if (filterName === 'tag_ids' || filterName === 'role_ids') {
                $count.text(count === 0 ? '· —' : '(' + count + ')');
            } else if (count === 0) {
                $count.text(labelAll());
            } else {
                $count.text('(' + count + ')');
            }
        }
    }

    function setToggleState($panel, open) {
        var $btn = $panel.find('.tag-cloud-filter-toggle');
        var $list = $panel.find('.tag-cloud-filter-list');
        $list.prop('hidden', !open);
        $btn.toggleClass('is-open', open);
        $btn.text(open ? '−' : '+');
    }

    $(document).on('click', '.tag-cloud-filter-toggle', function (e) {
        e.preventDefault();
        var $panel = $(this).closest('.tag-cloud-filter-panel');
        var $list = $panel.find('.tag-cloud-filter-list');
        var open = $list.prop('hidden');
        setToggleState($panel, open);
    });

    $(document).on('click', '.tag-cloud-filter-option', function (e) {
        e.preventDefault();
        $(this).toggleClass('is-selected');
        syncFilterPanel($(this).closest('.tag-cloud-filter-panel'));
    });

    // tag_filter checkbox shows/hides tag whitelist panel
    $(document).on('change', '#tag_cloud_tag_filter', function () {
        var on = $(this).is(':checked');
        $('#tag-cloud-tags-panel').prop('hidden', !on);
        if (!on) {
            $('#tag-cloud-tags-panel .tag-cloud-filter-option.is-selected').removeClass('is-selected');
            syncFilterPanel($('#tag-cloud-tags-panel'));
        }
    });

    // visibility radios show/hide roles panel
    function syncVisibilityPanels() {
        var value = $('input[name="tag_cloud[visibility]"]:checked').val() || 'all';
        var roles = value === 'roles';
        $('#tag-cloud-roles-panel').prop('hidden', !roles);
        if (!roles) {
            $('#tag-cloud-roles-panel .tag-cloud-filter-option.is-selected').removeClass('is-selected');
            syncFilterPanel($('#tag-cloud-roles-panel'));
        }
    }

    $(document).on('change', 'input[name="tag_cloud[visibility]"]', function () {
        syncVisibilityPanels();
    });

    // initial state on form load
    if ($('.tag-cloud-form').length) {
        syncVisibilityPanels();
        if (!$('#tag_cloud_tag_filter').is(':checked')) {
            $('#tag-cloud-tags-panel').prop('hidden', true);
        }
    }
});
