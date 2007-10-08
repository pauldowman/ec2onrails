class HelloWorldController < ApplicationController
  def index
    render :text => 'Hello world!'
  end
end
