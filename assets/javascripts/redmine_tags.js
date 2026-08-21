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

    // ---- Tag cloud form: expand/collapse filter multi-selects ----
    function setFilterOpen($row, open) {
        var $btn = $row.find('.tag-cloud-filter-toggle');
        var $select = $row.find('.tag-cloud-filter-select');
        var $summary = $row.find('.tag-cloud-filter-summary');

        $select.prop('hidden', !open);
        $summary.prop('hidden', open);
        $btn.toggleClass('is-open', open);
        $btn.text(open ? '−' : '+');

        // collapsing clears selection → empty = all
        if (!open) {
            $select.val(null);
        }
    }

    $(document).on('click', '.tag-cloud-filter-toggle', function (e) {
        e.preventDefault();
        var $row = $(this).closest('.tag-cloud-filter-row');
        var open = !$row.find('.tag-cloud-filter-select').prop('hidden');
        setFilterOpen($row, !open);
    });

    // tag_filter checkbox shows/hides tag whitelist panel
    $(document).on('change', '#tag_cloud_tag_filter', function () {
        var on = $(this).is(':checked');
        var $panel = $('#tag-cloud-tags-panel');
        $panel.prop('hidden', !on);
        if (!on) {
            $panel.find('select').val(null);
        }
    });

    // visibility radios show/hide roles panel
    function syncVisibilityPanels() {
        var value = $('input[name="tag_cloud[visibility]"]:checked').val() || 'all';
        var roles = value === 'roles';
        var $panel = $('#tag-cloud-roles-panel');
        $panel.prop('hidden', !roles);
        if (!roles) {
            $panel.find('select').val(null);
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
