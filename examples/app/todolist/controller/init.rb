module TodoList
  class Controller < Ramaze::Controller
    layout :default
    engine :Etanni

    map '/', :todolist
    app.location = '/'
  end
end

require __DIR__'task'
