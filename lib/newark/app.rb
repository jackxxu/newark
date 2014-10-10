# Base class that represents your Rack app
module Newark
  module App

    FOUR_O_FOUR = [ 404, {}, [] ].freeze

    HTTP_VERBS = [ :delete, :get, :head, :options,
                   :patch, :post, :put, :trace ].freeze

    def self.included(klass)
      klass.instance_variable_set :@routes, {}
      klass.extend ClassMethods
    end

    module ClassMethods

      HTTP_VERBS.each do |verb|
        define_method verb do |path, *args, &block|
          if block.is_a?(Proc)
            handler = block
            constraints = args[0] || {}
          else
            handler = args[0]
            constraints = args[1] || {}
          end

          define_route(verb.to_s.upcase, path, constraints, handler)
        end
      end

      def define_route(verb, path, constraints, handler)
        @routes[verb] ||= []
        @routes[verb] << Route.new(path, constraints, handler)
      end

      def before(&block)
        @before_hooks ||= []
        @before_hooks << block
      end

      def after(&block)
        @after_hooks ||= []
        @after_hooks << block
      end

      def rescue_from(exception_class, *args, &block)
        if block.is_a?(Proc)
          (@exception_handers ||= {})[exception_class] = block
        else
          (@exception_handers ||= {})[exception_class] = args[0].to_sym
        end
      end
    end

    attr_reader :request, :response

    def initialize(*)
      super
      @before_hooks = self.class.instance_variable_get(:@before_hooks)
      @after_hooks  = self.class.instance_variable_get(:@after_hooks)
      @routes       = self.class.instance_variable_get(:@routes)
      @exception_handers = self.class.instance_variable_get(:@exception_handers)
    end

    def call(env)
      dup._call(env)
    end

    def _call(env)
      @env      = env
      @request  = Request.new(@env)
      @response = Response.new
      route
    rescue => e
      if handler = @exception_handers[e.class]
        if handler.is_a?(Proc)
          handler.call(e)
        else
          send(handler, e)
        end
      else
        raise e
      end
    end

    def headers
      response.headers
    end

    def params
      request.params
    end

    def route
      route = match_route
      if route
        request.params.merge!(route.params)
        if exec_before_hooks
          response.body = exec(route.handler)
          exec_after_hooks
        end
        status, headers, body = response.finish
        [status, headers, body.respond_to?(:body) ? body.body : body]
      else
        FOUR_O_FOUR
      end
    end

    private

    def match_route
      Router.new(routes, request).route
    end

    def routes
      @routes[@request.request_method]
    end

    def exec(action)
      if action.respond_to? :to_sym
        send(action)
      else
        instance_exec(&action)
      end
    end

    def exec_handler(handler)
      exec(handler)
    end

    def exec_before_hooks
      exec_hooks @before_hooks
    end

    def exec_after_hooks
      exec_hooks @after_hooks
    end

    def exec_hooks(hooks)
      return true if hooks.nil?
      hooks.each do |hook|
        return false if exec(hook) == false
      end
    end
  end
end
