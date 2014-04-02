module SimpleNavigation
  # Represents an item in your navigation.
  # Gets generated by the item method in the config-file.
  class Item
    attr_reader :highlights_on,
                :key,
                :method,
                :sub_navigation,
                :url

    attr_writer :html_options

    # see ItemContainer#item
    #
    # The subnavigation (if any) is either provided by a block or
    # passed in directly as <tt>items</tt>
    def initialize(container, key, name, url_or_options = {}, options_or_nil = {}, items = nil, &sub_nav_block)
      options = setup_url_and_options(url_or_options, options_or_nil)

      @key = key
      @method = options.delete(:method)
      @name = name
      @container = container

      setup_sub_navigation(items, &sub_nav_block)
    end

    # Returns the item's name.
    # If :apply_generator option is set to true (default),
    # the name will be passed to the name_generator specified
    # in the configuration.
    #
    def name(options = {})
      options = { apply_generator: true }.merge(options)
      if (options[:apply_generator])
        config.name_generator.call(@name, self)
      else
        @name
      end
    end

    # Returns true if this navigation item should be rendered as 'selected'.
    # An item is selected if
    #
    # * it has a subnavigation and one of its subnavigation items is selected or
    # * its url matches the url of the current request (auto highlighting)
    #
    def selected?
      @selected ||= selected_by_subnav? || selected_by_condition?
    end

    # Returns the html-options hash for the item, i.e. the options specified
    # for this item in the config-file.
    # It also adds the 'selected' class to the list of classes if necessary.
    def html_options
      options = @html_options
      options[:id] ||= autogenerated_item_id

      classes = [@html_options[:class], selected_class, active_leaf_class]
      classes = classes.flatten.compact.join(' ')
      options[:class] = classes if classes && !classes.empty?

      options
    end

    # Returns the configured active_leaf_class if the item is the selected leaf,
    # nil otherwise
    def active_leaf_class
      if !selected_by_subnav? && selected_by_condition?
        config.active_leaf_class
      end
    end

    # Returns the configured selected_class if the item is selected,
    # nil otherwise
    def selected_class
      if selected?
        container.selected_class || config.selected_class
      end
    end

    protected

    # Returns true if item has a subnavigation and
    # the sub_navigation is selected
    def selected_by_subnav?
      sub_navigation && sub_navigation.selected?
    end

    # Returns true if the item's url matches the request's current url.
    def selected_by_condition?
      highlights_on ? selected_by_highlights_on? : selected_by_autohighlight?
    end

    # Returns true if both the item's url and the request's url are root_path
    def root_path_match?
      url == '/' && SimpleNavigation.request_path == '/'
    end

    # Returns the item's id which is added to the rendered output.
    def autogenerated_item_id
      config.id_generator.call(key) if config.autogenerate_item_ids
    end

    # Return true if auto_highlight is on for this item.
    def auto_highlight?
      config.auto_highlight && container.auto_highlight
    end

    def url_without_anchor
      url && url.split('#').first
    end

    private

    attr_reader :container

    attr_writer :highlights_on,
                :sub_navigation,
                :url

    def config
      SimpleNavigation.config
    end

    def request_uri
      SimpleNavigation.request_uri
    end

    def selected_by_autohighlight?
      auto_highlight? &&
      (root_path_match? ||
       (url_without_anchor &&
        SimpleNavigation.current_page?(url_without_anchor)))
    end

    def selected_by_highlights_on?
      case highlights_on
      when Regexp then request_uri =~ highlights_on
      when Proc then highlights_on.call
      when :subpath
        escaped_url = Regexp.escape(url_without_anchor)
        !!(request_uri =~ /^#{escaped_url}(\/|$|\?)/i)
      else
        fail ArgumentError, ':highlights_on must be a Regexp, Proc or :subpath'
      end
    end

    def setup_url_and_options(url_or_options, options_or_nil)
      case url_or_options
      when Hash then options = url_or_options # there is no url
      when Proc then self.url = url_or_options.call
      else self.url = url_or_options
      end

      options ||= options_or_nil
      self.highlights_on = options.delete(:highlights_on)
      self.html_options = options
    end

    def setup_sub_navigation(items = nil, &sub_nav_block)
      return unless sub_nav_block || items

      self.sub_navigation = ItemContainer.new(container.level + 1)

      if sub_nav_block
        sub_nav_block.call sub_navigation
      else
        sub_navigation.items = items
      end
    end
  end
end
