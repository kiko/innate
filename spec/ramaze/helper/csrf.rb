require File.expand_path('../../../../spec/helper', __FILE__)
require 'ramaze/helper/csrf'

##
# A quick note on this controller.
# I decided to user global variables ($foo) instead of sending
# certain data to the "browser", this makes it much easier to compare
# certain values.
#
# - Yorick Peterse
#
class SpecHelperCSRF < Ramaze::Controller
  
  engine :none
  helper :csrf
  
  before_all do
    csrf_protection :check_post, :protect_me do
      respond("The specified CSRF token is incorrect.", 401)
    end
  end

  # Generate a new csrf token
  def index
    generate_csrf_token
  end
  
  # Retrieve the current value of the CSRF token
  def get
    return get_csrf_token
  end
  
  # Check if the token isn't regenerated
  def dont_regenerate
    $token_sess   = session[:_csrf][:token]
    $token_method = get_csrf_token
  end
  
  # Check the TTL
  def check_ttl
    generate_csrf_token :ttl => 3
    $old_token = get_csrf_token
    sleep 4
    $new_token = get_csrf_token
  end
  
  # Check if the before_all block works
  def check_post
    "POST allowed."
  end
  
end

describe Ramaze::Helper::CSRF do
  behaves_like :rack_test
  
  # ------------------------------------------------
  # General validation
  
  it 'Generate a new CSRF token' do
    got = get '/'
    
    got.status.should.equal 200
    got.body.should.equal ''
  end
  
  it 'Retrieve the current CSRF token' do
    got = get '/get'
    
    got.status.should.equal 200
    got.body.length.should.equal 128
  end
  
  # ------------------------------------------------
  # Validate the token expiration
  
  it 'Check if the token is regenerated (it shouldn\'t)' do
    got = get '/dont_regenerate'
    
    got.status.should.equal 200
    $token_sess.should.equal $token_method
  end
  
  it 'Check if the token successfully expires after 3 seconds' do
    got = get '/check_ttl'
    
    got.status.should.equal 200
    $old_token.should.not.equal $new_token
  end
  
  # ------------------------------------------------
  # Validate all HTTP requests (GET, POST, etc)     
  
  it 'Validate all HTTP requests (GET, POST, etc)' do
    methods = [:get, :post, :put, :delete]
    
    methods.each do |method|
      got_invalid = self.send(method, '/check_post', :name => "Yorick Peterse")
      got_valid   = self.send(method, '/check_post', :csrf_token => $new_token)

      got_invalid.status.should.equal 401
      got_invalid.body.should.equal "The specified CSRF token is incorrect."
      
      got_valid.status.should.equal 200
      got_valid.body.should.equal "POST allowed."
    end
  end
  
end
