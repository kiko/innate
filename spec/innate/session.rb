require File.expand_path('../../helper', __FILE__)

class SpecSession
  Innate.node('/').provide(:html, :None)

  def index
    'No session here'
  end

  def init
    session[:counter] = 0
  end

  def view
    session[:counter]
  end

  def increment
    session[:counter] += 1
  end

  def decrement
    session[:counter] -= 1
  end

  def reset
    session.clear
  end

  def resid
    session.resid!
  end
  
end

describe Innate::Session do
  behaves_like :rack_test

  should 'initiate session as needed' do
    get '/'
    last_response.body.should == 'No session here'
    last_response['Set-Cookie'].should == nil

    get('/init')
    last_response.body.should == '0'

    1.upto(10) do |n|
      get('/increment').body.should == n.to_s
    end

    get('/reset')
    get('/view').body.should == ''
    get('/init').body.should == '0'

    -1.downto(-10) do |n|
      get('/decrement').body.should == n.to_s
    end
  end
  
  
  should 'set a session cookie that can be changed with #resid!' do
    clear_cookies
    get '/init'
    
    last_response['Set-Cookie'].should.not == nil
    old_set_cookie = last_response['Set-Cookie']
    sid = Innate::Current.session.sid
    get '/increment'
    get '/view'
    last_response.body.should == '1'
    
    get '/resid'
    last_response['Set-Cookie'].should.not == nil
    new_sid = Innate::Current.session.sid
    new_sid.should.not == sid

    get '/view'
    last_response.body.should == '1'
    last_response['Set-Cookie'].should == nil
    Innate::Current.session.sid.should == new_sid

    # We need to verify that the old session ID has been invalidated.
    # The session data must be moved, not copied, on #resid!.
    clear_cookies
    set_cookie(old_set_cookie)
    get '/view'
    last_response.body.should == ''
    
  end
  
  
  should 'expose sid method' do
    Innate::Current.session.sid.should.not.be.empty
  end
end
