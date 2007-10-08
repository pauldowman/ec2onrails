class SlowController < ApplicationController
  def index
    sleep 1
    render :text => 'Hello world!'
  end
end
