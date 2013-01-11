require 'pp'

module MapLayers
  module JsExtension

    class MapBuilder
      include JsWrapper
      attr_reader :map, :map_handler

      def initialize(map_name, options = {}, &block)
        @js = JsGenerator.new
        self.variable = map_name
        @map = Map.new(map_name, options)
        @map_handler = MapHandler.new(@map, options)

        @js << @map.js
        @js << @map_handler.js
        yield(self, @js) if block_given?
      end

      def create_vector_layer(name, url, options = {})
        projection = options[:projection] || JsExpr.new("#{@map.variable}.displayProjection")
        format = options[:format] || nil
        protocol = url.nil? ? {} : {
            :strategies => [OpenLayers::Strategy::Fixed.new], #, OpenLayers::Strategy::Cluster.new],
            :protocol => OpenLayers::Protocol::HTTP.new({
              :url => url,
              :format => format
            })
          }

        OpenLayers::Layer::Vector.new(name, {
            :projection => projection
          }.merge(protocol))
      end

      def replace_vector_layer(name, url, options = {})
        js = JsGenerator.new
        js << JsVar.new(@map_handler.variable).destroy_layer(name)
        js << add_vector_layer(name, url, options)

        js.to_s.html_safe
      end

      def add_vector_layer(name, url, options = {})
        no_global = options[:no_global]
        no_controls = options[:no_controls]
        format = options[:format] || :kml
        layer_name = name.parameterize

        js = JsGenerator.new

        frmt = case format
        when :georss
        else # :kml is the default
          OpenLayers::Format::KML.new({:extractStyles => true, :extractAttributes => true})
        end

        layer = create_vector_layer(name, url, options.merge(
            :format => frmt))

        @map.variables << layer_name

        js << JsVar.new(layer_name).assign(layer)
        js << JsVar.new(@map.variable).add_layer(JsVar.new(layer_name))

        js.to_s.html_safe
      end



      def to_js(options = {})
        method_name = "map_layers_init_#{variable}"

        variables = []
        # map js variables
        variables << map.variable
        variables.concat(map.variables)
        # map_handler js variable
        variables << map_handler.variable

        js = JsGenerator.new #(:included => true)

        # declare variables
        js << declare(variables.join(','))

        # init builder variable to null, to avoid multiple map loading
        js << JsExpr.new("#{variable} = null")
        js << "function #{method_name}() {\nif (#{variable} == null) {\n#{@js.to_s}}\n}"

        js.to_s.html_safe
      end

      def to_html(options = {})
        no_script_tag = options[:no_script_tag]

        html = ""
        #html << "<script defer=\"defer\" type=\"text/javascript\">\n" if !no_script_tag
        html << no_script_tag ? to_js(options) : javascript_tag(to_js(options))
        #html << "</script>" if !no_script_tag

        html.html_safe
      end
      alias_method :to_s, :to_html
    end

  end
end