module Excon
  module Middleware
    class RedirectFollower < Excon::Middleware::Base
      def response_call(datum)
        if datum.has_key?(:response) && [:get, :head].include?(datum[:method].to_s.downcase.to_sym)
          case datum[:response][:status]
          when 301, 302, 303, 307
            uri_parser = datum[:uri_parser] || Excon.defaults[:uri_parser]
            _, location = datum[:response][:headers].detect do |key, value|
              key.casecmp('Location') == 0
            end
            uri = uri_parser.parse(location)

            # delete old/redirect response
            datum.delete(:response)

            params = datum.dup
            params.delete(:stack)
            params.delete(:connection)
            params[:headers] = datum[:headers].dup
            params[:headers].delete('Authorization')
            params[:headers].delete('Proxy-Connection')
            params[:headers].delete('Proxy-Authorization')
            params[:headers].delete('Host')
            params.merge!(
              :scheme     => uri.scheme || datum[:scheme],
              :host       => uri.host   || datum[:host],
              :port       => uri.port   || datum[:port],
              :path       => uri.path,
              :query      => uri.query,
              :user       => (WEBrick::HTTPUtils.unescape(uri.user) if uri.user),
              :password   => (WEBrick::HTTPUtils.unescape(uri.password) if uri.password)
            )

            response = Excon::Connection.new(params).request
            datum.merge!({:response => response.data})
          else
            @stack.response_call(datum)
          end
        else
          @stack.response_call(datum)
        end
      end
    end
  end
end
