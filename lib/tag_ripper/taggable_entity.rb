module TagRipper
  # Follows the state changes of a taggable entity (class, model, or method)
  # as it responds to various Lexical tokens.
  # The idea here is that this class will mutate on each new 'event', where
  # and event is the presence of a new lexical token.
  #
  # TaggableEntities begin in a pre-open state, and become open when their
  # lexical scope opens up. When a new lexical nesting is detected, a child
  # entity is spawned. This creates a sort of recursion that allows a taggable
  # entity to be flexible to any amount of code nesting.
  class TaggableEntity
    def initialize(name: nil, parent: nil)
      @name = name
      @tags = Hash.new { |hash, key| hash[key] = Set.new }
      @ended = false
      @parent = parent
      @type = nil
      @open = false
    end

    def send_event(event_name, lex)
      if respond_to?(event_name, true)
        send(event_name, lex)
      else
        self
      end
    end

    def open?
      @open
    end

    def closed?
      @ended
    end

    def inspect
      "<id=#{id},@name=#{@name},tags=#{@tags},parent=#{@parent}>"
    end

    def tags
      @tags.dup
    end

    def name
      @name.to_s.dup
    end

    protected

    # private

    alias id object_id

    def parent
      @parent
    end

    def add_tag(name, value)
      @tags[name].add(value)
    end

    def named?
      !!@name
    end

    def name=(name)
      @name = name.to_s
    end

    def type=(type)
      @type = type.to_sym
    end

    def open
      @open = true
    end

    def close
      @open = false
      @ended = true
      freeze
    end

    def build_child
      self.class.new(parent: self)
    end

    # Lex is a comment
    def on_comment(lex)
      return self unless lex.tag_comment?

      open
      receiver = named? ? build_child : self
      if TagRipper.config[:only_tags].empty? ||
         TagRipper.config[:only_tags].include?(lex.tag_name)
        receiver.add_tag(lex.tag_name, lex.tag_value)
      end
      receiver
    end

    # Lex is a keyword (e.g. class, module, private, end, etc.)
    def on_kw(lex)
      event_token_method_name = :"#{lex.event}_#{lex.token}"
      return self unless respond_to?(event_token_method_name, true)

      send(event_token_method_name, lex)
    end

    def on_new_taggable_context_kw(_lex)
      return build_child if named?

      open

      self
    end

    alias on_kw_def on_new_taggable_context_kw
    alias on_kw_module on_new_taggable_context_kw
    alias on_kw_class on_new_taggable_context_kw

    def on_kw_end(_lex)
      close
      parent
    end

    def name_from_lex(lex)
      @name = lex.token
      @type = lex.type
      self
    end

    alias on_const name_from_lex
    alias on_ident name_from_lex
  end
end
