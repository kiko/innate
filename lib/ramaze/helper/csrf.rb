require 'securerandom'
require 'digest'

module Ramaze
  module Helper
    ##
    # A relatively basic yet useful helper that can be used to protect your application
    # from CSRF attacks/exploits. Note that this helper merely generates the required data,
    # and provides several methods. You still need to manually add the token to each form.
    #
    # The reason for this is because this is quite simple. Ramaze is meant as a framework that
    # works with any given helper, ORM, template engine and so on. If we were to automatically
    # load this helper and include (a perhaps more advanced) CSRF system that would mean that
    # every form helper, official or third-party, would have to support that specific system.
    # However, there's no need to panic as it's very easy to setup a basic anti CSRF system.
    #
    # == Usage
    #
    # In order to enable CSRF protection we need to do two things. Load the helper and create
    # a before_all block in a controller. Take a look at the following code:
    #
    #  class BaseController < Ramaze::Controller
    #    before_all do
    #      puts "Hello, before_all!"
    #    end
    #  end
    #
    # This would output "Hello, before_all!" to the console upon each request. Not very useful
    # but it does show what the before_all block can do. On to actual CSRF related code!
    #
    #  class BaseController < Ramaze::Controller
    #    before_all do
    #      csrf_protection :save do
    #        # ....
    #      end
    #    end
    #  end
    #
    # This example introduces an extra block that validates the current request.
    # Whenever a user requests a controller that either extends BaseController or has it's own
    # before_all block Ramaze will check if the current request data contains a CSRF token.
    # Of course an if/end isn't very useful if it doesn't do anything, let's add some code.
    #
    #  class BaseController < Ramaze::Controller
    #    before_all do
    #      csrf_protection :save do
    #        puts "Hello, unsafe data!"
    #      end
    #    end
    #  end
    #
    # The code above checks if the current method is "save" (or any other of the provided methods)
    # and checks if an CSRF token is supplied if the method matches. Protected methods require
    # a token in ALL HTTP requests (GET, POST, etc). While this may seem weird since GET is generally
    # used for safe actions it actually makes sence. Ramaze stores both the POST and GET parameters in
    # the request.params hash. While this makes it easy to work with POST/GET data this also makes it
    # easier to spoof POST requests using a GET request, thus this helper protects ALL request methods.
    #
    # If you're a lazy person you can copy-paste the example below and adapt it to your needs.
    #
    #  class BaseController < Ramaze::Controller
    #    before_all do
    #      csrf_protection :save do
    #        respond("The supplied CSRF token is invalid.", 401)
    #      end
    #    end
    #  end
    #
    # @author Yorick Peterse
    #
    module CSRF
      
      ##
      # Method that can be used to protect the specified methods against CSRF exploits.
      # Each protected method will require the token to be stored in a field called "csrf_token".
      # This method will then validate that token against the current token in the session.
      #
      # @author Yorick Peterse
      # @param  [Strings/Symbol] *methods Methods that will be protected/unprotected.
      # @param  [Block] Block that will be executed if the token is invalid.
      # @example
      #
      #  # Protect "create" and "save" against CSRF exploits
      #  before_all do
      #    csrf_protection :create, :save do
      #      respond("GET TO DA CHOPPA!", 401)
      #    end
      #  end
      #
      def csrf_protection *methods, &block
        # Only protect the specified methods
        if methods.include?(action.name) or methods.include?(action.name.to_sym)
          # THINK: For now the field name is hard-coded to "csrf_token". While
          # this is perfectly fine in most cases it might be a good idea
          # to allow developers to change the name of this field (for whatever the reason).
          if validate_csrf_token(request.params['csrf_token']) != true
            yield
          end
        end
      end
      
      ##
      # Generate a new token and create the session array that will be used to validate the client.
      # The following items are stored in the session:
      #
      # * token: An unique hash that will be stored in each form
      # * agent: The visitor's user agent
      # * ip: The IP address of the visitor
      # * time: Timestamp that indicates at what time the data was generated.
      #
      # Note that this method will be automatically called if no CSRF token exists. 
      #
      # @author Yorick Peterse
      # @param  [Hash] Additional arguments that can be set such as the TTL.
      # @return [Void]
      #
      def generate_csrf_token args = {}
        # Default TTL is 15 minutes
        if args[:ttl]
          ttl = args[:ttl]
        else
          ttl = 900
        end
        
        # Generate all the required data
        time    = Time.new.to_i.to_s
        number  = SecureRandom.random_number(10000).to_s
        base64  = SecureRandom.base64.to_s
        token   = Digest::SHA2.new(512).hexdigest(srand.to_s + rand.to_s + time + number + base64).to_s
        
        # Get several details from the client such as the user agent, IP, etc
        ip      = request.env['REMOTE_ADDR']
        agent   = request.env['HTTP_USER_AGENT']
        host    = request.env['REMOTE_HOST']
        
        # Time to store all the data
        session[:_csrf] = {
          :time  => time.to_i,
          :token => token,
          :ip    => ip,
          :agent => agent,
          :host  => host,
          :ttl   => ttl
        }
        
        # Prevent this method from returning any value (it isn't needed anyway)
        return
      end
      
      ##
      # Retrieves the current value of the CSRF token.
      #
      # @author Yorick Peterse
      # @return [String] The current CSRF token.
      # @example
      # 
      #  form(@data, :method => :post) do |f|
      #    f.input_hidden :csrf_token, get_csrf_token()
      #  end
      #
      def get_csrf_token
        if !session[:_csrf] or !self.validate_csrf_token(session[:_csrf][:token])
          self.generate_csrf_token
        end
        
        # Land ho!
        return session[:_csrf][:token]
      end
      
      ##
      # Validates the request based on the current session date stored in _csrf.
      # The following items are verified:
      #
      # * Do the user agent, ip and token match those supplied by the visitor?
      # * Has the token been expired? (after 15 minutes).
      #
      # If any of these checks fail this method will return FALSE. It's your job to
      # take action based on the results of this method.
      #
      # @author Yorick Peterse
      # @param  [String] input_token The CSRF token to validate.
      # @return [Bool]
      # @example
      #
      #  before_all do
      #    if validate_csrf_token(request.params['csrf_token']) != true
      #      respond("Invalid CSRF token", 401)
      #    end
      #  end
      #
      def validate_csrf_token input_token
        # Check if the CSRF data has been generated and generate it if this
        # hasn't been done already (usually on the first request).
        if !session[:_csrf] or session[:_csrf].empty?
          self.generate_csrf_token
        end
        
        # Get several details from the client such as the user agent, IP, etc
        ip      = session[:_csrf][:ip]
        agent   = session[:_csrf][:agent]
        host    = session[:_csrf][:host]
        
        # Get the current time and the time when the token was created
        now         = Time.new.to_i
        token_time  = session[:_csrf][:time]
        
        # Mirror mirror on the wall, who's the most secure of them all?
        results     = Array.new
        results.push( session[:_csrf][:token] == input_token )
        results.push( (now  - token_time) <= session[:_csrf][:ttl] )
        results.push( host  == request.env['REMOTE_HOST'] )
        results.push( ip    == request.env['REMOTE_ADDR'] )
        results.push( agent == request.env['HTTP_USER_AGENT'] )
        
        # Verify the results
        if results.include?(false)
          return false
        else
          return true
        end
      end
      
    end # <-- End of CSRF module
  end
end
