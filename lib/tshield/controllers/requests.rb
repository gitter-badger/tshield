# encoding: utf-8

require 'sinatra'

require 'byebug'

require 'tshield/options'
require 'tshield/configuration'
require 'tshield/request'
require 'tshield/sessions'

module TShield
  module Controllers
    module Requests
      PATHP = /([a-zA-Z0-9\/\._-]+)/

      def self.registered(app)
        app.configure :production, :development do
          app.enable :logging
        end
        
        app.get (PATHP) do
          treat(params, request, response)
        end

        app.post (PATHP) do
          treat(params, request, response)
        end

        app.put (PATHP) do
          treat(params, request, response)
        end

        app.patch (PATHP) do
          treat(params, request, response)
        end

        app.head (PATHP) do
          treat(params, request, response)
        end

        app.delete (PATHP) do
          treat(params, request, response)
        end
      end

      module Helpers
        def treat(params, request, response)
          path = params.fetch('captures', [])[0]

          debugger if TShield::Options.instance.break?(path: path, moment: :before)

          method = request.request_method
          request_content_type = request.content_type

          headers = {
            'Content-Type' => request.content_type || 'application/json'
          }

          add_headers(headers, path)

          options = {
            method: method,
            headers: headers,
            raw_query: request.env['QUERY_STRING'],
            ip: request.ip
          }

          if ['POST', 'PUT', 'PATCH'].include? method
            result = request.body.read.encode('UTF-8', {
              :invalid => :replace,
              :undef   => :replace,
              :replace => ''
            })
            options[:body] = result
          end

          set_content_type content_type

          api_response = TShield::Request.new(path, options).response

          logger.info(
            "original=#{api_response.original} method=#{method} path=#{path} content-type=#{request_content_type} session=#{current_session_name(request)}")

          status api_response.status
          headers api_response.headers.reject { |k,v| configuration.get_excluded_headers(domain(path)).include?(k) }
          body api_response.body
        end

        def set_content_type(request_content_type)
          content_type :json
        end

        def current_session_name(request)
          session = TShield::Sessions.current(request.ip)
          session ? session[:name] : 'no-session'
        end

        def add_headers(headers, path)
          configuration.get_headers(domain(path)).each do |source, destiny| 
            headers[destiny] = request.env[source] unless request.env[source].nil?
          end
        end

        def configuration
          @configuration ||= TShield::Configuration.singleton
        end

        def domain(path)
          @domain ||= configuration.get_domain_for(path)
        end
      end
    end
  end
end

