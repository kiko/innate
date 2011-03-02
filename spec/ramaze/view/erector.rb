require File.expand_path('../../../../spec/helper', __FILE__)
spec_require 'erector'

# Define what view and layout we'll need to load
Ramaze::App.options.views   = 'erector'
Ramaze::App.options.layouts = 'erector'

##
# Core spec class for the test.
# This class is nothing more than a regular controller but is called using Bacon instead of a browser.
#
class SpecErector < Ramaze::Controller
  # Map the controller to the root of the server.
  map '/'
  
  # Set the engine to Erector. We can't test Erector if we're not using it can we?
  engine :erector
  helper :erector, :thread
  layout :layout
  
  # The index method loads a very basic view in a layout.
  def index
  end
  
  # The tables method loads a view that contains a html table.
  def tables
    @users = [{:name => 'Yorick Peterse', :age => 18}, {:name => 'Chuck Norris', :age => 9000}, {:name => 'Bob Ross', :age => 53}]
  end
  
  # Render a view inside a view
  def view
  end
  
end

# Testing time!
describe Ramaze::View::Erector do
  # The test type is a basic Rack based test.
  behaves_like :rack_test
  
  # Render the index view. This is a basic view wrapped in a layout
  it 'Render a basic layout and view' do
    got = get '/'

    got.status.should.equal 200
    got['Content-Type'].should.equal 'text/html'
    got.body.strip.should.equal '<html><head><title>erector</title></head><body><p>paragraph text</p></body></html>'
  end
  
  # Render the tables view
  it 'Render a view with an HTML table' do
    got = get '/tables'
    
    got.status.should.equal 200
    got['Content-Type'].should.equal 'text/html'
    got.body.strip.should.equal '<html><head><title>erector</title></head><body><table><thead><tr><th>Name</th><th>Age</th></tr></thead><tbody><tr><td>Yorick Peterse</td><td>18</td></tr><tr><td>Chuck Norris</td><td>9000</td></tr><tr><td>Bob Ross</td><td>53</td></tr></tbody></table></body></html>'
  end
  
  # Render a view inside a view
  it 'Render a view inside a view' do
    got = get '/view'
    
    got.status.should.equal 200
    got['Content-Type'].should.equal 'text/html'
    got.body.strip.should.equal '<html><head><title>erector</title></head><body><h2>Hello, view!</h2><p>view body.</p></body></html>'
  end
  
end